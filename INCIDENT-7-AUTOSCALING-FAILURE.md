# Incident 7: Autoscaling Failure During Traffic Spike

## Overview

**Incident Type:** Infrastructure Misconfiguration - HPA Wrong Metric Target  
**Severity:** High (P2)  
**User Impact:** Front-end crashes during traffic surge despite autoscaling enabled  
**Root Cause:** HPA configured to monitor memory instead of CPU (front-end bottleneck is CPU-bound)

---

## Incident Description

This incident simulates a **common production error** where autoscaling is deployed but fails during an actual traffic spike due to misconfiguration. The SRE team enabled HorizontalPodAutoscaler (HPA) to handle traffic surges, but configured it to monitor **memory utilization** instead of **CPU utilization**.

**What Happens:**
- Traffic spike occurs (750 concurrent users)
- Front-end CPU climbs to 100% (300m limit exhausted) ← **Actual bottleneck**
- Memory usage remains at 60-70% (well below limits) ← Stable
- HPA monitors memory: 60% < 80% threshold → Sees no scaling needed
- Front-end pods crash (OOMKilled from CPU throttling)
- Replica count stays at 1 (autoscaling never triggers)

**Critical Observation:** HPA appears healthy in `kubectl get hpa` output, showing green status with valid metrics. The infrastructure is working as configured—it's just configured wrong.

**Business Impact:**
- Black Friday sale experiences outage
- Customers unable to complete checkouts
- Revenue loss during peak traffic window
- HPA was meant to prevent exactly this scenario

---

## Prerequisites

### Verify Metrics Server Installed

```powershell
# Check metrics-server (required for HPA)
kubectl get deployment metrics-server -n kube-system

# Expected: metrics-server 1/1 READY

# Verify metrics API works
kubectl top nodes

# Expected: CPU/Memory metrics displayed
```

### Verify Front-End Baseline

```powershell
# Check deployment
kubectl -n sock-shop get deployment front-end

# Expected: 1/1 READY

# Check NO HPA exists
kubectl -n sock-shop get hpa

# Expected: No resources found

# Baseline CPU/Memory
kubectl top pods -n sock-shop -l name=front-end

# Expected: CPU ~5m, Memory ~66Mi
```

---

## Incident Execution

### Step 1: Deploy Broken HPA (Monitors Memory)

```powershell
# Apply misconfigured HPA
kubectl apply -f D:\sock-shop-demo\incident-7-broken-hpa.yaml

# Verify HPA created
kubectl -n sock-shop get hpa

# Expected Output:
# NAME                    REFERENCE              TARGETS   MINPODS   MAXPODS   REPLICAS
# front-end-hpa-broken    Deployment/front-end   6%/80%    1         10        1
#                                                ↑ Memory usage (6%), not CPU!
```

### Step 2: Inspect HPA Configuration

```powershell
kubectl -n sock-shop describe hpa front-end-hpa-broken

# Key Output:
# Metrics:
#   Resource memory on pods:  6% / 80%
# ❌ Monitoring memory instead of CPU!
```

### Step 3: Generate High CPU Load

```powershell
# Apply 750-user load test
kubectl apply -f D:\sock-shop-demo\load\locust-hybrid-crash-test.yaml

# Wait for load test to start
kubectl -n sock-shop get pods -l job-name=locust-hybrid-crash-test -w

# Press Ctrl+C when Running
```

---

## Observation Phase

### Terminal 1: Watch Pods (Expect Crashes)

```powershell
kubectl -n sock-shop get pods -l name=front-end -w

# Expected Timeline:
# T+0:30  front-end-xxxxx  1/1  Running  0  (Load increasing)
# T+1:00  front-end-xxxxx  1/1  Running  0  (CPU at 100%)
# T+2:00  front-end-xxxxx  0/1  Running  1  (OOMKilled - RESTARTED)
# T+3:00  front-end-xxxxx  0/1  Running  2  (RESTARTED AGAIN)

# 🔴 KEY: Replicas NEVER increase (stays at 1)
```

### Terminal 2: Watch HPA (Expect NO Scaling)

```powershell
kubectl -n sock-shop get hpa front-end-hpa-broken -w

# Expected:
# NAME                    TARGETS   REPLICAS
# front-end-hpa-broken    6%/80%    1
# front-end-hpa-broken    8%/80%    1  (No change!)

# 🔴 KEY: Memory 6-8% (far below 80%)
```

