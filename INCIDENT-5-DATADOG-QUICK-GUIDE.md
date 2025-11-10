# INCIDENT-5: ASYNC PROCESSING FAILURE - Datadog Quick Guide

**Incident Type**: Silent Failure (Async Consumer Unavailable)

**Time (IST)**: Nov 10, 2025, 09:25:51 to 09:30:51 IST  
**Time (UTC)**: Nov 10, 2025, 03:55:51 to 04:00:51 UTC  
**Duration**: ~5 minutes

**Root Cause**: `queue-master` deployment scaled to 0 replicas → No consumer to process RabbitMQ messages

**User Impact**: Orders show SUCCESS ✅ but shipments NEVER processed ❌ (Silent Failure!)

---

## ⚠️ IMPORTANT: Service Name Format

Datadog uses **`sock-shop-` prefix** for service tags:
- ✅ Correct: `service:sock-shop-queue-master`
- ❌ Wrong: `service:queue-master`

**All Available Services**: `sock-shop-queue-master`, `sock-shop-shipping`, `sock-shop-orders`, `sock-shop-payment`, `sock-shop-catalogue`, `sock-shop-user`, `sock-shop-front-end`

---

## DATADOG LOGS

**Namespace Filter**: `kube_namespace:sock-shop`

---

### 1. Queue-Master Service (Consumer - Was DOWN)

```
kube_namespace:sock-shop service:sock-shop-queue-master
```

**Expected**:
- ❌ **ZERO logs from 03:55:51 to 04:01:56 UTC** (This is the incident!)
- ✅ Logs before incident (old pod)
- ✅ Logs after 04:01:56 UTC (new pod, processing backlog)

**Key Log Patterns**:
```
✅ "Started QueueMasterApplication" - Pod startup
✅ "Received shipment task: 69116273f9f4890001350fe0" - Processing backlog after recovery
❌ NO LOGS during incident = No consumer = Silent failure
```

**Critical Insight**: The **absence of logs** is the primary signal for this incident type.

---

### 2. Shipping Service (Producer - Still Active)

```
kube_namespace:sock-shop service:sock-shop-shipping
```

**Expected**:
- ✅ Logs **throughout** the incident period
- ✅ "Adding shipment to queue with publisher confirms"
- ✅ No errors in shipping service

**Key Log Patterns**:
```
✅ "Started ShippingServiceApplication"
✅ "Adding shipment to queue with publisher confirms..."
✅ Messages successfully published to RabbitMQ
```

**Critical Insight**: Producer (shipping) healthy while consumer (queue-master) absent = **Asymmetric failure** proving silent failure mode.

---

### 3. Orders Service (User-Facing Success - Proving Silent Failure)

```
kube_namespace:sock-shop service:sock-shop-orders
```

**Expected**:
- ✅ Orders created successfully during incident
- ✅ HTTP 201/200 responses
- ✅ **NO error messages** (users have no indication of problem!)

**Key Log Patterns**:
```
✅ "Order created successfully"
✅ Status: 201 Created
✅ No errors returned to users
```

**Critical Insight**: Users (you!) see SUCCESS despite broken async pipeline = **Silent failure**.

---

### 4. Combined View: Producer vs Consumer (Asymmetric Failure)

```
kube_namespace:sock-shop (service:sock-shop-shipping OR service:sock-shop-queue-master)
```

**Expected Pattern**:
- ✅ **Before incident**: Both services logging
- ⚠️ **During incident**: 
  - `sock-shop-shipping`: Logs present ✅
  - `sock-shop-queue-master`: **NO LOGS** ❌
- ✅ **After recovery**: Both services logging again

**Critical Insight**: Asymmetry between producer and consumer = async consumer failure.

---

### 5. Kubernetes Events (Scaling Actions)

```
kube_namespace:sock-shop @evt.name:queue-master
```

**Expected**:
- ❌ "Scaled down replica set queue-master from 1 to 0" at 03:55:51
- ❌ "Stopping container queue-master"
- ❌ "Deleted pod"
- ✅ "Scaled up replica set queue-master from 0 to 1" at 04:01:03
- ✅ "Created container queue-master"
- ✅ "Started container queue-master"

---

### 6. Log Absence Pattern (Visual Proof)

```
kube_namespace:sock-shop service:sock-shop-queue-master | timeseries count() by service
```

**Expected Graph**:
```
Log Count
  100 ────────┐
              │ ← Incident start (03:55:51)
              │
    0 ────────┴───────────┐
                          │ ← Recovery (04:01:03)
                          │
  100 ───────────────────┘
```

**Observation**: Complete drop to 0 log entries = Pod doesn't exist = Consumer absent.

---

## DATADOG METRICS

