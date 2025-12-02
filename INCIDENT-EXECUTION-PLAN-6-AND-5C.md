# 🎯 INCIDENT EXECUTION PLAN: INCIDENT-6 & INCIDENT-5C

**Date:** November 29, 2025  
**Executor:** Cascade AI  
**Status:** ✅ READY FOR EXECUTION

---

## 📋 EXECUTIVE SUMMARY

This document outlines the complete execution plan for running two critical incidents with full Datadog observability:

1. **INCIDENT-6:** Payment Gateway Timeout (External Dependency Failure)
2. **INCIDENT-5C:** Queue Blockage (Middleware Queue at Capacity)

**Key Requirements:**
- ✅ 30+ minute gap between incidents
- ✅ Complete recovery verification between incidents
- ✅ 5-minute user testing window during each incident
- ✅ Comprehensive Datadog queries for both logs and metrics
- ✅ Timestamp documentation for analysis

---

## 🗓️ EXECUTION TIMELINE

### **Phase 1: INCIDENT-6 (Payment Gateway Timeout)**
- **Duration:** ~15 minutes total
- **Active Window:** 5 minutes (user testing)
- **Recovery:** Immediate
- **Gap:** 30+ minutes

### **Phase 2: INCIDENT-5C (Queue Blockage)**
- **Duration:** ~8 minutes total
- **Active Window:** 5 minutes (user testing)
- **Recovery:** Automatic

---

## 🔧 PRE-FLIGHT CHECKLIST

### ✅ System Health Verification

**Run these commands before starting:**

```powershell
# 1. Verify all pods are running
kubectl -n sock-shop get pods

# Expected: All 15 pods Running (1/1 or 2/2 for rabbitmq)

# 2. Verify Datadog agent health
kubectl -n datadog get pods

# Expected: 3 pods Running (1 cluster-agent + 2 node agents)

# 3. Check Datadog logs are flowing
kubectl -n datadog exec datadog-agent-ktm56 -c agent -- agent status 2>&1 | Select-String -Pattern "LogsProcessed"

# Expected: LogsProcessed > 0

# 4. Verify port-forward is active
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:2025 -TimeoutSec 3

# Expected: StatusCode 200

# 5. Verify stripe-mock is running (for INCIDENT-6)
kubectl -n sock-shop get pods -l name=stripe-mock

# Expected: 1/1 Running

# 6. Verify queue-master is running (for INCIDENT-5C)
kubectl -n sock-shop get pods -l name=queue-master

# Expected: 1/1 Running
```

**Status:**
- [ ] All pods healthy
- [ ] Datadog agent operational
- [ ] Logs flowing to Datadog
- [ ] Port-forward active
- [ ] Stripe-mock running
- [ ] Queue-master running

---

## 🚨 INCIDENT-6: PAYMENT GATEWAY TIMEOUT

### **Incident Overview**
- **Type:** External dependency failure
- **Root Cause:** Third-party payment gateway (stripe-mock) unavailable
- **User Impact:** Payment failures, orders cannot be completed
- **Detection:** Payment pods healthy but gateway unreachable

---

### **Step 1: Activate Incident**

```powershell
# Navigate to repo
cd d:\sock-shop-demo

# Record start time
$INCIDENT6_START = Get-Date
Write-Host "INCIDENT-6 START TIME (IST): $($INCIDENT6_START.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "INCIDENT-6 START TIME (UTC): $($INCIDENT6_START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"

# Activate incident
.\incident-6-activate.ps1
```

**Expected Output:**
```
✅ INCIDENT 6 ACTIVATED SUCCESSFULLY!
✅ Payment service: RUNNING (healthy)
❌ Stripe-mock: SCALED TO 0 (gateway down)
❌ Payment gateway: UNREACHABLE
```

---

### **Step 2: User Testing Window (5 MINUTES)**

**Instructions for User:**

1. Open browser: `http://localhost:2025`
2. Login: `user` / `password`
3. Add items to cart (any products)
4. Proceed to checkout
5. Click "Place Order"
6. **Repeat 5-7 times** (place multiple orders)

**Expected Behavior:**
- ❌ All orders will FAIL
- ❌ Error message: "Payment declined. Payment gateway error: connection refused"
- ✅ Payment service pods remain healthy (1/1 Running)

**⏰ PAUSE HERE FOR 5 MINUTES - ALLOW USER TO PLACE ORDERS**

---

### **Step 3: Verify Incident Signals**

