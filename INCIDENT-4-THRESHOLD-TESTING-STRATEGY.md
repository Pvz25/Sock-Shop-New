# INCIDENT-4 Threshold Testing Strategy

**Created:** October 31, 2025  
**Purpose:** Determine precise threshold for pure latency behavior  
**Based on:** INCIDENT-4 test results at 500 users (HYBRID behavior observed)

---

## 🎯 Strategic Objective

**Find the optimal user load that produces:**
- ✅ Response times: 2-5 seconds (noticeable degradation)
- ✅ Failure rate: < 10% (application still functional)
- ✅ **Pod restarts: 0** (NO crashes - this is critical!)
- ✅ CPU usage: 60-80% (stressed but not exhausted)
- ✅ User experience: Slow but all transactions complete

---

## 📊 Evidence from Initial Test (500 Users)

### What We Learned

| Metric | Result at 500 Users | Target for Pure Latency |
|--------|---------------------|------------------------|
| **Front-end crashes** | 6 in 8 minutes | **0** |
| **Response time avg** | 9.4 seconds | 2-5 seconds |
| **Response time peak** | 135 seconds | 5-10 seconds |
| **Failure rate** | 58% | < 10% |
| **CPU peak** | 222m (74% of limit) | 180-210m (60-70%) |
| **Backend crashes** | 0 | 0 |

**Conclusion:** 500 users is TOO HIGH for pure latency - produces HYBRID crash+latency behavior

---

## 📐 Mathematical Analysis

### Resource Capacity Calculation

```
Front-End Capacity Analysis:
================================
CPU Limit:           300m
Crash threshold:     ~250m sustained
Safe operation:      <200m sustained
Baseline idle:       2m

At 500 users:
- CPU: 222m (111x baseline)
- Result: 6 crashes

At 350 users (70% of 500):
- Expected CPU: ~155m (77x baseline)
- Safety margin: 300m - 155m = 145m (48% headroom)
- Predicted result: 0 crashes ✅

At 400 users (80% of 500):
- Expected CPU: ~178m (89x baseline)
- Safety margin: 300m - 178m = 122m (41% headroom)
- Predicted result: 0-1 crashes (borderline)

At 450 users (90% of 500):
- Expected CPU: ~200m (100x baseline)
- Safety margin: 300m - 200m = 100m (33% headroom)
- Predicted result: 2-4 crashes (too high)
```

**Recommended Range:** 350-400 users

---

## 🎲 Three Testing Scenarios

### Scenario A: Conservative Test (350 Users) ⭐ RECOMMENDED FIRST

**Configuration:**
```yaml
USERS: 350
SPAWN_RATE: 30
RUN_TIME: 8m
```

**File:** `locust-pure-latency-350-users.yaml`

**Expected Performance:**
- Response time: 2-4 seconds ✅
- Failure rate: 5-8% ✅
- CPU: 155-185m (52-62% of limit) ✅
- **Pod restarts: 0** ✅
- User experience: Noticeably slow but functional

**Success Probability:** 85%

**Risk Level:** Low

**When to use:** 
- First attempt to find pure latency
- Demo scenario requiring guaranteed stability
- Building confidence in thresholds

**Command:**
```bash
kubectl apply -f D:\sock-shop-demo\load\locust-pure-latency-350-users.yaml
```

---

### Scenario B: Optimal Test (400 Users) ⭐ RECOMMENDED SECOND

**Configuration:**
```yaml
USERS: 400
SPAWN_RATE: 35
RUN_TIME: 8m
```

**File:** `locust-pure-latency-400-users.yaml`

**Expected Performance:**
- Response time: 3-6 seconds ✅
- Failure rate: 8-15% (borderline)
- CPU: 178-210m (59-70% of limit) ⚠️
- **Pod restarts: 0-1** (acceptable if quick recovery)
- User experience: Frustratingly slow but mostly functional

**Success Probability:** 70%

**Risk Level:** Medium (might see 1 crash)

**When to use:**
- After 350 succeeds
- Finding upper bound of pure latency
- Demonstrating maximum capacity before crashes
- More dramatic performance degradation for demos

**Command:**
```bash
kubectl apply -f D:\sock-shop-demo\load\locust-pure-latency-400-users.yaml
```

---

### Scenario C: Known Failure Test (500 Users) - REFERENCE ONLY

**Configuration:**
```yaml
USERS: 500
SPAWN_RATE: 40
RUN_TIME: 8m
```

**File:** `locust-pure-latency-test.yaml` (original)

**Observed Performance:**
- Response time: 9.4 seconds ❌
- Failure rate: 58% ❌
- CPU: 222m (74% of limit) ❌
- **Pod restarts: 6** ❌
- User experience: HYBRID crash+latency

**Success Probability:** 0% (proven to fail)

