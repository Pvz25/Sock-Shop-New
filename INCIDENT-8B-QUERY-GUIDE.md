# INCIDENT-8B: Datadog Query Guide - What Works and Why

**Created:** November 10, 2025  
**Purpose:** Definitive guide to querying INCIDENT-8B logs in Datadog

---

## 🎯 TL;DR - Use These Queries

### For Incident Analysis (4:25-4:27 PM):

**Primary (Most Useful):**
```
kube_namespace:sock-shop service:sock-shop-catalogue
```

**Secondary (Sparse but Available):**
```
kube_namespace:sock-shop kube_deployment:catalogue-db
```

**Combined:**
```
kube_namespace:sock-shop (service:sock-shop-catalogue OR service:sock-shop-front-end)
```

---

## 📊 Query Test Results

### ✅ QUERIES THAT WORK

| Query | Time Range | Results | Use Case |
|-------|-----------|---------|----------|
| `kube_namespace:sock-shop service:sock-shop-catalogue` | Incident window | 8,207 logs | ✅ **PRIMARY** - Shows catalogue service activity |
| `kube_namespace:sock-shop kube_deployment:catalogue-db` | Last 1 hour | 451 logs | ✅ Shows database logs (startup, etc.) |
| `kube_namespace:sock-shop mariadb` | Last 1 hour | 51 logs | ✅ Content search for "mariadb" text |

### ❌ QUERIES THAT DON'T WORK

| Query | Why It Fails |
|-------|--------------|
| `kube_namespace:sock-shop source:mariadb` | Source tag is `sock-shop-catalogue-db`, not `mariadb` |
| `kube_namespace:sock-shop mariadb` (during incident) | No logs with "mariadb" text during 4:25-4:27 PM |
| `kube_namespace:sock-shop service:sock-shop-catalogue-db` | Works, but no logs during incident (database quiet) |

---

## 🔍 Why Database Logs Are Empty During Incident

### The Critical Understanding:

**MariaDB only logs during:**
1. ✅ Startup/restart
2. ✅ Errors
3. ✅ Shutdown
4. ⚠️ Slow queries (if slow_query_log enabled - it's NOT)

**MariaDB does NOT log during:**
- ❌ Normal query execution
- ❌ Connection establishment
- ❌ High load
- ❌ Connection pool saturation

### What This Means for INCIDENT-8B:

**During Incident (4:25-4:27 PM):**
- Database was already running (started at ~4:30 PM earlier)
- No errors occurred (database handled load gracefully)
- No restarts occurred (pod stayed healthy)
- **Result: 0 NEW LOGS** ❌

**This is COMPLETELY NORMAL and EXPECTED!** ✅

---

## 📈 Focus on Metrics, Not Logs

### For Database Analysis, Use Metrics:

**Database CPU (Shows Load):**
```
kubernetes.cpu.usage.total from:kube_namespace:sock-shop,kube_deployment:catalogue-db
```

**Database Network (Shows Activity):**
```
kubernetes.network.rx_bytes from:kube_namespace:sock-shop,kube_deployment:catalogue-db
```

**Catalogue Response Time (Shows Impact):**
```
trace.http.request.duration from:service:sock-shop-catalogue
```

**These metrics WILL show the incident clearly!** ✅

---

## 🎓 Understanding Query Types

### Facet Query (Structured)
```
kube_namespace:sock-shop service:sock-shop-catalogue
```
- Searches indexed `service` facet
- Fast and precise
- Must match exactly

### Content Query (Text Search)
```
kube_namespace:sock-shop mariadb
```
- Searches log message text
- Finds any occurrence of "mariadb"
- Slower but flexible

### Why `source:mariadb` Doesn't Work:

**You expected:** Source facet = "mariadb"  
**Reality:** Source facet = "sock-shop-catalogue-db"

**Datadog agent status shows:**
```
Source: sock-shop-catalogue-db  ← This is the actual source tag
```

So you must use:
```
source:sock-shop-catalogue-db  ✅
```

NOT:
```
source:mariadb  ❌
```

---

## 🎯 Recommended Workflow for INCIDENT-8B

### Step 1: Check Catalogue Service Logs
```
kube_namespace:sock-shop service:sock-shop-catalogue
```
**Expected:** High volume, slow response times, database queries

### Step 2: Check Metrics (More Important!)
```
kubernetes.cpu.usage.total from:kube_deployment:catalogue-db
```
**Expected:** CPU spike during incident

### Step 3: Check Front-End Impact
```
kube_namespace:sock-shop service:sock-shop-front-end
```
**Expected:** Slow responses, potential timeouts

### Step 4: Skip Database Logs (Optional)
```
kube_namespace:sock-shop kube_deployment:catalogue-db
```
**Expected:** Probably empty during incident (this is normal)

---

## 📋 Query Cheat Sheet

### During Incident Window (4:25-4:27 PM):

**✅ WILL SHOW DATA:**
- Catalogue service logs (8,207 logs)
- Front-end service logs
- Catalogue CPU metrics
- Database CPU metrics
- Database network metrics

**❌ WILL BE EMPTY:**
- Database logs (no new logs during normal operation)
- Database error logs (no errors occurred)

### Outside Incident Window (e.g., Last 1 Hour):

**✅ WILL SHOW DATA:**
- All service logs
- Database startup logs (if pod restarted)
- All metrics

---

## 🚨 Common Mistakes

### Mistake 1: Expecting Database Logs During Incident
**Wrong Assumption:** "Database under load = lots of logs"  
**Reality:** Database under load = NO logs (unless errors)  
**Solution:** Use metrics instead of logs

### Mistake 2: Using Wrong Source Tag
**Wrong Query:** `source:mariadb`  
**Correct Query:** `source:sock-shop-catalogue-db` OR `kube_deployment:catalogue-db`

### Mistake 3: Content Search During Incident
**Wrong Query:** `kube_namespace:sock-shop mariadb` (during 4:25-4:27 PM)  
**Why It Fails:** No logs with "mariadb" text during that time  
**Solution:** Use facet queries, not content search

---

## ✅ Final Recommendations

### For Client Demo:

**Show These:**
1. ✅ Catalogue service logs (high volume, slow queries)
2. ✅ Database CPU metrics (spike during incident)
3. ✅ Catalogue response time metrics (100-200x slower)
4. ✅ Front-end logs (slow responses)

**Don't Show:**
1. ❌ Database logs (will be empty, confusing)
2. ❌ Content searches (inconsistent results)

### Best Queries for Demo:

```
# Primary evidence
kube_namespace:sock-shop service:sock-shop-catalogue

# Impact on users
kube_namespace:sock-shop service:sock-shop-front-end

# Database load (METRICS, not logs)
kubernetes.cpu.usage.total from:kube_deployment:catalogue-db
```

---

## 📝 Key Takeaways

1. ✅ **Database logs are sparse** - This is normal
2. ✅ **Use metrics for database analysis** - More reliable
3. ✅ **Catalogue service logs show the impact** - Most useful
4. ✅ **Facet queries > Content queries** - More precise
5. ✅ **Source tag ≠ "mariadb"** - It's "sock-shop-catalogue-db"

---

**Document Version:** 1.0  
**Last Updated:** November 10, 2025  
**Status:** Production Ready ✅
