# Incident 2: Hybrid Crash + Latency via Moderate Load

## Overview

**Incident Type:** HYBRID - Frontend Bottleneck Causing Crashes + Backend Latency  
**Severity:** High (P2)  
**User Impact:** Intermittent availability, severe slowness, frequent connection failures  
**Root Cause:** Frontend unable to handle 750 concurrent connections, crashes intermittently while backend experiences only latency

## Incident Description

When the Sock Shop application experiences 750 concurrent users, it exhibits a **HYBRID failure pattern**:
- **Frontend:** Crashes intermittently (5-10 restarts during 8-minute test), enters CrashLoopBackOff
- **Backend:** Remains stable (0 restarts) but experiences severe latency (9-13 second responses)
- Response times: 23+ seconds average (vs 150ms normal)
- Failure rate: 87%+ due to frontend connection timeouts
- Users experience intermittent availability with extreme slowness

This simulates a realistic scenario where an architectural bottleneck (frontend) causes partial system failure while other components remain operational but degraded.

**Key Differences:**
- **Incident 1 (3000 users):** Complete system-wide crash, all pods restart, total outage
- **Incident 2 (750 users):** Frontend crashes + backend latency, intermittent availability
- **Incident 4 (500 users):** Pure latency, NO crashes, slow but fully functional (see INCIDENT-4-APP-LATENCY.md)

---

## Application Performance Thresholds

### Load vs. Performance Profile

| User Count | Response Time | CPU Usage | Status | User Experience |
|------------|---------------|-----------|--------|-----------------|
| 50-100 | < 200ms | 10-30% | ✅ Healthy | Excellent |
| 200-400 | 200-800ms | 40-60% | ⚠️ Warning | Acceptable |
| **400-600** | **2-5 seconds** | **75-95%** | 🔴 **Degraded** | **Slow (see Incident 4)** |
| **750** | **20-25 seconds** | **80-95%** | 🔴💀 **HYBRID** | **Crashes + Latency (THIS)** |
| 1500+ | Timeouts | 100% | 💀 Crash | Unusable |

### Target Metrics for This Incident

| Metric | Normal | During Incident | Alert Threshold |
|--------|--------|-----------------|-----------------|
| **Response Time (avg)** | 150ms | **20-25 seconds** | > 2 seconds |
| **Failure Rate** | < 0.1% | **75-85%** | > 5% |
| **CPU Usage** | 5-15% | 80-95% | > 75% |
| **Memory Usage** | 20-40% | 60-85% | > 70% |
| **Request Queue Depth** | 0-5 | 50-200 | > 20 |

