# Incident 4: Pure Application Latency (Performance Degradation)

## Overview

**Incident Type:** Performance Degradation Due to Resource Pressure  
**Severity:** High (P2)  
**User Impact:** Slow response times, frustrating but functional user experience  
**Root Cause:** CPU/Memory pressure causing request queuing and slow processing, NO CRASHES

## Incident Description

When the Sock Shop application experiences 500 concurrent users, it exhibits **pure performance degradation WITHOUT crashes**:
- **All Services:** Remain stable and running (0 restarts)
- **Response times:** Increase to 2-5 seconds (vs 150ms normal)
- **Failure rate:** Low (< 5-10%) - application still working
- **CPU throttling:** Causes request queuing but not exhaustion
- **Users experience:** Frustrating slowness but can complete purchases

This simulates a realistic early-warning scenario where an e-commerce site experiences higher-than-normal traffic (e.g., weekend sales, marketing campaign) and becomes slow but doesn't completely fail. This is what you want to detect and respond to **BEFORE** it escalates to crashes.

**Key Differences:**
- **Incident 1 (3000 users):** Complete system-wide crash, all pods restart, total outage
- **Incident 2 (750 users):** Frontend crashes + backend latency, intermittent availability (HYBRID)
- **Incident 4 (500 users):** Pure latency, NO crashes, slow but fully functional (THIS)

**Why This Matters:** Detecting and responding to Incident 4-level degradation prevents escalation to Incident 2 (crashes). This is the golden window for scaling or optimization.

---

## Application Performance Thresholds

### Load vs. Performance Profile

| User Count | Response Time | CPU Usage | Status | User Experience | Pod Restarts |
|------------|---------------|-----------|--------|-----------------|--------------|
| 50-100 | < 200ms | 10-30% | ✅ Healthy | Excellent | 0 |
| 200-400 | 200-800ms | 40-60% | ⚠️ Warning | Acceptable | 0 |
| **500** | **2-5 seconds** | **70-85%** | 🔴 **Degraded** | **Slow (THIS)** | **0** |
| 750 | 20-25 seconds | 80-95% | 🔴💀 HYBRID | Crashes + Latency | 5-10 |
| 1500+ | Timeouts | 100% | 💀 Crash | Unusable | Many |

### Target Metrics for This Incident

| Metric | Normal | During Incident | Alert Threshold |
|--------|--------|-----------------|-----------------|
| **Response Time (avg)** | 150ms | **2-5 seconds** | > 1 second |
| **Failure Rate** | < 0.1% | **< 10%** | > 5% |
| **CPU Usage** | 5-15% | 70-85% | > 65% |
| **Memory Usage** | 20-40% | 50-70% | > 60% |
| **Pod Restarts** | 0 | **0 (NO CRASHES)** | > 0 |
| **Request Queue Depth** | 0-5 | 20-50 | > 15 |

**Note:** The 500 user load produces MODERATE degradation (2-5 second response times, <10% failure rate) demonstrating early warning signs BEFORE crashes occur.

---

## Pre-Incident Checklist

### 1. Verify Application Baseline Performance

```powershell
# Ensure all pods are running
kubectl -n sock-shop get pods

# Expected Output: All pods 1/1 READY, Running, 0 restarts
```

### 2. Capture Baseline Metrics

```powershell
# Baseline resource usage
kubectl top pods -n sock-shop

# Expected Output (Normal Load):
# NAME                            CPU(cores)   MEMORY(bytes)
# front-end-xxxxx                 3-8m         150-200Mi
# user-xxxxx                      1-3m         80-120Mi
# orders-xxxxx                    5-8m         200-250Mi
# carts-xxxxx                     2-4m         120-150Mi
# payment-xxxxx                   1-2m         50-80Mi
```

### 3. Test Baseline Response Time

```powershell
# Measure response time (should be fast)
Measure-Command { Invoke-WebRequest -UseBasicParsing http://localhost:2025/catalogue -TimeoutSec 10 } | Select-Object TotalMilliseconds

# Expected Output: ~100-300ms
```

### 4. Record Baseline Restart Counts

```powershell
# Record current restart counts
kubectl -n sock-shop get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# Save this - we should see NO new restarts after the test
```

---

## Incident Execution Steps

### Step 1: Deploy Locust Load Generator (Pure Latency - 500 Users)

The YAML file already exists at `d:\sock-shop-demo\load\locust-pure-latency-test.yaml`:

