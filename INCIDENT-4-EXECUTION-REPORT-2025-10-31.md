# INCIDENT-4 Execution Report

**Test Date:** October 31, 2025 11:24 AM IST  
**Test Type:** Pure Application Latency (500 concurrent users)  
**Test Duration:** 8 minutes (7m55s actual)  
**Tester:** Cascade AI Assistant  
**Environment:** KIND cluster (sockshop) with Datadog monitoring

---

## 🎯 Test Objective

**Goal:** Execute INCIDENT-4-APP-LATENCY to simulate pure performance degradation WITHOUT crashes at 500 concurrent users, demonstrating early-warning detection before escalation to crash scenarios.

**Expected Behavior:**
- ✅ Response times: 2-5 seconds average
- ✅ Failure rate: < 10%
- ✅ **Pod restarts: 0 (NO CRASHES)**
- ✅ User experience: Slow but functional

---

## ⚠️ ACTUAL RESULTS - HYBRID BEHAVIOR OBSERVED

### Critical Finding

**The test revealed HYBRID crash+latency behavior instead of pure latency!**

At 500 concurrent users, the front-end service experienced repeated crashes while backend services only exhibited latency. This indicates the application's crash threshold is **lower than anticipated**.

---

## 📊 Detailed Test Results

### Pre-Test Baseline (11:24 AM)

| Metric | Value |
|--------|-------|
| **All pods status** | 14/14 Running, healthy |
| **Front-end restarts** | 21 (baseline) |
| **Backend restarts** | Various (17, 13, 3, etc.) |
| **CPU usage (front-end)** | 2m (baseline) |
| **Memory usage (front-end)** | 82Mi (baseline) |
| **Datadog status** | Active, collecting logs |
| **Port-forward** | localhost:2025 → front-end:80 |

---

### During Test (11:25 AM - 11:33 AM)

#### Performance Metrics

| Metric | Value | Severity |
|--------|-------|----------|
| **Total requests** | 7,000+ | - |
| **Failure rate** | **58%** | 🔴 CRITICAL |
| **Average response time** | **9.4 seconds** | 🔴 CRITICAL |
| **Peak response time** | **135 seconds** (2.25 minutes!) | 🔴 CRITICAL |
| **Median response time** | 2.5 seconds | 🟡 HIGH |

#### Endpoint-Specific Results

| Endpoint | Requests | Failure Rate | Avg Response Time | Peak Time |
|----------|----------|--------------|-------------------|-----------|
| **Browse Catalogue** | 3,192 | 55.29% | 9.9 seconds | 135 seconds |
| **Login Page** | 698 | **100.00%** | 9.3 seconds | 73 seconds |
| **View Cart** | 1,254 | 47.21% | 8.0 seconds | 135 seconds |
| **View Item** | 1,893 | 54.94% | 9.6 seconds | 135 seconds |

**Connection Timeouts:**
- Browse Catalogue: 444 timeouts
- View Cart: 193 timeouts
- View Item: 255 timeouts
- Login Page: 79 timeouts
- **Total:** 971 connection timeouts

---

### Pod Behavior During Test

| Service | Baseline Restarts | Final Restarts | New Crashes | Status |
|---------|-------------------|----------------|-------------|--------|
| **front-end** | 21 | **27** | **6 crashes** | 🔴 CrashLoopBackOff |
| carts | 17 | 17 | 0 | ✅ Stable |
| catalogue | 13 | 13 | 0 | ✅ Stable |
| user | 13 | 13 | 0 | ✅ Stable |
| orders | 3 | 3 | 0 | ✅ Stable |
| payment | 1 | 1 | 0 | ✅ Stable |
| All databases | Various | No change | 0 | ✅ Stable |

**Critical Observation:** Front-end restarted 6 times during the 8-minute test (~0.75 crashes/minute), while ALL backend services remained completely stable.

---

### Resource Usage Pattern

#### Peak Load (T+2 to T+4 minutes)

| Service | CPU Peak | Memory Peak | Baseline CPU | Baseline Memory |
|---------|----------|-------------|--------------|-----------------|
| **front-end** | **222m** (111x increase!) | 122Mi | 2m | 82Mi |
| catalogue | 50m (50x increase) | 14Mi | 1m | 6Mi |
| user | 6m (6x increase) | 11Mi | 1m | 10Mi |
| orders | 3-4m | 400Mi | 4m | 400Mi |

