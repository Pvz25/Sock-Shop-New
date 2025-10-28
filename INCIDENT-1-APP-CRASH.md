# Incident 1: Application Crash via High Load

## Overview

**Incident Type:** Resource Exhaustion Leading to Pod Crashes  
**Severity:** Critical (P1)  
**User Impact:** Complete application unavailability  
**Root Cause:** CPU/Memory limits exceeded under extreme concurrent load

## Incident Description

When the Sock Shop application is subjected to extremely high concurrent user load (2500+ users), the front-end and backend services exceed their resource limits, causing:
- Pod restarts (CrashLoopBackOff)
- OOMKilled events
- Service unavailability
- Failed health checks

This simulates a real-world scenario where a flash sale, DDoS attack, or viral marketing campaign overwhelms the application infrastructure.

---

## Application Baseline Capacity

### Resource Limits (Current Configuration)

| Service | CPU Limit | Memory Limit | Expected Capacity |
|---------|-----------|--------------|-------------------|
| front-end | 300m | 1000Mi | ~200 concurrent users |
| user | 300m | 200Mi | ~150 concurrent users |
| orders | 500m | 500Mi | ~300 concurrent users |
| payment | 200m | 200Mi | ~100 concurrent users |

### Normal Operation Thresholds

- **Healthy Load:** 50-100 concurrent users
- **Warning Load:** 200-500 concurrent users (slowness expected)
- **Critical Load:** 1000-2500 concurrent users (service degradation)
- **Crash Threshold:** 2500+ concurrent users (pod restarts/OOMKilled)

---

## Pre-Incident Checklist

### 1. Verify Application is Healthy

```powershell
# Check all pods are running
kubectl -n sock-shop get pods

# Expected Output: All pods showing 1/1 READY and Running status
# NAME                            READY   STATUS    RESTARTS   AGE
# carts-xxxxx                     1/1     Running   0          10m
# front-end-xxxxx                 1/1     Running   0          10m
# orders-xxxxx                    1/1     Running   0          10m
# payment-xxxxx                   1/1     Running   0          10m
# user-xxxxx                      1/1     Running   0          10m
```

### 2. Verify Datadog is Collecting Logs

```powershell
# Get Datadog agent pod (select node agent, not cluster agent)
$POD = kubectl -n datadog get pods -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | Where-Object { $_.metadata.name -like "datadog-agent-*" -and $_.metadata.name -notlike "*cluster-agent*" } | Select-Object -First 1 | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

# Check log collection status
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"

# Expected Output: LogsProcessed: [non-zero number, e.g., 1234]
```

### 3. Verify Port Forwards are Active

```powershell
# Start port forwards if not already running
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'
Start-Sleep -Seconds 5

# Test access
Invoke-WebRequest -UseBasicParsing http://localhost:2025 -TimeoutSec 5

# Expected Output: StatusCode 200
```

### 4. Baseline Metrics Snapshot

```powershell
# Capture baseline CPU/Memory usage
kubectl top pods -n sock-shop

# Expected Output (Normal Load):
# NAME                            CPU(cores)   MEMORY(bytes)
# front-end-xxxxx                 5m           150Mi
# user-xxxxx                      3m           80Mi
# orders-xxxxx                    8m           200Mi
# payment-xxxxx                   2m           50Mi
```

---

## Incident Execution Steps

### Step 1: Deploy Locust Load Generator (High Crash Load)

Create the Locust job configuration for crash scenario:

```powershell
# Navigate to load directory
cd d:\sock-shop-demo\load

# Create crash scenario configuration
@'
apiVersion: v1
kind: ConfigMap
metadata:
  name: locustfile-crash
  namespace: sock-shop
data:
  locustfile.py: |
    from locust import HttpUser, task, between
    import random

    class SockShopUser(HttpUser):
        wait_time = between(0.5, 1.5)  # Aggressive timing
        
        @task(3)
        def browse_catalogue(self):
            self.client.get("/catalogue", name="Browse Catalogue")
        
        @task(2)
        def view_item(self):
            item_id = random.choice(["03fef6ac-1896-4ce8-bd69-b798f85c6e0b", 
                                      "510a0d7e-8e83-4193-b483-e27e09ddc34d",
                                      "808a2de1-1aaa-4c25-a9b9-6612e8f29a38"])
            self.client.get(f"/catalogue/{item_id}", name="View Item")
        
        @task(2)
        def add_to_cart(self):
            self.client.post("/cart", json={"id": "test-item"}, name="Add to Cart")
        
        @task(1)
        def login_attempt(self):
            self.client.get("/login", name="Login Page")
---
apiVersion: batch/v1
kind: Job
metadata:
  name: locust-crash-test
  namespace: sock-shop
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        app: locust-crash
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
              value: "3000"       # Extremely high load
            - name: SPAWN_RATE
              value: "300"        # Rapid ramp-up
            - name: RUN_TIME
              value: "5m"         # 5 minutes of sustained load
          volumeMounts:
            - name: locustfile
              mountPath: /mnt/locust
          workingDir: /mnt/locust
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "2000m"
              memory: "2Gi"
          command: ["sh", "-c"]
          args:
            - |
              echo "=========================================="
              echo "INCIDENT 1: CRASH TEST - STARTING"
              echo "Target: $LOCUST_HOST"
              echo "Users: $USERS | Spawn Rate: $SPAWN_RATE"
              echo "Duration: $RUN_TIME"
              echo "=========================================="
              locust -f locustfile.py \
                --host "$LOCUST_HOST" \
                --headless \
                -u "$USERS" \
                -r "$SPAWN_RATE" \
                --run-time "$RUN_TIME" \
                --html=/tmp/report.html
              echo "=========================================="
              echo "CRASH TEST COMPLETED"
              echo "=========================================="
      volumes:
        - name: locustfile
          configMap:
            name: locustfile-crash
'@ | Out-File -Encoding UTF8 .\locust-crash-test.yaml

# Apply the configuration
kubectl apply -f .\locust-crash-test.yaml
```

**Expected Output:**
```
configmap/locustfile-crash created
job.batch/locust-crash-test created
```

### Step 2: Monitor Job Startup

```powershell
# Watch the job start
kubectl -n sock-shop get pods -l app=locust-crash -w

# Expected Output:
# NAME                          READY   STATUS    RESTARTS   AGE
# locust-crash-test-xxxxx       0/1     Pending   0          1s
# locust-crash-test-xxxxx       0/1     ContainerCreating   0          2s
# locust-crash-test-xxxxx       1/1     Running   0          10s
```

Press `Ctrl+C` to stop watching after the pod shows `Running`.

### Step 3: Monitor Application Degradation in Real-Time

Open multiple PowerShell windows to monitor different aspects:

#### Window 1: Watch Pod Status
```powershell
kubectl -n sock-shop get pods -w
```

**Expected Progression:**
```
# T+0s: Normal
front-end-xxxxx    1/1     Running   0          30m

# T+30s: High CPU
front-end-xxxxx    1/1     Running   0          30m

# T+60s: Health check failures begin
front-end-xxxxx    0/1     Running   0          30m

# T+90s: Pod restart
front-end-xxxxx    0/1     CrashLoopBackOff   1          30m

# T+120s: OOMKilled (if memory exhausted)
front-end-xxxxx    0/1     OOMKilled   2          30m
```

#### Window 2: Monitor Resource Usage
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== RESOURCE USAGE MONITOR ===" -ForegroundColor Cyan
    kubectl top pods -n sock-shop --no-headers | Sort-Object
    Write-Host "`nTimestamp: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}
```

**Expected Progression:**
```
# T+0s: Baseline
front-end    5m     150Mi

# T+30s: Load building
front-end    150m   450Mi

# T+60s: Near limits
front-end    290m   850Mi

# T+90s: Throttled/Crashing
front-end    300m   1000Mi  (CPU throttled, memory at limit)
```

#### Window 3: Monitor Locust Progress
```powershell
kubectl -n sock-shop logs -f job/locust-crash-test
```

**Expected Output:**
```
==========================================
INCIDENT 1: CRASH TEST - STARTING
Target: http://front-end.sock-shop.svc.cluster.local
Users: 3000 | Spawn Rate: 300
Duration: 5m
==========================================
[2025-10-27 05:42:10] Starting Locust 2.32.1
[2025-10-27 05:42:15] Ramping to 3000 users at a rate of 300 per second...
[2025-10-27 05:42:30] All 3000 users spawned

