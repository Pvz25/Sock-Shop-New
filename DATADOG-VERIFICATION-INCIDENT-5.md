# INCIDENT-5: Async Processing Failure - Datadog Verification Guide

## Incident Timeline

**Type:** Asynchronous Processing Failure (Silent Failure)  
**Start Time (IST):** 2025-11-09 19:47:17  
**Start Time (UTC):** 2025-11-09 14:17:17  
**Trigger Time (IST):** 2025-11-09 19:54:11  
**Recovery Start (IST):** 2025-11-09 19:57:33  
**Recovery Complete (IST):** 2025-11-09 19:57:39  
**Total Duration:** ~10 minutes  
**Recovery Time:** 6 seconds

---

## Incident Summary

**Root Cause:** `queue-master` deployment scaled to 0 replicas, resulting in no consumer to process RabbitMQ messages.

**Symptom:** Orders appear successful to users (HTTP 200), but shipments are never processed. This is a **silent failure** - no immediate errors visible to users.

**Business Impact:**
- Orders placed but never fulfilled
- Customers charged but no shipment initiated
- Queue backlog growing silently
- No error messages to alert operators

**Technical Impact:**
- RabbitMQ `shipping-task` queue accumulating unprocessed messages
- `shipping` service publishing messages normally
- `queue-master` consumer completely absent (0 pods)
- System appears healthy from user perspective

---

## Datadog Log Queries

### 1. Check Queue Master Pod Status
```
kube_namespace:sock-shop service:queue-master
```

**Expected Results During Incident:**
- ❌ No logs from `queue-master` after 19:47:17 (IST)
- ❌ Pod termination logs: "Stopping container queue-master"
- ✅ Before incident: Normal startup logs and message consumption
- ✅ After recovery (19:57:39): New pod starts processing backlog

**Key Log Patterns:**
```
"Started QueueMasterApplication"
"Received shipment task"
"Processing shipment for order"
"Stopping container queue-master"  ← Incident trigger
```

---

### 2. Check Shipping Service Logs (Still Publishing)
```
kube_namespace:sock-shop service:shipping
```

**Expected Results:**
- ✅ Shipping service continues running normally
- ✅ Publishes messages to RabbitMQ queue
- ✅ No errors in shipping service itself
- ⚠️ **This is the danger:** Everything looks normal, but messages aren't consumed

**Key Log Patterns:**
```
"Started ShippingServiceApplication"
"RabbitMQ connection established"
"Publishing shipping task to queue"
```

**Critical Insight:**  
The shipping service has **no visibility** into whether messages are being consumed. It successfully publishes to RabbitMQ and returns HTTP 200, creating the illusion of success.

---

### 3. Check Kubernetes Events for Queue Master
```
kube_namespace:sock-shop @evt.name:queue-master
```

**Expected Results:**
- ❌ "Scaled down replica set queue-master-7c58cb7bcf from 1 to 0" at 19:47:17
- ❌ "Stopping container queue-master"
- ❌ "Deleted pod: queue-master-7c58cb7bcf-mcdd5"
- ✅ "Scaled up replica set queue-master-7c58cb7bcf from 0 to 1" at 19:57:33 (recovery)
- ✅ "Created container queue-master"
- ✅ "Started container queue-master"

---

### 4. Check for Missing Logs (The Silent Failure)
```
kube_namespace:sock-shop (service:queue-master OR @pod_name:*queue-master*) 
```

**Time Range:** 19:47:17 to 19:57:33 (IST)

**Expected Results:**
- ❌ **ZERO logs during incident window** (This is the smoking gun!)
- ✅ Logs before 19:47:17 (normal operation)
- ✅ Logs after 19:57:39 (recovery)

**Datadog Query to Highlight the Gap:**
```
kube_namespace:sock-shop @pod_name:*queue-master* | timeseries count() by @pod_name
```
**Expected Graph:**  
You'll see a **complete drop to 0** during the incident window, then resumption after recovery.

---

### 5. Check Combined View: Shipping vs Queue Master
```
kube_namespace:sock-shop (service:shipping OR service:queue-master)
```

**Expected Pattern:**
- ✅ **Before Incident:** Both services logging actively
- ⚠️ **During Incident:** 
  - `shipping`: Logs continue (publishing messages)
  - `queue-master`: **NO LOGS** (consumer absent)
- ✅ **After Recovery:** Both services logging again

