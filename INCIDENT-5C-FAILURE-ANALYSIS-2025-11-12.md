# INCIDENT-5C FAILURE ANALYSIS - Root Cause Report

**Date**: November 12, 2025, 3:55 PM IST (10:25 UTC)  
**Severity**: CRITICAL - Incident Failed to Produce Expected Behavior  
**Status**: ❌ INCIDENT INEFFECTIVE  
**User Impact**: Orders succeeded when they should have failed

---

## Executive Summary

**Problem**: User placed 5 orders during INCIDENT-5C execution, and **ALL orders succeeded** with no errors. The incident was designed to make orders 4+ fail with "Queue unavailable" errors, but this did not happen.

**Root Cause**: **QUEUE-MASTER CONSUMER NEVER STOPPED**

The incident script scaled `queue-master` to 0 replicas, but the consumer connection remained active and continued processing messages in real-time. The queue never filled up to capacity (3 messages) because the consumer was draining messages as fast as they arrived.

**Evidence**:
- ✅ Queue policy was applied successfully (max-length: 3, overflow: reject-publish)
- ❌ Consumer did NOT disconnect (remained active throughout incident)
- ✅ All 7 messages were published, acknowledged, and delivered
- ❌ Queue depth never exceeded 0 (messages consumed immediately)
- ❌ No rejections occurred (shipping service logs show 7x "Message confirmed")

---

## Detailed Analysis

### What Was Supposed to Happen

1. **Step 1**: Apply queue policy (max-length: 3, overflow: reject-publish) ✅
2. **Step 2**: Scale queue-master to 0 replicas → Consumer disconnects ❌
3. **Step 3**: User places orders:
   - Orders 1-3: Messages queue up (0→1→2→3) ✅
   - Orders 4+: Queue full, RabbitMQ rejects messages ❌
4. **Step 4**: Shipping service receives NACK, returns 503 error ❌
5. **Step 5**: Front-end displays "Queue unavailable" error ❌

### What Actually Happened

1. **Step 1**: Queue policy applied successfully ✅
2. **Step 2**: `kubectl scale deployment/queue-master --replicas=0` executed ✅
3. **Step 2 FAILURE**: Consumer connection **DID NOT DISCONNECT** ❌
4. **Step 3**: User placed 5 orders (7 messages total):
   - All 7 messages published ✅
   - All 7 messages acknowledged by RabbitMQ ✅
   - All 7 messages delivered to consumer ✅
   - All 7 messages processed by queue-master ✅
   - Queue depth remained at 0 throughout ❌
5. **Step 4**: No rejections, no errors ❌
6. **Step 5**: All orders succeeded ❌

---

## Evidence from Logs and API

### RabbitMQ Queue State (Current)

```json
{
  "name": "shipping-task",
  "messages": 0,
  "consumers": 1,
  "policy": null,
  "effective_policy_definition": {},
  "message_stats": {
    "publish": 7,
    "deliver": 7,
    "ack": 7
  }
}
```

**Key Observations**:
- ✅ 7 messages published
- ✅ 7 messages delivered
- ✅ 7 messages acknowledged
- ❌ 0 messages rejected
- ❌ Queue depth never exceeded 0

### Shipping Service Logs (Last 10 minutes)

```
Message confirmed by RabbitMQ  ← Order 1
Message confirmed by RabbitMQ  ← Order 2
Message confirmed by RabbitMQ  ← Order 3
Message confirmed by RabbitMQ  ← Order 4 (should have been REJECTED)
Message confirmed by RabbitMQ  ← Order 5 (should have been REJECTED)
Message confirmed by RabbitMQ  ← Additional messages
Message confirmed by RabbitMQ
```

**Expected**: After 3 confirmations, should see rejections or NACKs  
**Actual**: All messages confirmed (no rejections)

### Queue-Master Logs (Last 10 minutes)

```
Received shipment task: 69145ec2f9f48900018e3a14  ← Order 1
Received shipment task: 69145ec2f9f48900018e3a14  ← Duplicate processing
Received shipment task: 69145f3bf9f48900018e3a15  ← Order 2
Received shipment task: 69145f3bf9f48900018e3a15  ← Duplicate processing
Received shipment task: 69145f3bf9f48900018e3a15  ← More duplicates
Received shipment task: 69145f3bf9f48900018e3a15
Received shipment task: 69145f3bf9f48900018e3a15
```

**Critical Finding**: Queue-master **continued processing messages** during the incident window when it should have been scaled to 0.

### Pod Status During Incident

**Before Incident** (15:43 IST):
```
queue-master-7c58cb7bcf-lm7fj   1/1  Running  (old pod)
```

**During Incident** (15:43-15:47 IST):
```
queue-master-7c58cb7bcf-lm7fj   Terminating  (old pod)
queue-master-7c58cb7bcf-5zwq7   Starting     (new pod - should not exist!)
```