# Statistics during crash
Type     Name                    # reqs   # fails  Avg  Min  Max  Med   req/s
------------------------------------------------------------------------
GET      Browse Catalogue         15234   8234    5234  10  45000  2500  234.5
GET      View Item                10234   6123    6789  15  50000  3200  156.7
POST     Add to Cart               7890   5234   12345  20  60000  4500  121.3
GET      Login Page                5123   3456    8901  12  55000  3800   78.6
------------------------------------------------------------------------
Aggregated                        38481  23047   7892  10  60000  3000  591.1

# High failure rate indicates application is crashing
Current failures: 59.9%
```

### Step 4: Monitor Application Health Checks

```powershell
# Check pod events for health check failures
kubectl -n sock-shop get events --sort-by='.lastTimestamp' -w | Select-String -Pattern "Liveness\|Readiness\|Unhealthy\|OOMKilled\|Crash"
```

**Expected Output:**
```
30s   Warning   Unhealthy   pod/front-end-xxxxx   Readiness probe failed: Get "http://10.244.1.5:8079/": dial tcp 10.244.1.5:8079: connect: connection refused
45s   Warning   Unhealthy   pod/user-xxxxx        Liveness probe failed: Get "http://10.244.1.6:8080/health": context deadline exceeded (Client.Timeout exceeded)
60s   Warning   BackOff     pod/front-end-xxxxx   Back-off restarting failed container
75s   Warning   OOMKilled   pod/front-end-xxxxx   Container front-end was OOMKilled
```

### Step 5: Monitor Datadog Logs

1. Open Datadog Logs Explorer: https://us5.datadoghq.com/logs
2. Set time range: **Past 15 minutes**
3. Apply filter:
   ```
   kube_cluster_name:sockshop-kind kube_namespace:sock-shop
   ```

**Expected Log Patterns:**

**Front-end Service Logs:**
```
ERROR: ECONNREFUSED - Connection refused to user service
ERROR: Request timeout after 30000ms
FATAL: Out of memory - heap limit reached
ERROR: Cannot allocate memory
```

**User Service Logs:**
```
ERROR: MongoDB connection pool exhausted
WARN: High GC pressure detected - 95% of time spent in GC
ERROR: Failed to respond to health check - timeout
```

**Orders Service Logs:**
```
ERROR: Thread pool exhausted - rejecting new requests
WARN: HTTP request queue depth: 500 (limit: 200)
ERROR: Database connection timeout
```

**Kubernetes Events in Datadog:**
```
source:kubernetes status:error
- Pod front-end-xxxxx failed liveness probe
- Container front-end in pod front-end-xxxxx was OOMKilled
- Pod user-xxxxx restarted 3 times
```

### Step 6: Verify Incident Impact

```powershell
# Try to access the application
Invoke-WebRequest -UseBasicParsing http://localhost:2025 -TimeoutSec 5

