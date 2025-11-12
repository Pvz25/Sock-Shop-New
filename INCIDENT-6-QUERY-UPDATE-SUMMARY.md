# INCIDENT-6 QUERY UPDATE - BOTH OPTIONS VERIFIED

**Date:** November 11, 2025, 11:25 AM IST  
**Status:** ✅ BOTH OPTIONS VERIFIED AND DOCUMENTED

---

## ✅ BOTH QUERY FORMATS WORK!

You discovered that BOTH query formats return the same results:

### Option 1: Using `pod_name:`
```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
```

### Option 2: Using `kube_container_name:`
```
kube_namespace:sock-shop kube_container_name:payment "Payment gateway error"
```

**Both are equally valid!** ✅

---

## 🔍 KEY DIFFERENCES

| Aspect | `pod_name:` | `kube_container_name:` |
|--------|-------------|------------------------|
| **Wildcard needed?** | ✅ YES (`payment*`) | ❌ NO (`payment`) |
| **Why?** | Pod names have random suffixes | Container name is always exact |
| **Example pod name** | `payment-5fc5fd7f78-abc12` | Container: `payment` |
| **Results** | ✅ Same | ✅ Same |

---

## 📋 ALL QUERIES - BOTH OPTIONS

### Query 1: Payment Gateway Errors

**Option 1:**
```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
```

**Option 2:**
```
kube_namespace:sock-shop kube_container_name:payment "Payment gateway error"
```

---

### Query 2: Connection Refused

**Option 1:**
```
kube_namespace:sock-shop pod_name:payment* "connection refused" "stripe-mock"
```

**Option 2:**
```
kube_namespace:sock-shop kube_container_name:payment "connection refused" "stripe-mock"
```

---

### Query 3: Failed Orders

**Option 1:**
```
kube_namespace:sock-shop pod_name:orders* "PAYMENT_FAILED"
```

**Option 2:**
```
kube_namespace:sock-shop kube_container_name:orders "PAYMENT_FAILED"
```

---

### Query 4: Payment Service Health

**Option 1:**
```
kube_namespace:sock-shop pod_name:payment* ("starting on port" OR "Payment gateway:")
```

**Option 2:**
```
kube_namespace:sock-shop kube_container_name:payment ("starting on port" OR "Payment gateway:")
```

---

## 💡 WHICH ONE SHOULD YOU USE?

**Both work equally well!** Choose based on preference:

### Use `pod_name:` if:
- ✅ You're familiar with Kubernetes pod naming
- ✅ You want to see pod-level details (with hash suffix)
- ✅ You're already using `pod_name:` in other queries

### Use `kube_container_name:` if:
- ✅ You don't want to remember wildcards
- ✅ You prefer exact matches (cleaner syntax)
- ✅ You're more familiar with container names

**Pro tip:** `kube_container_name` is slightly cleaner since it doesn't need the `*` wildcard!

---

## 📁 FILES UPDATED

1. ✅ **`INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md`**
   - All queries now show BOTH options
   - Note added: "Both queries return the same results"

2. ✅ **`INCIDENT-6-CORRECTED-QUERIES.md`**
   - Quick reference updated with both formats
   - Key differences explained
   - All example queries show both options

---

## 🎯 WHAT YOU TESTED AND VERIFIED

| Query | Status | Notes |
|-------|--------|-------|
| `service:payment` | ❌ Doesn't work | Wrong tag type |
| `pod_name:payment*` | ✅ Works | Verified by you |
| `kube_container_name:payment` | ✅ Works | Verified by you |

**Conclusion:** Either `pod_name:` or `kube_container_name:` works perfectly!

---

## 📊 EXAMPLE: VIEWING IN DATADOG

### Time Range:
- **Nov 7:** 16:54-17:00 UTC (22:24-22:30 IST)
- **Nov 10:** 12:27-12:47 UTC (17:57-18:17 IST)

### Try Any of These (All Work):

```
# Short version (works because namespace+message is unique)
kube_namespace:sock-shop "Payment gateway error"

# With pod_name
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"

# With kube_container_name
kube_namespace:sock-shop kube_container_name:payment "Payment gateway error"
```

All three will show your payment gateway errors! ✅

---

## ✅ DOCUMENTATION STATUS

**Updated Files:**
- ✅ INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md (60+ pages)
- ✅ INCIDENT-6-CORRECTED-QUERIES.md (quick reference)

**Query Count:**
- ✅ 7 log queries (each with 2 format options)
- ✅ 5 metrics queries
- ✅ 2 APM queries (if enabled)

**Verification:**
- ✅ Tested by user in Datadog UI
- ✅ Both formats confirmed working
- ✅ All documentation updated

---

**Status:** 🟢 COMPLETE - Documentation reflects BOTH working query formats!

**Your contribution:** Testing and verifying `kube_container_name:` as an alternative!