```powershell
# Check stripe-mock status (should be 0)
kubectl -n sock-shop get pods -l name=stripe-mock

# Check payment pods (should be 1/1 Running)
kubectl -n sock-shop get pods -l name=payment

# Check payment logs for errors
kubectl -n sock-shop logs deployment/payment --tail=20

# Expected: "connection refused" errors to stripe-mock
```

---

### **Step 4: Recovery**

```powershell
# Record recovery time
$INCIDENT6_RECOVERY_START = Get-Date
Write-Host "INCIDENT-6 RECOVERY START (IST): $($INCIDENT6_RECOVERY_START.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "INCIDENT-6 RECOVERY START (UTC): $($INCIDENT6_RECOVERY_START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"

# Execute recovery
.\incident-6-recover.ps1

# Record recovery complete
$INCIDENT6_RECOVERY_END = Get-Date
Write-Host "INCIDENT-6 RECOVERY COMPLETE (IST): $($INCIDENT6_RECOVERY_END.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "INCIDENT-6 RECOVERY COMPLETE (UTC): $($INCIDENT6_RECOVERY_END.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
```

**Expected Output:**
```
✅ INCIDENT 6 RECOVERY COMPLETE!
✅ Payment service: RUNNING
✅ Stripe-mock: RUNNING
✅ Payment gateway: REACHABLE
```

---

### **Step 5: Verify Recovery**

```powershell
# Check all pods are running
kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'

# Expected: Both 1/1 Running

# Test a successful order
# User: Place one test order via UI
# Expected: ✅ Order succeeds, status: SHIPPED
```

---

### **Step 6: Document Timestamps**

```powershell
# Save timestamps for Datadog analysis
$INCIDENT6_DURATION = (New-TimeSpan -Start $INCIDENT6_START -End $INCIDENT6_RECOVERY_END).TotalMinutes

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  INCIDENT-6 TIMELINE SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Start (IST):    $($INCIDENT6_START.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Start (UTC):    $($INCIDENT6_START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Recovery (IST): $($INCIDENT6_RECOVERY_END.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Recovery (UTC): $($INCIDENT6_RECOVERY_END.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Duration:       $([Math]::Round($INCIDENT6_DURATION, 2)) minutes"
Write-Host "========================================`n"
```

---

## ⏸️ MANDATORY GAP: 30+ MINUTES

**Wait at least 30 minutes before proceeding to INCIDENT-5C**

This gap ensures:
- ✅ Datadog logs fully processed
- ✅ Metrics stabilized
- ✅ Clear separation in timeline
- ✅ System returned to baseline

**Recommended Activities During Gap:**
- Review INCIDENT-6 logs in Datadog
- Verify all pods healthy
- Check Datadog agent status
- Prepare for INCIDENT-5C

---

## 🐰 INCIDENT-5C: QUEUE BLOCKAGE

### **Incident Overview**
- **Type:** Middleware queue blockage
- **Root Cause:** RabbitMQ queue at capacity (max 3 messages) + consumer down
- **User Impact:** Orders 1-3 succeed, orders 4+ fail with visible errors
- **Detection:** Queue stuck at 3/3, consumer count = 0

---

### **Step 1: Activate Incident**

```powershell
# Navigate to repo
cd d:\sock-shop-demo

# Record start time
$INCIDENT5C_START = Get-Date
Write-Host "INCIDENT-5C START TIME (IST): $($INCIDENT5C_START.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "INCIDENT-5C START TIME (UTC): $($INCIDENT5C_START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))"

# Activate incident (with 5-minute duration)
.\incident-5c-execute-fixed.ps1 -DurationSeconds 300
```

**Expected Output:**
```
[Step 1] Configuring RabbitMQ queue policy via Management API...
✅ Queue policy set successfully via Management API

[Step 2] Stopping queue consumer...
✅ Queue-master pods scaled to 0
✅ Consumer is DOWN - queue will fill up (consumers: 0)

[Step 3] INCIDENT ACTIVE
⚠️ QUEUE LIMITED TO 3 MESSAGES
⚠️ ORDERS 4+ WILL FAIL WITH VISIBLE ERRORS
```

---

### **Step 2: User Testing Window (5 MINUTES)**

**Instructions for User:**

1. Open browser: `http://localhost:2025` (should already be open)
2. Login: `user` / `password` (if needed)
3. Add items to cart
4. Proceed to checkout
5. Click "Place Order"
6. **Repeat 7 times** (place 7 orders total)

