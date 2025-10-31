# INCIDENT-4 Datadog Monitoring Guide

**Test Date:** October 31, 2025  
**Test Type:** Pure Latency (500 concurrent users)  
**Actual Result:** HYBRID - Front-end crashes + backend latency  
**Duration:** 8 minutes

---

## 🔍 Real-Time Monitoring URLs

### 1. Live Logs Explorer
```
https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop&stream_sort=desc&viz=stream&live=true
```

### 2. Containers View (Resource Monitoring)
```
https://us5.datadoghq.com/containers?query=kube_namespace%3Asock-shop&sort=cpu&order=desc
```

### 3. Kubernetes Explorer
```
https://us5.datadoghq.com/orchestration/explorer?query=kube_namespace%3Asock-shop
```

### 4. Metrics Explorer
```
https://us5.datadoghq.com/metric/explorer
```

---

## 📊 Log Queries in Datadog

### Query 1: All Sock-Shop Logs
```
kube_namespace:sock-shop
```

**What to look for:**
- Application errors
- High response times
- Connection timeouts
- Pod restart events

---

### Query 2: Locust Test Statistics
```
kube_namespace:sock-shop service:locust-pure-latency
```

**OR** (if service tag not working):
```
kube_namespace:sock-shop pod_name:locust-pure-latency*
```

**Expected output:**
```
Type     Name                # reqs  # fails(%)  |  Avg    Min   Max    Med  | req/s failures/s
GET      Browse Catalogue    3,192   55.29%      |  9,906  2     135,095 2,800 | 0.30  0.30
GET      Login Page          698     100.00%     |  9,301  2     72,640  2,500 | 0.20  0.20
GET      View Cart           1,254   47.21%      |  8,034  2     134,768 1,600 | 0.30  0.30
GET      View Item           1,893   54.94%      |  9,631  2     134,944 2,800 | 0.20  0.20
Aggregated                   7,037   58.19%      |  9,439  2     135,095 2,500 | 1.00  1.00
```

**Key insights:**
- 58% failure rate (high but not total outage)
- 9.4 second average response time
- 135 second peak (2.25 minutes!)
- Login page completely failing (100%)

---

### Query 3: Front-End Service Logs
```
kube_namespace:sock-shop service:sock-shop-front-end
```

**OR:**
```
kube_namespace:sock-shop pod_name:front-end*
```

**What to look for:**
- SIGTERM signals (indicates crashes)
- npm ERR! command failed
- Connection refused errors
- 401 authentication errors
- High response time warnings

**Example crash log:**
```
npm ERR! signal SIGTERM
npm ERR! command sh -c node server.js
```

---

### Query 4: Backend Services (Catalogue, User, Orders)
```
kube_namespace:sock-shop (service:sock-shop-catalogue OR service:sock-shop-user OR service:sock-shop-orders)
```

**What to look for:**
- Health check results
- Slow query warnings
- Database connection issues
- Should show STABLE behavior (no crashes)

---

### Query 5: Error Logs Only
```
kube_namespace:sock-shop status:error
```

**This will show:**
- Application errors
- Connection failures
- Timeout errors
- Database errors

---

### Query 6: Pod Restart Events
```
kube_namespace:sock-shop "Killing container" OR "Container started" OR "Started container"
```

**Expected for this incident:**
- Front-end: Multiple container kill/restart events
- Backend services: Should show NO new restarts

---

## 📈 Metrics Queries in Datadog

### Metric 1: CPU Usage by Pod
```
Metric: kubernetes.cpu.usage.total
Filter: kube_namespace:sock-shop
Aggregation: avg by pod_name
Time Range: Last 15 minutes
```

**Expected graph:**
- **Front-end:** Spikes to 200-250m during load, drops during crashes
- **Catalogue:** Elevated to 50-100m (handling requests)
- **User:** Elevated to 30-60m
- **Others:** Baseline levels

**How to interpret:**
- Front-end shows jagged spikes = crash/restart cycle
- Backend shows sustained elevation = latency under load

---

### Metric 2: Memory Usage by Pod
```
Metric: kubernetes.memory.usage
Filter: kube_namespace:sock-shop
Aggregation: avg by pod_name
Time Range: Last 15 minutes
```

**Expected:**
- Front-end: 80-150Mi (variable due to restarts)
- Backend services: Stable at baseline levels
- Database pods: Stable

---

### Metric 3: Container Restarts (CRITICAL)
```
Metric: kubernetes.containers.restarts
Filter: kube_namespace:sock-shop
Aggregation: sum by pod_name
Time Range: Last 15 minutes
```

**Expected graph:**
- **Front-end:** Step increases (5+ new restarts during 8-minute test)
- **All backend services:** FLAT LINE (no increases)

**This metric proves it's a front-end bottleneck, not system-wide failure**

---

### Metric 4: Network Traffic
```
Metric: kubernetes.network.rx_bytes
Filter: kube_namespace:sock-shop
Aggregation: sum by pod_name
Time Range: Last 15 minutes
```

**Expected:**
- Front-end: High inbound traffic (receiving 500 concurrent connections)
- Backend: Moderate traffic (filtered through front-end crashes)

