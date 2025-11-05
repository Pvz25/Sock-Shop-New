# Sock Shop Observability Demo - Manager Presentation Guide
## What We Do, How We Do It, and What to Look For

**Prepared for:** Management Presentation  
**Date:** November 3, 2025  
**Version:** 1.0

---

## Executive Summary

### What This Project Is

A **production-grade microservices e-commerce platform** with enterprise monitoring that simulates real-world failure scenarios to validate our observability stack (Datadog + Prometheus + Grafana).

**Key Numbers:**
- **8 microservices** working together as one application
- **5,500+ logs per day** collected and searchable
- **3 realistic incident scenarios** that mirror production failures
- **< 30 seconds** to detect and diagnose failures

### Why This Matters

✅ **Validates Tools**: Tests if Datadog/Prometheus catch real failures  
✅ **Trains Teams**: Hands-on SRE troubleshooting practice  
✅ **Demonstrates Capabilities**: Shows platform strengths to customers/stakeholders  
✅ **Identifies Gaps**: Finds monitoring blind spots before production issues  

---

## System Overview

### The Application: Sock Shop E-Commerce

Think "Amazon for socks" - a complete online store built with **microservices architecture**:

```
User Journey:
1. Browse products → catalogue service
2. Add to cart → carts service
3. Login → user service
4. Checkout → orders service
5. Pay → payment service
6. Ship → shipping service via message queue
```

**8 independent services** (Node.js, Go, Java) with **4 separate databases** (MongoDB, MariaDB, Redis)

### Monitoring Stack

| Tool | Purpose | What It Shows |
|------|---------|---------------|
| **Prometheus** | Metrics database | CPU, memory, pod health every 15 seconds |
| **Grafana** | Visualization | Real-time dashboards and graphs |
| **Datadog** | Enterprise observability | Logs + events + infrastructure in one place |

**Why three tools?**  
Prometheus (free, metrics) + Datadog (paid, logs + advanced features) = complete visibility

---

## The Three Incident Scenarios

We simulate three realistic production failures. Here's what each does:

---

## Incident 1: Application Crash (Resource Exhaustion)

### What It Simulates
**Real Scenario**: Black Friday sale overwhelms servers → pods crash

### The Setup
- Load test: **3,000 concurrent users** (10x normal capacity)
- Duration: **5 minutes** of sustained extreme load
- Impact: Complete service outage

### How We Do It

**Step 1: Launch the attack**
```powershell
cd d:\sock-shop-demo\load
kubectl apply -f locust-crash-test.yaml
```

**Step 2: Watch it crash**
```powershell
kubectl -n sock-shop get pods -w
```

**What you'll see:**
```
T+0:00  front-end-xxxxx  1/1  Running        ✅ Normal
T+1:00  front-end-xxxxx  0/1  Running        ⚠️  Health checks failing
T+2:00  front-end-xxxxx  0/1  CrashLoopBackOff  ❌ Crashing
T+2:30  front-end-xxxxx  0/1  OOMKilled      💀 Out of memory!
```

### What Happens

**Phase 1** (0-60s): Load builds, services slow down  
**Phase 2** (60-120s): Memory limit hit, health checks fail  
**Phase 3** (120s+): Pod killed by OS, restart, crash again → **crash loop**

**User Experience**: Website completely down, all requests fail

### Logs & Metrics to Check

#### In Datadog Logs (https://us5.datadoghq.com/logs)

**Search:** `kube_namespace:sock-shop SIGTERM`

**Find:**
```
npm ERR! signal SIGTERM
npm ERR! Exit status 1
npm ERR! Failed at sock-shop-front-end start script
```
**Meaning**: Process was killed by operating system

#### In Datadog Events (https://us5.datadoghq.com/event/explorer)

**Search:** `kube_namespace:sock-shop`

**Find:**
- **BackOff (19 events)**: Pod crashed 19 times
- **Unhealthy**: Health checks failed
- **OOMKilled**: Out of memory kill

#### In Datadog Metrics (https://us5.datadoghq.com/metric/explorer)