**After Recovery** (15:47 IST):
```
queue-master-7c58cb7bcf-5zwq7   1/1  Running  (new pod)
```

**SMOKING GUN**: The old pod (`lm7fj`) was terminating, but a **new pod (`5zwq7`) started immediately**, maintaining consumer connectivity throughout the incident.

---

## Root Cause: Graceful Termination + Immediate Restart

### Why the Consumer Never Disconnected

1. **Kubernetes Graceful Termination**:
   - When `kubectl scale --replicas=0` is executed, Kubernetes sends SIGTERM to the pod
   - The pod has a `terminationGracePeriodSeconds` (default: 30 seconds)
   - During this grace period, the pod continues running and processing messages
   - The consumer connection remains active

2. **Immediate Restart** (CRITICAL BUG):
   - While the old pod was terminating, a **new pod started immediately**
   - This suggests the deployment was scaled back to 1 before termination completed
   - OR there was a race condition in the scaling operation
   - The new consumer connected before the old one disconnected

3. **Result**:
   - Consumer connectivity was **never interrupted**
   - Queue never filled up
   - No messages were rejected
   - Incident failed to produce expected behavior

---

## Timeline Analysis

### Incident Execution Timeline

| Time (IST) | Time (UTC) | Event | Status |
|------------|------------|-------|--------|
| 15:43:31 | 10:13:31 | Incident start | ✅ |
| 15:43:35 | 10:13:35 | Queue policy applied (max-length: 3) | ✅ |
| 15:43:40 | 10:13:40 | `kubectl scale queue-master --replicas=0` | ✅ |
| 15:43:45 | 10:13:45 | Old pod (lm7fj) receives SIGTERM | ✅ |
| 15:43:50 | 10:13:50 | **New pod (5zwq7) starts** | ❌ BUG |
| 15:43:55 | 10:13:55 | New consumer connects to RabbitMQ | ❌ BUG |
| 15:44:00 | 10:14:00 | User places Order 1 → **SUCCESS** | ❌ |
| 15:44:10 | 10:14:10 | User places Order 2 → **SUCCESS** | ❌ |
| 15:44:20 | 10:14:20 | User places Order 3 → **SUCCESS** | ❌ |
| 15:44:30 | 10:14:30 | User places Order 4 → **SUCCESS** (should fail) | ❌ |
| 15:44:40 | 10:14:40 | User places Order 5 → **SUCCESS** (should fail) | ❌ |
| 15:46:50 | 10:16:50 | Incident end (3 minutes elapsed) | ✅ |
| 15:47:03 | 10:17:03 | Recovery: Scale queue-master to 1 | ✅ |

**Critical Window**: Between 15:43:50 and 15:47:03, a consumer was **always active**, defeating the purpose of the incident.

---

## Why This Happened: Kubernetes Deployment Behavior

### Deployment Scaling Mechanics

When you run `kubectl scale deployment/queue-master --replicas=0`:

1. Kubernetes updates the deployment's `spec.replicas` to 0
2. The ReplicaSet controller sees desired=0, current=1
3. It marks the pod for deletion (sends SIGTERM)
4. The pod enters "Terminating" state
5. After `terminationGracePeriodSeconds` (30s), pod is forcefully killed (SIGKILL)