**Key Insight for AI SRE:**  
Look for **asymmetry** between producer (shipping) and consumer (queue-master). If one is active and the other is silent, it indicates a consumer failure.

---

### 6. Check Orders Service (User-Facing Success)
```
kube_namespace:sock-shop service:orders "created successfully"
```

**Expected Results:**
- ✅ Orders still being created successfully
- ✅ HTTP 201 responses returned to users
- ✅ No errors in orders service
- ⚠️ Users have **no indication** that shipments won't be processed

**Business Logic Flaw:**  
The orders service doesn't wait for confirmation that the shipping message was consumed - it assumes async reliability.

---

## Datadog Metrics Queries

### 1. Queue Master Pod Count
```
Metric: kubernetes_state.deployment.replicas_available
Filter: kube_namespace:sock-shop, kube_deployment:queue-master
Aggregation: sum
```

**Expected Observations:**
- ✅ **Before 19:47:17:** Value = 1 (healthy)
- ❌ **After 19:47:17:** Value drops to **0** (incident trigger)
- ⚠️ **During incident:** Stays at 0 for ~10 minutes
- ✅ **After 19:57:33:** Rises back to 1 (recovery)

**Graph Pattern:**  
```
1 ─────────┐
           │ <- Incident start (19:47:17)
           │
0 ─────────┘─────────────────┐
                             │ <- Recovery (19:57:33)
                             │
1 ───────────────────────────┘
```

---

### 2. RabbitMQ Queue Depth (Messages Piling Up)
```
Metric: rabbitmq.queue.messages
Filter: kube_namespace:sock-shop, queue:shipping-task
Aggregation: sum
```

**Expected Observations:**
- ✅ **Before incident:** Queue depth stays low (messages consumed quickly)
- ❌ **During incident:** Queue depth **grows linearly** (no consumer)
- ✅ **After recovery:** Queue depth **drops rapidly** (backlog processed)

**Graph Pattern:**
```
Messages
   │      ┌─────────────────┐ <- Queue fills up (no consumer)
   │     /                   \
   │    /                     \ <- Backlog drained (consumer restored)
   │___/                       \___
   ├─────────────────────────────────> Time
   19:00   19:47   19:54   19:57   20:00
           ^       ^       ^
           |       |       Recovery
           |       Incident fully active
           Consumer scaled to 0
```

---

### 3. RabbitMQ Consumer Count
```
Metric: rabbitmq.queue.consumers
Filter: kube_namespace:sock-shop, queue:shipping-task
Aggregation: sum
```

**Expected Observations:**
- ✅ **Before 19:47:17:** Value = 1 (queue-master consuming)
- ❌ **After 19:47:17:** Value drops to **0** (no consumer)
- ✅ **After 19:57:39:** Value returns to **1** (consumer restored)

**Critical Alert Threshold:**  
If `rabbitmq.queue.consumers` = 0 AND `rabbitmq.queue.messages` > 10, trigger **CRITICAL** alert.

---

### 4. Shipping Service Publish Rate (Stays Normal)
```
Metric: rabbitmq.queue.messages.publish.count
Filter: kube_namespace:sock-shop, queue:shipping-task
Aggregation: rate, sum
```

**Expected Observations:**
- ✅ **Throughout incident:** Publish rate remains steady
- ✅ **No dip or spike** in message publishing
- ⚠️ **This confirms:** Producer (shipping) unaware of consumer failure

---

### 5. Queue Master CPU/Memory (Drops to Zero)
```
Metric: kubernetes.cpu.usage.total
Filter: kube_namespace:sock-shop, kube_deployment:queue-master
Aggregation: avg by kube_deployment
```

**Expected Observations:**
- ✅ **Before incident:** CPU ~10-50m (normal processing)
- ❌ **During incident:** CPU drops to **0m** (no pod exists)
- ✅ **After recovery:** CPU returns to normal levels

---

## Kubernetes-Native Verification

### Check Deployment Status
```bash
kubectl -n sock-shop get deployment queue-master
```

**Expected Output During Incident:**
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
queue-master   0/0     0            0           5h44m
                ^
                └─ This is the problem!
```

**Expected Output After Recovery:**
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
queue-master   1/1     1            1           5h44m
```

---

### Check Pod Status
```bash
kubectl -n sock-shop get pods -l name=queue-master
```

**Expected Output During Incident:**
```
No resources found in sock-shop namespace.
```

