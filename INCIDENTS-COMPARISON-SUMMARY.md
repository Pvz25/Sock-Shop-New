# Incident Scenarios - Quick Comparison Guide

## At-a-Glance Comparison

| Aspect | Incident 1: Crash | Incident 3: Payment Failure | Incident 4: Latency |
|--------|-------------------|----------------------------|---------------------|
| **Severity** | 💀 Critical (P1) | 🔴 Critical (P1) | ⚠️  High (P2) |
| **User Load** | 3,000 users | Normal load | 500 users |
| **Duration** | 5 minutes | 10 minutes | 8 minutes |
| **User Impact** | Complete outage | Can't checkout | Slow but functional |
| **Pod Crashes** | Yes (6 times) | No | **No** |
| **Root Cause** | Memory exhaustion | Payment service down | CPU throttling |
| **Response Time** | Timeouts | Normal until checkout fails | 2-5 seconds |
| **Failure Rate** | 60% | 100% for checkouts | < 5% |
| **Recovery Time** | 2-3 minutes | Instant (restart service) | 30-60 seconds |

---

## Incident Progression Timelines

### Incident 1: Application Crash
```
T+0:00  ✅ Normal state (150ms response, 5% CPU, 150Mi memory)
T+0:30  ⚠️  Load building (500ms response, 40% CPU, 400Mi memory)
T+1:00  🔴 Near limits (2s response, 90% CPU, 850Mi memory)
T+1:30  💀 Health checks fail (5s response, 100% CPU, 1000Mi memory - LIMIT!)
T+2:00  💀 First OOMKill (pod terminated, Exit Code 137)
T+2:30  💀 Crash loop (restart → immediate crash → restart)
T+5:00  🛑 Load stops
T+7:00  ✅ Recovered (pods stable, 1/1 Running)
```

### Incident 3: Payment Transaction Failure
```
T+0:00  ✅ Normal operations
T+0:00  🔧 Scale payment to 0 (simulate outage)
T+0:30  ❌ First order attempt → PAYMENT_FAILED
T+1:00  ❌ Second order → PAYMENT_FAILED
T+5:00  ❌ Fourth order → PAYMENT_FAILED
T+10:00 🔧 Restore payment service (scale to 1)
T+10:30 ✅ First successful order post-recovery
```

### Incident 4: Application Latency
```
T+0:00  ✅ Normal (150ms response, 10% CPU)
T+1:00  ⚠️  Slowing (650ms response, 40% CPU)
T+2:00  🔴 Slow (1,950ms response, 70% CPU)
T+3:00  🔴 Very slow (2,800ms response, 80% CPU)
T+4-8:00 🔴 Sustained slowness (2.5-3.5s, 70-85% CPU)
         ✅ BUT: All pods stay Running (0 crashes!)
T+8:00  🛑 Load stops
T+8:30  ✅ Recovered (< 300ms response, 10% CPU)
```

---

## Key Metrics During Each Incident

### Incident 1: Application Crash

| Metric | Baseline | Peak | Critical Threshold |
|--------|----------|------|-------------------|
| **Memory** | 150Mi | **1000Mi** (limit) | 1000Mi = OOMKill |
| **CPU** | 8m | **300m** (limit) | 300m = throttling |
| **Response Time** | 150ms | Timeout | > 5s = unusable |
| **Failure Rate** | < 1% | **60%** | > 50% = outage |
| **Pod Restarts** | 42 | **48** (+6 crashes) | Any increase = problem |

**Smoking Gun**: Memory graph hits ceiling at exactly 1000Mi → sawtooth pattern (crash/restart cycles)

### Incident 3: Payment Transaction Failure

| Metric | Normal | During Incident |
|--------|--------|-----------------|
| **Payment Pods** | 1 pod Running | **0 pods** (scaled down) |
| **Failed Orders** | 0 | **4 orders** with PAYMENT_FAILED |
| **Connection Errors** | 0 | 4 "Connection refused" |
| **Order Creation** | Success | ✅ Order created but... |
| **Payment Processing** | Success | ❌ Connection timeout (2s) |
| **Final Status** | PAID | **PAYMENT_FAILED** |

**Smoking Gun**: "Connection refused" errors + orders with PAYMENT_FAILED status in database

### Incident 4: Application Latency

| Metric | Baseline | During Incident | Incident 1 (Comparison) |
|--------|----------|-----------------|------------------------|
| **Response Time** | 150ms | **2,500-3,500ms** | Timeout |
| **CPU** | 5-15% | **70-85%** | 100% (throttled) |
| **Memory** | 20-40% | **50-70%** | 100% (OOMKilled) |
| **Failure Rate** | < 1% | **< 5%** | 60% |
| **Pod Restarts** | 0 | **0** ✅ | 6+ crashes |

**Smoking Gun**: Flat restart count graph (no crashes) + high CPU (70-85%) + slow response times

---

## Evidence Collection Checklist

### For Incident 1 (Crash)

