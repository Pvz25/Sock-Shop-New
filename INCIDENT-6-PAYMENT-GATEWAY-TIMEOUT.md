# Incident 6: Payment Gateway Timeout/Failure (Third-Party API Issues)

## Overview

**Incident Type:** External Dependency Failure - Third-Party Payment Gateway API  
**Severity:** Critical (P1)  
**User Impact:** Payment processing failures → Orders cannot be completed → Direct revenue loss  
**Root Cause:** Third-party payment gateway API experiencing timeouts, rate limiting, or service unavailability

**✅ ARCHITECTURE:** This incident uses **Toxiproxy** to simulate realistic third-party API failures without modifying any application code. Toxiproxy acts as a transparent network proxy that can inject various failure modes (latency, errors, connection issues) to replicate real-world payment gateway problems.

## Incident Description

This incident simulates critical e-commerce scenarios where external payment gateways experience issues:

### Real-World Scenarios This Simulates:
1. **Stripe API Outage** - API returns 503 Service Unavailable
2. **PayPal Timeout** - Payment authorization takes 30+ seconds, causing timeouts
3. **Payment Processor Rate Limiting** - Too many requests trigger HTTP 429
4. **Gateway Slowness** - High latency (5-15 seconds) during peak traffic
5. **Intermittent Failures** - Gateway randomly fails 30-50% of requests

### Business Impact:
- **Revenue Loss:** Customers cannot complete purchases
- **Cart Abandonment:** Users frustrated by payment errors leave site
- **Customer Support Surge:** Help desk flooded with "payment failed" complaints
- **Reputation Damage:** Social media complaints about site being "broken"
- **Competitive Disadvantage:** Users switch to competitors with working checkouts

---

## Architecture: Toxiproxy-Based Failure Injection

### Normal Flow (No Incident):
```
User → Front-end → Orders Service → Payment Service → Payment Pods → ✅ Success
```

### Incident 6 Active Flow:
```
User → Front-end → Orders Service → Payment Service (selector:toxiproxy-payment)
                                            ↓
                                      Toxiproxy Pods
                                            ↓
                                    [INJECT FAILURES]
                                            ↓
                                      Payment Service (via ClusterIP)
                                            ↓
                                      Payment Pods → ❌ Timeout/Error
```

### How It Works:
1. **Toxiproxy Deployment:** Standalone proxy pod that forwards traffic to payment service
2. **Service Selector Patch:** During incident, payment service selector changes from `name:payment` to `name:toxiproxy-payment`
3. **Traffic Interception:** All orders → payment traffic flows through Toxiproxy
4. **Failure Injection:** Toxiproxy configured with "toxics" (latency, connection drops, etc.)
5. **Realistic Errors:** Orders service experiences same failures as real gateway outage

### Key Advantages:
✅ **Zero Code Changes:** No modification to payment or orders services  
✅ **Production-Realistic:** Simulates actual network-level failures  
✅ **Multiple Failure Modes:** Timeout, 503, 429, slowness, intermittent  
✅ **Instant Activation/Recovery:** Single command to enable/disable  
✅ **No Incident 3 Conflict:** Scaling payment to 0 still works independently

---

## Pre-Incident Checklist

### 1. Verify Toxiproxy is Deployed

```powershell
# Check Toxiproxy pod is running
kubectl -n sock-shop get pods -l name=toxiproxy-payment

# Expected Output:
# NAME                               READY   STATUS    RESTARTS   AGE
# toxiproxy-payment-xxxxx            1/1     Running   0          5m

# Verify Toxiproxy service exists
kubectl -n sock-shop get svc toxiproxy-payment

# Expected Output:
# NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
# toxiproxy-payment   ClusterIP   10.96.x.x       <none>        8474/TCP,80/TCP 5m
```

**If Toxiproxy is NOT deployed:**
```powershell
# Deploy Toxiproxy infrastructure
kubectl apply -f toxiproxy-deployment.yaml

# Configure payment proxy
.\configure-toxiproxy-local.ps1

# Verify configuration
kubectl -n sock-shop run test-proxy --rm -it --image=curlimages/curl --restart=Never -- curl -s http://toxiproxy-payment:80/health
```

### 2. Verify Application is Healthy

```powershell
# Check all pods are running (should see 15 pods: 14 app + 1 toxiproxy)
kubectl -n sock-shop get pods

# Test direct payment service (should work normally)
kubectl -n sock-shop run test-payment --rm -it --image=curlimages/curl --restart=Never -- curl -s http://payment:80/health

# Expected: {"health":[{"service":"payment","status":"OK",...}]}
```

### 3. Verify Payment Service Configuration

```powershell
# Check current payment service selector (should be "name: payment")
kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'

# Expected Output: payment (NOT toxiproxy-payment)
```

### 4. Test Baseline Order (Should Succeed)