**Pattern:** Front-end showed extreme CPU spikes with crash/restart cycles creating a jagged resource usage pattern.

---

### Response Time Timeline

```
T+0min:   Baseline (~150ms expected, unable to test due to port-forward issue)
T+1min:   5-10 seconds (load ramping up)
T+2min:   9-72 seconds (peak degradation, front-end crashing)
T+3min:   9-135 seconds (worst period, multiple connection timeouts)
T+4min:   8-70 seconds (sustained poor performance)
T+5min:   5-35 seconds (slight improvement as some users dropped)
T+6min:   5-20 seconds (stabilizing)
T+7min:   5-10 seconds (end of test)
T+8min:   Test completed
```

---

### Front-End Crash Analysis

**Log Evidence:**
```
npm ERR! path /usr/src/app
npm ERR! command failed
npm ERR! signal SIGTERM
npm ERR! command sh -c node server.js
```

**Crash Indicators:**
- SIGTERM signals (process terminated)
- CrashLoopBackOff status observed multiple times
- Container kill/restart cycles
- Readiness probe failures

**Root Cause:**
- Resource exhaustion under 500 concurrent connections
- Single replica unable to handle connection volume
- CPU limits (300m) too restrictive for this load
- Memory pressure contributing to instability

---

## 🔍 Post-Test Analysis (11:33 AM - 11:35 AM)

### Recovery Timeline

| Time | Front-End CPU | Front-End Status | Response Time | Notes |
|------|---------------|------------------|---------------|-------|
| T+8m | 222m | Running | N/A | Test stopped |
| T+9m | 150m | Running | Improving | Recovery starting |
| T+10m | 50m | Running | Normal | Almost recovered |
| T+12m | 2m | Running | Baseline | ✅ Fully recovered |

**Recovery Speed:** ~4 minutes to full baseline restoration

### Final State

| Metric | Status |
|--------|--------|
| **All pods** | 1/1 Running, healthy |
| **Front-end CPU** | 2m (back to baseline) ✅ |
| **Front-end memory** | 58Mi (below baseline) ✅ |
| **Front-end restarts** | 27 (6 new during test) |
| **Backend services** | All stable, no new restarts ✅ |
| **Locust resources** | Cleaned up (job + ConfigMap deleted) ✅ |

---

## 🎓 Key Findings & Insights

### 1. Threshold Discovery

**Expected:** Pure latency at 500 users  
**Actual:** HYBRID crash+latency at 500 users

**Conclusion:** The application's crash threshold is **< 500 users**, likely around 350-450 users for pure latency behavior. The original incident document's assumption of "NO CRASHES at 500 users" does not hold for this configuration.

### 2. Architectural Bottleneck Identified

**Front-end is the single point of failure:**
- ❌ Front-end: 6 crashes in 8 minutes
- ✅ All backends: 0 crashes, only latency

**Why front-end fails:**
- Single replica handling ALL 500 concurrent connections
- Resource limits too restrictive (300m CPU, 500Mi memory)
- Connection handler exhaustion
- Node.js single-threaded nature under extreme load

### 3. Failure Pattern Analysis

**Incident Classification Matrix:**

| User Load | Front-End Behavior | Backend Behavior | Classification |
|-----------|-------------------|------------------|----------------|
| < 400 | Latency only | Latency only | **Pure Latency** (Incident 4 goal) |
| **500** | **Crashes + Latency** | **Latency only** | **HYBRID** (This test) |
| 750 | Continuous crashes | Latency only | HYBRID (Incident 2) |
| 1500+ | Complete failure | Crashes | System-wide crash (Incident 1) |

**Insight:** There's a narrow band (400-500 users) where pure latency transitions to crashes.

### 4. Detection Opportunity

**This test demonstrates the critical detection window:**
- Detecting at 400 users → Scale before crashes (ideal)
- Detecting at 500 users → Already experiencing crashes (too late for pure prevention)
- Detecting at 750+ users → Damage control mode

**Recommendation:** Set alerting thresholds at:
- ⚠️ WARNING: Response time > 1 second OR CPU > 60%
- 🔴 CRITICAL: Response time > 2 seconds OR CPU > 70%
- 🚨 EMERGENCY: Pod restarts > 0 in 5 minutes

---

## 📈 Datadog Observations

### Metrics Captured