**Expected Output After Recovery:**
```
NAME                            READY   STATUS    RESTARTS   AGE
queue-master-7c58cb7bcf-ctpm9   1/1     Running   0          6s
```

---

### Check Events
```bash
kubectl -n sock-shop get events --sort-by='.lastTimestamp' | grep queue-master
```

**Key Events:**
```
19:47:17  Normal   ScalingReplicaSet   Scaled down replica set queue-master from 1 to 0
19:47:17  Normal   Killing             Stopping container queue-master
19:47:17  Normal   SuccessfulDelete    Deleted pod: queue-master-7c58cb7bcf-mcdd5
19:57:33  Normal   ScalingReplicaSet   Scaled up replica set queue-master from 0 to 1
19:57:39  Normal   Created             Created container queue-master
19:57:39  Normal   Started             Started container queue-master
```

---

### Check RabbitMQ Queue Status (Via Management API)
```bash
# Port-forward RabbitMQ management
kubectl -n sock-shop port-forward svc/rabbitmq 15672:9090

# Query queue status
curl -u guest:guest http://localhost:15672/api/queues/sock-shop/shipping-task
```

**Expected JSON Fields During Incident:**
```json
{
  "name": "shipping-task",
  "messages": 25,              ← Growing number
  "messages_ready": 25,        ← All messages unacknowledged
  "messages_unacknowledged": 0,
  "consumers": 0,              ← No consumers! THIS IS THE ISSUE
  "state": "running"
}
```

**Expected JSON Fields After Recovery:**
```json
{
  "name": "shipping-task",
  "messages": 0,               ← Queue drained
  "messages_ready": 0,
  "messages_unacknowledged": 1,
  "consumers": 1,              ← Consumer restored!
  "state": "running"
}
```

---

## AI SRE Agent Detection Workflow

### Step 1: Initial Analysis
**Query Datadog Logs:**
```
kube_namespace:sock-shop status:error
```

**Expected Result:** ⚠️ **No errors found!**  
**AI SRE Reasoning:** This is a silent failure - no immediate errors visible.

---

### Step 2: Deployment Health Check
**Query Datadog Metrics:**
```
kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop}
```

**AI SRE Observation:**  
- All deployments show `replicas_available = 1` EXCEPT:
  - ❌ `queue-master`: `replicas_available = 0`

**AI SRE Conclusion:** `queue-master` is scaled to 0 or crashed.

---

### Step 3: Correlate with Queue Metrics
**Query RabbitMQ Metrics:**
```
rabbitmq.queue.messages{kube_namespace:sock-shop, queue:shipping-task}
rabbitmq.queue.consumers{kube_namespace:sock-shop, queue:shipping-task}
```

**AI SRE Observation:**
- `rabbitmq.queue.messages`: Growing steadily (25+ messages)
- `rabbitmq.queue.consumers`: **0 consumers**

**AI SRE Reasoning:**  
Messages are being published but not consumed → Consumer failure.

---

### Step 4: Root Cause Identification
**Query Logs:**
```
kube_namespace:sock-shop service:queue-master
```

**AI SRE Observation:**  
- Last log entry: 19:47:17 "Stopping container queue-master"
- No logs after 19:47:17 until recovery at 19:57:39

**AI SRE Root Cause:**  
`queue-master` deployment scaled to 0 replicas, resulting in no consumer to process RabbitMQ messages.

---

### Step 5: Impact Assessment
**Check Orders Service:**
```
kube_namespace:sock-shop service:orders "created successfully"
```

**AI SRE Observation:**  
- Orders still being created successfully
- No errors returned to users

**AI SRE Business Impact:**  
**HIGH SEVERITY** - Silent failure where users believe orders are placed successfully, but shipments will never be processed. This leads to:
- Customer complaints ("Where's my order?")
- Revenue loss (refunds, customer churn)
- Reputation damage

---

### Step 6: Remediation
**AI SRE Action:**
```bash
kubectl -n sock-shop scale deployment/queue-master --replicas=1
```

**Verification:**
```bash
kubectl -n sock-shop wait --for=condition=ready pod -l name=queue-master --timeout=60s
```

**AI SRE Confirmation:**  
- `queue-master` pod created in 6 seconds
- RabbitMQ consumer count returns to 1
- Queue backlog starts draining

---

## Critical Insights for AI SRE Agent

### 1. **Silent Failure Detection**
**Lesson:** Not all failures produce errors. The absence of logs is itself a signal.