**Note:** The 750 user load produces EXTREME degradation (20-25 second response times and 75-85% failure rate), demonstrating the application cannot handle this level of traffic effectively.

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
# front-end-xxxxx                 5m           150Mi
# user-xxxxx                      3m           80Mi
# orders-xxxxx                    8m           200Mi
# carts-xxxxx                     4m           120Mi
# payment-xxxxx                   2m           50Mi
```

### 3. Test Baseline Response Time

```powershell
# Measure response time (should be fast)
Measure-Command { Invoke-WebRequest -UseBasicParsing http://localhost:2025/catalogue -TimeoutSec 10 } | Select-Object TotalMilliseconds

# Expected Output: ~100-300ms
```

### 4. Verify Port Forwards

```powershell
# Ensure front-end is accessible
Invoke-WebRequest -UseBasicParsing http://localhost:2025 -TimeoutSec 5

# Expected Output: StatusCode 200
```

### 5. Set Up Datadog Time Window

1. Go to Datadog Logs: https://us5.datadoghq.com/logs
2. Set time range to: **Live Tail** or **Past 15 minutes**
3. Keep this window open to watch logs in real-time during the incident

---

## Incident Execution Steps

### Step 1: Deploy Locust Load Generator (Moderate Latency Load)

Create the Locust job configuration for latency scenario:

```powershell
# Navigate to load directory
cd d:\sock-shop-demo\load

# Create latency scenario configuration
@'
apiVersion: v1
kind: ConfigMap
metadata:
  name: locustfile-latency
  namespace: sock-shop
data:
  locustfile.py: |
    from locust import HttpUser, task, between
    import random

    class SockShopUser(HttpUser):
        wait_time = between(1, 3)  # Moderate pacing
        
        @task(5)
        def browse_catalogue(self):
            """Most common user action"""
            with self.client.get("/catalogue", catch_response=True, name="Browse Catalogue") as resp:
                if resp.elapsed.total_seconds() > 3:
                    resp.failure(f"Slow response: {resp.elapsed.total_seconds():.2f}s")
        
        @task(3)
        def view_item_details(self):
            """View specific product"""
            item_ids = [
                "03fef6ac-1896-4ce8-bd69-b798f85c6e0b",
                "510a0d7e-8e83-4193-b483-e27e09ddc34d",
                "808a2de1-1aaa-4c25-a9b9-6612e8f29a38",
                "d3588630-ad8e-49df-bbd7-3167f7efb246"
            ]
            item_id = random.choice(item_ids)
            with self.client.get(f"/catalogue/{item_id}", catch_response=True, name="View Item") as resp:
                if resp.elapsed.total_seconds() > 2:
                    resp.failure(f"Slow item load: {resp.elapsed.total_seconds():.2f}s")
        
        @task(2)
        def check_cart(self):
            """Check shopping cart"""
            with self.client.get("/basket.html", catch_response=True, name="View Cart") as resp:
                if resp.elapsed.total_seconds() > 2:
                    resp.failure(f"Cart slow: {resp.elapsed.total_seconds():.2f}s")
        
        @task(1)
        def view_login(self):
            """View login page"""
            with self.client.get("/login", catch_response=True, name="Login Page") as resp:
                if resp.elapsed.total_seconds() > 2:
                    resp.failure(f"Login page slow: {resp.elapsed.total_seconds():.2f}s")
---
apiVersion: batch/v1
kind: Job
metadata:
  name: locust-latency-test
  namespace: sock-shop
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: locust-latency
    spec:
      restartPolicy: Never
      containers:
        - name: locust
          image: locustio/locust:2.32.1
          imagePullPolicy: IfNotPresent
          env:
            - name: LOCUST_HOST
              value: "http://front-end.sock-shop.svc.cluster.local"
            - name: USERS
              value: "750"        # HYBRID: Causes frontend crashes + backend latency
            - name: SPAWN_RATE
              value: "50"         # Gradual ramp-up
            - name: RUN_TIME
              value: "8m"         # Extended duration to observe latency
          volumeMounts:
            - name: locustfile
              mountPath: /mnt/locust
          workingDir: /mnt/locust
          resources:
            requests:
              cpu: "300m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          command: ["sh", "-c"]
          args:
            - |
              echo "=========================================="
              echo "INCIDENT 2: HYBRID CRASH + LATENCY TEST - STARTING"
              echo "Target: $LOCUST_HOST"
              echo "Users: $USERS | Spawn Rate: $SPAWN_RATE"
              echo "Duration: $RUN_TIME"
              echo "Goal: Induce frontend crashes + backend latency (HYBRID)"
              echo "=========================================="
              locust -f locustfile.py \
                --host "$LOCUST_HOST" \
                --headless \
                -u "$USERS" \
                -r "$SPAWN_RATE" \
                --run-time "$RUN_TIME" \
                --html=/tmp/latency-report.html \
                --csv=/tmp/latency-stats
              echo "=========================================="
              echo "LATENCY TEST COMPLETED"
              echo "=========================================="
      volumes:
        - name: locustfile
          configMap:
            name: locustfile-latency
'@ | Out-File -Encoding UTF8 .\locust-latency-test.yaml

# Apply the configuration
kubectl apply -f .\locust-latency-test.yaml
```

**Expected Output:**
```
configmap/locustfile-latency created
job.batch/locust-latency-test created
```

### Step 2: Monitor Job Startup

```powershell
# Watch the job start
kubectl -n sock-shop get pods -l app=locust-latency

# Expected Output:
# NAME                          READY   STATUS    RESTARTS   AGE
# locust-latency-test-xxxxx     1/1     Running   0          15s
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

**Expected Progression:**
```
# T+0s: Baseline (before load)
[10:00:00] Response Time: 120ms        (Green)

# T+60s: Load ramping up
[10:01:00] Response Time: 450ms        (Green/Yellow)

# T+120s: Moderate load established
[10:02:00] Response Time: 1,850ms      (Yellow)

# T+180s: Peak latency
[10:03:00] Response Time: 3,420ms      (Red)
[10:03:10] Response Time: 4,100ms      (Red)
[10:03:20] Response Time: 3,890ms      (Red)

# T+240s: Sustained slow performance
[10:04:00] Response Time: 3,200ms      (Red)
```

#### Window 2: Monitor Resource Usage
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== RESOURCE USAGE MONITOR (LATENCY INCIDENT) ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'HH:mm:ss')`n" -ForegroundColor Yellow
    
    kubectl top pods -n sock-shop --no-headers | ForEach-Object {
        $parts = $_ -split '\s+'
        $pod = $parts[0]
        $cpu = $parts[1]
        $mem = $parts[2]
        
        # Color code based on resource usage
        $cpuNum = [int]($cpu -replace '[^0-9]','')
        $color = if ($cpuNum -lt 100) { "Green" } 
                 elseif ($cpuNum -lt 250) { "Yellow" } 
                 else { "Red" }
        
        Write-Host "$pod" -NoNewline
        Write-Host " | CPU: " -NoNewline
        Write-Host "$cpu" -ForegroundColor $color -NoNewline
        Write-Host " | MEM: $mem"
    }
    
    Start-Sleep -Seconds 5
}
```

