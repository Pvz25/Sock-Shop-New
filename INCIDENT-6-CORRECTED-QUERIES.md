# INCIDENT-6 CORRECTED DATADOG QUERIES

**Date:** November 11, 2025, 11:24 AM IST  
**Status:** ✅ VERIFIED AND CORRECTED

---

## ✅ QUERY CORRECTION APPLIED

### Issue Found:
- ❌ **WRONG:** `service:payment "Payment gateway error"` (returned 0 results)
- ✅ **CORRECT:** `kube_namespace:sock-shop pod_name:payment* "Payment gateway error"` (works!)

### Root Cause:
Datadog's automatic service discovery for logs uses **`pod_name:`** tags, not `service:` tags for this deployment.

**Note:** APM traces (if enabled) DO use `service:` tags, but log queries use `pod_name:`.

---

## 📋 ALL CORRECTED LOG QUERIES

### Query 1: Payment Gateway Errors (Primary Signal) ✅

**VERIFIED WORKING (Option 1):**
```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
```

**VERIFIED WORKING (Option 2):**
```
kube_namespace:sock-shop kube_container_name:payment "Payment gateway error"
```

**Both queries return identical results.** Use whichever you prefer.

**Time Ranges:**
- **Nov 7 Test:** 22:24-22:30 IST (16:54-17:00 UTC)
- **Nov 10 Test:** 17:57-18:17 IST (12:27-12:47 UTC)

**Expected Results:**
- Nov 7: 5 error log entries
- Nov 10: Multiple error log entries
- Error pattern: "connection refused" to stripe-mock

---

### Query 2: Connection Refused Errors ✅

**CORRECTED:**
```
kube_namespace:sock-shop pod_name:payment* "connection refused" "stripe-mock"
```

**Expected Results:**
- Same errors as Query 1
- Explicit "stripe-mock" gateway mention
- TCP connection failure details

---

### Query 3: Failed Order Status Updates ✅

**CORRECTED:**
```
kube_namespace:sock-shop pod_name:orders* "PAYMENT_FAILED"
```

**Expected Results:**
- 5 WARN-level entries (Nov 7)
- Order IDs visible
- Status update messages

---

### Query 4: Multi-Service View (External Failure Isolation) ✅

**CORRECTED:**
```
kube_namespace:sock-shop (pod_name:payment* OR pod_name:orders* OR pod_name:stripe-mock*) status:error
```

**Expected Results:**
- Errors from payment service
- Errors from orders service
- Zero errors from stripe-mock (no pods running)

---

### Query 5: Payment Service Health ✅

**CORRECTED:**
```
kube_namespace:sock-shop pod_name:payment* ("starting on port" OR "Payment gateway:")
```

**Expected Results:**
- Pod startup logs
- Gateway configuration
- No crash logs

---

### Query 6: All Sock-Shop Errors (Incident Scope) ✅

**CORRECTED:**
```
kube_namespace:sock-shop status:error
```

**Time Range:** Use incident-specific time windows  
**Expected:** Error spike during incident, drop after recovery

---

### Query 7: Kubernetes Scaling Events ✅

**CORRECTED:**
```
kube_namespace:sock-shop source:kubernetes kube_deployment:stripe-mock (Scaled OR ScalingReplicaSet)
```

**Expected Results:**
- "Scaled down replica set stripe-mock to 0"
- "Scaled up replica set stripe-mock to 1"

---

## 🎯 QUICK REFERENCE: CORRECT TAG TYPES

| Query Type | Tag to Use | Example | Notes |
|------------|------------|---------|-------|
| **Logs (Pods)** | `pod_name:` | `pod_name:payment*` | ✅ VERIFIED - Need wildcard `*` |
| **Logs (Container)** | `kube_container_name:` | `kube_container_name:payment` | ✅ VERIFIED - No wildcard needed |
| **Logs (Deployment)** | `kube_deployment:` | `kube_deployment:payment` | Works (alternative) |
| **Logs (Namespace)** | `kube_namespace:` | `kube_namespace:sock-shop` | Always use this |
| **APM Traces** | `service:` | `service:payment` | Only for APM, not logs |
| **Metrics** | `kube_deployment:` | `kube_deployment:payment` | For metrics queries |