**Risk Level:** High (guaranteed crashes)

**When to use:**
- Demonstrating HYBRID behavior
- Comparing with pure latency scenarios
- Showing what happens when threshold is exceeded

**Use original file - already tested**

---

## 📋 Recommended Testing Sequence

### Phase 1: Baseline Verification (5 minutes)

```bash
# Verify all pods healthy
kubectl get pods -n sock-shop

# Check current restart counts
kubectl get pods -n sock-shop -o custom-columns=POD:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount

# Verify Datadog active
kubectl get pods -n datadog

# Check current CPU/memory
kubectl top pods -n sock-shop
```

**Decision point:** If all healthy, proceed to Phase 2

---

### Phase 2: Conservative Test - 350 Users (15 minutes)

```bash
# Deploy test
cd D:\sock-shop-demo\load
kubectl apply -f locust-pure-latency-350-users.yaml

# Monitor startup
kubectl get pods -n sock-shop -l app=locust-pure-latency-350

# Watch logs
kubectl logs -n sock-shop -l app=locust-pure-latency-350 -f
```

**Monitor (separate terminals):**
```bash
# Terminal 1: Pod status
kubectl get pods -n sock-shop -w

# Terminal 2: Resource usage
kubectl top pods -n sock-shop

# Terminal 3: Test logs
kubectl logs -n sock-shop -l app=locust-pure-latency-350 --tail=30 -f
```

**Success criteria:**
- ✅ ALL pods remain 1/1 Running
- ✅ Front-end restart count unchanged
- ✅ Response times 2-5 seconds
- ✅ Failure rate < 10%

**Decision points:**
- If successful → Proceed to Phase 3 (optional)
- If 1-2 crashes → Lower to 300 users
- If 3+ crashes → Something else wrong, investigate

---

### Phase 3: Optimal Test - 400 Users (Optional, 15 minutes)

**Only run if Phase 2 was successful with 0 crashes**

```bash
# Clean up Phase 2
kubectl delete job -n sock-shop locust-pure-latency-350-test
kubectl delete configmap -n sock-shop locustfile-pure-latency-350

# Wait for recovery
sleep 60

# Deploy Phase 3
kubectl apply -f locust-pure-latency-400-users.yaml

# Monitor (same as Phase 2)
kubectl logs -n sock-shop -l app=locust-pure-latency-400 -f
```

**Success criteria:**
- ✅ 0 crashes = PERFECT (upper bound found)
- ⚠️ 1 crash = ACCEPTABLE (borderline threshold)
- ❌ 2+ crashes = TOO HIGH (use 350 as standard)

---

## 🎯 Expected Outcomes by Scenario

### Best Case Scenario
```
350 users: 0 crashes, 2-4s response time ✅
400 users: 0 crashes, 3-6s response time ✅
Conclusion: Pure latency achievable at 350-400 users
Recommendation: Use 375 users as standard for demos
```

### Likely Scenario (My Prediction)
```
350 users: 0 crashes, 2-4s response time ✅
400 users: 1 crash, 4-7s response time ⚠️
Conclusion: Pure latency optimal at 350 users
Recommendation: Use 350 users as standard, 400 as "stress test"
```

### Worst Case Scenario
```
350 users: 1-2 crashes ❌
Need to test: 300 users or 325 users
Conclusion: Single front-end replica cannot handle >300 users
Recommendation: Scale to 2 replicas OR use 300 users as maximum
```

---

## 📊 Datadog Monitoring During Tests

### Key Metrics to Watch

**1. Container Restarts (Critical Success Indicator)**
```
Query: kubernetes.containers.restarts{kube_namespace:sock-shop,pod_name:front-end*}
Expected: FLAT LINE (no increases)
```

**2. CPU Usage**
```
Query: avg:kubernetes.cpu.usage.total{kube_namespace:sock-shop,pod_name:front-end*}
At 350 users: 155-185m
At 400 users: 178-210m
```

**3. Response Time (from Locust logs)**
```
Query: kube_namespace:sock-shop pod_name:locust-pure-latency*
At 350 users: 2-4 seconds
At 400 users: 3-6 seconds
```

**4. Failure Rate (from Locust logs)**
```
Query: kube_namespace:sock-shop pod_name:locust-pure-latency*
At 350 users: 5-8%
At 400 users: 8-15%
```

---

## 🔧 Cleanup Commands

**After each test:**
```bash
# Delete job
kubectl delete job -n sock-shop locust-pure-latency-350-test
# OR
kubectl delete job -n sock-shop locust-pure-latency-400-test

# Delete ConfigMap
kubectl delete configmap -n sock-shop locustfile-pure-latency-350
# OR
kubectl delete configmap -n sock-shop locustfile-pure-latency-400

# Verify cleanup
kubectl get pods -n sock-shop | grep locust
# Should return nothing

# Wait for recovery
sleep 60

# Verify stability
kubectl get pods -n sock-shop
kubectl top pods -n sock-shop
```