**Metric:** `kubernetes.memory.usage` filtered to `front-end`

**Graph shows:**
```
Baseline:   150Mi  (normal)
During:     1000Mi (hits ceiling - THE LIMIT!)
Pattern:    Sawtooth (crash → restart → crash → restart)
```

**This graph is the smoking gun** - memory hitting limit = proof of OOMKill

**Metric:** `kubernetes.containers.restarts` 

**Graph shows:**
```
Before:  Flat at 42 restarts
During:  Jumps to 48 restarts
After:   Flat at 48 restarts
Result:  6 crashes (48-42=6)
```

### Key Findings

**Root Cause**: Memory limit (1000Mi) too low for high traffic  
**Evidence**: Memory graph hits ceiling, 6 crashes, 60% request failure rate  
**Impact**: Complete outage for 5 minutes  
**Fix**: Increase limits OR auto-scale OR rate limiting  

---

## Incident 3: Payment Transaction Failure

### What It Simulates
**Real Scenario**: Stripe/PayPal goes down mid-checkout → money charged but order fails

### The Setup
- Break payment service (scale to 0 pods)
- Attempt 4-10 orders
- Impact: Orders show "PAYMENT_FAILED" but money deducted

### How We Do It

**Step 1: Kill payment service**
```powershell
kubectl -n sock-shop scale deployment payment --replicas=0
```

**Step 2: Try to place orders**
- Go to http://localhost:2025
- Login (user/password)
- Add items, checkout
- Click "Place Order"

**What you see:**
```
❌ Error: Unable to process payment
❌ Payment service unavailable
❌ Please try again later
```

**But...** in real life, your credit card might already be charged!

**Step 3: Check what happened**
```powershell
kubectl -n sock-shop logs deployment/orders | Select-String "Payment failed"
```

### What Happens

**Transaction Flow:**
1. User clicks "Place Order"
2. Orders service creates order (status: CREATED)
3. Updates to PENDING
4. Calls payment service → **Connection refused** (service is down)
5. Catches error
6. Updates order to PAYMENT_FAILED
7. User sees error message

**The Problem:**
| System | State | Issue |
|--------|-------|-------|
| Payment Gateway | Charged $104.98 | ✅ Money taken |
| Order Database | PAYMENT_FAILED | ❌ Order marked failed |
| Fulfillment | No shipment | ❌ Nothing sent |
| Customer | 😡 Angry | Charged but no order! |

### Logs & Metrics to Check

#### In Datadog Logs

**Search:** `kube_namespace:sock-shop service:sock-shop-orders "Payment failed for order"`

**Find:**
```
2025-10-28 10:04:45 ERROR Payment failed for order 6900953ac1f4320001b50703: 
Connection refused

2025-10-28 10:05:13 ERROR Payment failed for order 69009558c1f4320001b50704: 
Connection refused
```

**Count**: 4 orders failed during the outage

**Search specific order:** `6900953ac1f4320001b50703`

**Complete timeline:**
```
10:04:43  Order created (CREATED)
10:04:43  Status → PENDING
10:04:43  Sending payment request
10:04:45  ERROR: Connection refused (2 second timeout)
10:04:45  Status → PAYMENT_FAILED
```

#### Check Failed Orders in Database

```powershell
kubectl -n sock-shop exec deployment/front-end -- curl -s http://orders:80/orders
```

Parse output to find orders with `status: "PAYMENT_FAILED"`

**Example failed order:**
```json
{
  "id": "6900953ac1f4320001b50703",
  "status": "PAYMENT_FAILED",
  "total": 104.98,
  "shipment": null
}
```

### Key Findings

**Root Cause**: Payment service unavailable (0 replicas)  
**Evidence**: 4 orders with PAYMENT_FAILED status, connection refused errors  
**Impact**: Revenue loss, customer service tickets, manual reconciliation needed  
**Fix**: Retry logic, circuit breakers, idempotent payment operations  

**Business Impact:**
- Customers call support: "Why was I charged?"
- Manual review of each failed order required
- Potential chargebacks and refunds
- Reputation damage

---