**Expected Progression:**
```
=== RESOURCE USAGE MONITOR (LATENCY INCIDENT) ===
Timestamp: 10:00:00

front-end-xxxxx | CPU: 8m | MEM: 180Mi

# T+60s: Load building
Timestamp: 10:01:00
front-end-xxxxx | CPU: 120m | MEM: 380Mi      (Yellow - getting busy)

# T+120s: High but not crashing
Timestamp: 10:02:00
front-end-xxxxx | CPU: 245m | MEM: 720Mi      (Yellow - near limits)
user-xxxxx      | CPU: 180m | MEM: 160Mi      (Yellow)

# T+180s: Sustained pressure (CPU throttled but not crashing)
Timestamp: 10:03:00
front-end-xxxxx | CPU: 285m | MEM: 850Mi      (Red - throttled)
user-xxxxx      | CPU: 250m | MEM: 180Mi      (Red - throttled)
orders-xxxxx    | CPU: 320m | MEM: 420Mi      (Red - over limit but stable)
```

**Key Observation:** Frontend WILL crash intermittently (5-10 restarts), backend stays running

#### Window 3: Monitor Pod Status (Verify No Crashes)
```powershell
kubectl -n sock-shop get pods -w
```

**Expected Output:**
```
# Pods remain Running throughout the incident
NAME                            READY   STATUS    RESTARTS   AGE
front-end-xxxxx                 1/1     Running   0          45m
user-xxxxx                      1/1     Running   0          45m
orders-xxxxx                    1/1     Running   0          45m
payment-xxxxx                   1/1     Running   0          45m
carts-xxxxx                     1/1     Running   0          45m

# Frontend WILL show CrashLoopBackOff, backend stays Running (HYBRID behavior)
```

#### Window 4: Monitor Locust Statistics
```powershell
kubectl -n sock-shop logs -f job/locust-latency-test
```

**Expected Output:**
```
==========================================
INCIDENT 2: LATENCY TEST - STARTING
Target: http://front-end.sock-shop.svc.cluster.local
Users: 750 | Spawn Rate: 50
Duration: 8m
Goal: Induce 2-5 second response times
==========================================
[2025-10-27 10:00:10] Starting Locust 2.32.1
[2025-10-27 10:00:15] Ramping to 750 users at a rate of 50 per second...
[2025-10-27 10:00:30] All 750 users spawned

# Statistics showing LATENCY but not massive failures
Type     Name                    # reqs   # fails  Avg     Min   Max    Med    req/s
------------------------------------------------------------------------------------
GET      Browse Catalogue        12,456   234     3,245   120   8,900  3,100  45.2
GET      View Item                7,890   123     2,890   110   7,200  2,800  28.6
GET      View Cart                5,234    89     2,456   105   6,500  2,300  19.0
GET      Login Page               2,987    45     2,123    98   5,800  2,000  10.8
------------------------------------------------------------------------------------
Aggregated                       28,567   491     2,803   98    8,900  2,700  103.6

# Low failure rate (~1.7%) but HIGH average response time (2.8s)
Current failures: 1.7%
Average response time: 2,803ms  ⚠️ DEGRADED PERFORMANCE
```

**Key Metrics:**
- ✅ Failure rate LOW (< 5%) - Application still working
- 🔴 Response time HIGH (2-4 seconds) - Users experiencing slowness
- ✅ Request rate STABLE - No service crashes