```powershell
# Open application
Start-Process http://localhost:2025

# Manually place order:
# 1. Browse catalogue
# 2. Add item to cart
# 3. Login (username: user / password: password)
# 4. Complete checkout
# 5. Verify order success page appears

# Check order was created successfully
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders | ConvertFrom-Json | Select-Object -ExpandProperty _embedded | Select-Object -ExpandProperty customerOrders | Select-Object -Last 1

# Expected: Latest order should have status: "PAID"
```

---

## Incident Execution Steps

### Method 1: Quick Start (Default: 30-Second Timeout)

```powershell
# Activate incident with default timeout failure
.\incident-6-activate.ps1

# Expected Output:
# ✅ Backup saved to payment-service-backup.yaml
# ✅ Traffic now flows through Toxiproxy
# ✅ Configured: All payment requests will timeout after 30s
# ✅ INCIDENT 6 ACTIVATED
```

### Method 2: Choose Specific Failure Mode

```powershell
# Option A: 30-second timeout (simulates slow gateway)
.\incident-6-activate.ps1 -FailureMode timeout

# Option B: HTTP 503 Service Unavailable (80% failure rate)
.\incident-6-activate.ps1 -FailureMode 503

# Option C: Rate limiting (50% failure rate)
.\incident-6-activate.ps1 -FailureMode 429

# Option D: Gateway slowness (5-15 second delays)
.\incident-6-activate.ps1 -FailureMode slowness

# Option E: Intermittent failures (30% timeout, 30% fail, 40% succeed)
.\incident-6-activate.ps1 -FailureMode intermittent
```

---

## Observing the Incident

### Step 1: Attempt to Place Orders (Should Fail)

```powershell
# Open application
Start-Process http://localhost:2025

# Try to place order:
# 1. Add items to cart
# 2. Login (user/password)
# 3. Go to checkout
# 4. Click "Place Order"
```

**Expected User Experience:**

**With Timeout Mode:**
- User clicks "Place Order"
- Page loads for 30+ seconds
- Eventually shows: "Payment processing failed" or "Payment service temporarily unavailable"

**With 503/429 Mode:**
- User clicks "Place Order"
- Immediate error: "Payment gateway unavailable"
- Order marked PAYMENT_FAILED in database

**With Slowness Mode:**
- User clicks "Place Order"
- Page takes 10-15 seconds to respond
- May succeed or fail depending on timeout thresholds

**With Intermittent Mode:**
- Some orders succeed (40%)
- Some orders timeout (30%)
- Some orders fail immediately (30%)
- Creates unpredictable user experience

### Step 2: Check Orders Database for Failed Orders

```powershell
# Get all orders with PAYMENT_FAILED status
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders | ConvertFrom-Json | Select-Object -ExpandProperty _embedded | Select-Object -ExpandProperty customerOrders | Where-Object { $_.status -eq "PAYMENT_FAILED" } | Select-Object _id, customerId, status, date

# Example Output:
# _id                      customerId               status          date
# ---                      ----------               ------          ----
# 6900a1f2c1f4320001b5071a 57a98d98e4b00679b4a830af PAYMENT_FAILED 2025-11-07T09:50:15.123Z
# 6900a1f9c1f4320001b5071b 57a98d98e4b00679b4a830af PAYMENT_FAILED 2025-11-07T09:51:22.456Z
```

### Step 3: View Toxiproxy Statistics

```powershell
# Port-forward to Toxiproxy API
kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474

# In another terminal, get proxy stats
Invoke-RestMethod -Uri "http://localhost:8474/proxies" -Method Get -Headers @{"User-Agent"="PowerShell"} | ConvertTo-Json -Depth 5

# Shows active toxics and proxy configuration
```

---

## Datadog Observability

### Key Metrics to Monitor

**1. Payment Service Latency Spike:**
```
metric: http.server.requests.duration{service:payment} > 25000ms
```

**2. Payment Service Error Rate:**
```
metric: http.server.requests.count{service:payment,status:5xx}
rate increase > 50%
```

**3. Orders Service Payment Failures:**
```
log: "Payment failed for order" source:orders service:orders-service
```

**4. Front-End Checkout Errors:**
```
metric: http.client.requests.count{service:front-end,uri:/orders,status:500}
```

### Datadog Log Queries

**Failed Payment Attempts:**
```
service:orders "Payment failed" @status:PAYMENT_FAILED
```

**Gateway Timeout Errors:**
```
service:orders "timeout" OR "timed out" @http.status_code:500
```

**Connection Refused (503 mode):**
```
service:orders "Connection refused" OR "Connection reset"
```

### Expected Datadog Evidence

**Normal State (Before Incident):**
```
[INFO] Payment authorization successful for order abc123
[INFO] Order status updated to PAID
[INFO] Shipping task queued successfully
```