```powershell
# Navigate to load directory
cd d:\sock-shop-demo\load

# Apply the configuration
kubectl apply -f .\locust-pure-latency-test.yaml
```

**Expected Output:**
```
configmap/locustfile-pure-latency created
job.batch/locust-pure-latency-test created
```

### Step 2: Monitor Job Startup

```powershell
# Watch the job start
kubectl -n sock-shop get pods -l app=locust-pure-latency

# Expected Output:
# NAME                              READY   STATUS    RESTARTS   AGE
# locust-pure-latency-test-xxxxx    1/1     Running   0          15s
```

### Step 3: Monitor Real-Time Latency Impact

Open multiple PowerShell windows for comprehensive monitoring:

#### Window 1: Monitor Response Times (Live Test)
```powershell
# Continuously test response time every 10 seconds
while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    try {
        $elapsed = (Measure-Command { 
            Invoke-WebRequest -UseBasicParsing http://localhost:2025/catalogue -TimeoutSec 10 
        }).TotalMilliseconds
        
        $color = if ($elapsed -lt 500) { "Green" } 
                 elseif ($elapsed -lt 2000) { "Yellow" } 
                 else { "Red" }
        
        Write-Host "[$timestamp] Response Time: " -NoNewline
        Write-Host "$([math]::Round($elapsed))ms" -ForegroundColor $color
    }
    catch {
        Write-Host "[$timestamp] ERROR: $_" -ForegroundColor Red
    }
    Start-Sleep -Seconds 10
}
```

**Expected Progression (NO CRASHES):**
```
# T+0s: Baseline (before load)
[13:00:00] Response Time: 120ms        (Green)

# T+60s: Load ramping up
[13:01:00] Response Time: 650ms        (Yellow)

# T+120s: Moderate load established
[13:02:00] Response Time: 1,950ms      (Yellow/Red)

# T+180s: Peak latency (but still functional)
[13:03:00] Response Time: 2,800ms      (Red)
[13:03:10] Response Time: 3,200ms      (Red)
[13:03:20] Response Time: 2,950ms      (Red)

# T+240s: Sustained slow performance (NO CRASHES!)
[13:04:00] Response Time: 3,100ms      (Red)
```

#### Window 2: Monitor Resource Usage
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== RESOURCE USAGE MONITOR (PURE LATENCY - NO CRASHES) ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'HH:mm:ss')`n" -ForegroundColor Yellow
    
    kubectl top pods -n sock-shop --no-headers | ForEach-Object {
        $parts = $_ -split '\s+'
        $pod = $parts[0]
        $cpu = $parts[1]
        $mem = $parts[2]
        
        # Color code based on resource usage
        $cpuNum = [int]($cpu -replace '[^0-9]','')
        $color = if ($cpuNum -lt 100) { "Green" } 
                 elseif ($cpuNum -lt 200) { "Yellow" } 
                 else { "Red" }
        
        Write-Host "$pod" -NoNewline
        Write-Host " | CPU: " -NoNewline
        Write-Host "$cpu" -ForegroundColor $color -NoNewline
        Write-Host " | MEM: $mem"
    }
    
    Start-Sleep -Seconds 5
}
```

**Expected Progression (CPU high but stable):**
```
=== RESOURCE USAGE MONITOR (PURE LATENCY - NO CRASHES) ===
Timestamp: 13:00:00

front-end-xxxxx | CPU: 8m | MEM: 180Mi       (Green - normal)

# T+60s: Load building
Timestamp: 13:01:00
front-end-xxxxx | CPU: 95m | MEM: 350Mi      (Green - manageable)

# T+120s: High but not critical
Timestamp: 13:02:00
front-end-xxxxx | CPU: 185m | MEM: 550Mi     (Yellow - stressed but stable)
user-xxxxx      | CPU: 120m | MEM: 140Mi     (Yellow)

# T+180s: Sustained pressure (high but NO crashes!)
Timestamp: 13:03:00
front-end-xxxxx | CPU: 220m | MEM: 650Mi     (Yellow/Red - throttled but running)
user-xxxxx      | CPU: 180m | MEM: 160Mi     (Yellow - stable)
orders-xxxxx    | CPU: 210m | MEM: 380Mi     (Yellow - stable)
```

**Key Observation:** CPU stays below crash threshold, pods remain Running (0 restarts)

#### Window 3: Monitor Pod Status (CRITICAL - Verify NO CRASHES!)
```powershell
kubectl -n sock-shop get pods -w
```