**Expected Behavior:**
- ✅ **Orders 1-3:** SUCCESS (green "Order placed" alert)
- ❌ **Orders 4-7:** FAILURE (red "Internal Server Error" alert)
- ✅ Queue stuck at 3/3 messages
- ✅ Errors visible to user

**⏰ SCRIPT WILL AUTO-COUNTDOWN FOR 5 MINUTES**

---

### **Step 3: Automatic Recovery**

**The script will automatically:**
1. Remove queue policy
2. Restore queue-master consumer
3. Process stuck messages
4. Verify system health

**Expected Output:**
```
[Step 5] RECOVERING SYSTEM
✅ Queue policy removed via Management API
✅ Queue-master recovered successfully
✅ Queue-master processing backlog

✅ INCIDENT-5C RECOVERED
```

---

### **Step 4: Document Timestamps**

**The script automatically outputs:**
```
INCIDENT-5C SUMMARY
Incident Timeline:
  Start:    [IST] ([UTC])
  End:      [IST]
  Recovery: [IST] ([UTC])
  Duration: X.XX minutes

Datadog Analysis Time Range:
  From: [UTC]
  To:   [UTC]
```

**Save these timestamps for Datadog queries!**

---

## 📊 DATADOG VERIFICATION QUERIES

### **INCIDENT-6: Payment Gateway Timeout**

#### **Log Queries**

**1. Payment Gateway Errors (Primary Signal)**
```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
```
**Time Range:** Use INCIDENT-6 timestamps (IST or UTC)  
**Expected:** Multiple "connection refused" errors

---

**2. Connection Refused Errors**
```
kube_namespace:sock-shop pod_name:payment* "connection refused" "stripe-mock"
```
**Expected:** Same errors showing stripe-mock unreachable

---

**3. Orders Service Payment Failures**
```
kube_namespace:sock-shop service:sock-shop-orders "PaymentResponse{authorised=false"
```
**Expected:** Multiple failed payment responses

---

**4. Multi-Service View**
```
kube_namespace:sock-shop (pod_name:payment* OR pod_name:orders* OR pod_name:stripe-mock*) status:error
```
**Expected:** Errors from payment and orders, ZERO from stripe-mock (no pods)

---

**5. Payment Service Health (Proving Internal Health)**
```
kube_namespace:sock-shop pod_name:payment* ("starting on port" OR "Payment gateway:")
```
**Expected:** Startup logs, no crashes

---

**6. Kubernetes Scaling Events**
```
kube_namespace:sock-shop source:kubernetes kube_deployment:stripe-mock (Scaled OR ScalingReplicaSet)
```
**Expected:** "Scaled down to 0" and "Scaled up to 1" events

---

#### **Metric Queries**

**1. Stripe-Mock Available Replicas (PRIMARY SIGNAL)**
```
Metric: kubernetes_state.deployment.replicas_available
Filters: kube_namespace:sock-shop, kube_deployment:stripe-mock
```
**Expected Pattern:**
- Baseline: 1 replica
- During incident: 0 replicas
- Recovery: 1 replica

---

**2. Payment Pod Count (Proving Internal Health)**
```
Metric: kubernetes.pods.running
Filters: kube_namespace:sock-shop, kube_deployment:payment
```
**Expected:** Flat line at 1 (stable throughout)

---

**3. Payment Container Restarts**
```
Metric: kubernetes.containers.restarts
Filters: kube_namespace:sock-shop, kube_deployment:payment
```
**Expected:** Flat line (ZERO restarts)

---

### **INCIDENT-5C: Queue Blockage**

#### **Log Queries**

**1. Message Rejections (Shipping Logs)**
```
kube_namespace:sock-shop service:shipping "rejected" OR "Message rejected"
```
**Time Range:** Use INCIDENT-5C timestamps  
**Expected:** 4+ rejection log entries (orders 4-7)

---

**2. HTTP 503 Errors (Orders Service)**
```
kube_namespace:sock-shop service:orders "503" OR "HttpServerErrorException"
```
**Expected:** Multiple 503 errors from shipping service

---

**3. Publisher Confirms (ACKs/NACKs)**
```
kube_namespace:sock-shop service:shipping ("confirmed" OR "rejected")
```
**Expected Pattern:**
- 3-6 "confirmed" entries (orders 1-3)
- 4+ "rejected" entries (orders 4+)

---