### Step 4: Monitor Application-Level Symptoms

#### Test User Journey (Manual)

In a browser, navigate to http://localhost:2025 and experience the slowness:

1. **Homepage Load:** 3-5 seconds (normally < 1 second)
2. **Click on a product:** 4-6 seconds delay
3. **View cart:** 3-4 seconds delay
4. **Every page action:** Noticeably slow but eventually works

**User Experience:** "The website is so slow! Is something wrong?"

#### Monitor HTTP Status Codes
```powershell
kubectl -n sock-shop logs -f deployment/front-end | Select-String -Pattern "GET\|POST\|status"
```

**Expected Patterns:**
```
GET /catalogue HTTP/1.1" 200 - response_time=3245ms
GET /catalogue/03fef6ac HTTP/1.1" 200 - response_time=4123ms
GET /basket.html HTTP/1.1" 200 - response_time=2890ms
GET /login HTTP/1.1" 200 - response_time=2456ms

# Occasional timeouts
GET /catalogue/510a0d7e HTTP/1.1" 504 - response_time=10000ms (timeout)
```

---

## Datadog Monitoring & Investigation

### Step 1: View Real-Time Logs in Datadog

#### Open Datadog Logs Explorer

```powershell
# Open Logs Explorer with live tail
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop&stream_sort=desc&viz=stream&live=true"
```

**What to look for:**
- Locust service logs showing request statistics
- High response times (20,000+ milliseconds)
- High failure rates (75-85%)
- Error messages from application services

#### View Specific Service Logs

```powershell
# Front-end service logs
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop%20service%3Asock-shop-front-end"

# Catalogue service logs
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop%20service%3Asock-shop-catalogue"

# User service logs
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop%20service%3Asock-shop-user"

# Locust load test logs (statistics)
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop%20service%3Alocust"
```

**Expected Log Patterns:**
```
# Locust statistics showing high response times
Aggregated 8214 6923(84.28%) | 24674 1 135551 4900 | 21.80 21.80
GET Browse Catalogue 3706 3058(82.51%) | 25521 1 135529 5100 | 10.80 10.80
GET View Item 2267 1912(84.34%) | 24567 1 135551 5200 | 5.30 5.30

# Service health checks
ts=2025-10-27T17:43:09.021400444Z caller=middlewares.go:153 method=Health result=2 took=574.757µs
```

### Step 2: Monitor Container Metrics in Datadog

#### Open Containers View

```powershell
# View all sock-shop containers sorted by CPU usage
Start-Process "https://us5.datadoghq.com/containers?query=kube_namespace%3Asock-shop&sort=cpu&order=desc"
```

**In the Containers view:**
1. Click **"Infrastructure"** → **"Containers"** in left sidebar
2. Filter: `kube_namespace:sock-shop`
3. Sort by: **CPU** (descending)

**What to look for:**
- **CPU near 100%** = Service is CPU-bound (bottleneck!)
- **Memory climbing** = Memory pressure
- **High network traffic** = Service handling lots of requests
- **Restarts > 0** = Service crashed during test

**Expected during test:**
- front-end: 400-500m CPU (80-100% of limit)
- catalogue: 350-450m CPU
- user: 300-400m CPU

#### Monitor Kubernetes Metrics

```powershell
# Open Metrics Explorer
Start-Process "https://us5.datadoghq.com/metric/explorer"
```

**Useful Metric Queries:**

**Query 1: CPU Usage by Pod**
```
avg:kubernetes.cpu.usage.total{kube_namespace:sock-shop} by {pod_name}
```

**Query 2: Memory Usage by Pod**
```
avg:kubernetes.memory.usage{kube_namespace:sock-shop} by {pod_name}
```

**Query 3: CPU Throttling (Critical!)**
```
avg:kubernetes.cpu.cfs.throttled.seconds{kube_namespace:sock-shop} by {pod_name}
```

**Query 4: Network Traffic**
```
avg:kubernetes.network.rx_bytes{kube_namespace:sock-shop} by {pod_name}
```

**Expected Graph:** CPU spikes to 400-500m during test, then drops back to <100m after recovery

### Step 3: Analyze Logs in Datadog

Go to Datadog Logs Explorer: https://us5.datadoghq.com/logs

#### Query 1: Locust Test Statistics
```
kube_namespace:sock-shop service:locust
```