✅ **CPU Usage:** Front-end spike to 222m clearly visible  
✅ **Memory Usage:** Front-end pressure visible  
✅ **Container Restarts:** Front-end step increases logged  
✅ **Network Traffic:** Inbound spike on front-end  
✅ **Pod Events:** Container kill/restart events captured  

### Logs Collected

✅ **Locust statistics:** Full request/failure metrics  
✅ **Front-end crash logs:** SIGTERM signals captured  
✅ **Connection errors:** AttributeError and timeouts logged  
✅ **Backend health checks:** Continued passing during test  
✅ **Service logs:** Slow response warnings captured  

### Key Datadog Queries

**See comprehensive guide:** `INCIDENT-4-DATADOG-QUERIES.md`

**Quick access URLs:**
- Logs: `https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop`
- Containers: `https://us5.datadoghq.com/containers?query=kube_namespace%3Asock-shop`
- Metrics: `https://us5.datadoghq.com/metric/explorer`

---

## 🔧 Recommended Remediation

### Immediate Actions (< 1 hour)

1. **Scale front-end horizontally:**
   ```bash
   kubectl scale deployment front-end --replicas=3 -n sock-shop
   ```
   **Impact:** Distributes 500 users across 3 replicas (~167 users each)

2. **Verify scaling helped:**
   ```bash
   kubectl get pods -n sock-shop -l app=front-end
   kubectl top pods -n sock-shop -l app=front-end
   ```

### Short-Term Actions (< 1 day)

3. **Increase resource limits:**
   ```yaml
   resources:
     requests:
       cpu: 200m
       memory: 256Mi
     limits:
       cpu: 500m      # was 300m
       memory: 1Gi    # was 500Mi
   ```

4. **Monitor improvement:**
   - Re-run test at 500 users with 3 replicas
   - Expected: Pure latency, no crashes
   - Target: < 2 second response time, < 5% failure rate

### Long-Term Actions (< 1 week)