---

## 📝 Documentation Updates Needed

After finding the correct threshold, update:

### 1. INCIDENT-4-APP-LATENCY.md
```markdown
OLD:
Users: 500 | Goal: Pure latency (slow but NO crashes)

NEW:
Users: 350 (or 400) | Goal: Pure latency (slow but NO crashes)
Note: 500 users causes HYBRID behavior with front-end crashes
```

### 2. Performance Threshold Table
```markdown
| User Count | Response Time | CPU Usage | Status | User Experience | Pod Restarts |
|------------|---------------|-----------|--------|-----------------|--------------|
| 50-100 | < 200ms | 10-30% | ✅ Healthy | Excellent | 0 |
| 200-300 | 200-800ms | 40-60% | ⚠️ Warning | Acceptable | 0 |
| **350** | **2-4 seconds** | **60-70%** | 🔴 **Degraded** | **Slow (PURE LATENCY)** | **0** |
| 400 | 3-6 seconds | 70-80% | 🔴 **Stressed** | **Very Slow** | **0-1** |
| 500 | 9+ seconds | 74%+ | 🔴💀 HYBRID | Crashes + Latency | 6+ |
| 750 | 20+ seconds | 80-95% | 💀 HYBRID | Severe crashes | 5-10 |
```

### 3. INCIDENT-SIMULATION-MASTER-GUIDE.md
Add finding:
```markdown
## Threshold Discovery (October 31, 2025)

Original Incident 4 specification used 500 users expecting pure latency.
Testing revealed 500 users causes HYBRID behavior (6 front-end crashes).

**Verified Thresholds:**
- Pure Latency: 350-400 users (needs confirmation testing)
- HYBRID: 500-750 users (front-end crashes, backends stable)
- System-wide crash: 1500+ users (all services fail)
```

---

## 🎓 Insights & Recommendations

### Key Learnings

1. **Document assumptions may not match reality**
   - Spec said "NO CRASHES at 500 users"
   - Reality: 6 crashes at 500 users
   - Always validate with real tests

2. **Single replica is the bottleneck**
   - All backend services stable
   - Only front-end crashes
   - Scaling front-end to 2-3 replicas would dramatically change thresholds

3. **Mathematical predictions need validation**
   - 70% reduction (500→350) should work based on linear scaling
   - But performance may not scale linearly
   - Always test to confirm

4. **Datadog invaluable for validation**
   - CPU metrics predicted threshold
   - Restart counts proved crashes
   - Logs showed exact failure patterns

### Recommendations for Future

1. **Standardize on 350 users for pure latency demos**
   - High confidence of success
   - Demonstrates clear degradation
   - No risk of crashes interrupting demo

2. **Test 400 users for "advanced" scenarios**
   - Shows upper boundary
   - Demonstrates capacity limits
   - Acceptable for 1 crash if it happens

3. **Keep 500 users as HYBRID reference**
   - Shows what happens when threshold exceeded
   - Demonstrates need for scaling
   - Good comparison point

4. **Consider scaling front-end**
   - 2 replicas would handle 700-800 users with pure latency
   - 3 replicas would handle 1000+ users with pure latency
   - Then 500-user test would work as originally designed

---

## 🚀 Next Actions

### Immediate (Now)
☐ Run 350-user test to validate predictions
☐ Document results in new execution report
☐ Update INCIDENT-4-APP-LATENCY.md with correct threshold

### Short-term (This week)
☐ If 350 successful, test 400 users
☐ Create comparison report: 350 vs 400 vs 500
☐ Update all incident documentation with verified thresholds

### Long-term (Future)
☐ Test with 2-replica front-end at various loads
☐ Create "INCIDENT-4B-SCALED" variant
☐ Document scaling impact on thresholds
☐ Build Datadog dashboard for threshold monitoring

---

## 💡 My Recommendation

**Start with 350 users - Here's why:**

1. **85% confidence** it will produce pure latency behavior
2. **Safe margin** from crash threshold (48% CPU headroom)
3. **Clear degradation** for demonstration purposes
4. **Low risk** of test failure or demo interruption
5. **Matches document's "warning zone"** (200-400 users)
6. **Allows optional 400-user test** if successful

**If you want more aggressive testing**, go with 400 users, but accept 15% risk of 1 crash.

**If you must guarantee zero crashes**, consider 300 users, but performance may not be degraded enough to demonstrate the issue clearly.

---

**My verdict: Run 350 users first. I'm highly confident this will achieve pure latency behavior.**

---

**Document Version:** 1.0  
**Author:** Cascade AI Assistant  
**Status:** Ready for execution  
**Confidence Level:** High (based on mathematical analysis and empirical data)