**Filter in Datadog:**
1. Search: `kube_namespace:sock-shop service:locust`
2. Look for lines containing: `Aggregated` or `GET Browse Catalogue`

**Expected Logs:**
```
Aggregated 8214 6923(84.28%) | 24674 1 135551 4900 | 21.80 21.80
GET Browse Catalogue 3706 3058(82.51%) | 25521 1 135529 5100 | 10.80 10.80
GET Login Page 758 758(100.00%) | 21948 2 135550 4400 | 1.70 1.70
GET View Cart 1483 1195(80.58%) | 24113 1 135529 3400 | 4.00 4.00
GET View Item 2267 1912(84.34%) | 24567 1 135551 5200 | 5.30 5.30
```

**How to read:**
- Format: `# reqs # fails(%) | Avg Min Max Med | req/s failures/s`
- Example: `3706 3058(82.51%) | 25521 ...` means:
  - 3,706 total requests
  - 3,058 failures (82.51% failure rate)
  - 25,521ms average response time (25.5 seconds!)

#### Query 2: Application Service Logs
```
kube_namespace:sock-shop (service:sock-shop-front-end OR service:sock-shop-catalogue OR service:sock-shop-user)
```

**Expected Logs:**
```
ts=2025-10-27T17:43:09.021400444Z caller=middlewares.go:153 method=Health result=2 took=574.757µs
ts=2025-10-27T17:43:04.211944235Z caller=logging.go:36 method=Health result=1 took=5.372µs
```

#### Query 3: Error Logs (if any)
```
kube_namespace:sock-shop status:error
```

**Look for:**
- Connection errors
- Timeout errors  
- Database errors
- OOM (Out of Memory) errors

#### Query 4: Database Logs
```
kube_namespace:sock-shop (service:mongodb OR service:redis)
```

**Expected Logs:**
```
1:M 27 Oct 2025 17:43:06.626 * Background saving terminated with success
31:C 27 Oct 2025 17:43:06.591 * DB saved on disk
```

### Step 4: Extract Locust HTML Report (Optional)

After the test completes, you can extract the detailed HTML report:

```powershell
# Get the locust pod name
$locustPod = kubectl -n sock-shop get pods -l job-name=locust-latency-test -o jsonpath='{.items[0].metadata.name}'

# Create reports directory
New-Item -ItemType Directory -Force -Path "d:\sock-shop-demo\load\reports"

# List available reports
kubectl -n sock-shop exec $locustPod -- ls -la /mnt/locust/reports/

# Copy HTML report to local machine
kubectl -n sock-shop cp ${locustPod}:/mnt/locust/reports/locust_report.html d:\sock-shop-demo\load\reports\incident2-latency-report.html

# Open report in browser
Start-Process "d:\sock-shop-demo\load\reports\incident2-latency-report.html"
```

**Expected Output:**
- Beautiful HTML dashboard with:
  - Response time charts over time
  - Request statistics table
  - Failure distribution
  - Download links for CSV data

### Step 5: Key Datadog Views Summary

**Quick Access URLs:**

```powershell
# All sock-shop logs (live tail)
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop&live=true"

# Containers view (CPU/Memory metrics)
Start-Process "https://us5.datadoghq.com/containers?query=kube_namespace%3Asock-shop&sort=cpu&order=desc"

# Metrics Explorer (custom queries)
Start-Process "https://us5.datadoghq.com/metric/explorer"

# Kubernetes Explorer (cluster view)
Start-Process "https://us5.datadoghq.com/orchestration/explorer?query=kube_namespace%3Asock-shop"
```

**Recommended Datadog Monitors (For Future):**

1. **High CPU Usage Alert**
   - Metric: `kubernetes.cpu.usage.total{kube_namespace:sock-shop}`
   - Threshold: > 400m for 5 minutes
   - Severity: WARNING

2. **Memory Pressure Alert**
   - Metric: `kubernetes.memory.usage{kube_namespace:sock-shop}`
   - Threshold: > 450Mi for 5 minutes
   - Severity: WARNING

3. **Pod Restart Alert**
   - Metric: `kubernetes.containers.restarts{kube_namespace:sock-shop}`
   - Threshold: > 0 in 10 minutes
   - Severity: CRITICAL

---

## Recovery Steps

### Step 1: Stop the Load Generator