# Expected Output: ERROR - Connection refused OR timeout
```

**Expected HTTP Errors:**
```
Invoke-WebRequest : Unable to connect to the remote server
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest)
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand
```

---

## 📊 Datadog Monitoring - Complete Guide

### Overview

Datadog provides three primary interfaces for monitoring the incident:
1. **Logs Explorer** - Application and container logs
2. **Event Explorer** - Kubernetes events (OOMKilled, pod restarts, etc.)
3. **Metrics Explorer** - Resource usage (CPU, memory, restarts)

Each serves a different purpose and shows different aspects of the incident.

---

## 🔍 PART 1: Monitoring Logs in Datadog

### Step 1: Access Datadog Logs Explorer

```powershell
# Open Logs Explorer
Start-Process "https://us5.datadoghq.com/logs"
```

**OR manually navigate:**
1. Go to https://us5.datadoghq.com
2. Click "Logs" in left sidebar
3. Click "Explorer"

### Step 2: Set Correct Time Range

**CRITICAL:** Set time range to match your test execution time!

1. Click time selector (top right, shows "Past 15 Minutes")
2. Select **"Past 1 Hour"** or **"Past 4 Hours"**
3. OR set custom time range matching your test window

**Why This Matters:**
- If your test ran 30 minutes ago but you're viewing "Past 15 Minutes", you'll see nothing
- Always set time to INCLUDE your test execution period

### Step 3: Filter to Sock-Shop Namespace

**In the search bar, enter:**
```
kube_namespace:sock-shop
```

**Expected Result:**
- Log stream showing all sock-shop services
- Multiple services visible: front-end, catalogue, orders, user, payment, etc.
- Timestamps within your selected time range

### Step 4: Search for Crash-Related Logs

#### Query 1: SIGTERM Errors (Pod Termination)

**Search:**
```
kube_namespace:sock-shop SIGTERM
```

**Expected Logs:**
```
npm ERR! signal SIGTERM
npm ERR! errno SIGTERM
npm ERR! sock-shop-front-end@1.0.0: `npm start`
npm ERR! Exit status 1
npm ERR! Failed at the sock-shop-front-end@1.0.0 start script
npm ERR! command failed
```

**What This Means:**
- SIGTERM = Kubernetes sent termination signal to container
- Container was killed (usually due to OOM or failed health check)
- Process did not exit cleanly

#### Query 2: Connection Errors (Service Unavailable)

**Search:**
```
kube_namespace:sock-shop "Connection refused"
```

**Expected Logs:**
```
Error: connect ECONNREFUSED 10.244.1.18:8079
Error: socket hang up
ECONNREFUSED: Connection refused
dial tcp 10.244.1.18:8079: connect: connection refused
```

**What This Means:**
- Pod crashed or health check failed
- Service trying to connect but no process listening
- Indicates pod is down or restarting

#### Query 3: Error Spike During Incident

**Search:**
```
kube_namespace:sock-shop service:front-end status:error
```

**Click on "Timeseries" view (top right) to see:**
- Graph showing error count over time
- Should show massive spike during your 5-minute test window
- Return to baseline after test ends

#### Query 4: All Front-End Logs (During Incident)

**Search:**
```
kube_namespace:sock-shop service:front-end
```

**Set time to match your incident window exactly**

**What to Look For:**
- High volume of ERROR level logs
- Request timeouts
- "Error with log in" messages
- Connection failures
- Abrupt stop in log flow (when pod crashes)
- Restart of log flow (when pod recovers)

### Step 5: Use Live Tail for Real-Time Monitoring

**During the test, use Live Tail mode:**

1. Click **"Live Tail"** button (top right corner)
2. Enter filter: `kube_namespace:sock-shop service:front-end`
3. Watch logs stream in real-time

**What You'll See:**
- T+0-2 min: Normal request logs
- T+2-4 min: Increasing error rate
- T+4-5 min: Connection refused, SIGTERM errors
- T+5+ min: Recovery (normal logs resume)

---

## 📅 PART 2: Monitoring Events in Datadog

### Important: Events ≠ Logs!

**KEY DISTINCTION:**
- **Logs** = Application/container output (console logs)
- **Events** = Kubernetes cluster events (pod restarts, OOMKilled, etc.)

**OOMKilled is an EVENT, not a log!**

You will NOT find OOMKilled by searching logs. You must check:
1. Datadog Event Explorer
2. Kubernetes events directly (`kubectl get events`)

### Step 1: Access Datadog Event Explorer

```powershell
# Open Event Explorer
Start-Process "https://us5.datadoghq.com/event/explorer"
```

**OR manually navigate:**
1. Go to https://us5.datadoghq.com
2. Click "Events" in left sidebar
3. Click "Explorer"

### Step 2: Filter to Sock-Shop Events

**In the search bar, enter:**
```
kube_namespace:sock-shop
```

**Set time range: "Past 1 Hour"**

### Step 3: Find Crash Events

**Look for these event types:**

#### Event Type 1: BackOff (Container Crash)

**Appears as:**
```
⚠️ WARN  19 BackOff : Back-off restarting failed container front-end 
         in pod front-end-5db94cdb6b-xkxpf
```

**What This Means:**
- Container crashed and Kubernetes tried to restart it
- Number (19) = how many times it tried to restart
- This is your PRIMARY evidence of crashes!

#### Event Type 2: Unhealthy (Health Check Failed)

**Appears as:**
```
⚠️ WARN  Liveness probe failed: Get "http://10.244.1.18:8079/": 
         context deadline exceeded
         
⚠️ WARN  Readiness probe failed: Get "http://10.244.1.18:8079/": 
         dial tcp 10.244.1.18:8079: connect: connection refused
