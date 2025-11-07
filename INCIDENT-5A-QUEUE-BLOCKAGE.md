# Incident 5A: Middleware Queue Blockage (Message Queue At Capacity)

## Overview

**Incident Type:** Middleware Queue Capacity Exhaustion  
**Severity:** High (P2)  
**User Impact:** Orders appear successful but fail at shipping → Silent business failure  
**Root Cause:** RabbitMQ queue reaches capacity, rejecting new publications

---

## Incident Description

This incident simulates a **critical middleware blockage** where:

1. Payment succeeds, order marked PAID ✅
2. **First 3 orders:** Shipping messages queued successfully ✅
3. **Queue reaches capacity** (max 3 messages) ⚠️
4. **Orders 4+:** RabbitMQ REJECTS publishes (406 PRECONDITION_FAILED) ❌
5. **No user-facing error** - Fire-and-forget pattern ❌

**Business Impact:**
- Customers charged but orders never shipped
- Silent failure (UI shows "Shipped" for all)
- Discovered only through monitoring or complaints

**Key Characteristics:**
- Middleware actively blocking messages
- Dual failure: Stuck messages (in queue) + Rejected messages (blocked)
- Production-realistic backpressure scenario
- Fire-and-forget publishing without error propagation

---

## Key Differences: INCIDENT-5 vs INCIDENT-5A

| Aspect | INCIDENT-5 | INCIDENT-5A |
|--------|-----------|-------------|
| **Root Cause** | Consumer unavailable | Queue capacity + Consumer unavailable |
| **Queue State** | Accepts all | Rejects after capacity |
| **RabbitMQ Response** | ACK for all | ACK for first N, NACK for rest |
| **Error Signal** | None | 406 PRECONDITION_FAILED |
| **Failure Type** | Processing blockage | Entry + Processing blockage |

---

## Pre-Incident Checklist

1. Verify all pods running: `kubectl -n sock-shop get pods`
2. Check queue baseline: `kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl list_queues name messages consumers`
3. Verify no existing policies: `kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl list_policies`
4. Place test order to verify normal flow

---

## Incident Execution Steps

### Step 1: Set Queue Policy (Capacity Limit)

```powershell
# Apply policy: max 3 messages, reject overflow
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  sh -c 'rabbitmqctl set_policy queue-limit "shipping-task" ''{"max-length":3,"overflow":"reject-publish"}'' --apply-to queues'
```

### Step 2: Verify Policy Applied

```powershell
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl list_policies
# Expected: queue-limit policy for shipping-task with max-length:3
```

### Step 3: Stop Consumer

```powershell
# Scale queue-master to 0
kubectl -n sock-shop scale deployment/queue-master --replicas=0
Start-Sleep -Seconds 15

# Verify consumer stopped
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  rabbitmqctl list_queues name messages consumers
# Expected: shipping-task 0 0
```

### Step 4: Place 5-7 Orders