```powershell
# Delete the Locust job
kubectl -n sock-shop delete job locust-latency-test

# Verify deletion
kubectl -n sock-shop get pods -l app=locust-latency
```

**Expected Output:**
```
job.batch "locust-latency-test" deleted
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

**Expected Recovery Timeline:**
```
[10:08:00] Response Time: 3,200ms     (Still slow - load just stopped)
[10:08:10] Response Time: 2,100ms     (Improving)
[10:08:20] Response Time: 1,200ms     (Better)
[10:08:30] Response Time: 650ms       (Getting there)
[10:08:40] Response Time: 280ms       (Almost normal)
[10:08:50] Response Time: 150ms       (RECOVERED)

✅ Performance RECOVERED! Response time back to normal.
```

### Step 3: Verify Resource Usage Normalized

```powershell
kubectl top pods -n sock-shop
```

**Expected Output:**
```
NAME                            CPU(cores)   MEMORY(bytes)
front-end-xxxxx                 6m           180Mi         ✅ Back to baseline
user-xxxxx                      3m           85Mi          ✅ Normal
orders-xxxxx                    7m           210Mi         ✅ Normal
payment-xxxxx                   2m           52Mi          ✅ Normal
```

### Step 4: Check Pod Restart Status

```powershell
kubectl -n sock-shop get pods
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS         AGE
front-end-xxxxx                 1/1     Running   56 (31m ago)     12d    ⚠️ NEW RESTARTS!
carts-xxxxx                     1/1     Running   13 (4h44m ago)   12d    ✅ No new restarts
catalogue-xxxxx                 1/1     Running   9 (4h44m ago)    12d    ✅ No new restarts
user-xxxxx                      1/1     Running   9 (4h44m ago)    12d    ✅ No new restarts
orders-xxxxx                    1/1     Running   13 (4h44m ago)   12d    ✅ No new restarts
payment-xxxxx                   1/1     Running   9 (4h44m ago)    12d    ✅ No new restarts
```

**Key Findings:**
- ⚠️ **Front-end pod**: Typically shows 5-10 NEW restarts during the 8-minute test
- ✅ **Backend services**: Should show NO new restarts (restart timestamp older than test)
- 📊 **Pattern**: Front-end is the bottleneck and experiences crashes under this load
- 🔍 **Why**: Front-end handles all incoming traffic and becomes overwhelmed at 750 concurrent users

**This is a HYBRID incident** - front-end crashes intermittently while backend services only experience latency

### Step 5: Clean Up Locust Resources

```powershell
# Remove ConfigMap
kubectl -n sock-shop delete configmap locustfile-latency