**During Incident 6 (Timeout Mode):**
```
[ERROR] Payment service connection timeout after 30000ms for order abc456
[ERROR] org.springframework.web.client.ResourceAccessException: I/O error on POST request for "http://payment/paymentAuth": Read timed out
[WARN] Order abc456 status updated to PAYMENT_FAILED due to: Read timed out
[ERROR] Servlet.service() threw exception: Payment gateway timeout for order abc456
```

**During Incident 6 (503 Mode):**
```
[ERROR] Payment failed for order abc789: Connection refused (Connection refused)
[ERROR] org.springframework.web.client.ResourceAccessException: I/O error on POST request for "http://payment/paymentAuth": Connection reset by peer
[WARN] Order abc789 status updated to PAYMENT_FAILED
```

---

## Recovery Steps

### Method 1: Automated Recovery (Recommended)

```powershell
# Restore normal payment flow
.\incident-6-recover.ps1

# Expected Output:
# ✅ All failure injections removed
# ✅ Payment service restored to direct routing
# ✅ Payment service is healthy and responding normally
# ✅ INCIDENT 6 RECOVERED - System Restored to Normal
```

### Method 2: Manual Recovery

```powershell
# Step 1: Remove toxics from Toxiproxy
kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474 &
$headers = @{"User-Agent"="PowerShell"}
Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics/gateway_timeout" -Method Delete -Headers $headers

# Step 2: Restore payment service selector
kubectl -n sock-shop patch svc payment -p '{"spec":{"selector":{"name":"payment"}}}'

# Step 3: Verify recovery
kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'
# Should output: payment
```

### Verification After Recovery

```powershell
# Test payment service health
kubectl -n sock-shop run test-recovery --rm -it --image=curlimages/curl --restart=Never -- curl -s http://payment:80/health

# Expected: {"health":[{"service":"payment","status":"OK",...}]}

# Place a test order via UI
Start-Process http://localhost:2025
# Order should complete successfully
```

---

## Post-Incident Analysis

### 1. Count Failed Orders During Incident

```powershell
# Get count of PAYMENT_FAILED orders in last hour
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders | ConvertFrom-Json | Select-Object -ExpandProperty _embedded | Select-Object -ExpandProperty customerOrders | Where-Object { $_.status -eq "PAYMENT_FAILED" -and $_.date -gt (Get-Date).AddHours(-1) } | Measure-Object

# Example Output:
# Count: 15 (15 orders failed due to payment gateway issues)
```

### 2. Calculate Business Impact

```powershell
# Get average order value
$allOrders = kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders | ConvertFrom-Json | Select-Object -ExpandProperty _embedded | Select-Object -ExpandProperty customerOrders

$avgOrderValue = ($allOrders | Where-Object { $_.status -eq "PAID" } | ForEach-Object { $_.total } | Measure-Object -Average).Average

$failedOrderCount = ($allOrders | Where-Object { $_.status -eq "PAYMENT_FAILED" } | Measure-Object).Count

$estimatedRevenueLoss = $avgOrderValue * $failedOrderCount

Write-Host "Estimated Revenue Loss: $$estimatedRevenueLoss" -ForegroundColor Red
Write-Host "Failed Orders: $failedOrderCount" -ForegroundColor Yellow
Write-Host "Average Order Value: $$avgOrderValue" -ForegroundColor Cyan
```

### 3. Review Datadog Timeline

**Timeline Analysis:**
1. **T+0**: Incident activated, Toxiproxy routing enabled
2. **T+1min**: First payment timeout errors appear in logs
3. **T+2-10min**: Failed orders accumulate in database
4. **T+10min**: Incident recovered, routing restored
5. **T+11min**: New orders processing successfully

---

## AI SRE Agent Testing Scenarios

### Scenario 1: Detect Payment Gateway Degradation

**Initial Signal:** Spike in orders with PAYMENT_FAILED status

**AI SRE Investigation Path:**
1. **Symptom Detection:**
   ```
   Query: service:orders @order.status:PAYMENT_FAILED
   Finding: 15 failed orders in last 10 minutes (normally 0)
   ```

2. **Root Cause Analysis:**
   ```
   Query: service:orders "Payment failed" @error.message:*
   Finding: Multiple "Read timed out" and "Connection refused" errors
   ```

3. **Component Identification:**
   ```
   Query: service:payment @http.status_code:500
   Finding: Payment service experiencing 90% error rate
   ```

4. **External Dependency Correlation:**
   ```
   Query: service:payment "timeout" OR "refused"
   Finding: All errors indicate external connectivity issues, not internal service crashes
   ```

**AI SRE Conclusion:**
- ✅ Payment service pods are healthy (not crashing)
- ✅ Database connections are normal
- ✅ Internal network is functioning
- ❌ **Root Cause:** External payment gateway API is unavailable/slow
- **Action:** Check third-party payment provider status page, implement circuit breaker