**Expected Output:**
```
# ALL pods remain 1/1 Running throughout the incident
NAME                            READY   STATUS    RESTARTS   AGE
front-end-xxxxx                 1/1     Running   0          45m  ✅ NO NEW RESTARTS!
user-xxxxx                      1/1     Running   0          45m  ✅ NO NEW RESTARTS!
orders-xxxxx                    1/1     Running   0          45m  ✅ NO NEW RESTARTS!
payment-xxxxx                   1/1     Running   0          45m  ✅ NO NEW RESTARTS!
carts-xxxxx                     1/1     Running   0          45m  ✅ NO NEW RESTARTS!

# NO CrashLoopBackOff! NO OOMKilled! ALL SERVICES STAY RUNNING!
```

#### Window 4: Monitor Locust Statistics
```powershell
kubectl -n sock-shop logs -f job/locust-pure-latency-test
```

**Expected Output:**
```
==========================================
INCIDENT 4: PURE LATENCY TEST - STARTING
Target: http://front-end.sock-shop.svc.cluster.local
Users: 500 | Spawn Rate: 40
Duration: 8m
Goal: Pure latency (slow but NO crashes)
==========================================
[2025-10-30 13:00:10] Starting Locust 2.32.1
[2025-10-30 13:00:15] Ramping to 500 users at a rate of 40 per second...
[2025-10-30 13:00:25] All 500 users spawned

# Statistics showing LATENCY with LOW failure rate
Type     Name                    # reqs   # fails  Avg     Min   Max    Med    req/s
------------------------------------------------------------------------------------
GET      Browse Catalogue        18,456   892     2,845   110   7,200  2,700  62.5
GET      View Item               11,234   567     2,650   105   6,800  2,500  38.2
GET      View Cart                7,890   234     2,350   98    6,200  2,200  26.8
GET      Login Page               3,987   123     2,180   95    5,900  2,100  13.5
------------------------------------------------------------------------------------
Aggregated                       41,567  1,816    2,634   95    7,200  2,500  141.0

# LOW failure rate (~4.4%) but HIGH response time (2.6s) - SLOW BUT WORKING!
Current failures: 4.4%           ✅ Application still functional!
Average response time: 2,634ms   🔴 Slow but acceptable
```

**Key Metrics:**
- ✅ Failure rate LOW (< 5%) - Application still working
- 🔴 Response time HIGH (2-3 seconds) - Users experiencing slowness  
- ✅ Request rate STABLE - No service crashes
- ✅ Pod restarts: 0 - All services remain running

---

## Datadog Monitoring & Investigation

### Step 1: View Metrics in Datadog

#### Query 1: CPU Usage (Should be high but not critical)
```
Metric: kubernetes.cpu.usage.total
Filter: kube_namespace:sock-shop
Aggregation: avg by pod_name
```

**Expected:** Frontend 180-220m, backends 120-180m (high but below crash threshold)

#### Query 2: Memory Usage (Should be elevated but stable)
```
Metric: kubernetes.memory.usage
Filter: kube_namespace:sock-shop
Aggregation: avg by pod_name
```

**Expected:** Frontend 500-650Mi, backends 300-400Mi (pressure but not OOMKill territory)

#### Query 3: Container Restarts (CRITICAL - Should be ZERO!)
```
Metric: kubernetes.containers.restarts
Filter: kube_namespace:sock-shop
Aggregation: sum by pod_name
```

**Expected:** FLAT LINE - NO increases during test window! ✅

### Step 2: View Logs in Datadog

#### Query 1: Locust Test Statistics
```
kube_namespace:sock-shop service:locust-pure-latency
```

**Expected:** Logs showing 2-5 second response times, <5% failure rate

#### Query 2: Application Service Logs (Should show slow but successful requests)
```
kube_namespace:sock-shop (service:sock-shop-front-end OR service:sock-shop-catalogue)
```

**Expected:** Slow response warnings but NO crash/restart messages

---

## Recovery Steps

### Step 1: Stop the Load Generator

```powershell
# Delete the Locust job
kubectl -n sock-shop delete job locust-pure-latency-test

# Delete ConfigMap
kubectl -n sock-shop delete configmap locustfile-pure-latency

# Verify cleanup
kubectl -n sock-shop get pods -l app=locust-pure-latency
```

