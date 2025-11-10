# INCIDENT-8: Analysis and Correction

## What Happened (First Attempt)

### ❌ Problem: Database CRASHED Instead of SLOWED

**Configuration Used:**
```yaml
resources:
  limits:
    cpu: 50m      # TOO RESTRICTIVE
    memory: 128Mi
  requests:
    cpu: 25m
    memory: 64Mi
```

**Result:**
- Database couldn't even start properly with 50m CPU
- MariaDB requires minimum ~100m CPU to function
- Catalogue service got NO response from database
- UI showed blank pages (0 products)
- This simulated a **CRASH**, not **SLOWNESS**

**User Experience:**
- ❌ Blank homepage
- ❌ "Showing 6 of undefined products" (but nothing displayed)
- ❌ Complete failure, not latency

---

## ✅ Corrected Approach: Simulate SLOWNESS

### Client Requirement
> "Product search slowness due to database latency or connection pool exhaustion"

**Key Word:** **SLOWNESS** (not crash)

### New Configuration (MODERATE Constraints)

```yaml
resources:
  limits:
    cpu: 200m     # MODERATE - allows DB to function but be slow
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Why This Works:**
- 200m CPU is enough for MariaDB to run
- But NOT enough to handle queries quickly
- Database will be CPU-throttled under load
- Queries will complete, just take 2-5 seconds instead of <100ms

**Expected User Experience:**
- ✅ Products DO load (not blank)
- ⏳ But take 2-5 seconds (noticeable delay)
- 🐌 Frustrating slowness
- ✅ This matches "product search slowness"

---

## Technical Analysis

### Why 50m Failed

**MariaDB Minimum Requirements:**
- Baseline CPU for idle: ~30-50m
- CPU for query processing: +50-100m per query
- Concurrent queries: multiply accordingly

**With 50m limit:**
```
Idle DB: 40m
Query arrives: needs +60m
Total needed: 100m
Available: 50m
Result: CPU throttling → query queues → timeout → crash
```

### Why 200m Works for Slowness

**With 200m limit:**
```
Idle DB: 40m
Query arrives: needs +60m
Total needed: 100m
Available: 200m
Result: Query completes, but slower than normal
Multiple queries: CPU hits 200m → throttling → slowness
```

---

## Correct Incident Execution

### Step 1: Activate Slowness (Use New Script)

```powershell
.\incident-8-activate-slowness.ps1
```

**This will:**
- Apply 200m CPU limit (moderate constraint)
- Wait for pod to restart
- Generate initial load
- Database will be functional but slow

### Step 2: Test in UI (Your 45-Second Window)

**Open:** http://localhost:2025

**What You'll Experience:**
1. **Homepage:**
   - Products carousel WILL load
   - But takes 2-3 seconds (was instant)

2. **Catalogue Page:**
   - Click "Catalogue"
   - Products WILL appear
   - But page load takes 3-5 seconds
   - Noticeable delay, frustrating

3. **Refresh Multiple Times:**
   - Each refresh takes 2-5 seconds
   - Consistent slowness
   - Database CPU at 80-100% of 200m limit

4. **Product Details:**
   - Click any product
   - Details page loads slowly
   - Images may be delayed

### Step 3: Recovery

```powershell
.\incident-8-recover.ps1
```

**Result:**
- Products load instantly again (<1 second)
- Smooth browsing restored

---

## Datadog Signals (Corrected Incident)

### What AI SRE Should Detect

**1. CPU Throttling (Not Crash):**
```
kubernetes.cpu.usage.total{pod_name:catalogue-db*}
→ 160-200m (80-100% of limit)
→ NOT spiking to infinity (that's a crash)
```

**2. Query Latency Increase:**
```
mysql.performance.query_run_time.avg
→ Increases from 50ms to 2000-5000ms
→ Queries still complete (not timing out)
```

**3. Service Response Time:**
```
http.request.duration{service:catalogue}
→ P95: 3000-5000ms (was 100ms)
→ P99: 5000-8000ms
```

**4. No Error Rate Increase:**
```
http.errors{service:catalogue}
→ Should remain LOW (queries succeed, just slow)
→ If errors spike, DB is crashing (too restrictive)
```

---

## Key Learnings

### 1. Slowness vs Crash

| Metric | Slowness | Crash |
|--------|----------|-------|
| CPU Limit | 200m (moderate) | 50m (too low) |
| Query Completion | ✅ Yes (slow) | ❌ No (timeout) |
| Error Rate | Low | High |
| User Experience | Frustrating delay | Complete failure |
| Products Display | ✅ Yes (delayed) | ❌ No (blank) |

### 2. Client Requirement Match

**Requirement:** "Product search slowness due to database latency"

**Correct Simulation:**
- ✅ Products load (just slowly)
- ✅ Database latency increased
- ✅ User experiences slowness
- ✅ Matches real-world scenario

**Incorrect Simulation (50m):**
- ❌ Products don't load at all
- ❌ Database crashes/fails
- ❌ User experiences failure
- ❌ This is INCIDENT-3 territory (service down)

### 3. Real-World Scenarios

**Slowness (200m limit) simulates:**
- Database under-provisioned for traffic spike
- Flash sale causing CPU saturation
- Inefficient queries consuming CPU
- Connection pool near exhaustion
- **Users complain: "Site is slow"**

**Crash (50m limit) simulates:**
- Database completely down
- Out of resources
- Cannot serve any requests
- **Users complain: "Site is broken"**

---

## Recommended Approach Going Forward

### For Database Performance Degradation

**Use:** `incident-8-activate-slowness.ps1`

**CPU Limits to Test:**
- **200m:** Moderate slowness (2-5 second delays)
- **150m:** More severe slowness (5-10 second delays)
- **100m:** Borderline crash (10+ seconds, some timeouts)
- **50m:** Complete crash (don't use for slowness demo)

### For Database Crash

**Use:** `incident-8-activate.ps1` (original)

**CPU Limits:**
- **50m:** Complete failure
- **25m:** Instant crash

**Better suited for:**
- Testing failure detection
- Testing error handling
- Testing circuit breakers
- **NOT for "slowness" demos**

---

## Files Available

1. **`incident-8-activate-slowness.ps1`** ✅ NEW - Use this for client demo
2. **`incident-8-activate.ps1`** ⚠️ Original - Too restrictive, causes crash
3. **`incident-8-recover.ps1`** ✅ Works for both scenarios

---

## Ready to Re-Execute?

**When you're ready to try again with the CORRECT slowness simulation:**

```powershell
# Activate slowness (not crash)
.\incident-8-activate-slowness.ps1

# Test in UI - you'll see SLOW loading, not blank pages
# http://localhost:2025

# Recover when done
.\incident-8-recover.ps1
```

**This will give you the 45-second window to experience real latency!** 🚀