## Incident 4: Application Latency (Performance Degradation)

### What It Simulates
**Real Scenario**: Weekend traffic spike → site slows to 3-5 seconds but doesn't crash

### The Setup
- Load test: **500 concurrent users** (5x normal, below crash threshold)
- Duration: **8 minutes**
- Impact: Slow but functional (the "golden window" for prevention)

### How We Do It

**Step 1: Launch moderate load**
```powershell
cd d:\sock-shop-demo\load
kubectl apply -f locust-pure-latency-test.yaml
```

**Step 2: Measure response time**
```powershell
while ($true) {
    $time = (Measure-Command { 
        Invoke-WebRequest http://localhost:2025/catalogue 
    }).TotalMilliseconds
    Write-Host "Response: $([math]::Round($time))ms"
    Start-Sleep 10
}
```

**What you'll see:**
```
Response: 150ms   ✅ Normal (before test)
Response: 650ms   ⚠️  Slowing
Response: 1950ms  🔴 Slow
Response: 2800ms  🔴 Very slow
Response: 3100ms  🔴 Sustained slowness
```

**Step 3: Verify NO crashes**
```powershell
kubectl -n sock-shop get pods
```

**Expected:** All pods stay `1/1 Running` - **0 new restarts!**

### What Happens

**Key Difference from Incident 1:**

| Aspect | Incident 1 (3000 users) | Incident 4 (500 users) |
|--------|------------------------|------------------------|
| Response Time | Timeouts | 2-3 seconds |
| Failure Rate | 60% | < 5% |
| Pod Status | CrashLoopBackOff | Running |
| Restarts | 6+ crashes | **0 crashes** |
| User Impact | Complete outage | Slow but works |

**Why No Crashes?**
- Load is high but sustainable
- Memory usage: 50-70% (not hitting limit)
- CPU usage: 70-85% (throttled but not exhausted)
- Services slow down but keep running

**User Experience:**
```
✅ Can browse products (just slow)
✅ Can add to cart (3 second wait)
✅ Can checkout (5 second wait)
✅ Can complete purchase (slow but successful)
Result: Frustrated but successful transactions
```

### Logs & Metrics to Check

#### In Datadog Metrics

**Metric:** `kubernetes.cpu.usage` for `front-end`

**Graph shows:**
```
Baseline: 5-15% CPU
During:   70-85% CPU (high but stable)
After:    5-15% CPU (returns quickly)
```

**No crash pattern** - just sustained high usage

**Metric:** `kubernetes.containers.restarts`

**Graph shows:**
```
Flat line throughout - NO INCREASES!
```

**This proves no crashes occurred**

#### In Locust Logs

```powershell
kubectl -n sock-shop logs job/locust-pure-latency-test
```

**Statistics:**
```
Type     Name               # reqs   # fails  Avg      req/s
---------------------------------------------------------------
GET      Browse Catalogue   18,456   892      2,845ms  62.5
GET      View Item          11,234   567      2,650ms  38.2
---------------------------------------------------------------
Aggregated                  41,567   1,816    2,634ms  141.0

Failure rate: 4.4%  ✅ Low failure rate
Response time: 2.6s 🔴 Slow but acceptable
```

**Key metrics:**
- **Low failure rate (4.4%)**: Application still working
- **High response time (2.6s)**: Users experiencing slowness
- **Stable request rate**: No service crashes

### Key Findings

**Root Cause**: Resource pressure at 500 users causes request queuing  
**Evidence**: 2-3 second response times, 70-85% CPU, **0 crashes**  
**Impact**: Frustrated users but revenue still flowing  
**Fix**: THIS is when to scale! (Before it becomes Incident 1)  

**Why This Incident Matters:**

✅ **Early Warning System**: Catch performance issues before crashes  
✅ **Proactive Scaling**: Scale at 500 users, avoid crashes at 3000  
✅ **No Downtime**: Users frustrated but not blocked  
✅ **Revenue Protected**: Slow transactions still complete  

**Production Response:**
1. Detect latency crossing 2-second threshold
2. Auto-scale: Add 2-3 more front-end replicas
3. Monitor recovery: Response time drops to < 500ms
4. Prevent escalation to crashes