### 1. Deployment Replica Count (Primary Signal)

**Metric**: `kubernetes_state.deployment.replicas_available`  
**From**: `kube_namespace:sock-shop, kube_deployment:queue-master`  
**Aggregation**: `avg by kube_deployment`

**Observation Expectations**:
```
Replicas
  1 ──────┐
          │ ← Incident start (03:55:51)
          │
  0 ──────┴─────────┐
                    │ ← Recovery (04:01:03)
                    │
  1 ───────────────┘
```

**✅ Baseline**: 1 replica (healthy)  
**❌ Incident**: **0 replicas** (deployment scaled to zero)  
**✅ Recovery**: 1 replica (restored)

**Conclusion**: Deployment scaled to 0 = No pods = No consumer = Silent failure

---

### 2. RabbitMQ Consumer Count (Critical Signal)

**Metric**: `rabbitmq.queue.consumers`  
**From**: `kube_namespace:sock-shop, queue:shipping-task`  
**Aggregation**: `sum`

**Observation Expectations**:
```
Consumers
  1 ──────┐
          │ ← Incident start
          │
  0 ──────┴─────────┐
                    │ ← Recovery
                    │
  1 ───────────────┘
```

**✅ Baseline**: 1 consumer  
**❌ Incident**: **0 consumers** (no queue-master pod)  
**✅ Recovery**: 1 consumer

**Conclusion**: Consumer count = 0 + Queue depth > 0 = **CRITICAL ALERT CONDITION**

---

### 3. RabbitMQ Queue Depth (Messages Piling Up)

**Metric**: `rabbitmq.queue.messages`  
**From**: `kube_namespace:sock-shop, queue:shipping-task`  
**Aggregation**: `sum`

**Observation Expectations**:
```
Messages
   │        ┌──────┐
   │       /        \
   │      /          \ ← Backlog drained after recovery
   │_____/            \____
   ├────────────────────────> Time
   03:50  03:55  04:01  04:05
          ↑      ↑
          Start  Recovery
```

**✅ Baseline**: Low queue depth (messages consumed quickly)  
**❌ Incident**: **Queue fills up** (your orders accumulating, no consumer)  
**✅ Recovery**: **Queue drains** (backlog processed by restored consumer)

**Conclusion**: Queue depth increases while consumers = 0 = Messages accumulating but never processed

---

### 4. Queue-Master CPU Usage (Drops to Zero)

**Metric**: `kubernetes.cpu.usage.total`  
**From**: `kube_namespace:sock-shop, kube_deployment:queue-master`  
**Aggregation**: `avg by kube_deployment`

**Observation Expectations**:

**✅ Baseline**: ~10-50m (normal processing)  
**❌ Incident**: **CPU = 0m** (no pod exists)  
**✅ Recovery**: Returns to ~10-50m (normal processing)

**Conclusion**: CPU drops to absolute zero = Pod doesn't exist (not just idle)

---

### 5. Queue-Master Memory Usage (Drops to Zero)

**Metric**: `kubernetes.memory.usage`  
**From**: `kube_namespace:sock-shop, kube_deployment:queue-master`  
**Aggregation**: `avg by kube_deployment`

**Observation Expectations**:

**✅ Baseline**: ~80-120 MiB  
**❌ Incident**: **Memory = 0** (no pod exists)  
**✅ Recovery**: Returns to ~80-120 MiB

**Conclusion**: Memory drops to zero = Pod doesn't exist

---

### 6. RabbitMQ Message Publish Rate (Producer Still Active)

**Metric**: `rabbitmq.queue.messages.publish.count`  
**From**: `kube_namespace:sock-shop, queue:shipping-task`  
**Aggregation**: `rate, sum`

**Observation Expectations**:

**✅ Before Incident**: Steady publish rate  
**✅ During Incident**: **Publish rate continues** (shipping service still active)  
**✅ After Recovery**: Steady publish rate

**Conclusion**: Consistent publish rate during incident = Producer unaware of consumer failure = Proves asymmetric failure

---

## INCIDENT FLOW

```
User Places Orders (You!)
        ↓
✅ Orders Service: HTTP 200 OK (Success to user)
        ↓
✅ Payment Service: Payment processed
        ↓
✅ Shipping Service: Publishes message to RabbitMQ queue
        ↓
❌ Queue-Master: SCALED TO 0 (NO CONSUMER!)
        ↓
⚠️ RabbitMQ Queue: Messages pile up (your orders accumulating)
        ↓
❌ Shipments: NEVER CREATED (Silent failure!)
        ↓
😟 User Impact: Thinks order succeeded, but shipment will never arrive
```

---

## DETECTION PATTERN (For AI SRE Agent)

