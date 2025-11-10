# INCIDENT-6: Ready for Testing

**Date:** November 10, 2025  
**Time:** 5:55 PM IST  
**Status:** ✅ READY FOR TESTING

---

## ✅ PRE-TEST VERIFICATION COMPLETE

### System State:
```
✅ Payment Service: RUNNING (sock-shop-payment-gateway:v2)
✅ Environment Variable: PAYMENT_GATEWAY_URL=http://stripe-mock
✅ Stripe-Mock Gateway: RUNNING (1/1 pods)
✅ Front-End: ACCESSIBLE (http://localhost:2025)
✅ Port-Forward: ACTIVE
```

### Payment Service Logs:
```
2025/11/10 12:25:21 ✅ Payment gateway: http://stripe-mock
2025/11/10 12:25:21 🚀 Payment service starting on port 8080
```

**Confirmation:** Payment service is correctly configured to call external gateway.

---

## 📋 ESSENTIAL FILES (Cleaned Up)

### Active Files:
1. ✅ `INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md` - Main documentation
2. ✅ `incident-6-activate.ps1` - Activation script
3. ✅ `incident-6-recover.ps1` - Recovery script
4. ✅ `stripe-mock-deployment.yaml` - Gateway deployment

### Archived Files:
- 📦 `archive/incident-6-tests/INCIDENT-6-LIVE-TEST-2025-11-07.md`
- 📦 `archive/incident-6-tests/INCIDENT-6-TEST-REPORT-2025-11-07.md`
- 📦 `archive/incident-6-tests/INCIDENT-6-TEST-RESULTS-FINAL.md`

**Note:** Historical test reports moved to archive to avoid confusion.

---

## 🎯 CLIENT REQUIREMENT

**Requirement:**
> "Payment gateway timeout or failure, caused by third-party API issues"

**Implementation:**
- ✅ External payment gateway (stripe-mock)
- ✅ Payment service calls gateway via HTTP
- ✅ Gateway failure simulated by scaling to 0
- ✅ Connection refused errors expected
- ✅ Payment pods stay healthy (external failure, not internal)

---

## 🚀 TEST EXECUTION PLAN

### Step 1: Activate Incident (AUTOMATED)
```powershell
.\incident-6-activate.ps1
```

**What Happens:**
- Stripe-mock scaled to 0 replicas
- Payment gateway becomes unreachable
- Payment service will return connection refused errors

**Duration:** ~10 seconds

---

### Step 2: Order Placement Window (180 SECONDS)

**⏱️ TIME WINDOW: 3 MINUTES (180 seconds)**

**User Actions:**
1. Open UI: http://localhost:2025
2. Login: username=`user`, password=`password`
3. Add items to cart
4. Proceed to checkout
5. Click "Place Order"

**Expected Result:**
```
❌ Error: Payment declined. 
Payment gateway error: Post "http://stripe-mock/v1/charges": 
dial tcp 10.96.145.169:80: connect: connection refused
```

**Database Result:**
- Order created with status: `PAYMENT_FAILED`
- No shipment record created
- Cart NOT cleared (known bug)

---

### Step 3: Monitoring During Incident

**Payment Service Logs:**
```bash
kubectl logs -n sock-shop deployment/payment -f
```

**Expected:**
```
❌ Payment gateway error: Post "http://stripe-mock/v1/charges": 
dial tcp 10.96.145.169:80: connect: connection refused (0.1s)
```

**Orders Service Logs:**
```bash
kubectl logs -n sock-shop deployment/orders -f
```

**Expected:**
```
WARN - Order <id> status updated to PAYMENT_FAILED
```

---

### Step 4: Recovery (AUTOMATED)
```powershell
.\incident-6-recover.ps1
```

**What Happens:**
- Stripe-mock scaled back to 1 replica
- Payment gateway becomes reachable
- New orders will succeed

**Duration:** ~30 seconds

---

## 📊 DATADOG OBSERVABILITY

### Logs Queries:
```
# Payment gateway errors
service:payment "Payment gateway error"

# Failed orders
service:orders "PAYMENT_FAILED"

# Connection refused
"connection refused" AND "stripe-mock"
```

### Metrics Queries:
```
# Gateway availability
kubernetes.pods.running{kube_deployment:stripe-mock}

# Payment service health
kubernetes.pods.running{kube_deployment:payment}

# Container restarts (should be 0)
kubernetes.containers.restarts{kube_deployment:payment}
```

---

## ✅ SUCCESS CRITERIA

### During Incident:
- ✅ Payment service pods: 1/1 Running (healthy)
- ✅ Stripe-mock pods: 0/0 (gateway down)
- ✅ Orders fail with "connection refused"
- ✅ Orders status: PAYMENT_FAILED
- ✅ No payment service crashes

### After Recovery:
- ✅ Stripe-mock pods: 1/1 Running
- ✅ New orders succeed
- ✅ Orders status: PAID → SHIPPED
- ✅ Payment logs show successful authorization

---

## 🎯 KEY DISTINGUISHING FACTORS

**INCIDENT-6 (External Gateway Failure):**
- ✅ Payment pods: HEALTHY
- ✅ Error: "connection refused to stripe-mock"
- ✅ Root cause: External dependency down
- ✅ Detection: Healthy pods + failed external calls

**INCIDENT-3 (Internal Service Failure):**
- ❌ Payment pods: 0/0 (scaled to 0)
- ❌ Error: "service unavailable"
- ❌ Root cause: Internal service down
- ❌ Detection: No pods running

**This distinction is CRITICAL for AI SRE agent training.**

---

## ⚠️ KNOWN ISSUES (Not Blockers)

1. **Cart doesn't clear on failed orders** - This is a known bug, not related to INCIDENT-6
2. **UI shows "shipped" for failed orders** - UI bug, database shows correct status
3. **Duplicate orders possible** - No idempotency, can place multiple failed orders

**These bugs don't affect the incident simulation.**

---

## 🎬 READY TO BEGIN

**System Status:** 🟢 READY  
**Payment Gateway:** ✅ CONFIGURED  
**Stripe-Mock:** ✅ RUNNING  
**Test Window:** ⏱️ 180 SECONDS (3 minutes)  

**Execute:** `.\incident-6-activate.ps1` when ready!

---

**Document Version:** 1.0  
**Created:** November 10, 2025, 5:55 PM IST  
**Status:** Production Ready ✅