**Kubernetes:**
- [ ] `kubectl get pods` → Restart count increased (e.g., 42 → 48)
- [ ] `kubectl get events` → OOMKilled, BackOff, Unhealthy events
- [ ] `kubectl describe pod` → Last State: OOMKilled, Exit Code: 137

**Datadog Logs:**
- [ ] Search: `SIGTERM` → npm crash errors
- [ ] Search: `Connection refused` → service unavailability
- [ ] Search: `status:error` → error spike during incident window

**Datadog Events:**
- [ ] BackOff events (e.g., "19 BackOff")
- [ ] Unhealthy warnings (health check failures)
- [ ] Killing events (pod terminations)

**Datadog Metrics:**
- [ ] `kubernetes.memory.usage` → Spikes to 1000Mi (limit)
- [ ] `kubernetes.cpu.usage` → Plateaus at 300m (limit)
- [ ] `kubernetes.containers.restarts` → Jump from 42 → 48

**Locust:**
- [ ] Test logs → 60% failure rate

### For Incident 3 (Payment Failure)

**Kubernetes:**
- [ ] `kubectl get pods -l name=payment` → No pods (0/0)
- [ ] `kubectl logs deployment/orders` → "Payment failed" errors

**Datadog Logs:**
- [ ] Search: `"Payment failed for order"` → 4 ERROR logs
- [ ] Search: `"Connection refused"` → Payment connection failures
- [ ] Search specific order ID → Complete transaction timeline

**Database Query:**
- [ ] Query orders service → Find orders with `status: PAYMENT_FAILED`
- [ ] Count failed orders → Should match log count (4)

**Timeline:**
- [ ] Order created (CREATED) → PENDING → Payment call → Connection refused → PAYMENT_FAILED

### For Incident 4 (Latency)

**Kubernetes:**
- [ ] `kubectl get pods` → All remain 1/1 Running (0 new restarts) ✅
- [ ] `kubectl top pods` → CPU 70-85%, Memory 50-70%

**Datadog Metrics:**
- [ ] `kubernetes.cpu.usage` → High (70-85%) but stable
- [ ] `kubernetes.memory.usage` → Elevated (50-70%) but below limit
- [ ] `kubernetes.containers.restarts` → **FLAT LINE** (no crashes)

**Response Time Test:**
- [ ] Manual curl/Invoke-WebRequest → 2-5 second responses
- [ ] Locust stats → Avg 2,634ms, failure rate 4.4%

**Key Evidence:**
- [ ] NO new restarts ✅
- [ ] NO CrashLoopBackOff ✅
- [ ] NO OOMKilled events ✅
- [ ] But slow response times 🔴

---

## Datadog Query Cheat Sheet

### Incident 1: Crash

```
Logs:
- kube_namespace:sock-shop SIGTERM
- kube_namespace:sock-shop "Connection refused"
- kube_namespace:sock-shop service:front-end status:error

Events:
- kube_namespace:sock-shop

Metrics:
- kubernetes.memory.usage (filter: pod_name:front-end*)
- kubernetes.cpu.usage (filter: pod_name:front-end*)
- kubernetes.containers.restarts (filter: pod_name:front-end*)
```

### Incident 3: Payment Failure

```
Logs:
- kube_namespace:sock-shop service:sock-shop-orders "Payment failed for order"
- kube_namespace:sock-shop "6900953ac1f4320001b50703" (specific order)
- kube_namespace:sock-shop service:sock-shop-orders "Connection refused"
- kube_namespace:sock-shop service:sock-shop-payment (should be empty during outage)

Check Database:
kubectl -n sock-shop exec deployment/front-end -- curl -s http://orders:80/orders
(Parse JSON for status: "PAYMENT_FAILED")
```

### Incident 4: Latency

```
Logs:
- kube_namespace:sock-shop service:locust-pure-latency

Metrics:
- kubernetes.cpu.usage (filter: kube_namespace:sock-shop)
- kubernetes.memory.usage (filter: kube_namespace:sock-shop)
- kubernetes.containers.restarts (filter: kube_namespace:sock-shop)
  → Should show FLAT line (no increases)

Response Time:
Measure-Command { Invoke-WebRequest http://localhost:2025/catalogue }
→ Should be 2000-5000ms during incident
```

---

## Recovery Procedures

### Incident 1: Crash

```powershell
# Stop load
kubectl delete job locust-crash-test -n sock-shop

# Wait for self-healing (2-3 minutes)
kubectl get pods -n sock-shop -w

# Verify recovery
kubectl get pods -n sock-shop  # All 1/1 Running
kubectl top pods -n sock-shop  # CPU/Memory back to baseline
```

### Incident 3: Payment Failure

```powershell
# Restore payment service
kubectl scale deployment payment --replicas=1 -n sock-shop

# Verify payment is up (15-30 seconds)
kubectl get pods -l name=payment -n sock-shop

# Test payment health
kubectl run test-curl --rm -it --image=curlimages/curl -- curl http://payment:80/health

# Test order placement via UI
# Should succeed immediately
```