### Terminal 3: Monitor CPU (Expect 100%)

```powershell
while ($true) {
    Clear-Host
    Write-Host "FRONT-END MONITORING" -ForegroundColor Cyan
    kubectl top pods -n sock-shop -l name=front-end
    Start-Sleep -Seconds 5
}

# Expected:
# CPU: 298m (AT 300m LIMIT!)
# Memory: 280Mi (Only 28% of 1000Mi limit)
```

---

## Datadog Monitoring & Investigation

### Query 1: Front-End CPU Saturation

**Datadog Metric Explorer:**
```
Metric: kubernetes.cpu.usage.total{kube_deployment:front-end}
Time Range: Last 15 minutes
```

**What You See:**
```
Graph showing:
Before incident: 0.005-0.010 cores (5-10m)
During incident: 0.298-0.300 cores (298-300m) ← AT 300m LIMIT
Pattern: Sustained at 100% of limit for 3+ minutes
```

---

### Query 2: Front-End Memory Usage (Normal)

**Datadog Metric Explorer:**
```
Metric: kubernetes.memory.usage{kube_deployment:front-end}
Time Range: Last 15 minutes
```

**What You See:**
```
Graph showing:
Before incident: 180-200Mi
During incident: 250-350Mi (only 25-35% of 1000Mi limit)
Pattern: Stable, well below limits
```

---

### Query 3: Replica Count Not Scaling

**Datadog Metric Explorer:**
```
Metric: kubernetes_state.deployment.replicas_available{kube_deployment:front-end}
Time Range: Last 15 minutes
```

**What You See:**
```
Graph showing:
Flat line at 1 replica throughout entire incident
No increase despite high CPU
```

---

### Query 4: HPA Configuration

**Datadog Metric Explorer:**
```
Metric: kubernetes_state.horizontalpodautoscaler.spec_target_metric
Filter: kube_hpa:front-end-hpa-broken, kube_namespace:sock-shop
```

**What You See:**
```
metric_name: memory
metric_target_type: Utilization
metric_target_value: 80
```

**vs Expected for CPU scaling:**
```
metric_name: cpu
metric_target_value: 70
```

---

### Query 5: HPA Current vs Target

**Datadog Metrics:**
```
Metric 1: kubernetes_state.horizontalpodautoscaler.metric.current{kube_hpa:front-end-hpa-broken}
Metric 2: kubernetes_state.horizontalpodautoscaler.metric.target{kube_hpa:front-end-hpa-broken}
```

**What You See:**
```
Current: 6-8 (6-8% memory utilization)
Target: 80 (80% threshold)
Calculation: 8% < 80% → HPA determines NO SCALING NEEDED
```

---

### Query 6: Kubernetes Events (ScaleUp Missing)

**Datadog Events:**
```
Query: source:kubernetes tags:(kube_namespace:sock-shop,kube_hpa:front-end-hpa-broken)
Filter: "ScaledUp" OR "SuccessfulRescale"
```

**What You See:**
```
NO EVENTS FOUND (during 15-minute incident window)

Expected for working HPA:
- "Scaled up deployment front-end from 1 to 5"
- "SuccessfulRescale"
```

---

### Query 7: Front-End Pod Crashes

**Datadog Logs:**
```
Query: kube_namespace:sock-shop service:sock-shop-front-end (error OR FATAL OR memory)
```

**What You See:**
```
[timestamp] ERROR Request timeout after 30000ms
[timestamp] FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed
[timestamp] ERROR JavaScript heap out of memory
[timestamp] npm ERR! errno 1
[timestamp] npm ERR! Exit status 1
```

**Datadog Events:**
```
Query: source:kubernetes "front-end" (OOMKilled OR Killing OR Unhealthy)
```

**What You See:**
```
Killing container with id docker://front-end reason:OOMKilled
Back-off restarting failed container front-end in pod front-end-xxxxx
Liveness probe failed: Get "http://10.244.x.x:8079/": context deadline exceeded
```

---

### Query 8: Pod Restart Count Increase

**Datadog Metric:**
```
Metric: kubernetes.containers.restarts{kube_deployment:front-end}
Time Range: Last 15 minutes
```

**What You See:**
```
Graph showing:
Before incident: Flat line (e.g., 17 restarts)
During incident: Step increases (17 → 18 → 19 → 20 → 21)
Total: 4-5 new restarts during incident window
```