```python
IF (
    kubernetes_state.deployment.replicas_available == 0  # No pods
    AND
    rabbitmq.queue.messages > 5  # Messages accumulating
    AND
    rabbitmq.queue.consumers == 0  # No consumer
    AND
    rabbitmq.queue.publish_rate > 0  # Producer still active
    AND
    no_error_logs_from_user_services  # Users see success
):
    ALERT(
        severity="CRITICAL",
        type="SILENT_FAILURE",
        title="Async Consumer Failure - Orders Paid but Not Shipped",
        remediation="kubectl scale deployment/queue-master --replicas=1"
    )
```

---

## CRITICAL INSIGHTS

### 1. Why Traditional Monitoring Fails

**Traditional Approach** (Looking for errors):
```
Search: kube_namespace:sock-shop status:error
Result: ❌ NO ERRORS FOUND
Conclusion: System healthy? NO! Silent failure!
```

### 2. Correct Approach (Metrics + Log Absence)

**Metrics-Based Detection**:
- Deployment replicas = 0 ✅ (Primary signal)
- Queue consumers = 0 ✅ (Critical signal)
- Queue depth increasing ✅ (Secondary signal)
- **Log absence** = Pod doesn't exist ✅ (Confirmatory signal)

### 3. Why It's "Silent"

| Component | Status | User Visibility |
|-----------|--------|-----------------|
| Orders | ✅ Success | Visible |
| Payment | ✅ Success | Visible |
| Shipping | ✅ Published | Hidden |
| **Queue-Master** | ❌ **DOWN** | **HIDDEN** |
| Shipment | ❌ **Never created** | **HIDDEN** (discovered days later!) |

**Danger**: User thinks order succeeded → Discovers shipment never arrives → Customer complaint → Reputation damage

---

## COMPARISON: INCIDENT-1 vs INCIDENT-5

| Aspect | INCIDENT-1 (App Crash) | INCIDENT-5 (Async Failure) |
|--------|------------------------|----------------------------|
| **User Visibility** | ✅ Errors visible (503, 500) | ❌ No errors (HTTP 200) |
| **Error Logs** | ✅ Many error logs | ❌ **No error logs** |
| **Detection Method** | Log errors + status codes | **Metrics + log absence** |
| **Primary Signal** | Error logs + restarts | **Replicas = 0, consumers = 0** |
| **Failure Mode** | Synchronous (immediate) | **Asynchronous (delayed)** |
| **Discovery Time** | Immediate (monitoring) | **Delayed (complaints)** |
| **Business Impact** | High (users can't order) | **Critical (orders paid, never shipped)** |
| **Severity** | High | **Critical (silent)** |
| **MTTR** | 1-5 minutes (restart) | 6 seconds (scale up) |

---

## KEY TAKEAWAYS

### 1. Silent Failures Are Most Dangerous
- ✅ User sees: "Order successful"
- ❌ Reality: Shipment will never be created
- 💰 Impact: Revenue loss, customer dissatisfaction, reputation damage

### 2. Metrics Over Logs
- Logs: No errors (misleading!)
- Metrics: Replicas = 0, consumers = 0 (truth!)

### 3. Asymmetric Failure Detection
```
IF (producer.healthy AND consumer.absent)
THEN: Async pipeline broken
```

### 4. Absence is Evidence
- No error logs ≠ Healthy system
- No logs at all = Pod doesn't exist = **Critical signal**

### 5. Multi-Signal Correlation
- Single metric: Replicas = 0 (might be intentional scaling)
- Multiple metrics: Replicas = 0 + Consumers = 0 + Queue depth > 10 = **CRITICAL INCIDENT**

---

## RECOMMENDED DATADOG ALERTS

### Alert 1: Consumer Failure (Primary)
```
rabbitmq.queue.consumers{queue:shipping-task} = 0
AND
rabbitmq.queue.messages{queue:shipping-task} > 10

→ CRITICAL: "RabbitMQ consumer failure - queue-master not consuming messages"
```

### Alert 2: Deployment Scaled to Zero
```
kubernetes_state.deployment.replicas_available{kube_deployment:queue-master} = 0

→ CRITICAL: "queue-master deployment has no replicas - async processing halted"
```

### Alert 3: Queue Depth Threshold
```
rabbitmq.queue.messages{queue:shipping-task} > 50

→ WARNING: "RabbitMQ queue depth exceeds threshold - check consumer health"
```

---

**Test Date**: November 10, 2025  
**Execution**: 03:55:51 - 04:01:56 UTC (09:25:51 - 09:31:56 IST)  
**Status**: ✅ Real orders placed, backlog processed after recovery  
**Datadog**: ✅ All signals captured and ready for analysis