### Incident 4: Latency

```powershell
# Stop load
kubectl delete job locust-pure-latency-test -n sock-shop

# Monitor response time recovery (30-60 seconds)
Measure-Command { Invoke-WebRequest http://localhost:2025/catalogue }

# Verify pods stayed healthy
kubectl get pods -n sock-shop  # Should show NO new restarts

# Check resources returned to baseline
kubectl top pods -n sock-shop  # CPU < 20%, Memory < 300Mi
```

---

## When to Use Each Incident Scenario

### Incident 1: Application Crash
**Use for:**
- Testing autoscaling responses (HPA)
- Validating resource limit configurations
- Training: "Complete outage - all hands on deck"
- Demonstrating OOMKill detection
- Testing alerting for critical failures

**Audience:**
- SRE teams (incident commander training)
- Platform teams (capacity planning)
- Management (business impact of outages)

### Incident 3: Payment Transaction Failure
**Use for:**
- Testing distributed transaction handling
- Validating retry logic and circuit breakers
- Training: "Data inconsistency - financial impact"
- Demonstrating log correlation across services
- Testing runbook for payment gateway outages

**Audience:**
- Backend developers (transaction design)
- Finance teams (reconciliation procedures)
- Customer support (handling complaints)
- Compliance (audit trail verification)

### Incident 4: Application Latency
**Use for:**
- Testing early warning alerting
- Validating performance thresholds
- Training: "Proactive scaling before crashes"
- Demonstrating the difference between slowness and failure
- Testing capacity planning decisions

**Audience:**
- SRE teams (proactive scaling)
- Product teams (user experience impact)
- Management (preventing revenue loss)

---

## Common Pitfalls & Solutions

### Pitfall 1: "I don't see OOMKilled in Datadog Logs"
**Solution**: OOMKilled is a Kubernetes **EVENT**, not a log. Check:
1. Datadog **Event Explorer** (not Logs)
2. `kubectl get events` directly
3. `kubectl describe pod` → Last State section

### Pitfall 2: "No logs showing in Datadog"
**Solution**: Check time range
1. Set "Past 1 Hour" or "Past 4 Hours"
2. Ensure test ran WITHIN selected time window
3. Verify Datadog agent: `kubectl exec datadog-agent-xxx -- agent status`

### Pitfall 3: "Incident 4 shows crashes"
**Problem**: Load too high (> 500 users)
**Solution**: 
- Verify YAML uses 500 users (not 750 or 3000)
- Check: `kubectl get pods` → Restart count should NOT increase
- If crashes: You're running Incident 2 (750 users), not Incident 4

### Pitfall 4: "Can't find order IDs in Datadog"
**Solution**: 
1. Correct service name is `sock-shop-orders` (not `orders`)
2. Use exact search: `"6900953ac1f4320001b50703"` (with quotes)
3. Expand time range to include test execution window

---

## Quick Reference: File Locations

| File | Purpose | Line Count |
|------|---------|-----------|
| `INCIDENT-1-APP-CRASH.md` | Complete crash scenario guide | 1,128 lines |
| `INCIDENT-3-PAYMENT-FAILURE.md` | Payment failure scenario | 1,272 lines |
| `INCIDENT-4-APP-LATENCY.md` | Latency scenario | 606 lines |
| `MANAGER-PRESENTATION-GUIDE.md` | This document | Manager-friendly summary |
| `COMPLETE-SETUP-GUIDE.md` | Full environment setup | Infrastructure guide |
| `SOCK-SHOP-COMPLETE-DEMO-GUIDE.md` | Live demo script | 30-45 min presentation |

---

## Summary: The Three Failure Modes

```
┌─────────────────────────────────────────────────────────────┐
│  INCIDENT 4 (500 users)                                     │
│  ⚠️  EARLY WARNING - Slow but functional                    │
│  → Detection window for proactive scaling                   │
│  → Prevent escalation to crashes                            │
│  → Best time to act!                                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Traffic increases
                            │ No action taken
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  INCIDENT 2 (750 users) - Not covered in this guide         │
│  🔴 HYBRID - Frontend crashes + backend latency             │
│  → Intermittent availability                                │
│  → Damage control mode                                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Traffic continues to grow
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  INCIDENT 1 (3000 users)                                    │
│  💀 COMPLETE OUTAGE - System-wide crash                     │
│  → All services down                                        │
│  → Too late for prevention                                  │
│  → Full incident response required                          │
└─────────────────────────────────────────────────────────────┘
```

**Key Lesson**: Catch issues at Incident 4 stage (latency) to prevent Incident 1 (crashes)!

---

**Pro Tip for Presentations:**
Start with Incident 4 (latency) → "This is when we want to act"
Then show Incident 1 (crash) → "This is what happens if we don't"
Finish with Incident 3 (payment) → "This is why distributed systems need observability"