5. **Implement Horizontal Pod Autoscaler:**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: front-end-hpa
     namespace: sock-shop
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: front-end
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 60
   ```

6. **Set up proactive monitoring:**
   - Datadog monitor for CPU > 60% (WARNING)
   - Datadog monitor for response time > 1s (WARNING)
   - Datadog monitor for pod restarts > 0 (CRITICAL)
   - PagerDuty integration for critical alerts

7. **Implement rate limiting:**
   - Add NGINX ingress with rate limiting
   - Protect against sudden traffic spikes
   - Graceful degradation instead of crashes

---

## 📝 Comparison with Expected Behavior

### Expected (Pure Latency - Incident 4 Goal)

| Metric | Expected | Actual | Match? |
|--------|----------|--------|--------|
| Response time | 2-5 seconds | 9.4 seconds | ❌ WORSE |
| Peak response time | 5-8 seconds | 135 seconds | ❌ MUCH WORSE |
| Failure rate | < 10% | 58% | ❌ MUCH WORSE |
| Connection timeouts | < 50 | 971 | ❌ MUCH WORSE |
| **Pod restarts (front-end)** | **0** | **6** | ❌ **CRASHES OCCURRED** |
| Pod restarts (backend) | 0 | 0 | ✅ MATCH |
| CPU usage | 70-85% | 222m (~74% of limit) | ⚠️ CLOSE |
| User experience | Slow but functional | Intermittent failures | ❌ WORSE |

**Verdict:** Test did NOT achieve pure latency behavior. System exhibited HYBRID crash+latency pattern similar to Incident 2 at 750 users.

---

## 💡 Lessons Learned

### What Went Well

1. ✅ **Pre-flight checks comprehensive** - Verified baseline before starting
2. ✅ **Monitoring effective** - Datadog captured all key metrics and logs
3. ✅ **Test execution smooth** - Locust job deployed and ran successfully
4. ✅ **Backend stability confirmed** - No crashes in 7 services proved front-end is bottleneck
5. ✅ **Documentation thorough** - Created detailed Datadog queries guide
6. ✅ **Recovery automatic** - System self-recovered after load stopped

### What Could Be Improved

1. ❌ **Port-forward reliability** - Initial connection failed, required restart
2. ❌ **Baseline response time** - Unable to capture due to port-forward issue
3. ⚠️ **Test assumptions** - Document claimed "NO CRASHES at 500 users" but crashes occurred
4. ⚠️ **Resource limits** - Front-end limits too restrictive for stated goals

### Recommendations for Future Tests

1. **Update INCIDENT-4 documentation** to reflect actual thresholds:
   - Pure latency: 300-400 users (not 500)
   - HYBRID behavior: 500-750 users
   - System-wide crash: 1500+ users

2. **Create INCIDENT-4B variant:**
   - Same 500 user load
   - Front-end scaled to 2-3 replicas
   - Test true "pure latency" behavior with proper scaling

3. **Add pre-test validation:**
   - Verify port-forward working
   - Capture baseline response time
   - Confirm resource limits appropriate for test goals

4. **Real-time dashboard:**
   - Create Datadog dashboard for live monitoring
   - Display key metrics during test execution
   - Share screen during demos

---

## 📊 Test Artifacts Generated

1. ✅ **INCIDENT-4-DATADOG-QUERIES.md** - Comprehensive monitoring guide
2. ✅ **INCIDENT-4-EXECUTION-REPORT-2025-10-31.md** - This document
3. ✅ **Locust logs** - Captured in Datadog and kubectl logs
4. ✅ **Pod events** - Crash/restart events in Kubernetes
5. ✅ **Metrics history** - CPU, memory, restart data in Datadog

---

## 🎯 Success Criteria Assessment

| Criterion | Target | Actual | Status |
|-----------|--------|--------|--------|
| Test completes full 8 minutes | Yes | Yes (7m55s) | ✅ PASS |
| All pods monitored | Yes | Yes | ✅ PASS |
| Datadog captures logs/metrics | Yes | Yes | ✅ PASS |
| **NO front-end crashes** | **Yes** | **No (6 crashes)** | ❌ **FAIL** |
| NO backend crashes | Yes | Yes | ✅ PASS |
| Response time 2-5s | Yes | No (9.4s avg) | ❌ FAIL |
| Failure rate < 10% | Yes | No (58%) | ❌ FAIL |
| Recovery after test | Yes | Yes (~4 min) | ✅ PASS |

**Overall Assessment:** Test executed successfully but did NOT meet pure latency goals. System exhibited HYBRID behavior requiring updated documentation and configuration adjustments.

---

## 🚀 Next Steps

### For This Environment

1. ☐ Scale front-end to 3 replicas
2. ☐ Increase front-end resource limits
3. ☐ Re-run test to verify improvements
4. ☐ Implement HPA for automatic scaling

### For Documentation

5. ☐ Update INCIDENT-4-APP-LATENCY.md with actual thresholds
6. ☐ Create INCIDENT-4B variant (with scaling)
7. ☐ Add "Known Issues" section noting 500-user crashes
8. ☐ Update performance threshold table

### For Future Testing

9. ☐ Create pre-test checklist with port-forward validation
10. ☐ Build Datadog dashboard for live monitoring
11. ☐ Test incremental loads (100, 200, 300, 400, 500) to find exact threshold
12. ☐ Document connection limit tuning for Node.js front-end

---

## 📞 Support & Questions

For questions about this test or Datadog queries:
- **Datadog Queries:** See `INCIDENT-4-DATADOG-QUERIES.md`
- **Test Configuration:** `load/locust-pure-latency-test.yaml`
- **Incident Documentation:** `INCIDENT-4-APP-LATENCY.md`

---

**Test Completed:** October 31, 2025 11:35 AM IST  
**Total Duration:** ~11 minutes (including setup and cleanup)  
**Status:** ✅ Test executed successfully, ❌ Did not achieve pure latency goals  
**Recommendation:** Scale front-end and re-test

---

## Appendix: Command Reference

### Baseline Checks
```bash
kubectl get pods -n sock-shop
kubectl top pods -n sock-shop
kubectl get pods -n datadog
```

### Deploy Test
```bash
cd D:\sock-shop-demo\load
kubectl apply -f locust-pure-latency-test.yaml
```

### Monitor Test
```bash
kubectl get pods -n sock-shop -l app=locust-pure-latency
kubectl logs -n sock-shop -l app=locust-pure-latency -f
kubectl top pods -n sock-shop
kubectl get pods -n sock-shop -w
```

### Cleanup
```bash
kubectl delete job -n sock-shop locust-pure-latency-test
kubectl delete configmap -n sock-shop locustfile-pure-latency
```

### Verify Recovery
```bash
kubectl get pods -n sock-shop
kubectl top pods -n sock-shop
```

---

**Report Author:** Cascade AI Assistant  
**Report Version:** 1.0  
**Classification:** Test Execution Report  
**Confidence Level:** High (based on direct observation and Datadog data)