**Expected Output:**
```
job.batch "locust-pure-latency-test" deleted
configmap "locustfile-pure-latency" deleted
No resources found in sock-shop namespace.
```

### Step 2: Monitor Performance Recovery

```powershell
# Watch response time normalize
while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    try {
        $elapsed = (Measure-Command { 
            Invoke-WebRequest -UseBasicParsing http://localhost:2025/catalogue -TimeoutSec 10 
        }).TotalMilliseconds
        
        $color = if ($elapsed -lt 500) { "Green" } else { "Yellow" }
        Write-Host "[$timestamp] Response Time: $([math]::Round($elapsed))ms" -ForegroundColor $color
        
        if ($elapsed -lt 300) {
            Write-Host "`n✅ Performance RECOVERED! Response time back to normal.`n" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "[$timestamp] ERROR: $_" -ForegroundColor Red
    }
    Start-Sleep -Seconds 5
}
```

**Expected Recovery Timeline (FASTER than Incident 2 - no crashes to recover from!):**
```
[13:08:00] Response Time: 2,800ms     (Still slow - load just stopped)
[13:08:10] Response Time: 1,200ms     (Improving fast)
[13:08:20] Response Time: 650ms       (Almost there)
[13:08:30] Response Time: 280ms       (Normal)
[13:08:40] Response Time: 150ms       (RECOVERED)

✅ Performance RECOVERED! Response time back to normal.
```

### Step 3: Verify NO Pod Restarts (CRITICAL CHECK)

```powershell
kubectl -n sock-shop get pods
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS         AGE
front-end-xxxxx                 1/1     Running   17 (XX ago)      XXh    ✅ No new restarts!
carts-xxxxx                     1/1     Running   13 (XXh ago)     XXd    ✅ No new restarts!
catalogue-xxxxx                 1/1     Running   9 (XXh ago)      XXd    ✅ No new restarts!
user-xxxxx                      1/1     Running   9 (XXh ago)      XXd    ✅ No new restarts!
orders-xxxxx                    1/1     Running   13 (XXh ago)     XXd    ✅ No new restarts!
payment-xxxxx                   1/1     Running   9 (XXh ago)      XXd    ✅ No new restarts!
```

**Critical Finding:** ALL restart counts should be UNCHANGED from baseline! Restart timestamps should be OLDER than the test start time.

---

## Post-Incident Analysis

### Incident Summary

**Duration:** ~10 minutes (8m load + 2m recovery)  
**Peak Response Time:** 2,500-3,500ms average (2.5-3.5 seconds)  
**Failure Rate:** < 5% (application remained functional)  
**Pod Restarts:** **0 across ALL services** ✅  
**User Impact:** Frustrating slowness but transactions complete successfully  

**Incident Type:** PURE LATENCY - Performance degradation WITHOUT crashes

### Root Cause

**Primary:** Resource pressure (CPU/Memory) at 500 concurrent users causes request queuing and slow processing, but does NOT exceed capacity limits that would trigger crashes.

**Why No Crashes Occurred:**
1. **Load below crash threshold**: 500 users vs 750 (Incident 2) or 3000 (Incident 1)
2. **Resource headroom**: Services throttled but not exhausted
3. **Graceful degradation**: Application slows down but continues functioning
4. **Connection handling**: Frontend can maintain 500 connections without exhaustion

### Evidence Collected

1. **Metrics (from Datadog):**
   - Average response time: 2,500-3,500ms (baseline: 150ms)
   - CPU usage: 70-85% (high but sustainable)
   - Memory usage: 50-70% (pressure but not critical)
   - **Pod restarts: 0** ✅ (NO CRASHES)

2. **Logs (from Datadog & kubectl):**
   - Slow response warnings (2-5 second responses)
   - Low failure rate (<5%)
   - No crash/restart messages
   - Health checks passing (slow but passing)

3. **Pod Behavior (from kubectl):**
   - **ALL pods: 0 new restarts** ✅
   - All pods remained 1/1 Running
   - No CrashLoopBackOff events
   - No OOMKilled events

### Comparison with Incidents 1, 2, and 4