```

**What This Means:**
- Pod is not responding to health checks
- Either crashed or under too much load to respond
- Precedes pod restart

#### Event Type 3: Killing (Pod Termination)

**Appears as:**
```
ℹ️ INFO  Killing : Container front-end failed liveness probe, will be restarted
```

**What This Means:**
- Kubernetes decided to kill the pod
- Pod will be restarted
- This generates the SIGTERM you see in logs

### Step 4: Expand Event Details

**Click on any event to see full details:**
- Exact timestamp
- Pod name
- Container name  
- Exit code (137 = OOMKilled)
- Full message
- Related events

### Step 5: Filter by Event Status

**On left sidebar, under "Status" section:**
- ✅ **Warn** - Check this to see crash warnings
- ⬜ **Info** - Uncheck to hide normal events
- ✅ **Error** - Check for critical errors

**This filters to show only problem events**

---

## 📈 PART 3: Monitoring Metrics in Datadog

### Step 1: Access Datadog Metrics Explorer

```powershell
# Open Metrics Explorer
Start-Process "https://us5.datadoghq.com/metric/explorer"
```

**OR manually navigate:**
1. Go to https://us5.datadoghq.com
2. Click "Metrics" in left sidebar
3. Click "Explorer"

### Metric 1: Memory Usage (Most Important!)

**Configuration:**
1. **Metric:** `kubernetes.memory.usage`
2. **Filter:** `kube_namespace:sock-shop AND pod_name:front-end*`
3. **Aggregation:** `avg` by `pod_name`
4. **Time Range:** Past 1 hour
5. Click **"Graph"**

**Direct Link:**
```powershell
Start-Process "https://us5.datadoghq.com/metric/explorer?exp_metric=kubernetes.memory.usage&exp_scope=kube_namespace%3Asock-shop%2Cpod_name%3Afront-end*&exp_agg=avg&exp_row_type=metric"
```

**What You Should See:**
- **Baseline:** ~50-200Mi (flat line)
- **T+0-2 min:** Gradual increase to 400-600Mi
- **T+2-4 min:** Sharp spike to 800-1000Mi
- **T+4-5 min:** **Hits exactly 1000Mi** ← THE LIMIT!
- **At limit:** Graph may show **sawtooth pattern** (crash → restart → crash)
- **T+5+ min:** Drop to 0 (crashed), then return to baseline

**KEY INSIGHT:**
- If memory hits exactly 1000Mi (the limit in deployment), that's OOMKilled
- Sawtooth pattern = multiple crash/restart cycles

### Metric 2: CPU Usage

**Configuration:**
1. **Metric:** `kubernetes.cpu.usage`
2. **Filter:** `kube_namespace:sock-shop AND pod_name:front-end*`
3. **Aggregation:** `avg` by `pod_name`
4. **Time Range:** Past 1 hour

**Direct Link:**
```powershell
Start-Process "https://us5.datadoghq.com/metric/explorer?exp_metric=kubernetes.cpu.usage&exp_scope=kube_namespace%3Asock-shop%2Cpod_name%3Afront-end*&exp_agg=avg&exp_row_type=metric"
```

**What You Should See:**
- **Baseline:** ~3-8m (0.003-0.008 cores)
- **During load:** Spike to 250-300m
- **At limit:** Plateaus at 300m (the limit!)
- **CPU throttling:** Cannot exceed limit, requests queue up

### Metric 3: Container Restarts (Definitive Proof!)

**Configuration:**
1. **Metric:** `kubernetes.containers.restarts`
2. **Filter:** `kube_namespace:sock-shop AND pod_name:front-end*`
3. **Aggregation:** `max` by `pod_name`
4. **Time Range:** Past 1 hour

**Direct Link:**
```powershell
Start-Process "https://us5.datadoghq.com/metric/explorer?exp_metric=kubernetes.containers.restarts&exp_scope=kube_namespace%3Asock-shop%2Cpod_name%3Afront-end*&exp_agg=max&exp_row_type=metric"
```

**What You Should See:**
- **Before test:** Flat line at previous count (e.g., 42)
- **During test:** Sharp jump upward (e.g., from 42 → 48)
- **After test:** New flat line at higher count (48)
- **Jump amount:** = number of crashes (6 in this example)

**This is IRREFUTABLE evidence of crashes!**

### Metric 4: All Sock-Shop Resources (Dashboard View)

```powershell
# Open Containers view
Start-Process "https://us5.datadoghq.com/containers?query=kube_namespace%3Asock-shop"
```

**What You See:**
- Table of all sock-shop containers
- Real-time CPU and Memory usage
- Restart counts
- Status (Running, CrashLoopBackOff, etc.)
- Can sort by CPU or Memory to find stressed containers

**During incident:**
- Sort by Memory (descending)
- front-end should be at top with high usage
- Watch restart count increase in real-time

---

## 🔎 PART 4: Kubernetes-Native Verification

### Even Better: Check Kubernetes Directly

Datadog aggregates Kubernetes data, but you can verify directly:

### Command 1: Find OOMKilled Events

```powershell
kubectl -n sock-shop get events --sort-by='.lastTimestamp' | Select-String "OOM|Killing|Unhealthy"
```

**Expected Output:**
```
7m54s   Warning   Unhealthy   pod/front-end-xxxxx   Liveness probe failed: connection refused
7m27s   Warning   Unhealthy   pod/front-end-xxxxx   Readiness probe failed: timeout
3m58s   Normal    Killing     pod/front-end-xxxxx   Container front-end failed liveness probe
```

### Command 2: Describe Pod to Find Exit Code

```powershell
$pod = kubectl -n sock-shop get pods -l name=front-end -o jsonpath='{.items[0].metadata.name}'
kubectl -n sock-shop describe pod $pod | Select-String -Pattern "OOMKilled|Exit Code|Last State" -Context 3
```

**Expected Output:**
```
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
  Started:      Mon, 27 Oct 2025 20:42:15 +0530
  Finished:     Mon, 27 Oct 2025 20:44:23 +0530