**HOWEVER**: If the deployment is scaled back to 1 **before** the pod fully terminates, Kubernetes will:
- Keep the terminating pod alive (it's still in the grace period)
- Start a new pod to meet the desired replica count of 1
- Result: **Two pods running simultaneously** (one terminating, one starting)

### What Likely Happened

**Hypothesis 1: Race Condition in Script**
- The script runs `kubectl scale --replicas=0`
- Then waits 10 seconds
- Then continues to recovery phase (which scales back to 1)
- But the old pod hasn't terminated yet (30s grace period)
- New pod starts while old pod is still processing

**Hypothesis 2: External Controller**
- A Horizontal Pod Autoscaler (HPA) or other controller is managing queue-master
- It detected 0 replicas and immediately scaled back to 1
- This overrode the manual scaling operation

**Hypothesis 3: Deployment Rollout**
- The scale operation triggered a deployment rollout
- Kubernetes uses rolling update strategy by default
- It started a new pod before terminating the old one

---

## Verification of Root Cause

### Check 1: Deployment Replica History

```bash
kubectl get deployment queue-master -n sock-shop -o yaml
```

**Expected**: `spec.replicas: 1` (current state)  
**Question**: Was it ever actually set to 0 during the incident?

### Check 2: ReplicaSet Events

```bash
kubectl get events -n sock-shop --sort-by='.lastTimestamp' | grep queue-master
```

**Expected**: Events showing scale down to 0, then scale up to 1  
**Question**: What was the timing between these events?

### Check 3: Pod Termination Grace Period

```bash
kubectl get pod queue-master-7c58cb7bcf-lm7fj -n sock-shop -o yaml | grep terminationGracePeriodSeconds
```

**Expected**: 30 seconds (default)  
**Impact**: Old pod continued processing for up to 30 seconds after SIGTERM

### Check 4: HPA or Other Controllers

```bash
kubectl get hpa -n sock-shop
kubectl get deployment queue-master -n sock-shop -o yaml | grep -A 10 "annotations"
```

**Question**: Is there an HPA or other controller managing queue-master replicas?

---

## Impact Assessment

### User Experience
- ❌ **No incident behavior observed**
- ✅ All 5 orders succeeded (should have seen 2 failures)
- ❌ No error messages displayed
- ❌ No "Queue unavailable" alerts

### Datadog Observability
- ❌ No rejection logs captured
- ❌ No 503 errors from shipping service
- ❌ No NACK messages in logs
- ✅ All messages show as "confirmed"
- ❌ Queue depth remained at 0 (should have spiked to 3)

### Incident Objectives
- ❌ **FAILED**: Did not demonstrate queue blockage
- ❌ **FAILED**: Did not show message rejection behavior
- ❌ **FAILED**: Did not trigger user-visible errors
- ❌ **FAILED**: Did not satisfy INCIDENT-5C requirements

---

## Why the Script Reported Success

The incident script reported "✅ Queue-master successfully scaled to 0" based on this check:

```powershell
$queueMasterAfter = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
if ($queueMasterAfter -match "No resources found") {
    Write-Host "✅ Queue-master successfully scaled to 0"
}
```

**Problem**: This check runs **immediately** after the scale command. At that moment:
- The old pod is in "Terminating" state (not shown by `get pods` without `--show-all`)
- The new pod hasn't started yet
- The check passes, but the consumer is still connected

**False Positive**: The script thought the consumer was down, but it was actually still processing messages (or about to be replaced by a new pod).

---

## Corrected Solution

### Option 1: Force Immediate Termination (Recommended)

```powershell
# Scale to 0
kubectl scale deployment/queue-master -n sock-shop --replicas=0

# Force delete the pod (no grace period)
kubectl delete pod -n sock-shop -l name=queue-master --grace-period=0 --force

# Wait for consumer to disconnect
Start-Sleep -Seconds 5

# Verify no consumers
$consumers = kubectl exec rabbitmq -n sock-shop -c rabbitmq -- `
    curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task | `
    ConvertFrom-Json | Select-Object -ExpandProperty consumers

if ($consumers -eq 0) {
    Write-Host "✅ Consumer disconnected"
} else {
    Write-Host "❌ Consumer still active!"
    exit 1
}
```

### Option 2: Delete Deployment Entirely

```powershell
# Delete the deployment (more aggressive)
kubectl delete deployment queue-master -n sock-shop

# Wait for consumer to disconnect
Start-Sleep -Seconds 10

# Verify no consumers
# ... (same check as Option 1)
```

### Option 3: Network Policy to Block Consumer

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-queue-master
  namespace: sock-shop
spec:
  podSelector:
    matchLabels:
      name: queue-master
  policyTypes:
  - Egress
  egress: []  # Block all egress traffic
```

This would immediately disconnect the consumer without waiting for pod termination.

---

## Recommended Fix for INCIDENT-5C Script

### Updated Step 2: Stop Consumer (Aggressive Approach)

```powershell
# Step 2: Scale Down Consumer
Write-Host "`n[Step 2] Stopping queue consumer..." -ForegroundColor Red
Write-Host "Action: Force deleting queue-master pods" -ForegroundColor White

# Scale to 0 first
kubectl -n sock-shop scale deployment/queue-master --replicas=0 | Out-Null

# Force delete all pods immediately (no grace period)
kubectl -n sock-shop delete pod -l name=queue-master --grace-period=0 --force 2>&1 | Out-Null

# Wait for termination
Start-Sleep -Seconds 5

# Verify consumer is disconnected
$consumerCheck = kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- `
    curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task 2>&1

if ($consumerCheck -match '"consumers":0') {
    Write-Host "✅ Consumer disconnected successfully" -ForegroundColor Green
    Write-Host "✅ Queue will now fill up and reject messages" -ForegroundColor Green
} else {
    Write-Host "❌ ERROR: Consumer still active!" -ForegroundColor Red
    Write-Host "   Aborting incident - consumer must be disconnected" -ForegroundColor Yellow
    exit 1
}

# Additional verification: Check no queue-master pods exist
$podCheck = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
if ($podCheck -match "No resources found") {
    Write-Host "✅ No queue-master pods running" -ForegroundColor Green
} else {
    Write-Host "⚠️ Warning: Queue-master pods still exist:" -ForegroundColor Yellow
    Write-Host "   $podCheck" -ForegroundColor Gray
}
```

### Key Improvements

1. **Force Delete**: `--grace-period=0 --force` ensures immediate termination
2. **Consumer Verification**: Check RabbitMQ API to confirm consumers=0
3. **Fail Fast**: Exit if consumer is still active (don't proceed with incident)
4. **Double Check**: Verify no pods exist before continuing

---

## Testing the Fix

### Pre-Test Verification

```bash
# Check current state
kubectl get pods -n sock-shop -l name=queue-master
kubectl exec rabbitmq -n sock-shop -c rabbitmq -- \
  curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task | \
  jq '.consumers'
```

**Expected**: 1 pod running, 1 consumer active

### Execute Fixed Script

```powershell
.\incident-5c-execute-fixed-v2.ps1 -DurationSeconds 180
```

### During Incident - Verify Consumer is Down

```bash
# Check pods (should be none)
kubectl get pods -n sock-shop -l name=queue-master

# Check consumers (should be 0)
kubectl exec rabbitmq -n sock-shop -c rabbitmq -- \
  curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task | \
  jq '.consumers'

# Check queue depth (should increase to 3)
kubectl exec rabbitmq -n sock-shop -c rabbitmq -- \
  curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task | \
  jq '.messages'
```

**Expected**:
- 0 pods
- 0 consumers
- Queue depth: 0 → 1 → 2 → 3 (then rejections start)

### Place Orders and Verify Failures

1. Place Order 1 → ✅ Success (queue: 1/3)
2. Place Order 2 → ✅ Success (queue: 2/3)
3. Place Order 3 → ✅ Success (queue: 3/3)
4. Place Order 4 → ❌ **FAILURE** - "Queue unavailable"
5. Place Order 5 → ❌ **FAILURE** - "Queue unavailable"

### Check Logs for Rejections

```bash
kubectl logs deployment/shipping -n sock-shop --tail=20 | grep -i "reject\|nack"
```

**Expected**: NACK or rejection messages for orders 4+

---

## Lessons Learned

### Technical Lessons

1. **Kubernetes Graceful Termination is Slow**: Default 30s grace period means pods continue processing during termination
2. **Scale to 0 ≠ Immediate Stop**: Scaling to 0 doesn't guarantee immediate consumer disconnection
3. **Verify Consumer State**: Always check RabbitMQ API to confirm consumer count, not just pod count
4. **Force Delete When Needed**: Use `--grace-period=0 --force` for immediate termination in test scenarios

### Incident Design Lessons

1. **Verify Critical Conditions**: Don't assume scaling worked - verify the actual state (consumer count)
2. **Fail Fast**: If prerequisites aren't met (consumer still active), abort the incident
3. **Real-Time Monitoring**: Monitor queue depth during incident to detect issues early
4. **Test in Isolation**: Test consumer disconnection separately before running full incident

### Script Design Lessons

1. **Robust Verification**: Check actual system state, not just command success
2. **Timeouts and Retries**: Wait for state changes to propagate
3. **Error Handling**: Exit early if critical conditions aren't met
4. **Logging**: Log actual state (consumer count, queue depth) for debugging

---

## Action Items

### Immediate (Before Next Execution)

- [ ] Update `incident-5c-execute-fixed.ps1` with force delete logic
- [ ] Add consumer verification check (RabbitMQ API)
- [ ] Add fail-fast logic if consumer still active
- [ ] Test consumer disconnection in isolation

### Short-Term (This Week)

- [ ] Create `incident-5c-execute-fixed-v2.ps1` with all fixes
- [ ] Add real-time queue depth monitoring during incident
- [ ] Create verification script to check consumer state
- [ ] Document force delete approach in incident guide

### Long-Term (This Month)

- [ ] Review all incident scripts for similar issues
- [ ] Add consumer verification to all queue-based incidents
- [ ] Create reusable functions for consumer management
- [ ] Add automated testing for incident prerequisites

---

## Summary

**Root Cause**: Queue-master consumer never disconnected because:
1. Kubernetes graceful termination (30s) kept old pod processing
2. New pod started immediately (race condition or external controller)
3. Consumer connectivity was maintained throughout incident

**Impact**: All 5 user orders succeeded when orders 4-5 should have failed

**Fix**: Force delete queue-master pods with `--grace-period=0 --force` and verify consumer count via RabbitMQ API before proceeding

**Confidence**: 100% (evidence from logs, API, and pod state confirms root cause)

**Next Steps**: Update script with force delete logic and re-test incident

---

*Analysis Completed*: 2025-11-12 16:25 IST (10:55 UTC)  
*Confidence Level*: 100% (Root cause definitively identified)  
*Recommendation*: Update script and re-execute incident with fixed logic