---

### Metric 5: CPU Throttling (Advanced)
```
Metric: kubernetes.cpu.cfs.throttled.seconds
Filter: kube_namespace:sock-shop
Aggregation: rate by pod_name
Time Range: Last 15 minutes
```

**Expected:**
- Front-end: High throttling = CPU limits being hit
- This indicates resource constraints causing slowness

---

## 🔔 Events in Datadog

### View Pod Events
```
Navigate to: Infrastructure → Kubernetes Explorer
Filter: kube_namespace:sock-shop
Select: front-end pod
View: Events tab
```

**Expected events:**
- Container killed (repeated)
- Container started (repeated)
- Liveness probe failed
- Readiness probe failed
- Back-off restarting failed container

---

## 🎯 Key Findings Summary

### Expected Behavior (Pure Latency - Incident 4 Goal)
- ✅ Response times: 2-5 seconds
- ✅ Failure rate: < 10%
- ✅ Pod restarts: **0** (NO CRASHES)
- ✅ User experience: Slow but functional

### Actual Behavior (HYBRID - Similar to Incident 2)
- 🔴 Response times: 9-135 seconds (much worse!)
- 🔴 Failure rate: 58% (very high!)
- 🔴 Front-end restarts: **5+ crashes** (NOT pure latency!)
- 🔴 User experience: Intermittent with frequent failures

**Conclusion:** At 500 users, the application exhibits HYBRID behavior (front-end crashes + backend latency), not pure latency as intended. The threshold for pure latency is likely **< 400 users**.

---

## 🔧 Datadog Dashboard Widgets (Recommended)

If creating a dashboard for this incident:

### Widget 1: Timeseries - CPU Usage
```
Metric: avg:kubernetes.cpu.usage.total{kube_namespace:sock-shop} by {pod_name}
```

### Widget 2: Timeseries - Container Restarts
```
Metric: sum:kubernetes.containers.restarts{kube_namespace:sock-shop} by {pod_name}
```

### Widget 3: Query Value - Current Failure Rate
```
Log Query: kube_namespace:sock-shop service:locust-pure-latency
Pattern match: "Aggregated"
Extract: failure percentage
```

### Widget 4: Log Stream - Live Errors
```
kube_namespace:sock-shop status:error
```

---

## 💡 Investigation Workflow

When investigating this incident in Datadog:

1. **Start with Logs Explorer** → Confirm test is running
   ```
   kube_namespace:sock-shop service:locust-pure-latency
   ```

2. **Check Containers View** → Identify which pods have high CPU/restarts
   ```
   Filter: kube_namespace:sock-shop
   Sort by: CPU (descending)
   ```

3. **View Metrics** → Confirm front-end is bottleneck
   ```
   kubernetes.containers.restarts{kube_namespace:sock-shop}
   ```

4. **Examine Pod Events** → Understand crash reasons
   ```
   Kubernetes Explorer → front-end pod → Events
   ```

5. **Correlate Logs** → Match restart times with error logs
   ```
   kube_namespace:sock-shop pod_name:front-end* "SIGTERM"
   ```

---

## 📧 Alert Configuration (Recommended)

### Alert 1: High CPU Usage
```
Monitor Type: Metric Monitor
Metric: avg:kubernetes.cpu.usage.total{kube_namespace:sock-shop,pod_name:front-end*}
Threshold: Alert > 200m for 3 minutes
Message: Front-end CPU high - potential performance degradation
```

### Alert 2: Pod Restarts
```
Monitor Type: Metric Monitor
Metric: sum:kubernetes.containers.restarts{kube_namespace:sock-shop,pod_name:front-end*}
Threshold: Alert if increases by > 0 in 5 minutes
Message: Front-end pod restarting - investigate immediately
```

### Alert 3: High Error Rate
```
Monitor Type: Log Monitor
Query: kube_namespace:sock-shop status:error
Threshold: Alert if > 50 errors in 5 minutes
Message: High error rate in sock-shop namespace
```

---

## 🎓 Learning Points

### What This Incident Teaches:

1. **Front-end is the bottleneck** - Single replica cannot handle 500 concurrent users
2. **Horizontal scaling needed** - HPA or manual scaling to 2-3 replicas
3. **Resource limits matter** - CPU/memory constraints cause crashes
4. **Monitoring is critical** - Datadog caught all the symptoms

### Remediation Strategies:

1. **Immediate:** Scale front-end to 2-3 replicas
   ```bash
   kubectl scale deployment front-end --replicas=3 -n sock-shop
   ```

2. **Short-term:** Increase resource limits
   ```yaml
   resources:
     limits:
       cpu: 500m      # was 300m
       memory: 1Gi    # was 500Mi
   ```

3. **Long-term:** Implement HPA
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: front-end-hpa
   spec:
     scaleTargetRef:
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
           averageUtilization: 60
   ```

---

**Document Created:** October 31, 2025  
**Test Scenario:** INCIDENT-4-APP-LATENCY (500 users, 8 minutes)  
**Actual Result:** HYBRID crash+latency behavior  
**Datadog Site:** us5.datadoghq.com