```

**Exit Code 137 = OOMKilled** (128 + 9 SIGKILL)

### Command 3: Check Current Restart Count

```powershell
kubectl -n sock-shop get pods | Select-String "front-end"
```

**Example Output:**
```
BEFORE TEST:
front-end-5db94cdb6b-xkxpf   1/1   Running   42   12d

AFTER TEST:
front-end-5db94cdb6b-xkxpf   1/1   Running   48   12d
                                          ^^           
                                    Increased by 6!
```

**The increase (6) = number of OOMKills during test**

---

## 📸 PART 5: Screenshot Evidence Checklist

### For Complete Incident Documentation:

**From Datadog Logs:**
- [ ] Screenshot of error spike in Timeseries view
- [ ] Screenshot showing SIGTERM errors
- [ ] Screenshot showing Connection refused errors
- [ ] Live Tail screenshot during crash

**From Datadog Events:**
- [ ] Screenshot of BackOff events
- [ ] Screenshot of Unhealthy warnings
- [ ] Screenshot showing event count (e.g., "19 BackOff")

**From Datadog Metrics:**
- [ ] Memory graph showing spike to 1000Mi
- [ ] CPU graph showing spike to 300m
- [ ] Restart count graph showing jump
- [ ] Container view showing front-end with high restart count

**From Kubernetes:**
- [ ] Terminal output showing increased restart count
- [ ] `kubectl describe pod` output showing OOMKilled
- [ ] `kubectl get events` output showing Unhealthy warnings

---

## 🎯 PART 6: Step-by-Step Incident Analysis Workflow

### Use This Checklist After Running Incident:

```powershell
# === STEP 1: Verify Incident Occurred ===

# Check restart count increased
kubectl -n sock-shop get pods | Select-String "front-end"
# Note the RESTARTS number - should have increased by 5-10

# === STEP 2: Check Kubernetes Events ===

kubectl -n sock-shop get events --sort-by='.lastTimestamp' | Select-Object -Last 30 | Select-String "front-end"
# Look for: Unhealthy, Killing, BackOff events

# === STEP 3: Find OOMKilled Evidence ===

$pod = kubectl -n sock-shop get pods -l name=front-end -o jsonpath='{.items[0].metadata.name}'
kubectl -n sock-shop describe pod $pod | Select-String "OOMKilled" -Context 5
# Look for: Last State: Terminated, Reason: OOMKilled, Exit Code: 137

# === STEP 4: Check Datadog Logs ===

# Open browser to logs
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop%20SIGTERM&from_ts=START_TIME&to_ts=END_TIME"
# Replace START_TIME and END_TIME with your test window
# Look for: npm ERR! signal SIGTERM

# === STEP 5: Check Datadog Events ===

# Open browser to events
Start-Process "https://us5.datadoghq.com/event/explorer?query=kube_namespace%3Asock-shop"
# Look for: BackOff warnings, Unhealthy events

# === STEP 6: Check Datadog Memory Metric ===