# Verify cleanup
kubectl -n sock-shop get configmap | Select-String locust
```

**Expected Output:** No locust-related configmaps

### Step 6: Verify Datadog Shows Recovery

1. Go to Datadog Logs: https://us5.datadoghq.com/logs
2. Query: `kube_namespace:sock-shop service:front-end`
3. Look for recent logs

**Expected Log Patterns (Recovered):**
```
INFO - GET /catalogue - 200 - response_time: 145ms     ✅ Fast again
INFO - GET /basket.html - 200 - response_time: 98ms    ✅ Normal
INFO - Request processed successfully in 52ms          ✅ Healthy
```

---

## Post-Incident Analysis

### Incident Summary

**Duration:** ~10 minutes (8m24s load + 2m recovery)  
**Peak Response Time:** 9,000-13,000ms average (9-13 seconds)  
**Connection Timeout Errors:** 1,464 total (706 Browse, 374 View Item, 266 View Cart, 118 Login)  
**Pod Restarts:** Front-end restarted 8 times during test; all other pods stable  
**User Impact:** Severe slowness with frequent connection failures  

**Incident Type:** HYBRID - Front-end experienced crashes (partial Incident 1 behavior) while backend services only experienced latency (pure Incident 2 behavior)

### Root Cause

**Primary:** Front-end service unable to handle connection volume at 750 concurrent users, causing repeated crashes and restarts while backend services remain stable.

**Why Front-End Failed:**
1. **Connection exhaustion**: Front-end runs out of available connection handlers
2. **Single replica bottleneck**: All 750 users hitting one front-end pod
3. **CPU throttling**: Front-end at 80-95% CPU limits, unable to accept new connections
4. **Crash-restart cycle**: Pod crashes when connections exceed capacity → Kubernetes restarts → Temporary relief → Crash again

**Why Backend Services Survived:**
1. **Request filtering**: Many requests never reached backend (failed at front-end)
2. **Lower actual load**: Only ~20-25% of requests made it through front-end
3. **Synchronous processing**: Backend services processed requests sequentially, avoiding overload
4. **Resource headroom**: Backend services had sufficient CPU/memory for the filtered load

### Evidence Collected

1. **Metrics (from Datadog Containers view):**
   - Average response time: 9,000-13,000ms during load (baseline: 150ms)
   - Peak response time: 135,000ms (135 seconds - worst case)
   - CPU usage: Front-end at 80-95% of limits (sustained throttling)
   - Memory usage: 60-85% of limits (pressure but not OOMKilled)

2. **Logs (from Datadog Logs Explorer & kubectl):**
   - Locust slow response warnings: 9-13 second response times
   - Browse Catalogue: Average 12.7 seconds per request
   - View Cart: Average 12.0 seconds per request  
   - Login Page: Average 13.0 seconds per request
   - View Item: Average 12.6 seconds per request
   - Connection timeout errors: 1,464 total failures
   - Service health checks: Backend services passing, front-end intermittent

3. **Pod Behavior (from kubectl get pods):**
   - Front-end pod: 8 restarts during 8-minute test (~1 restart/minute)
   - Backend pods: 0 restarts (carts, catalogue, user, orders, payment all stable)
   - Restart pattern: Front-end crash → Kubernetes restart → Brief recovery → Crash again
   - Root cause: Front-end overwhelmed by connection volume, not backend processing

4. **Error Analysis (from Locust logs):**
   - Primary error: `ConnectTimeoutError` to front-end service
   - 706 timeouts on Browse Catalogue endpoint
   - 374 timeouts on View Item endpoint
   - 266 timeouts on View Cart endpoint
   - 118 timeouts on Login Page endpoint
   - Pattern indicates front-end unable to accept new connections (likely during crash/restart cycles)

### Comparison with Incident 1

| Metric | Incident 1 (Crash) | Incident 2 (Latency) - Actual Results |
|--------|-------------------|-------------------------------------|
| User Load | 3000 users | 750 users |
| Front-End Restarts | Continuous crashes | 8 restarts in 8 minutes |
| Backend Restarts | Multiple crashes | 0 (all stable) |
| Response Time | Complete timeouts | 9-13 seconds average |
| Connection Errors | All services fail | 1,464 front-end connection timeouts |
| User Impact | Complete outage | Intermittent availability, severe slowness |
| Recovery | Requires manual intervention | Automatic (load drops) |
| Root Cause | OOMKill across all services | Front-end connection exhaustion |
| Bottleneck | System-wide | Front-end only |

**Key Insight:** Incident 2 at 750 users created a HYBRID scenario:
- Front-end behaved like Incident 1 (crashes and restarts)
- Backend services behaved as expected for Incident 2 (latency but stable)
- This reveals front-end as the architectural bottleneck in the sock-shop application

---

## Recommended Remediation (For Production)

### Immediate Actions
1. **Add Horizontal Pod Autoscaling (HPA):**
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
           averageUtilization: 70
   ```

2. **Increase Resource Limits (+30%):**
   ```yaml
   resources:
     limits:
       cpu: 400m      # was 300m
       memory: 1300Mi # was 1000Mi
   ```

### Short-Term Optimizations
1. Implement connection pooling (database, HTTP clients)
2. Add request rate limiting at ingress (prevent abuse)
3. Enable response caching for catalogue service
4. Implement circuit breakers with fallback responses

### Long-Term Improvements
1. Migrate to async processing for heavy operations
2. Implement CDN for static assets
3. Add read replicas for databases
4. Consider serverless components for burst handling

---

## Expected Outcomes - ACTUAL RESULTS

### During Incident (750 Users, 8 Minutes)
✅ **Response times:** 9-13 seconds average (successful requests)  
✅ **Connection timeout errors:** 1,464 total (front-end unable to accept connections)  
✅ **CPU usage:** Front-end at 80-95%; backend services at 40-60%  
✅ **Memory usage:** 60-85% across all services (no OOMKills)  
⚠️ **Front-end pod:** 5-10 restarts during test (~1 restart/minute)  
✅ **Backend pods:** 0 restarts (remain stable throughout)  
✅ **Datadog logs:** Connection timeout errors, slow response warnings  
⚠️ **User experience:** Intermittent availability with severe slowness