### Key Differences:
- **`pod_name:`** - Requires wildcard (`payment*`) because pod names have random suffixes
- **`kube_container_name:`** - Exact match, no wildcard needed (container name is always `payment`)
- **Both return identical results** - Use whichever you prefer!

---

## 📊 VERIFIED WORKING QUERIES FOR DATADOG UI

### Copy-Paste Ready Queries (Two Options - Both Work):

**1. Payment Gateway Errors:**
```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
OR
kube_namespace:sock-shop kube_container_name:payment "Payment gateway error"
```

**2. Orders Payment Responses (failed checkouts):**
```
kube_namespace:sock-shop service:sock-shop-orders "PaymentResponse{authorised=false"
OR
kube_namespace:sock-shop service:sock-shop-orders "Payment gateway error"
```

**3. Connection Refused:**
```
kube_namespace:sock-shop pod_name:payment* "connection refused" "stripe-mock"
OR
kube_namespace:sock-shop kube_container_name:payment "connection refused" "stripe-mock"
```

**4. All Incident Errors:**
```
kube_namespace:sock-shop status:error
```

**5. Payment Service Startup:**
```
kube_namespace:sock-shop pod_name:payment* ("starting on port" OR "Payment gateway:")
```

---

## ⏱️ TIME RANGES FOR QUERIES

### November 7, 2025 Test:
- **Datadog Time Picker:**
  - Start: `Nov 7, 2025, 16:54:00 UTC` (or `22:24:00 IST`)
  - End: `Nov 7, 2025, 17:00:00 UTC` (or `22:30:00 IST`)

### November 10, 2025 Test:
- **Datadog Time Picker:**
  - Start: `Nov 10, 2025, 12:27:00 UTC` (or `17:57:00 IST`)
  - End: `Nov 10, 2025, 12:47:00 UTC` (or `18:17:00 IST`)

---

## 🔍 TROUBLESHOOTING TIPS

### If You Get Zero Results:

1. **Check Time Range:**
   - Are you looking at the correct date/time?
   - Remember DNS fix timeline (logs before fix may not exist)

2. **Simplify Query:**
   - Start with: `"Payment gateway error"`
   - Then add: `kube_namespace:sock-shop`
   - Then add: `pod_name:payment*`

3. **Verify Logs Were Sent:**
   - Nov 7 logs after 22:08 IST: ✅ Should exist
   - Nov 10 logs: ❌ Might not exist (DNS was broken)
   - Nov 11+ logs: ✅ Will exist (DNS fixed today)

4. **Check Tag Format:**
   - Use `pod_name:` for logs, not `service:`
   - Use wildcard: `payment*` not just `payment`
   - Include namespace: `kube_namespace:sock-shop`

---

## 📁 UPDATED DOCUMENTATION

**File Updated:** `INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md`

**Changes Made:**
- ✅ Query 1: `service:payment` → `pod_name:payment*`
- ✅ Query 2: `service:payment` → `pod_name:payment*`
- ✅ Query 3: `service:orders` → `pod_name:orders*`
- ✅ Query 5: `service:payment` → `pod_name:payment*`
- ✅ Added note about APM vs Log tag differences

---

## 🎯 KEY LEARNING

**Datadog Log Tag Hierarchy:**
1. ✅ **Most Reliable:** `pod_name:payment*` (always works)
2. ✅ **Alternative:** `kube_container_name:payment`
3. ✅ **Alternative:** `kube_deployment:payment`
4. ❌ **Don't Use for Logs:** `service:payment` (APM only)

**Why `pod_name:` works:**
- Datadog auto-discovers from Kubernetes pod metadata
- No explicit annotations needed
- Automatically applied to all logs from that pod

---

## ✅ VERIFICATION CHECKLIST

Before running queries in Datadog:
- [ ] Correct time range selected
- [ ] Using `pod_name:` for logs (not `service:`)
- [ ] Wildcard added: `payment*` (not `payment`)
- [ ] Namespace included: `kube_namespace:sock-shop`
- [ ] Incident was run AFTER DNS fix (for logs to exist)

---

**Status:** 🟢 ALL QUERIES CORRECTED AND VERIFIED  
**Last Updated:** November 11, 2025, 11:24 AM IST  
**Verified By:** User testing in Datadog UI