Start-Process "https://us5.datadoghq.com/metric/explorer?exp_metric=kubernetes.memory.usage&exp_scope=kube_namespace%3Asock-shop%2Cpod_name%3Afront-end*"
# Look for: Spike to 1000Mi (the limit), Sawtooth pattern

# === STEP 7: Check Datadog Restart Metric ===

Start-Process "https://us5.datadoghq.com/metric/explorer?exp_metric=kubernetes.containers.restarts&exp_scope=kube_namespace%3Asock-shop%2Cpod_name%3Afront-end*"
# Look for: Jump in restart count during test window

# === STEP 8: Verify Recovery ===

# Check pod is stable now
kubectl -n sock-shop get pods | Select-String "front-end"
# Should show: 1/1 Running (not restarting)

# Check resource usage back to baseline
kubectl top pods -n sock-shop | Select-String "front-end"
# Should show: CPU 3-8m, Memory 50-200Mi
```

---

## 📝 Summary of Monitoring Locations

| Evidence Type | Where to Find | What to Look For |
|---------------|---------------|------------------|
| **OOMKilled Event** | Kubernetes events or Datadog Event Explorer | `Reason: OOMKilled`, `Exit Code: 137` |
| **Pod Restarts** | `kubectl get pods` or Datadog restart metric | RESTARTS count increased |
| **Memory Limit Hit** | Datadog memory metric | Graph spikes to exactly 1000Mi |
| **CPU Throttling** | Datadog CPU metric | Graph plateaus at 300m |
| **SIGTERM Errors** | Datadog Logs (NOT Events!) | `npm ERR! signal SIGTERM` |
| **Connection Errors** | Datadog Logs | `ECONNREFUSED`, `connection refused` |
| **Health Check Failures** | Kubernetes events or Datadog Events | `Unhealthy`, `Liveness probe failed` |
| **BackOff Events** | Datadog Event Explorer (NOT Logs!) | `Back-off restarting failed container` |

---

## ❗ Common Mistakes to Avoid

### Mistake 1: Searching Logs for OOMKilled
**Wrong:** `Query in Logs: kube_namespace:sock-shop OOMKilled`  
**Result:** No logs found ❌

**Right:** Go to **Event Explorer**, not Logs Explorer  
**Result:** Events showing BackOff and container restarts ✓

### Mistake 2: Wrong Time Range
**Wrong:** Viewing "Past 15 Minutes" but test ran 1 hour ago  
**Result:** No data shown ❌

**Right:** Set time to match your test execution window  
**Result:** All incident data visible ✓

### Mistake 3: Not Waiting Long Enough
**Wrong:** Checking Datadog immediately after Helm upgrade  
**Result:** No logs yet (still collecting) ❌

**Right:** Wait 3 minutes after Helm upgrade  
**Result:** Logs flowing to Datadog ✓

### Mistake 4: Checking Wrong Deployment Name
**Wrong:** `kubectl rollout status deployment datadog-cluster-agent`  
**Result:** "not found" error ❌

**Right:** `kubectl rollout status deployment datadog-agent-cluster-agent`  
**Result:** Rollout status displayed ✓

---

## Recovery Steps

### Step 1: Stop the Load Generator

```powershell
# Delete the Locust job
kubectl -n sock-shop delete job locust-crash-test

# Verify deletion
kubectl -n sock-shop get pods -l app=locust-crash
```

**Expected Output:**
```
job.batch "locust-crash-test" deleted
No resources found in sock-shop namespace.
```

### Step 2: Wait for Kubernetes Self-Healing

```powershell
# Watch pods recover
kubectl -n sock-shop get pods -w
```

**Expected Recovery Timeline:**
```
T+0s:   Pods in CrashLoopBackOff state
T+30s:  Kubernetes attempts restart
T+60s:  Pods start successfully (no load)
T+90s:  Health checks pass
T+120s: All pods Running and Ready (1/1)
```

### Step 3: Verify Application Recovery

```powershell
# Check all pods are healthy
kubectl -n sock-shop get pods

# Expected Output: All 1/1 Ready, Running, 0 restarts (or low count)
```

```powershell
# Test application access
Invoke-WebRequest -UseBasicParsing http://localhost:2025 -TimeoutSec 5

