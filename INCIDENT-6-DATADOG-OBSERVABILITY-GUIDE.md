# INCIDENT-6 DATADOG OBSERVABILITY GUIDE
## Payment Gateway Timeout / Failure - Third-Party API Down

**Incident Type:** External Dependency Failure (Payment Gateway)  
**Client Requirement:** "Payment gateway timeout or failure, caused by third-party API issues"  
**Date:** November 7, 2025 (Baseline) | November 10, 2025 (Extended Incident) | November 11, 2025 (Regression Test)  
**Status:** ✅ VERIFIED - Evidence Available in Datadog (Nov 7 & Nov 11)

---

## INCIDENT TIMELINES

### Timeline 1: November 7, 2025 (Planned Test - 4.5 Minutes)

**Test Execution: November 7, 2025**

**All times shown in both UTC and IST (India Standard Time, UTC+5:30)**

| Event | IST Time | UTC Time |
|-------|----------|----------|
| Pre-incident verification | 22:22:00 | 16:52:00 |
| Stripe-mock scaled to 0 (incident activated) | 22:24:14 | 16:54:14 |
| Order placement window start | 22:24:44 | 16:54:44 |
| First failed order | 22:25:33 | 16:55:33 |
| Second failed order | 22:25:48 | 16:55:48 |
| Third failed order | 22:26:03 | 16:56:03 |
| Fourth failed order | 22:26:14 | 16:56:14 |
| Fifth failed order | 22:26:25 | 16:56:25 |
| Order window end | 22:26:44 | 16:56:44 |
| Recovery executed (stripe-mock scaled to 1) | 22:28:44 | 16:58:44 |
| System stabilized | 22:29:11 | 16:59:11 |

**Analysis Window:**  
- **IST:** 22:24:00 to 22:30:00 (November 7, 2025)
- **UTC:** 16:54:00 to 17:00:00 (November 7, 2025)

**Duration:** 4 minutes 57 seconds  
**Failed Orders:** 5 orders  
**Revenue Blocked:** $353.16  
**Status:** ✅ Successful planned test with proper recovery

---

### Timeline 2: November 10, 2025 (Extended Incident - 19m 30s Active, 2h+ Detection Delay)

**Test Execution: November 10, 2025**

**All times shown in both UTC and IST (India Standard Time, UTC+5:30)**

| Event | IST Time | UTC Time |
|-------|----------|----------|
| System preparation complete | 17:55:00 | 12:25:00 |
| Payment service deployed (gateway v2) | 17:55:21 | 12:25:21 |
| Payment gateway configured | 17:55:21 | 12:25:21 |
| Incident activation (stripe-mock → 0) | 17:57:00 | 12:27:00 |
| 180-second order window start | 17:57:15 | 12:27:15 |
| User placing orders (window active) | 17:57-18:00 | 12:27-12:30 |
| 180-second order window end | 18:00:15 | 12:30:15 |
| **Recovery NOT executed** ⚠️ | - | - |
| User first order attempt (still failing) | 18:02:01 | 12:32:01 |
| User second order attempt (still failing) | 18:02:12 | 12:32:12 |
| User reported: "Orders still failing" | 18:14:00 | 12:44:00 |
| Investigation started | 18:14:30 | 12:44:30 |
| Root cause identified (missed recovery) | 18:15:00 | 12:45:00 |
| **Recovery executed** (stripe-mock → 1) | 18:16:30 | 12:46:30 |
| Stripe-mock pod started | 18:16:49 | 12:46:49 |
| System verified healthy | 18:17:00 | 12:47:00 |

**Analysis Window (Active Incident):**  
- **IST:** 17:57:00 to 18:16:30 (November 10, 2025)
- **UTC:** 12:27:00 to 12:46:30 (November 10, 2025)

**Duration:** 19 minutes 30 seconds  
**Failed Orders:** Multiple (exact count unknown)  
**Status:** ⚠️ Extended incident due to missed recovery step

**⚠️ CRITICAL NOTE - Logs Not in Datadog:**
The Nov 10 incident logs were **NOT sent to Datadog** because the DNS issue had regressed between Nov 7 and Nov 10. Additionally, pod restarts on Nov 11 wiped the local Kubernetes logs. While the incident definitely occurred (users reported failing orders), no log evidence remains in Datadog or Kubernetes.