---

### Log Correlation Timeline

**Combined Datadog Query:**
```
kube_namespace:sock-shop (kube_deployment:front-end OR kube_hpa:front-end-hpa-broken)
```

**What You See (Chronological):**
```
[T+0:00] HPA created with memory target
[T+0:05] Load test started (750 users)
[T+0:30] front-end CPU: 150m (50% utilization)
[T+1:00] front-end CPU: 300m (100% utilization) ← AT LIMIT
[T+1:00] front-end memory: 280Mi (28% utilization)
[T+1:00] HPA: Current 28% < Target 80% → No action
[T+2:00] front-end pod OOMKilled (restart 1)
[T+2:15] front-end CPU: 300m again (100% utilization)
[T+2:15] HPA: Still no scaling (memory still low)
[T+3:00] front-end pod OOMKilled (restart 2)
[T+3:15] front-end CPU: 300m again (100% utilization)
[T+3:15] HPA replicas: Still 1 (never increased)
```

---

## Recovery Steps

### Step 1: Stop Load Test

```powershell
kubectl -n sock-shop delete job locust-hybrid-crash-test
kubectl -n sock-shop delete configmap locustfile-hybrid-crash
```

### Step 2: Delete Broken HPA

```powershell
kubectl -n sock-shop delete hpa front-end-hpa-broken

# Verify deletion
kubectl -n sock-shop get hpa
# Expected: No resources found
```

### Step 3: Deploy Correct HPA

```powershell
# Apply fixed HPA (monitors CPU)
kubectl apply -f D:\sock-shop-demo\incident-7-correct-hpa.yaml

# Verify configuration
kubectl -n sock-shop get hpa front-end-hpa-fixed

# Expected Output:
# NAME                   REFERENCE              TARGETS   MINPODS   MAXPODS   REPLICAS
# front-end-hpa-fixed    Deployment/front-end   1%/70%    1         10        1
#                                               ↑ Now shows CPU usage!
```

### Step 4: Verify HPA Details

```powershell
kubectl -n sock-shop describe hpa front-end-hpa-fixed

# Expected:
# Metrics:
#   Resource cpu on pods:  1% / 70%
# ✅ CORRECT: Monitoring CPU!
```

---

## Verification: Test Autoscaling Works

### Step 5: Generate Load Again

```powershell
# Re-apply load test
kubectl apply -f D:\sock-shop-demo\load\locust-hybrid-crash-test.yaml
```

### Step 6: Watch HPA Scale Up

**Terminal 1: HPA Status**
```powershell
kubectl -n sock-shop get hpa front-end-hpa-fixed -w

# Expected Progression:
# T+0:30  TARGETS: 45%/70%   REPLICAS: 1  (Load increasing)
# T+1:00  TARGETS: 85%/70%   REPLICAS: 1  (Above threshold!)
# T+1:15  TARGETS: 85%/70%   REPLICAS: 5  (✅ SCALED UP!)
# T+1:45  TARGETS: 90%/70%   REPLICAS: 8  (✅ SCALED MORE!)
# T+2:00  TARGETS: 40%/70%   REPLICAS: 8  (Load distributed - stable!)

# 🟢 KEY: Replicas increase 1 → 8
```

**Terminal 2: Pods**
```powershell
kubectl -n sock-shop get pods -l name=front-end -w

# Expected:
# front-end-xxxxx-aaa  1/1  Running  0
# front-end-xxxxx-bbb  0/1  Pending  0  (New pod 1)
# front-end-xxxxx-bbb  1/1  Running  0
# front-end-xxxxx-ccc  0/1  Pending  0  (New pod 2)
# ... (up to 8 total replicas)

# 🟢 KEY: Multiple new pods, NO RESTARTS
```

**Terminal 3: CPU Distribution**
```powershell
kubectl top pods -n sock-shop -l name=front-end

# Expected (8 replicas):
# NAME                    CPU    MEMORY
# front-end-xxxxx-aaa     40m    280Mi
# front-end-xxxxx-bbb     42m    265Mi
# front-end-xxxxx-ccc     38m    270Mi
# ... (8 pods total)

# 🟢 CPU distributed: ~40m per pod (NOT 300m on one pod)
```

### Step 7: Verify Performance Recovered