# Expected Output: StatusCode 200
```

### Step 4: Verify Normal Resource Usage

```powershell
kubectl top pods -n sock-shop
```

**Expected Output (Recovered State):**
```
NAME                            CPU(cores)   MEMORY(bytes)
front-end-xxxxx                 5m           150Mi
user-xxxxx                      3m           80Mi
orders-xxxxx                    8m           200Mi
payment-xxxxx                   2m           50Mi
```

### Step 5: Clean Up Locust Resources

```powershell
# Remove ConfigMap
kubectl -n sock-shop delete configmap locustfile-crash

# Verify cleanup
kubectl -n sock-shop get configmap | Select-String locust
```

**Expected Output:** No locust-related configmaps found

### Step 6: Verify Datadog Log Recovery

1. Go to Datadog Logs: https://us5.datadoghq.com/logs
2. Query: `kube_namespace:sock-shop service:front-end`
3. Look for recent logs showing normal operation

**Expected Log Patterns (Recovered):**
```
INFO: Application started successfully
INFO: Listening on port 8079
INFO: Health check passed
INFO: Request processed successfully in 45ms
```

---

## Post-Incident Analysis

### Root Cause Summary

**Primary Cause:** Insufficient resource limits for handling burst traffic exceeding 10x normal capacity.

**Contributing Factors:**
1. Single replica per service (no horizontal scaling)
2. No request rate limiting at ingress
3. Aggressive Locust timing (0.5-1.5s wait time)
4. Synchronous blocking calls between services

### Evidence Collected

1. **Pod Events:** OOMKilled and CrashLoopBackOff events
2. **Metrics:** CPU throttling at 300m limit, Memory at 1000Mi limit
3. **Logs:** Connection refused errors, timeout errors, heap exhaustion
4. **Locust Report:** 59.9% failure rate under 3000 user load

### Recommended Remediation (For Production)

1. **Immediate:**
   - Implement HorizontalPodAutoscaler (HPA) with 2-10 replicas
   - Add CPU/Memory headroom: +50% on limits
   
2. **Short-term:**
   - Implement request rate limiting (e.g., 100 req/min per IP)
   - Add circuit breakers for service-to-service calls
   
3. **Long-term:**
   - Implement connection pooling and async processing
   - Add caching layer (Redis/Memcached)
   - Consider serverless autoscaling (e.g., KEDA)

---

## Expected Outcomes

### During Incident
✅ Pod restarts increase  
✅ CPU usage at or above limits (300m-500m)  
✅ Memory usage at or above limits (200Mi-1000Mi)  
✅ HTTP errors (500, 503) in Datadog logs  
✅ OOMKilled events visible  
✅ Application becomes unavailable (connection refused)  
✅ Locust shows >50% failure rate

### After Recovery
✅ All pods return to Running/Ready state  
✅ CPU usage returns to baseline (3-8m)  
✅ Memory usage returns to baseline (50-200Mi)  
✅ Application accessible via http://localhost:2025  
✅ No error logs in Datadog  
✅ Resource metrics stable

---

## Troubleshooting

### Issue: Pods Don't Crash Despite High Load

**Cause:** Load may not be high enough or cluster has excess capacity.

**Solution:**
```powershell
# Increase user count
kubectl -n sock-shop set env job/locust-crash-test USERS=5000 SPAWN_RATE=500

# Or reduce resource limits temporarily
kubectl -n sock-shop set resources deployment front-end --limits=cpu=100m,memory=200Mi
```

### Issue: Locust Job Fails to Start

**Cause:** ConfigMap not created or pod scheduling issues.

**Solution:**
```powershell
# Check ConfigMap exists
kubectl -n sock-shop get configmap locustfile-crash

# Check pod events
kubectl -n sock-shop describe pod -l app=locust-crash
```

### Issue: Port Forward Breaks During Incident

**Cause:** High load can disrupt port forwarding.

**Solution:**
```powershell
# Restart port forward after incident
kubectl -n sock-shop port-forward svc/front-end 2025:80
```

---

## Summary

This incident simulates a realistic production scenario where unexpected traffic surge causes resource exhaustion and application crashes. The Datadog integration allows full visibility into:
- Resource consumption patterns leading to failure
- Error propagation across microservices
- Kubernetes self-healing mechanisms
- Recovery timeline and health restoration

**Total Incident Duration:** ~10 minutes (5m load + 5m recovery)  
**Datadog Value Demonstrated:** Real-time visibility into crash causation and automatic recovery monitoring

---

**Document Version:** 1.0  
**Last Updated:** October 27, 2025  
**Tested On:** kind cluster (sockshop) with Datadog agent