**4. Deployment Scaling Events**
```
kube_namespace:sock-shop kube_deployment:queue-master "Scaled"
```
**Expected Events:**
- "Scaled down" (1 → 0)
- "Scaled up" (0 → 1)

---

#### **Metric Queries**

**1. Queue Depth (Stuck at Capacity)**
```
Metric: rabbitmq.queue.messages
Filters: queue:shipping-task, kube_namespace:sock-shop
```
**Expected Pattern:**
- Rises from 0 → 1 → 2 → 3
- **Stays flat at 3** (blocked at capacity)
- After recovery: Drops to 0

---

**2. Queue Consumer Count**
```
Metric: rabbitmq.queue.consumers
Filters: queue:shipping-task, kube_namespace:sock-shop
```
**Expected Pattern:**
- Drops from 1 → 0 (consumer scaled down)
- Stays at 0 during incident
- Returns to 1 after recovery

---

**3. Queue-Master Pod Count**
```
Metric: kubernetes.pods.running
Filters: kube_namespace:sock-shop, kube_deployment:queue-master
```
**Expected Pattern:**
- Drops from 1 → 0
- Stays at 0 during incident
- Returns to 1 after recovery

---

## 📝 POST-EXECUTION CHECKLIST

### **After INCIDENT-6:**
- [ ] Stripe-mock restored to 1 replica
- [ ] Payment service healthy (1/1 Running)
- [ ] Test order succeeds
- [ ] Timestamps documented
- [ ] 30+ minute gap before INCIDENT-5C

### **After INCIDENT-5C:**
- [ ] Queue policy removed
- [ ] Queue-master restored to 1 replica
- [ ] All pods healthy
- [ ] Timestamps documented
- [ ] Datadog queries verified

### **Final Verification:**
- [ ] All 15 pods Running
- [ ] Datadog agent healthy
- [ ] Logs flowing to Datadog
- [ ] No errors in recent logs
- [ ] System returned to baseline

---

## 🎯 SUCCESS CRITERIA

### **INCIDENT-6:**
✅ Payment gateway errors visible in Datadog  
✅ Stripe-mock pod count = 0 during incident  
✅ Payment pods remained healthy (1/1)  
✅ Multiple failed orders documented  
✅ Clear timeline with timestamps  
✅ Successful recovery verified

### **INCIDENT-5C:**
✅ Queue stuck at 3/3 messages  
✅ Consumer count = 0 during incident  
✅ Orders 1-3 succeeded  
✅ Orders 4+ failed with visible errors  
✅ Shipping logs show ACKs and NACKs  
✅ Automatic recovery successful

---

## 🚀 EXECUTION COMMANDS (QUICK REFERENCE)

### **INCIDENT-6 (One-Liner)**
```powershell
cd d:\sock-shop-demo; $START=Get-Date; Write-Host "START: $($START.ToString('yyyy-MM-dd HH:mm:ss')) IST / $($START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC"; .\incident-6-activate.ps1
# [USER PLACES ORDERS FOR 5 MINUTES]
# Then run:
.\incident-6-recover.ps1; $END=Get-Date; Write-Host "END: $($END.ToString('yyyy-MM-dd HH:mm:ss')) IST / $($END.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC"
```

### **INCIDENT-5C (One-Liner)**
```powershell
cd d:\sock-shop-demo; .\incident-5c-execute-fixed.ps1 -DurationSeconds 300
# Script handles everything automatically, including timestamps
```

---

## 📚 REFERENCE DOCUMENTATION

**INCIDENT-6:**
- `INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md` - Complete guide
- `INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md` - Datadog queries
- `incident-6-activate.ps1` - Activation script
- `incident-6-recover.ps1` - Recovery script

**INCIDENT-5C:**
- `INCIDENT-5C-COMPLETE-GUIDE.md` - Complete guide
- `incident-5c-execute-fixed.ps1` - Execution script (auto-recovery)

---

## ⚠️ IMPORTANT NOTES

1. **Always verify Datadog health before starting**
2. **Document timestamps immediately** (don't rely on memory)
3. **Wait 30+ minutes between incidents** (critical for clean separation)
4. **Execute recovery immediately** (don't leave incidents active)
5. **Save Datadog queries** (use exact timestamps for analysis)
6. **Test one successful order** after each recovery

---

**Status:** ✅ READY FOR EXECUTION  
**Prepared By:** Cascade AI  
**Date:** November 29, 2025  
**Version:** 1.0