```powershell
# Test response time
Measure-Command { 
    Invoke-WebRequest -UseBasicParsing http://localhost:2025/catalogue -TimeoutSec 10 
} | Select-Object TotalMilliseconds

# Expected: 200-600ms (vs 30,000ms during incident)

# Check no new restarts
kubectl -n sock-shop get pods -l name=front-end

# Expected: All new pods show 0 restarts
```

### Step 8: Monitor Scale Down

```powershell
# After load stops, HPA scales down gradually
kubectl -n sock-shop get hpa front-end-hpa-fixed -w

# Expected (after ~5 minutes):
# T+10:00  TARGETS: 8%/70%    REPLICAS: 8  (Load stopped)
# T+15:30  TARGETS: 3%/70%    REPLICAS: 4  (Scaled down)
# T+25:00  TARGETS: 1%/70%    REPLICAS: 1  (Back to baseline)

# Scale-down has 5-minute stabilization window
```

### Step 9: Cleanup

```powershell
# Remove load test
kubectl -n sock-shop delete job locust-hybrid-crash-test
kubectl -n sock-shop delete configmap locustfile-hybrid-crash

# HPA can remain deployed for future protection
# Or remove if testing other incidents:
# kubectl -n sock-shop delete hpa front-end-hpa-fixed
```

---

## Technical Notes

### Front-End Resource Profile

**Under Normal Load (50-100 users):**
- CPU: 5-15m (2-5% of 300m limit)
- Memory: 180-250Mi (18-25% of 1000Mi limit)

**Under High Load (750 users):**
- CPU: 300m (100% of limit) ← **Bottleneck**
- Memory: 250-350Mi (25-35% of limit) ← Still healthy

**Why CPU-bound:**
- Node.js single-threaded event loop
- Server-side rendering (CPU-intensive)
- HTTP connection handling
- Template processing

**Why Memory Stable:**
- V8 garbage collection keeps heap < 700Mi
- Session data stored in Redis (not in-process)
- Request buffering uses bounded queues

### HPA Scaling Behavior

**Broken Configuration (Memory-based):**
```
Current: 8% memory usage
Target: 80% memory threshold
Calculation: 8% < 80% → No scaling needed
Result: HPA does nothing, pods crash from CPU exhaustion
```

**Correct Configuration (CPU-based):**
```
Current: 99% CPU usage
Target: 70% CPU threshold
Calculation: 99% > 70% → Scaling needed
Result: HPA scales 1 → 2 → 4 → 8 replicas until CPU < 70%
```

### Metrics Server Requirement

**Purpose:** Provides resource metrics API for HPA to query pod CPU/memory usage

**Status in Your Cluster:** Already installed (v0.8.0, 9+ days ago)

**Verification:**
```powershell
kubectl get deployment metrics-server -n kube-system
# Expected: 1/1 READY
```

---

## Key Learnings

**For Production SRE Teams:**
1. ✅ Verify HPA monitors the actual bottleneck resource
2. ✅ Load test autoscaling behavior BEFORE production traffic spikes
3. ✅ Monitor HPA current metrics vs configured thresholds
4. ✅ Include HPA configuration review in deployment checklists
5. ✅ Set alerts for: HPA exists + High resource usage + No scaling events

---

## Troubleshooting

### Issue 1: HPA Shows `<unknown>`

**Symptom:**
```
NAME        TARGETS      REPLICAS
front-end   <unknown>    1
```

**Diagnosis:**
```powershell
# Check if metrics-server running
kubectl get deployment metrics-server -n kube-system

# If not found, install:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For KIND clusters, add --kubelet-insecure-tls flag
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'
```

### Issue 2: HPA Doesn't Scale Despite High CPU

**Check:**
1. Verify metrics-server is working: `kubectl top pods`
2. Check HPA conditions: `kubectl describe hpa`
3. Verify resource requests are set (HPA needs requests for percentage calculation)
4. Check HPA target metric type (CPU vs Memory)

### Issue 3: Pods Scale But App Still Slow

**Possible Causes:**
- Database bottleneck (check `kubectl top pods` for DB pods)
- Network latency (check service-to-service communication)
- Incorrect HPA threshold (too high, scales too late)

---

**Test Date:** November 5, 2025  
**Environment:** KIND cluster (sockshop) with Datadog agent  
**Metrics Server:** v0.8.0 (pre-installed)  
**Front-End Image:** quay.io/powercloud/sock-shop-front-end:v1.1-error-fix  

---