### Scenario 2: Distinguish Incident 3 vs Incident 6

**Challenge:** Both incidents cause payment failures. How does AI SRE differentiate?

| Signal | Incident 3 (Service Down) | Incident 6 (Gateway Failure) |
|--------|---------------------------|------------------------------|
| **Pod Status** | payment pods: 0/1 or CrashLoopBackOff | payment pods: 1/1 Running ✅ |
| **Error Message** | "Connection refused" to payment:80 | "Read timed out" or "Connection reset" |
| **Response Time** | Immediate failure (<1s) | Delayed failure (30s timeout) |
| **Service Health** | /health endpoint unreachable | /health endpoint responds OK |
| **Kubernetes Events** | Pod termination, scaling events | No pod events |
| **Recovery** | Scale up payment pods | Wait for gateway recovery, implement retry |

**AI SRE Detection Logic:**
```python
if payment_pods_running and payment_health_ok and timeout_errors:
    return "EXTERNAL_GATEWAY_ISSUE"  # Incident 6
elif payment_pods_zero or payment_pods_crashed:
    return "INTERNAL_SERVICE_DOWN"   # Incident 3
```

### Scenario 3: Predict MTTR Based on Failure Mode

**AI SRE Intelligence:**

| Failure Mode | Typical MTTR | Action |
|--------------|--------------|--------|
| **Timeout (30s)** | 15-60 min | Wait for gateway recovery, implement cache |
| **503 Service Unavailable** | 5-30 min | Wait, check provider status page |
| **429 Rate Limiting** | 1-5 min | Reduce request rate, implement backoff |
| **Intermittent** | 30-90 min | Most complex, requires circuit breaker |

### Scenario 4: Automated Remediation

**AI SRE Actions:**
1. **Immediate:** Activate circuit breaker to fail fast (don't wait 30s)
2. **Short-term:** Queue failed orders for retry when gateway recovers
3. **Communication:** Auto-post status page: "Payments temporarily unavailable"
4. **Escalation:** Page on-call engineer if failure rate > 50% for > 5 min

---

## Cleanup (Optional)

If you want to completely remove Toxiproxy infrastructure:

```powershell
# Remove Toxiproxy deployment and service
kubectl -n sock-shop delete -f toxiproxy-deployment.yaml

# Verify removal
kubectl -n sock-shop get pods -l name=toxiproxy-payment
# Should return: No resources found

# Remove configuration scripts (optional)
Remove-Item configure-toxiproxy-local.ps1
Remove-Item incident-6-activate.ps1
Remove-Item incident-6-recover.ps1
```

---

## Comparison: Incident 3 vs Incident 6

| Aspect | Incident 3 | Incident 6 |
|--------|-----------|-----------|
| **Root Cause** | Payment service unavailable (scaled to 0) | Third-party gateway API issues |
| **Symptom** | Immediate connection refused | Timeout or intermittent failures |
| **User Experience** | Clear error message (service down) | Confusing (some succeed, some fail) |
| **Detection** | Pod count = 0, health check fails | Pod healthy, but requests fail |
| **Recovery** | Scale payment pods back to 1 | Wait for gateway, implement retry |
| **MTTR** | <1 minute (kubectl scale) | 15-60 minutes (wait for third-party) |
| **Prevention** | Monitoring + auto-restart | Circuit breaker, fallback payment method |

---

## Key Takeaways

✅ **Realistic Simulation:** Toxiproxy accurately replicates third-party API failures  
✅ **Zero Code Changes:** No application modifications required  
✅ **Multiple Failure Modes:** Timeout, 503, 429, slowness, intermittent  
✅ **Instant Activation:** Single command to start/stop incident  
✅ **AI SRE Testing:** Validates detection of external dependency failures  
✅ **Production Relevance:** Mirrors real Stripe/PayPal/payment processor outages  

---

## Troubleshooting

### Issue: Incident won't activate

```powershell
# Check Toxiproxy is running
kubectl -n sock-shop get pods -l name=toxiproxy-payment

# Check proxy configuration
kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474
Invoke-RestMethod -Uri "http://localhost:8474/proxies" -Headers @{"User-Agent"="PS"}
```

### Issue: Orders still succeeding during incident

```powershell
# Verify service selector was patched
kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'
# Should output: toxiproxy-payment (NOT payment)

# If wrong, re-run activation
.\incident-6-activate.ps1
```

### Issue: Recovery doesn't restore normal operation

```powershell
# Manual recovery
kubectl -n sock-shop patch svc payment -p '{"spec":{"selector":{"name":"payment"}}}'

# Verify
kubectl -n sock-shop get svc payment -o yaml
```

---

**Document Version:** 1.0  
**Last Updated:** November 7, 2025  
**Tested On:** KIND Kubernetes 1.27, Sock Shop v1.1