| Metric | Incident 1 (3000) | Incident 2 (750) | Incident 4 (500) |
|--------|-------------------|------------------|------------------|
| **User Load** | 3000 users | 750 users | 500 users |
| **Frontend Restarts** | Continuous | 5-10 crashes | **0** ✅ |
| **Backend Restarts** | Multiple | 0 | **0** ✅ |
| **Response Time** | Timeouts | 9-13 seconds | **2-3 seconds** |
| **Failure Rate** | 98-99% | 87% | **<5%** |
| **User Impact** | Complete outage | Intermittent | **Slow but works** |
| **Pod Status** | CrashLoopBackOff | Frontend crashes | **All Running** ✅ |
| **Recovery** | Manual intervention | Automatic | **Immediate** |
| **Root Cause** | OOMKill | Frontend exhaustion | **CPU throttling** |
| **Detection Window** | Too late | During crisis | **EARLY WARNING** ✅ |

**Key Insight:** Incident 4 represents the **IDEAL DETECTION POINT** - catching performance issues BEFORE they escalate to crashes. This is when you should scale or optimize!

---

## Recommended Actions (Production)

### Immediate Response (When Detecting Incident 4 Pattern)

**1. Scale horizontally BEFORE crashes occur:**
```bash
# Add more frontend replicas
kubectl -n sock-shop scale deployment front-end --replicas=3

# Add more backend replicas if needed
kubectl -n sock-shop scale deployment user --replicas=2
kubectl -n sock-shop scale deployment catalogue --replicas=2
```

**2. Implement Horizontal Pod Autoscaling (HPA) for prevention:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: front-end-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: front-end
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # Scale BEFORE reaching 70-80%
```

**3. Set up alerting at Incident 4 thresholds:**
- Response time > 1 second for 2 minutes → WARNING
- Response time > 2 seconds for 5 minutes → CRITICAL (scale NOW!)
- CPU > 65% for 5 minutes → WARNING (scale proactively)

### Why This Matters

**Incident 4 is your early warning system:**
- ✅ Detected BEFORE crashes
- ✅ Time to scale proactively
- ✅ Users frustrated but not blocked
- ✅ Revenue still flowing
- ✅ No downtime to recover from

**Incident 2 (750 users) is when you've MISSED the window:**
- ❌ Already crashing
- ❌ Intermittent availability
- ❌ Users blocked from transactions
- ❌ Revenue loss during crashes
- ❌ Requires recovery time

---

## Expected Outcomes - ACTUAL RESULTS

### During Incident (500 Users, 8 Minutes)
✅ **Response times:** 2-3 seconds average (slow but acceptable)  
✅ **Failure rate:** < 5% (application remains functional)  
✅ **CPU usage:** 70-85% (high but sustainable)  
✅ **Memory usage:** 50-70% (pressure but not critical)  
✅ **Pod restarts:** **0 across ALL services** (NO CRASHES!)  
✅ **Pod status:** All remain 1/1 Running (no CrashLoopBackOff)  
✅ **User experience:** Slow and frustrating but functional  

**Incident Classification:** PURE LATENCY (early warning stage)

### After Recovery (Load Stops)
✅ Response times return to < 300ms within 30-60 seconds (faster than Incident 2)  
✅ CPU usage returns to baseline (1-8m)  
✅ Memory usage stable at baseline (150-400Mi)  
✅ **NO pod restarts to count** (none occurred)  
✅ Application fully functional  

---

## Summary

This incident demonstrates **pure performance degradation** - the IDEAL failure mode to detect and respond to:

### What Happened at 500 Users

**System Behavior:**
- All services remained stable (0 restarts)
- Response times increased to 2-5 seconds
- Low failure rate (<5%) - application still working
- CPU/Memory high but sustainable
- Users frustrated but able to complete transactions

### Why This Is Valuable

**Early Warning Detection:**
1. **Prevents escalation** - Catch issues before crashes (Incident 2)
2. **Proactive scaling** - Scale BEFORE user impact becomes severe
3. **No downtime** - No crashes to recover from
4. **Revenue protection** - Users can still transact (slowly)

**Production Response:**
- This is when you trigger horizontal scaling
- This is when you implement rate limiting
- This is when you enable caching
- This is the GOLDEN WINDOW for SRE action

### Key Learning

**Incident 4 (Pure Latency) → Scale proactively → Prevent Incident 2 (Crashes)**

Not detecting Incident 4 patterns means you'll face Incident 2 (crashes) - by then it's damage control, not prevention.

---

**Document Version:** 1.0  
**Created:** October 30, 2025  
**Tested On:** kind cluster (sockshop) with Datadog agent  
**Test Configuration:** 500 users, 8m duration, 0 restarts across all services  
**Incident Classification:** PURE LATENCY (performance degradation without crashes)