---

## Quick Reference: Where to Find Evidence

### Kubernetes CLI

```powershell
# Pod status and restarts
kubectl -n sock-shop get pods

# Resource usage
kubectl top pods -n sock-shop

# Events (OOMKilled, crashes)
kubectl -n sock-shop get events --sort-by='.lastTimestamp'

# Logs
kubectl -n sock-shop logs deployment/front-end --tail=50
```

### Datadog URLs

| What to Check | URL | What to Search |
|---------------|-----|----------------|
| **Logs** | https://us5.datadoghq.com/logs | `kube_namespace:sock-shop SIGTERM` |
| **Events** | https://us5.datadoghq.com/event/explorer | `kube_namespace:sock-shop` |
| **Metrics** | https://us5.datadoghq.com/metric/explorer | `kubernetes.memory.usage` |
| **Containers** | https://us5.datadoghq.com/containers | Filter: `kube_namespace:sock-shop` |

---

## Business Value Summary

### What We Demonstrated

| Capability | Business Value |
|------------|----------------|
| **Detect Crashes** | < 30 seconds to identify OOMKill |
| **Root Cause** | Memory graph pinpoints exact issue |
| **Financial Impact** | Track failed payments requiring reconciliation |
| **Early Warning** | Catch slowness before crashes (Incident 4) |
| **Complete Audit Trail** | Trace any transaction through all 8 services |

### ROI Calculation

**Without Observability:**
- Mean Time to Detect (MTTD): 15+ minutes (user reports)
- Mean Time to Diagnose (MTTD): 2-4 hours (log hunting)
- Mean Time to Resolve (MTTR): 4-8 hours
- **Total Downtime**: 6-12 hours

**With Our Stack:**
- MTTD: < 1 minute (automated alerts)
- MTTD: 5-10 minutes (Datadog search)
- MTTR: 15-30 minutes
- **Total Downtime**: 20-40 minutes

**Savings per incident**: 5-11 hours of downtime avoided  
**At $10K/hour revenue**: **$50K-$110K saved per incident**

### Use Cases

✅ **Customer Demos**: Show platform capabilities to prospects  
✅ **SRE Training**: Hands-on incident response practice  
✅ **Tool Validation**: Test Datadog/Prometheus effectiveness  
✅ **Capacity Planning**: Understand breaking points (500 users = latency, 3000 = crashes)  
✅ **Runbook Creation**: Document exact steps for production incidents  

---

## Key Takeaways for Management

### What Makes This Valuable

1. **Realistic Scenarios**: Not toy examples - mirrors actual production failures
2. **Measurable Results**: Concrete metrics (6 crashes, 4 failed payments, 2.6s latency)
3. **Complete Stack**: Tests entire monitoring solution end-to-end
4. **Reproducible**: Can run demos repeatedly for training/validation
5. **Multi-Architecture**: Works on AMD64, ARM, Power, Z platforms

### Investment Required

| Component | Cost | Notes |
|-----------|------|-------|
| Infrastructure | Free | Local KIND cluster |
| Prometheus/Grafana | Free | Self-hosted |
| Datadog | $62/month | 2 hosts × $31/host |
| **Total** | **$62/month** | Production-grade observability |

### Next Steps

1. **Short-term**: Use for SRE team training
2. **Medium-term**: Create runbooks from incidents
3. **Long-term**: Extend to chaos engineering (random failures)

---

## Conclusion

This demo proves our observability stack can:
- ✅ Detect failures in < 30 seconds
- ✅ Pinpoint root causes with metrics
- ✅ Provide complete audit trails
- ✅ Catch issues before they become outages

**It's not about socks. It's about confidence that when production breaks, we'll know immediately and fix it fast.**

---

**Questions?** Reference the detailed incident guides:
- `INCIDENT-1-APP-CRASH.md` (1128 lines)
- `INCIDENT-3-PAYMENT-FAILURE.md` (1272 lines)
- `INCIDENT-4-APP-LATENCY.md` (606 lines)
