# INCIDENT-8: Database Performance Degradation - Quick Start Guide

## 🎯 What This Demonstrates

**Client Requirement:** *"Product search slowness due to database latency or connection pool exhaustion"*

**Simulation:**
- Catalogue database (MariaDB) CPU throttled to 50m (5% of 1 core)
- Query latency increases from 50ms → 4500ms
- Product browsing becomes extremely slow
- Users experience timeouts and errors

---

## ✅ Pre-Flight Checklist

**1. Verify UI is accessible:**
```powershell
# Should already be running from health check
# If not, run:
kubectl port-forward -n sock-shop svc/front-end 2025:80
```

**2. Test baseline (BEFORE incident):**
- Open: http://localhost:2025
- Click "Catalogue" or browse products
- **Expected:** Page loads in < 1 second ⚡

**3. Verify pods healthy:**
```powershell
kubectl get pods -n sock-shop -l name=catalogue
kubectl get pods -n sock-shop -l name=catalogue-db
# Both should be Running
```

---

## 🚀 Activate Incident (30 seconds)

```powershell
.\incident-8-activate.ps1
```

**What happens:**
1. Applies severe CPU limit (50m) to catalogue-db
2. Pod restarts with new constraints
3. Database becomes CPU-throttled
4. Queries slow down dramatically

---

## 🌐 UI Verification (Your 45-Second Window)

**Open browser:** http://localhost:2025

**Test these actions:**

1. **Browse Products**
   - Click "Catalogue" in navigation
   - **Before:** Loads in <1 second
   - **During Incident:** Takes 5-10 seconds or times out ❌

2. **Refresh Page (F5)**
   - Press F5 multiple times
   - **Before:** Instant refresh
   - **During Incident:** Slow, may show errors ❌

3. **Search Products**
   - Use search bar
   - **Before:** Instant results
   - **During Incident:** Very slow or timeout ❌

4. **View Product Details**
   - Click on any product
   - **Before:** Opens immediately
   - **During Incident:** Slow loading ❌

**Expected User Experience During Incident:**
- ⏳ Long loading times (5-10 seconds)
- ❌ "Error loading products" messages
- ❌ 504 Gateway Timeout errors
- 🐌 Extremely frustrating experience
- 💔 Users would abandon the site

---

## 📊 Datadog Signals to Watch

**In Datadog UI, look for:**

1. **CPU Throttling:**
   ```
   kubernetes.cpu.usage.total{pod_name:catalogue-db*}
   → Should spike to 100% of limit (50m)
   ```

2. **CPU Limits:**
   ```
   kubernetes.cpu.limits{pod_name:catalogue-db*}
   → Shows 50m (0.05 cores) - EXTREMELY LOW
   ```

3. **Service Response Time:**
   ```
   http.request.duration{service:catalogue}
   → Increases from ~50ms to 5000ms+
   ```

4. **Error Rate:**
   ```
   http.errors{service:catalogue}
   → Increases (500/504 errors)
   ```

5. **Database Connections:**
   ```
   mysql.performance.threads_connected
   → May show connection pool exhaustion
   ```

---

## 🔧 Recovery (30 seconds)

```powershell
.\incident-8-recover.ps1
```

**What happens:**
1. Removes CPU/memory limits from catalogue-db
2. Pod restarts with unlimited resources
3. Database performance restored
4. Product browsing fast again

**Verify in UI:**
- Refresh http://localhost:2025
- Products should load instantly (<1 second) ✅
- No errors or timeouts ✅

---

## 🎓 AI SRE Learning Objectives

**This incident teaches the AI SRE agent to:**

1. **Detect Database Performance Issues:**
   - CPU throttling (usage at 100% of limit)
   - Query latency increase (P95 > 1000ms)
   - Connection pool exhaustion
   - Slow response times in dependent services

2. **Correlate Symptoms:**
   - Database CPU high → Service latency high → User errors
   - Cascade effect: DB → App → Frontend → User

3. **Root Cause Analysis:**
   - Identify resource constraints (CPU limits too low)
   - Distinguish from code issues (queries are fine, resources are the problem)
   - Recognize infrastructure vs application issues

4. **Remediation Strategy:**
   - Immediate: Increase database resources
   - Short-term: Scale database vertically
   - Long-term: Optimize queries, add read replicas, implement caching

5. **Business Impact Assessment:**
   - Product browsing = core business function
   - Slow browsing = revenue loss (users abandon site)
   - Severity: HIGH (P2) - affects all users

---

## 📋 Timeline Summary

| Time | Event | User Impact |
|------|-------|-------------|
| T+0s | Activate incident | None (pod restarting) |
| T+15s | Pod restarted with limits | None (warming up) |
| T+30s | First user request | Slow (5-10s) |
| T+60s | Sustained load | Timeouts, errors |
| T+Recovery | Remove limits | Immediate improvement |
| T+Recovery+30s | Full recovery | Fast browsing restored |

---

## 🔍 Troubleshooting

**If incident doesn't trigger:**

1. **Check pod restarted:**
   ```powershell
   kubectl get pods -n sock-shop -l name=catalogue-db
   # AGE should be < 1 minute
   ```

2. **Verify resource limits applied:**
   ```powershell
   kubectl get deployment -n sock-shop catalogue-db -o yaml | Select-String "resources:" -Context 5
   # Should show limits: cpu: 50m, memory: 128Mi
   ```

3. **Check CPU usage:**
   ```powershell
   kubectl top pod -n sock-shop -l name=catalogue-db
   # CPU should be at or near 50m (the limit)
   ```

**If UI still fast:**
- Wait 30 seconds for cache to clear
- Try browsing different product categories
- Use Ctrl+Shift+R (hard refresh) to bypass browser cache

---

## 💡 Pro Tips

1. **Best Time to Demo:**
   - After showing normal operation first
   - Contrast is dramatic and clear

2. **Emphasize to Client:**
   - This is a REAL production scenario
   - Happens during traffic spikes, flash sales
   - Silent degradation (no crash, just slow)
   - Affects revenue directly

3. **AI SRE Value Proposition:**
   - Detects issue before users complain
   - Correlates metrics across stack
   - Suggests remediation automatically
   - Predicts business impact

---

## 📞 Support

**Issue:** Incident not working  
**Check:** `kubectl get events -n sock-shop --sort-by='.lastTimestamp'`

**Issue:** UI not accessible  
**Check:** `kubectl get svc -n sock-shop front-end`

**Issue:** Recovery not working  
**Solution:** Manually delete pod: `kubectl delete pod -n sock-shop -l name=catalogue-db`

---

**Ready to proceed? You have everything you need!** 🚀
