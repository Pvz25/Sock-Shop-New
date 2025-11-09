# INCIDENT-5: ASYNC PROCESSING FAILURE

**Time:** Nov 9th, 2025 - 20:13 to 20:18 IST (14:43 to 14:48 UTC)

**Datadog Logs:** kube_namespace:sock-shop

---

## Commands:

### 1. Check Queue Master Status
```
kube_namespace:sock-shop service:queue-master
```

**Expected:**
- ❌ NO LOGS during incident window (14:43-14:48 UTC)
- Last log before incident: "Stopping container queue-master"
- First log after recovery: "Started QueueMasterApplication" (~14:48 UTC)
- **Key Signal:** Complete absence of logs = consumer failure

---

### 2. Check Shipping Service (Still Publishing)
```
kube_namespace:sock-shop service:shipping
```

**Expected:**
- ✅ Logs continue throughout incident
- ✅ "Publishing shipping task to queue" messages
- ✅ No errors (shipping doesn't know consumer is down)
- **Key Signal:** Producer active, but consumer absent = silent failure

---

### 3. Check for Pod Scaling Events
```
kube_namespace:sock-shop @evt.name:queue-master
```

**Expected:**
- ❌ "Scaled down replica set queue-master from 1 to 0" at 14:43 UTC
- ❌ "Stopping container queue-master"
- ❌ "Deleted pod: queue-master-xxx"
- ✅ "Scaled up replica set queue-master from 0 to 1" at 14:48 UTC (recovery)
- ✅ "Created container queue-master"
- ✅ "Started container queue-master"

---

### 4. Check Orders Service (User-Facing Success)
```
kube_namespace:sock-shop service:orders "created successfully"
```

**Expected:**
- ✅ Orders still being created successfully
- ✅ HTTP 201 responses
- ✅ NO errors visible to users
- **Key Signal:** Users think orders are working, but shipments won't happen

---

### 5. Combined View: Producer vs Consumer
```
kube_namespace:sock-shop (service:shipping OR service:queue-master)
```

**Expected:**
- ✅ `shipping` logs: Continuous activity
- ❌ `queue-master` logs: ZERO activity during incident
- **Key Signal:** Asymmetry between producer/consumer indicates consumer failure

---

## Metrics:

### 1. Queue Master Pod Count
**Metric:** `kubernetes_state.deployment.replicas_available`
```
from: kube_namespace:sock-shop, kube_deployment:queue-master
sum
```

**Observation Expectations:**
- ✅ Baseline: Value = 1 (healthy)
- ❌ At 14:43 UTC: Drops to **0** (incident trigger)
- ⚠️ During incident: Stays at 0 for ~5 minutes
- ✅ At 14:48 UTC: Returns to **1** (recovery)

**Graph Pattern:**
```
1 ─────┐
       │ ← Incident (14:43)
       │
0 ─────┘────────────┐
                    │ ← Recovery (14:48)
                    │
1 ──────────────────┘
```

---

### 2. RabbitMQ Queue Depth (Messages Piling Up)
**Metric:** `rabbitmq.queue.messages`
```
from: kube_namespace:sock-shop, queue:shipping-task
sum
```

**Observation Expectations:**
- ✅ Before 14:43: Queue depth low (messages consumed quickly)
- ❌ After 14:43: Queue depth **grows linearly** (no consumer)
- ⚠️ Messages accumulate during 5-minute window
- ✅ After 14:48: Queue depth **drops rapidly** (consumer drains backlog)

**Graph Pattern:**
```
Messages
   │      ┌──────────────┐ ← Queue fills up
   │     /                \
   │    /                  \ ← Backlog drained
   │___/                    \___
       14:43           14:48
```

---

### 3. RabbitMQ Consumer Count
**Metric:** `rabbitmq.queue.consumers`
```
from: kube_namespace:sock-shop, queue:shipping-task
sum
```

**Observation Expectations:**
- ✅ Before 14:43: Value = 1 (consumer active)
- ❌ At 14:43: Drops to **0** (consumer killed)
- ⚠️ During incident: Stays at 0 for ~5 minutes
- ✅ At 14:48: Returns to **1** (consumer restored)

**Critical Alert Pattern:**
```
IF (consumers = 0) AND (queue.messages > 10)
THEN: CRITICAL - Consumer failure detected
```

---

### 4. Queue Master CPU/Memory (Drops to Zero)
**Metric:** `kubernetes.cpu.usage.total`
```
from: kube_namespace:sock-shop, kube_deployment:queue-master
avg by: kube_deployment
```

**Observation Expectations:**
- ✅ Before incident: CPU ~10-50m (normal processing)
- ❌ At 14:43: CPU drops to **0m** (no pod exists)
- ⚠️ During incident: CPU remains at 0m
- ✅ After 14:48: CPU returns to normal levels

---

### 5. Shipping Service Publish Rate (Stays Normal)
**Metric:** `rabbitmq.queue.messages.publish.count`
```
from: kube_namespace:sock-shop, queue:shipping-task
rate, sum
```

**Observation Expectations:**
- ✅ Publish rate remains steady throughout incident
- ✅ NO dip or spike in message publishing
- **Key Signal:** Producer unaware of consumer failure

---

## Root Cause Analysis:

### What Happened:
```
queue-master scaled to 0 replicas
        ↓
No consumer to process RabbitMQ messages
        ↓
Messages accumulate in shipping-task queue
        ↓
Orders appear successful (HTTP 201)
        ↓
Shipments never processed (silent failure)
        ↓
Business Impact: HIGH (customers charged but not shipped)
```

---

## AI SRE Detection Strategy:

### Step 1: Check Pod Count
```
Query: kubernetes_state.deployment.replicas_available{kube_deployment:queue-master}
Result: Value = 0 ← PROBLEM DETECTED
```

### Step 2: Check Queue Metrics
```
Query: rabbitmq.queue.consumers{queue:shipping-task}
Result: Value = 0 ← NO CONSUMER

Query: rabbitmq.queue.messages{queue:shipping-task}
Result: Growing linearly ← BACKLOG ACCUMULATING
```

### Step 3: Check Logs
```
Query: kube_namespace:sock-shop service:queue-master
Result: NO LOGS during incident ← ABSENCE IS THE SIGNAL
```

### Conclusion:
**Root Cause:** `queue-master` deployment scaled to 0 → No consumer for RabbitMQ queue → Silent failure (orders succeed but shipments never processed)

**Fix:** Scale `queue-master` back to 1 replica

**Recovery Time:** 6 seconds (pod startup time)

---

## Key Insights for AI SRE:

1. **Silent Failure:** No errors in logs, users unaware of problem
2. **Metrics Over Logs:** Pod count and queue metrics more reliable than logs
3. **Absence as Signal:** The LACK of logs is itself diagnostic
4. **Asymmetry Detection:** Producer active + Consumer absent = Consumer failure
5. **Business Impact:** High (orders charged but never fulfilled)

---

**Document Generated:** Nov 9, 2025  
**Incident Duration:** 5 minutes  
**Recovery:** Successful (queue backlog drained)  
**Datadog Status:** ✅ Logs flowing (2,029 sent)