**Detection Pattern:**
```
IF (deployment.replicas_available = 0) 
AND (rabbitmq.queue.messages > 10)
AND (rabbitmq.queue.consumers = 0)
THEN: Consumer failure (silent)
```

---

### 2. **Async System Failure Modes**
**Producer/Consumer Mismatch:**
- Producer (shipping): Publishing messages successfully
- Consumer (queue-master): Absent

**Detection:**
```
IF (publish_rate > 0) AND (consumer_count = 0)
THEN: Consumer failure
```

---

### 3. **Metrics Over Logs**
**Why Logs Failed:**  
No error logs were generated because the consumer simply didn't exist.

**Why Metrics Succeeded:**
- `kubernetes_state.deployment.replicas_available = 0` (pod count)
- `rabbitmq.queue.consumers = 0` (consumer count)
- `rabbitmq.queue.messages` growing (queue depth)

**AI SRE Strategy:**  
For silent failures, **metrics are more reliable than logs**.

---

### 4. **Time-Series Analysis**
**Key Pattern:**
- Pod count drops from 1 → 0 at 19:47:17
- Queue depth starts growing at 19:47:17
- Consumer count drops to 0 at 19:47:17

**Correlation:**  
All three metrics change at the **exact same timestamp** → Strong causal link.

---

### 5. **Recovery Validation**
**Metrics to Monitor Post-Recovery:**
1. `kubernetes_state.deployment.replicas_available` returns to 1 ✅
2. `rabbitmq.queue.consumers` returns to 1 ✅
3. `rabbitmq.queue.messages` drops to 0 (backlog drained) ✅
4. New logs from `queue-master` pod ✅

**Recovery Time:** 6 seconds (pod startup time)

---

## Comparison: INCIDENT-5 vs INCIDENT-1

| Aspect | INCIDENT-1 (App Crash) | INCIDENT-5 (Async Failure) |
|--------|------------------------|----------------------------|
| **User Visibility** | ✅ Errors visible (503, 500) | ❌ No errors (HTTP 200) |
| **Log Errors** | ✅ Many error logs | ❌ No error logs |
| **Failure Mode** | Synchronous (immediate) | Asynchronous (delayed) |
| **Detection Difficulty** | Easy (errors everywhere) | Hard (silent failure) |
| **Business Impact Timing** | Immediate (order fails) | Delayed (shipment never arrives) |
| **Primary Signal** | Logs + Errors | Metrics (pod count, queue depth) |
| **Recovery Complexity** | Medium (pod restart) | Easy (scale up) |
| **MTTR** | 1-5 minutes | 6 seconds |

---

## Alerting Rules for Datadog

### Rule 1: Consumer Failure Alert
```
Alert when:
  rabbitmq.queue.consumers{queue:shipping-task} = 0
AND
  rabbitmq.queue.messages{queue:shipping-task} > 10

Severity: CRITICAL
Notification: "RabbitMQ consumer failure - queue-master not consuming messages"
```

### Rule 2: Queue Depth Alert
```
Alert when:
  rabbitmq.queue.messages{queue:shipping-task} > 50

Severity: WARNING
Notification: "RabbitMQ queue depth exceeds threshold - check consumer health"
```

### Rule 3: Pod Count Alert
```
Alert when:
  kubernetes_state.deployment.replicas_available{kube_deployment:queue-master} = 0

Severity: CRITICAL
Notification: "queue-master deployment scaled to 0 - async processing halted"
```

---

## Summary for AI SRE Agent

**Incident Type:** Silent Failure (Async Processing)

**Root Cause:** `queue-master` scaled to 0 → No consumer for RabbitMQ queue

**Detection Method:**
1. Check pod count (`replicas_available = 0`)
2. Check queue consumers (`rabbitmq.queue.consumers = 0`)
3. Check queue depth (`rabbitmq.queue.messages` growing)
4. Check log absence (no `queue-master` logs)

**Key Insight:**  
**The absence of logs is the signal.** Metrics (pod count, queue depth) are more reliable than logs for detecting silent failures.

**Recovery:**
```bash
kubectl -n sock-shop scale deployment/queue-master --replicas=1
```

**Verification:**
- Pod count returns to 1
- Consumer count returns to 1
- Queue depth drops to 0
- Logs resume from new pod

---

**Document Version:** 1.0  
**Incident Date:** November 9, 2025  
**Verification Status:** ✅ Logs flowing to Datadog (1023 logs sent)  
**AI SRE Readiness:** ✅ All signals captured and documented