**Nov 10 Log Status:**
- ❌ **No logs in Datadog** (DNS broken, logs never sent)
- ❌ **No logs in Kubernetes** (pods restarted Nov 11, logs wiped)
- ⚠️ Incident definitely occurred (user-reported) but evidence permanently lost
- ⚠️ Extended duration (19m 30s) but no log traces available
- ✅ **Use Nov 7 or Nov 11 logs for analysis** (both have complete evidence)

---

### Timeline 3: November 11, 2025 (Regression Test - 13 Minutes)

**Test Execution: November 11, 2025**

**All times shown in both UTC and IST (India Standard Time, UTC+5:30)**

| Event | IST Time | UTC Time |
|-------|----------|----------|
| Test initiated | 12:00:00 | 06:30:00 |
| Pre-test verification complete | 12:00:15 | 06:30:15 |
| Incident activation (stripe-mock → 0) | 12:00:30 | 06:30:30 |
| Stripe-mock pod terminated | 12:00:45 | 06:30:45 |
| Order attempts begin (window active) | 12:01:00 | 06:31:00 |
| First failed order (amount $77.30) | 12:07:53 | 06:37:53 |
| Second failed order (amount $94.45) | 12:09:04 | 06:39:04 |
| Additional attempts (all failed) | 12:01-12:13 | 06:31-06:43 |
| User confirmed testing complete | 12:13:00 | 06:43:00 |
| Recovery initiated (stripe-mock → 1) | 12:13:30 | 06:43:30 |
| Stripe-mock pod running (READY 1/1) | 12:13:45 | 06:43:45 |
| System verified healthy | 12:14:00 | 06:44:00 |

**Analysis Window (Active Incident):**  
- **IST:** 12:00:30 to 12:13:30 (November 11, 2025)  
- **UTC:** 06:30:30 to 06:43:30 (November 11, 2025)

**Duration:** 13 minutes (gateway down from activation to recovery)  
**Failed Orders:** Multiple (≥2 confirmed via logs/UI)  
**Status:** ✅ Successful regression test with immediate recovery

**Nov 11 Log Status:**
- ✅ **Logs in Datadog** (DNS fix permanent, logs transmitted)  
- ✅ **Logs in Kubernetes (live)** (payment deployment still running)  
- ✅ **Evidence archived** via Datadog queries, screenshots, and summary doc

**Key Learning:** Reinforces that the permanent DNS fix restores full observability. Demonstrates that INCIDENT-6 signatures are consistent and repeatable, differentiating external dependency failures from internal service outages.