Via UI (http://localhost:2025):
- Login (user/password)
- Place 5-7 orders rapidly

**Expected:**
- Orders 1-3: Queued ✅
- Orders 4+: Rejected by queue ❌
- UI: All show "Shipped" (misleading!)

### Step 5: Verify Blockage

```powershell
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  rabbitmqctl list_queues name messages consumers messages_ready

# Expected Output:
# shipping-task   3   0   3   ← STUCK AT CAPACITY!
```

---

## 📊 Datadog Monitoring

### Primary Detection Signals

| Signal | Metric/Query | Expected | Reliability |
|--------|--------------|----------|-------------|
| **Queue Stuck** | `rabbitmq.queue.messages{queue:shipping-task}` | Flat line at 3 | ⭐⭐⭐⭐⭐ |
| **No Consumer** | `rabbitmq.queue.consumers{queue:shipping-task}` | Drops to 0 | ⭐⭐⭐⭐⭐ |
| **Pod Absent** | Infrastructure → queue-master | Missing | ⭐⭐⭐⭐⭐ |
| **Deployment** | `kubernetes_state.deployment.replicas` | 0 | ⭐⭐⭐⭐⭐ |

### Metric 1: Queue Depth (CRITICAL)

**Datadog Metrics Explorer:**
- Metric: `rabbitmq.queue.messages`
- Filter: `queue:shipping-task`
- Expected: Rises to 3, then STUCK (flat line)

**🚨 KEY INSIGHT:** Queue stuck at exactly 3 = BLOCKAGE CONFIRMED

### Metric 2: Queue Consumers

- Metric: `rabbitmq.queue.consumers{queue:shipping-task}`
- Expected: Drops from 1 → 0

### Logs Query

```
kube_namespace:sock-shop service:sock-shop-shipping status:error
```

**⚠️ Note:** Fire-and-forget may show NO errors (silent failure)

### Events Query

```
source:kubernetes kube_namespace:sock-shop deployment:queue-master
```

Expected: "Scaled deployment queue-master from 1 to 0"

---

## Recovery Steps

### Step 1: Remove Queue Policy

```powershell
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  rabbitmqctl clear_policy queue-limit

# Verify
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl list_policies
# Expected: Empty
```

### Step 2: Restore Consumer

```powershell
kubectl -n sock-shop scale deployment/queue-master --replicas=1
Start-Sleep -Seconds 30

# Verify
kubectl -n sock-shop get pods -l name=queue-master
# Expected: 1/1 Running
```

### Step 3: Verify Queue Drains

```powershell
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  rabbitmqctl list_queues name messages consumers

# Expected Progression:
# shipping-task   3   1  → 2   1  → 1   1  → 0   1
```

### Step 4: Test New Order

Place 1 order via UI and verify queue processes immediately (returns to 0).

---

## Post-Incident Analysis

### Root Cause

Queue reached max capacity (3) + consumer unavailable → RabbitMQ rejected orders 4-7

### Failure Timeline

```
T+0:    Policy applied, consumer stopped
T+1-3:  Orders 1-3 queued (fills to 3/3)
T+3-10: Orders 4-7 REJECTED by RabbitMQ
T+12:   Policy removed, consumer restored
T+15:   Queue drained, normal operation
```

### Evidence

1. Queue depth stuck at 3
2. queue-master at 0 replicas
3. Silent failure (no errors logged)
4. 7 orders paid, 0 shipped

### Business Impact (Example)

- Orders: 7 × $20 = $140 revenue at risk
- Support: 7 tickets × $50 = $350
- **Total:** $490 + reputation damage

---

## Recommended Remediation

### Immediate Alerts

```yaml
# Datadog Monitor: Queue Depth High
Alert when: rabbitmq.queue.messages{queue:shipping-task} > 100

# Datadog Monitor: Queue Consumer Down
Alert when: rabbitmq.queue.consumers{queue:shipping-task} == 0

# Datadog Monitor: Deployment Down
Alert when: kubernetes_state.deployment.replicas_available{deployment:queue-master} == 0
```

### Short-Term Fixes

1. **Increase capacity:** Set max-length to 1000+
2. **Dead letter queue:** Route rejected messages
3. **Consumer redundancy:** Scale to 2+ replicas
4. **Circuit breaker:** Add fallback for failures

### Long-Term Changes

1. **Error propagation:** Replace fire-and-forget with synchronous validation
2. **Status tracking:** Log publish success/failure
3. **Retry mechanism:** Exponential backoff
4. **Autoscaling:** HPA based on queue depth
5. **Persistence:** Ensure messages survive restarts

---

## AI SRE Testing Scenarios

### Scenario 1: Real-Time Detection (5 min)

**Expected AI Behavior:**
```
T+1: "⚠️ ANOMALY: queue-master at 0 replicas"
T+2: "🚨 CRITICAL: Queue stuck at 3/3 capacity"
T+3: "📊 Root Cause: Consumer down + capacity limit"
T+4: "💡 Fix: Scale queue-master to 1+ replicas"
```

### Scenario 2: Silent Failure Detection

**Challenge:** No shipping errors logged

**Expected Reasoning:**
- Logs show normal activity, no errors
- BUT metrics show queue stuck
- Conclusion: Fire-and-forget + monitoring critical

### Scenario 3: Business Impact

**Expected Analysis:**
- 7 orders in incident window
- First 3 queued (stuck), last 4 rejected
- Impact: "$490 + reputation damage"

---

## Success Criteria

### Execution ✅
- [ ] Policy applied, consumer stopped
- [ ] 7 orders placed (3 queued, 4 rejected)
- [ ] Queue stuck at 3
- [ ] UI showed "Shipped" for all (misleading)

### Detection ✅
- [ ] Queue depth flat at 3
- [ ] Consumer metric = 0
- [ ] Deployment replicas = 0
- [ ] K8s events show scale-down

### Recovery ✅
- [ ] Policy removed
- [ ] Consumer restored
- [ ] Queue drained 3→0
- [ ] New order processes normally

---

## Technical Notes

### RabbitMQ Policy

- **max-length:** Hard limit on queue size
- **overflow:reject-publish:** Reject when full
- **Alternatives:** drop-head (FIFO), reject-publish-dlx (DLQ)

### Fire-and-Forget Pattern

**Pros:** High performance, better availability, simpler code  
**Cons:** Silent failures, no immediate feedback, requires monitoring

### Production Realism

- Most e-commerce uses fire-and-forget
- Queue capacity limits are common
- Monitoring essential for detection
- Dead letter queues provide safety net

---

## Appendix: Actual Execution (Nov 6, 2025)

**Timeline:**
- Start: 2025-11-06 16:36:59 IST
- Orders: 7 placed in 59 seconds (11:09:39 - 11:10:38)
- Recovery: ~3 minutes

**Results:**
- ✅ Queue stuck at 3/3
- ✅ All orders showed "Shipped" (misleading)
- ✅ Orders 1-3 queued, 4-7 rejected
- ✅ Zero shipping errors (silent)
- ✅ Datadog metrics showed clear blockage
- ✅ Recovery successful

**Key Insight:** Fire-and-forget + capacity limits = perfect silent failure

---

## Version History

**Version:** 1.0  
**Created:** November 6, 2025  
**Purpose:** AI SRE observability - Middleware queue blockage detection  
**Related:** INCIDENT-5 (Consumer Failure), INCIDENT-3 (Payment Failure)