**Incident Classification:** HYBRID
- Front-end: Exhibits Incident 1 behavior (crashes and restarts)
- Backend: Exhibits Incident 2 behavior (latency but stable)

### After Recovery (Load Stops)
✅ Response times return to < 200ms within 1-2 minutes  
✅ CPU usage returns to baseline (1-17m)  
✅ Memory usage stable at baseline (50-400Mi)  
⚠️ Front-end shows NEW restarts (identifies as bottleneck)  
✅ Backend services show NO new restarts  
✅ Datadog logs show normal operation  
✅ Application fully functional

### Key Architectural Insight
The 750-user load reveals **front-end as the bottleneck** in the sock-shop application:
- Front-end cannot handle connection volume (single replica limitation)
- Backend services have sufficient capacity for the filtered load
- **Recommended fix:** Scale front-end to 3-5 replicas minimum

---

## Troubleshooting

### Issue: Not Seeing Latency (Still Fast)

**Cause:** Load may not be sufficient or cluster has excess capacity.

**Solution:**
```powershell
# Increase user count
kubectl -n sock-shop patch job locust-latency-test --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "1000"}]'

# Or decrease resource limits temporarily
kubectl -n sock-shop set resources deployment front-end --limits=cpu=200m,memory=500Mi
```

### Issue: Front-End Pod Crashes (Expected at 750 Users)

**Cause:** 750 users creates a HYBRID incident - front-end crashes while backend stays stable.

**This is EXPECTED behavior at this load level.**

**If you want pure latency without crashes:**
```powershell
# Reduce to 400-500 users
kubectl -n sock-shop delete job locust-latency-test
# Edit USERS to "500" in the YAML
kubectl apply -f locust-latency-test.yaml
```

**If you want to scale front-end to handle 750 users:**
```powershell
# Scale front-end to 3 replicas
kubectl -n sock-shop scale deployment front-end --replicas=3

# Verify scaling
kubectl -n sock-shop get pods -l name=front-end
```

### Issue: Datadog Not Showing High Response Times

**Cause:** May need to check correct metric or service.

**Solution:**
```
# Try these queries in Datadog Logs
kube_namespace:sock-shop response_time:>1000
kube_namespace:sock-shop status:warning
kube_namespace:sock-shop "slow" OR "latency" OR "timeout"
```

---

## Summary

This incident demonstrates a **HYBRID failure scenario** that reveals critical architectural insights:

### What Actually Happened at 750 Users

**Front-End Behavior (Incident 1-like):**
- Crashed and restarted 8 times during 8-minute test
- Connection timeout errors: 1,464 total
- Unable to accept new connections during crash/restart cycles
- Single replica overwhelmed by connection volume

**Backend Behavior (Incident 2-like):**
- All backend services remained stable (0 restarts)
- Experienced latency (9-13 second response times) but didn't crash
- Sufficient capacity for the filtered load (many requests blocked at front-end)

### Why This Is Valuable

This incident is **harder to diagnose** than pure crashes because:
1. **Intermittent availability** - some requests succeed, others timeout
2. **Mixed signals** - front-end crashes while backend appears healthy
3. **Root cause not obvious** - is it front-end, backend, database, or network?

### Key Architectural Discovery

**Front-end is the bottleneck** - revealed through differential pod behavior:
- Front-end cannot handle 750 concurrent connections (single replica limit)
- Backend services can handle the load but are shielded by front-end failures
- **Production fix:** Scale front-end to 3-5 replicas minimum

### Datadog's Role

The Datadog integration provided crucial visibility:
- **Logs:** Connection timeout patterns pointing to front-end
- **Metrics:** Front-end CPU at 95% vs backend at 40-60%
- **Container view:** Front-end restarts visible, backend stable
- **Root cause confirmation:** Data clearly identified the bottleneck

**Key Learning:** Not all incidents are pure crashes or pure latency—real production failures often exhibit HYBRID behavior that requires sophisticated observability to diagnose accurately.

---

**Document Version:** 2.0  
**Last Updated:** October 27, 2025  
**Tested On:** kind cluster (sockshop) with Datadog agent  
**Actual Test Results:** 750 users, 8m24s duration, front-end 8 restarts, backend 0 restarts  
**Incident Classification:** HYBRID (front-end crashes + backend latency)