**Key Learning:** The Nov 10 incident demonstrated the importance of:
1. Executing recovery immediately after the test window
2. Verifying Datadog health BEFORE running incidents
3. Archiving test evidence immediately (don't rely on Datadog alone)

---

### Comparison: Nov 7 vs Nov 10

| Metric | Nov 7, 2025 | Nov 10, 2025 | Nov 11, 2025 |
|--------|-------------|--------------|--------------|
| **Test Type** | Planned, documented | Planned, but recovery missed | Regression test with permanent DNS fix |
| **Incident Duration** | 4m 57s | 19m 30s | 13m 00s |
| **Failed Orders (confirmed)** | 5 orders | Multiple (2+ confirmed) | Multiple (≥2 confirmed) |
| **Revenue Blocked** | $353.16 | Unknown (extended impact) | $171.75+ (based on confirmed attempts) |
| **Recovery** | Executed at 4m 30s | Delayed until 19m 30s | Executed at 13m 30s |
| **Detection** | Immediate | User-reported at 17 minutes | Immediate (observed during test) |
| **Root Cause** | Gateway scaled to 0 (expected) | Gateway down + recovery not run | Gateway scaled to 0 (expected) |
| **Logs in Datadog** | ✅ YES (DNS working) | ❌ NO (DNS broken) | ✅ YES (DNS fix permanent) |
| **Lesson** | Successful simulation | Importance of recovery SOP + Datadog health checks | Validated permanent DNS fix + consistent incident signatures |

**Recommendation for Future Tests:**  
Always execute `incident-6-recover.ps1` immediately after the order placement window to prevent extended outages.

---

## INCIDENT SUMMARY

**What Happened (Both Tests):**
- Stripe-mock payment gateway scaled to **0 replicas** (simulating third-party API outage)
- **Nov 7:** 5 customer orders attempted, all failed with `PAYMENT_FAILED` status
- **Nov 10:** Multiple customer orders attempted, all failed (extended incident)
- Payment service remained **healthy** (1/1 Running) throughout both incidents
- Connection errors: "connection refused" to stripe-mock gateway
- Orders not completed, customers unable to checkout
- **Nov 7:** System recovered after 4m 57s (planned recovery)
- **Nov 10:** System recovered after 19m 30s (delayed recovery)

**Root Cause:**
- External payment gateway (stripe-mock) unavailable
- Payment service could not establish TCP connection to gateway endpoint
- Fast-fail behavior (~0.1s timeout, no hanging requests)

**Impact:**
- **Nov 7:** 5 failed order attempts, $353.16 revenue blocked
- **Nov 10:** Multiple failed attempts (extended impact due to missed recovery)
- 100% payment failure rate during incident windows
- Revenue loss (orders not completed)
- Customer friction (checkout errors)
- **Zero internal service failures** (payment pods stayed healthy in both tests)

**Key Distinguishing Factor:**
```
INCIDENT-6: External gateway down, payment pods healthy ✅
INCIDENT-3: Payment service down, 0 pods running ❌

This distinction is CRITICAL for AI SRE agent training.
```

---

## DATADOG LOG QUERIES

### Query 1: Payment Gateway Errors (Primary Signal)

**Query (Option 1 - Using pod_name):**
```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
```

**Query (Option 2 - Using kube_container_name):**
```
kube_namespace:sock-shop kube_container_name:payment "Payment gateway error"
```

**Both queries return the same results.** Use whichever you prefer.

**Time Ranges:**
- **Nov 7 Test:** 22:24-22:30 IST (16:54-17:00 UTC) ✅ **Logs available in Datadog**
- **Nov 10 Test:** 17:57-18:17 IST (12:27-12:47 UTC) ❌ **Logs NOT in Datadog (DNS broken)**

**Note:** Only Nov 7 logs are available in Datadog. Nov 10 logs were never sent due to DNS issues and were subsequently lost when pods restarted.

**Expected Results:**

**Nov 7, 2025:**
- ✅ 5 error log entries (one per failed order)
- ✅ Error status (red indicator)
- ✅ Timestamps: 16:55:33, 16:55:48, 16:56:03, 16:56:14, 16:56:25 UTC
- ✅ Clear message: "Post 'http://stripe-mock/v1/charges': dial tcp ... connection refused"

**Nov 10, 2025:**
- ✅ Multiple error log entries
- ✅ Timestamps: 12:32:01, 12:32:12 UTC (confirmed), plus others during extended outage
- ✅ Same error pattern: "connection refused" to stripe-mock

**Sample Log Entry:**
```json
{
  "timestamp": "2025-11-07T16:55:33Z",
  "status": "error",
  "service": "payment",
  "message": "❌ Payment gateway error: Post \"http://stripe-mock/v1/charges\": dial tcp 10.96.196.183:80: connect: connection refused (0.00s)",
  "kube_namespace": "sock-shop",
  "kube_deployment": "payment",
  "pod_name": "payment-xxxxx"
}
```

**Log Volume:**
- Baseline: 0 errors/minute
- During incident: 2-3 errors/minute (5 total in ~2 minutes)
- Post-recovery: 0 errors/minute

**Analysis:**
- Fast failure (~0.1s) indicates immediate connection refused
- No retries or hanging (good error handling)
- External service name visible ("stripe-mock")
- Clear distinction from internal payment service failure

---

### Query 2: Connection Refused Errors

**Query (Option 1 - Using pod_name):**
```
kube_namespace:sock-shop pod_name:payment* "connection refused" "stripe-mock"
```

**Query (Option 2 - Using kube_container_name):**
```
kube_namespace:sock-shop kube_container_name:payment "connection refused" "stripe-mock"
```

**Expected Results:**
- ✅ Same 5 error entries as Query 1
- ✅ Explicit mention of "stripe-mock" gateway
- ✅ TCP connection failure details
- ✅ ClusterIP address visible (10.96.196.183:80)

**Key Log Patterns:**
```
"connection refused"           # TCP connection failure
"stripe-mock"                  # External gateway name
"dial tcp"                     # Go HTTP client error
"Post /v1/charges"            # Stripe API endpoint
```

**Correlation:**
- All errors reference same ClusterIP (stripe-mock service)
- Port 80 (Kubernetes service port)
- Immediate refusal (service scaled to 0, no pods listening)

---

### Query 3: Orders Service Payment Responses

**Query (VERIFIED WORKING - Using service tag):**
```
kube_namespace:sock-shop service:sock-shop-orders "PaymentResponse{authorised=false"
```

**Alternative (Broader match):**
```
kube_namespace:sock-shop service:sock-shop-orders "Payment gateway error"
```

**Important:** The orders service does **not** emit the literal string `"PAYMENT_FAILED"` in its application logs. Instead, each checkout records the full payment response payload. During INCIDENT-6 the payloads show `PaymentResponse{authorised=false, message=Payment gateway error: ...}` at INFO level.

**Expected Results:**
- ✅ Multiple INFO log entries during incident windows
- ✅ `authorised=false` flag visible in the message
- ✅ Same timestamps as payment service errors
- ✅ Embedded customer/cart context for each attempt

**Sample Log Entry:**
```
2025-11-11T06:38:22Z INFO [orders,...] Received payment response: PaymentResponse{authorised=false, message=Payment gateway error: Post "http://stripe-mock/v1/charges": dial tcp 10.96.145.169:80: connect: connection refused}
```

**Key Insight:**
- Use the `PaymentResponse{authorised=false}` pattern (or the shared "Payment gateway error" string) to detect failed orders. Datadog queries targeting `PAYMENT_FAILED` will return zero results because that token is never logged by the orders service codebase.
- Conversion rate: 0% (all orders failed)

---

### Query 4: Multi-Service View (External Failure Isolation)

**Query:**
```
kube_namespace:sock-shop (pod_name:payment* OR pod_name:orders* OR pod_name:stripe-mock*) status:error
```

**Expected Results:**
- ✅ Errors ONLY from payment service (gateway caller)
- ✅ Errors from orders service (downstream effect)
- ✅ ZERO errors from stripe-mock (no pods running)

**Service Distribution:**
```
payment:      100% of "connection refused" errors
orders:       100% of "PAYMENT_FAILED" status updates
stripe-mock:  0% (no pods, no logs)
```

**Analysis:**
- Payment service healthy (pod running, calling gateway)
- Orders service healthy (processing payment failures)
- Stripe-mock absent (0 pods = external service down)
- **Isolation confirmed:** Only external dependency affected

---

### Query 5: Payment Service Health (Proving Internal Health)

**Query (Option 1 - Using pod_name):**
```
kube_namespace:sock-shop pod_name:payment* ("starting on port" OR "Payment gateway:")
```

**Query (Option 2 - Using kube_container_name):**
```
kube_namespace:sock-shop kube_container_name:payment ("starting on port" OR "Payment gateway:")
```

**Expected Results:**
- ✅ Pod startup log: "Payment service starting on port 8080"
- ✅ Gateway configuration: "✅ Payment gateway: http://stripe-mock"
- ✅ ZERO crash logs
- ✅ ZERO SIGTERM signals

**Sample Startup Log:**
```
2025/11/10 12:25:21 ✅ Payment gateway: http://stripe-mock
2025/11/10 12:25:21 🚀 Payment service starting on port 8080
```

**Health Indicators:**
- Payment service configured with correct gateway URL
- Service listening on port 8080
- No restarts during incident
- Liveness/readiness probes passing

**Contrast with INCIDENT-3:**
```
INCIDENT-6: Payment pods healthy, gateway calls failing ✅
INCIDENT-3: Payment pods scaled to 0, no service running ❌
```

---

### Query 6: All Sock-Shop Errors (Incident Scope)

**Query:**
```
kube_namespace:sock-shop status:error
```

**Time Range:** November 7, 2025, 22:24-22:30 IST (16:54-17:00 UTC)

**Expected Results:**
- ✅ Error spike during incident window
- ✅ Payment service dominates error count
- ✅ Orders service shows downstream effects
- ✅ Clear start/end correlation with incident activation/recovery

**Service Breakdown:**
| Service | Error Count | Primary Error Types |
|---------|-------------|---------------------|
| payment | 5 | Connection refused to gateway |
| orders | 5 | Payment authorization failed, status updates |
| Others | 0 | No impact on other services |

**Graph Pattern:**
```
Errors/min
      5 |     ╱╲    
        |    ╱  ╲   
      4 |   ╱    ╲  
        |  ╱      ╲ 
      3 | ╱        ╲
        |╱          ╲
      0 |────────────╲────
        22:22  22:25  22:29
               ↑      ↑
         Incident  Recovery
           Start
```

---

### Query 7: Kubernetes Event Logs (Stripe-Mock Scaled Down)

**Query:**
```
kube_namespace:sock-shop source:kubernetes kube_deployment:stripe-mock (Scaled OR ScalingReplicaSet)
```

**Expected Results:**
- ✅ "Scaled down replica set stripe-mock-xxx to 0"
- ✅ "Scaled up replica set stripe-mock-xxx to 1" (recovery)
- ✅ Timestamps matching incident timeline

**Sample Events:**
```
Normal: ScalingReplicaSet - Scaled down replica set stripe-mock-84fd48f97d to 0 from 1
Normal: ScalingReplicaSet - Scaled up replica set stripe-mock-84fd48f97d to 1 from 0
```

**Event Timeline:**
- 22:24:14 IST → Scaled to 0 (incident start)
- 22:28:44 IST → Scaled to 1 (recovery)
- Duration: 4 minutes 30 seconds

---

## DATADOG METRICS QUERIES

### Metric 1: Stripe-Mock Available Replicas (PRIMARY SIGNAL)

**Metric (use kube-state metrics):**
```
kubernetes_state.deployment.replicas_available
```

**Filters:**
```
from: kube_namespace:sock-shop, kube_deployment:stripe-mock
avg by: kube_deployment
```

**Recommended Graph Settings (Metrics Explorer):**
- Display: `Lines`
- `Rollup → max` with 1-min interval
- `Fill missing values → 0` (so gaps render as zero)

**Why this metric?**
- `kubernetes.pods.running` only emits data while pods exist. When the deployment is scaled to 0 the timeseries disappears, and Datadog keeps plotting the last value (1), giving a flat baseline.
- `kubernetes_state.deployment.replicas_available` continues to report `0` even when no pods are running, so the graph captures the outage precisely.

**Observation Expectations (Nov 7 & Nov 11 tests):**

✅ **Baseline:** value = `1` replica

✅ **During Incident:** value drops to `0` immediately after `stripe-mock` is scaled to 0 and remains at `0` for the duration of the outage

✅ **Recovery:** value returns to `1` within ~30 seconds of running `incident-6-recover.ps1`

**Graph Pattern:**
```
Replicas
  1 |─╖              ╔─
    | ║              ║
    | ║              ║
    | ╙──────────────╜
  0 |──────────────────
    06:30         06:43
        Incident  Recovery
```

**Key Insight:**
- This metric cleanly distinguishes “all gateway pods absent” versus “available”. It is the preferred signal for alerting dashboards and drill-downs.

> ℹ️ If you must stay with `kubernetes.pods.running`, switch the display to `Fill → 0` or apply `.rollup(count, 60)` to avoid Datadog’s last-value carry-over. However, `kubernetes_state.deployment.replicas_available` remains the authoritative source.

**Related metrics:**

- `kubernetes_state.deployment.replicas_desired` mirrors the scale commands (1 → 0 → 1). Overlaying desired vs. available makes the outage window obvious.
- `kubernetes_state.deployment.replicas_unavailable` stays at `0` during this incident because desired replicas are set to `0` while the gateway is intentionally disabled. To see the “missing replicas” view, create a formula:  
  `A - B` where `A = kubernetes_state.deployment.replicas_desired` and `B = kubernetes_state.deployment.replicas_available`.

---

### Metric 2: Payment Pod Count (Proving Internal Health)

**Metric:**
```
kubernetes.pods.running
```

**Filters:**
```
from: kube_namespace:sock-shop, kube_deployment:payment
sum by: kube_deployment
```

**Observation Expectations:**

✅ **Throughout Entire Incident:**
- Pod count: **1 (stable)**
- No drops or spikes
- Payment service unaffected

**Graph Pattern:**
```
Pods
    1 |═══════════════════
      |
      |
      |
      |
    0 |────────────────────
      22:20  22:25  22:30
```

**Conclusion:**
- Payment service remained healthy
- **External failure, not internal**
- Pods did not crash or restart
- Liveness/readiness probes passing

**AI SRE Detection:**
```
IF payment_pods = 1 AND stripe_mock_pods = 0 AND payment_errors > 0:
    CLASSIFY as "External dependency failure"
    RECOMMENDED ACTION: "Check third-party gateway status, enable circuit breaker"

IF payment_pods = 0 AND payment_errors > 0:
    CLASSIFY as "Internal service failure"
    RECOMMENDED ACTION: "Scale up payment service, check deployment health"
```

---

### Metric 3: Payment Container Restarts (Stability Indicator)

**Metric:**
```
kubernetes.containers.restarts
```

**Filters:**
```
from: kube_namespace:sock-shop, kube_deployment:payment
sum
```

**Observation Expectations:**

✅ **Flat line (no increases)**

**Graph Pattern:**
```
Restarts
    N |═══════════════════
      | (baseline, e.g., 3)
      |
      |
      |
    0 |────────────────────
      22:20  22:25  22:30
```

**Analysis:**
- ZERO restarts during incident
- Payment service stable
- Error handling worked correctly (didn't crash on gateway errors)
- Good resilience design

**Contrast:**
```
INCIDENT-7: 7 restarts in 8 minutes (CPU throttling) ❌
INCIDENT-6: 0 restarts (external failure handling) ✅
```

---

### Metric 4: Network Bytes Transmitted (Payment Service)

**Metric:**
```
kubernetes.network.tx_bytes
```

**Filters:**
```
from: kube_namespace:sock-shop, kube_deployment:payment
rate
```

**Observation Expectations:**

✅ **Baseline:** ~100-500 bytes/sec (minimal traffic)  
✅ **During Incident:** Slight increase (outgoing connection attempts)  
✅ **Recovery:** Return to baseline

**Analysis:**
- Payment service attempting to connect to gateway
- Minimal data transmission (connection refused immediately)
- No data sent/received (no successful connections)

---

### Metric 5: Orders Service Request Rate (Downstream Impact)

**Metric:**
```
kubernetes.network.rx_bytes
```

**Filters:**
```
from: kube_namespace:sock-shop, kube_deployment:orders
rate
```

**Observation Expectations:**

✅ **Traffic pattern matches failed orders**
- 5 distinct spikes (one per order attempt)
- Each spike represents HTTP POST to /paymentAuth
- Response received (payment failure)

**Graph Pattern:**
```
Bytes/sec
   500 |  │  │ │ │
       |  │  │ │ │
   400 |  │  │ │ │
       |  │  │ │ │
   300 | ││  ││││
       | ││  ││││
   200 | ││  ││││
       | ││  ││││
   100 |│││││││││
       |│││││││││
     0 |─────────────
       16:55  16:56
```

**Analysis:**
- Orders service actively calling payment service
- Payment service responding (not hanging)
- Fast failures propagating correctly

---

## DATADOG APM TRACES (If Enabled)

**Note:** APM traces use `service:` tags (different from log queries which use `pod_name:`). If APM/tracing is not enabled, these queries will return no results.

### Trace Query 1: Failed Payment Authorization Calls

**Query:**
```
service:orders resource_name:/paymentAuth status:error
```

**Expected Results:**
- 5 failed traces
- Error: "Payment authorization failed"
- Downstream call to payment service visible
- Fast response time (~0.1s)

---

### Trace Query 2: Payment Service Gateway Calls

**Query:**
```
service:payment resource_name:POST_/v1/charges error:true
```

**Expected Results:**
- 5 failed outbound HTTP calls
- Target: stripe-mock endpoint
- Error: "connection refused"
- Span duration: ~0.1s (fast-fail)

---

## KEY METRICS SUMMARY

### November 7, 2025 Test

| Metric | Baseline | During Incident | Recovery | Significance |
|--------|----------|-----------------|----------|--------------|
| **Stripe-Mock Pods** | 1 | 0 | 1 | 🔴 Gateway unavailable |
| **Payment Pods** | 1 | 1 | 1 | ✅ Service healthy |
| **Payment Restarts** | N | N | N | ✅ No crashes |
| **Failed Orders** | 0 | 5 | 0 | 🔴 Revenue impact |
| **Payment Errors/min** | 0 | 2-3 | 0 | 🔴 Gateway errors |
| **Incident Duration** | - | 4m 57s | - | ✅ Quick recovery |

### November 10, 2025 Test

| Metric | Baseline | During Incident | Recovery | Significance |
|--------|----------|-----------------|----------|--------------|
| **Stripe-Mock Pods** | 1 | 0 | 1 | 🔴 Gateway unavailable |
| **Payment Pods** | 1 | 1 | 1 | ✅ Service healthy |
| **Payment Restarts** | N | N | N | ✅ No crashes |
| **Failed Orders** | 0 | Multiple (2+) | 0 | 🔴 Extended impact |
| **Payment Errors/min** | 0 | ~1-2 | 0 | 🔴 Gateway errors |
| **Incident Duration** | - | 19m 30s | - | ⚠️ Delayed recovery |

---

## INCIDENT DETECTION SIGNATURES

### Primary Signals (Red Flags)
1. ✅ Payment gateway errors mentioning "connection refused"
2. ✅ Stripe-mock pod count = 0
3. ✅ Orders with PAYMENT_FAILED status
4. ✅ Payment service pods = 1 (healthy)
5. ✅ Fast failure times (~0.1s, not hanging)

### Secondary Signals (Context)
1. ✅ Zero payment service restarts
2. ✅ Payment service logs showing startup/health
3. ✅ Gateway URL configured correctly
4. ✅ ClusterIP visible in error messages
5. ✅ Kubernetes scaling events (stripe-mock)

### Distinguishing from Similar Incidents
```
INCIDENT-3 (Payment Service Down):
- Payment pods: 0
- Error: "service unavailable" or 5xx
- No external gateway mentioned
- Scaling event: payment service scaled to 0

INCIDENT-6 (Payment Gateway Down):
- Payment pods: 1 (healthy)
- Error: "connection refused" to stripe-mock
- External service name visible
- Scaling event: stripe-mock scaled to 0
```

---

## BUSINESS IMPACT METRICS

### November 7, 2025 Test

**Revenue Impact:**
- **Total blocked revenue:** $353.16
- **Failed transactions:** 5
- **Conversion rate:** 0% (during outage)
- **Average order value:** $70.63

**Customer Impact:**
- **Affected customers:** 5 (minimum, could be more abandoned carts)
- **Error experience:** "Payment declined" error message
- **Retry behavior:** Unknown (not tracked)
- **Potential churn:** High (payment failures erode trust)

**Time-Based Metrics:**
- **Incident duration:** 4m 57s
- **Detection time:** <1 minute (first failed order)
- **Recovery time:** 30 seconds (gateway restored)
- **MTTR (Mean Time To Recovery):** ~5 minutes

---

### November 10, 2025 Test

**Revenue Impact:**
- **Total blocked revenue:** Unknown (multiple failed orders)
- **Failed transactions:** Multiple (at least 2 confirmed, likely more)
- **Conversion rate:** 0% (during extended outage)
- **Average order value:** Unknown

**Customer Impact:**
- **Affected customers:** Multiple (potentially higher due to longer outage)
- **Error experience:** "Payment declined" error message (same as Nov 7)
- **Retry behavior:** Multiple retry attempts observed
- **Potential churn:** Very High (extended payment failures)

**Time-Based Metrics:**
- **Incident duration:** 19m 30s
- **Detection time:** 17 minutes (user-reported)
- **Recovery time:** 30 seconds (gateway restored)
- **MTTR (Mean Time To Recovery):** ~20 minutes

**Key Difference:**
- Nov 7: Fast detection and recovery (5 min total)
- Nov 10: Delayed detection and recovery (20 min total)
- **4x longer incident duration** highlights importance of SOP compliance

---

## DATADOG DASHBOARD RECOMMENDATIONS

### Dashboard 1: Payment Gateway Health
**Widgets:**
1. Stripe-mock pod count (gauge)
2. Payment gateway error rate (timeseries)
3. Failed order count (query value)
4. Payment service health (pod count)

---

### Dashboard 2: External Dependency Monitoring
**Widgets:**
1. Payment gateway response time (latency)
2. Gateway connection errors (timeseries)
3. Payment vs gateway pod comparison (top list)
4. External call error rate (query value)

---

## ALERT RECOMMENDATIONS

### Alert 1: Payment Gateway Unavailable

**Condition:**
```
kubernetes.pods.running{kube_deployment:stripe-mock} == 0
```

**Severity:** Critical  
**Notification:** Immediate (PagerDuty, Slack)  
**Message:** "Payment gateway (stripe-mock) has zero pods running. All payment processing will fail."

---

### Alert 2: High Payment Error Rate

**Condition:**
```
log.error.count{service:payment} > 5 in last 5 minutes
```

**Severity:** High  
**Notification:** Slack, email  
**Message:** "Payment service experiencing elevated error rate. Check gateway connectivity."

---

### Alert 3: Failed Orders Spike

**Condition:**
```
log.warn.count{service:orders,message:PAYMENT_FAILED} > 3 in last 5 minutes
```

**Severity:** High  
**Notification:** Business team, on-call  
**Message:** "Multiple orders failing payment authorization. Revenue impact in progress."

---

## RUNBOOK: INCIDENT-6 RECOVERY

### Step 1: Verify External Gateway Status
```bash
kubectl get pods -n sock-shop -l name=stripe-mock
# Expected: 0 pods running (if incident active)
```

### Step 2: Check Payment Service Health
```bash
kubectl get pods -n sock-shop -l name=payment
# Expected: 1/1 Running (service healthy)
```

### Step 3: Review Recent Payment Errors
**Datadog Query:**
```
service:payment "connection refused" --last 10m
```

### Step 4: Execute Recovery
```bash
# Restore gateway
kubectl scale deployment stripe-mock --replicas=1 -n sock-shop

# Wait for pod
kubectl wait --for=condition=ready pod -l name=stripe-mock -n sock-shop --timeout=60s
```

### Step 5: Verify Recovery
**Datadog Queries:**
```
# Should see new startup logs
service:payment "Payment gateway:" --last 5m

# Errors should stop
service:payment status:error --last 5m
```

### Step 6: Test Payment Flow
```bash
# Place test order via UI
# Expected: Order succeeds, status PAID → SHIPPED
```

---

## VERIFICATION CHECKLIST

**Pre-Test:**
- [ ] Datadog agent healthy (logs being sent)
- [ ] Payment service using custom gateway image (v2)
- [ ] PAYMENT_GATEWAY_URL environment variable set
- [ ] Stripe-mock running (1 pod)

**During Incident:**
- [ ] Stripe-mock scaled to 0
- [ ] Payment pods remain 1/1 Running
- [ ] Order attempts generate gateway errors
- [ ] Errors appear in Datadog within 1 minute

**Post-Recovery:**
- [ ] Stripe-mock scaled to 1
- [ ] Payment errors stop
- [ ] New orders succeed
- [ ] No payment service restarts

---

## DATADOG CONFIGURATION STATUS

**Last Verified:** November 11, 2025, 11:00 AM IST  
**DNS Fix Applied:** ✅ YES  
**Endpoint:** http-intake.logs.us5.datadoghq.com:443  
**Logs Sent:** 3,422+  
**Bytes Sent:** 3.7 MB+  
**Status:** 🟢 HEALTHY

**Environment Variable:**
```yaml
DD_LOGS_CONFIG_LOGS_DD_URL=http-intake.logs.us5.datadoghq.com:443
```

---

## FILES REFERENCE

**Documentation:**
- `INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md` - Main incident guide
- `INCIDENT-6-READY-TO-TEST.md` - Test preparation
- `DATADOG-DNS-FIX-APPLIED.md` - DNS configuration

**Scripts:**
- `incident-6-activate.ps1` - Activation automation
- `incident-6-recover.ps1` - Recovery automation

**Historical:**
- `archive/incident-6-tests/INCIDENT-6-TEST-RESULTS-FINAL.md` - Nov 7 test report
- `archive/incident-6-tests/INCIDENT-6-LIVE-TEST-2025-11-07.md` - Live test logs

---

## CONCLUSION

**INCIDENT-6 is a production-grade simulation of external payment gateway failure.**

**Key Achievements:**
- ✅ Accurately simulates third-party API outage
- ✅ Distinguishable from internal service failures
- ✅ Observable in Datadog (logs + metrics)
- ✅ Clear business impact (revenue loss)
- ✅ Fast detection and recovery
- ✅ No false positives (payment service healthy)

**AI SRE Training Value:**
- **High:** Teaches external vs internal failure classification
- **Critical:** Tests root cause analysis (pods healthy but errors)
- **Realistic:** Common production scenario (gateway timeouts)
- **Measurable:** Clear metrics and logs for detection

---

**Document Version:** 1.0  
**Created:** November 11, 2025, 11:00 AM IST  
**Last Updated:** November 11, 2025, 11:00 AM IST  
**Status:** ✅ Production Ready  
**Verified By:** Datadog Agent Status + Historical Test Data
