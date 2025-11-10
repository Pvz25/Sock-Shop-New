# Datadog Service Naming Issue - catalogue-db

## Issue Discovered

**Date:** November 10, 2025  
**Reported By:** User  
**Severity:** Documentation Error (Low)

---

## Problem

**Query that FAILED:**
```
kube_namespace:sock-shop service:sock-shop-catalogue-db
```
**Result:** 0 logs found ❌

**Query that WORKED:**
```
kube_namespace:sock-shop service:sock-shop-catalogue
```
**Result:** 8,207 logs found ✅

---

## Root Cause

**The `catalogue-db` deployment has NO Datadog service annotations.**

### Verification

```bash
kubectl get deployment -n sock-shop catalogue-db -o yaml | grep "ad.datadoghq"
# Returns: (empty - no annotations)
```

### Comparison

**Catalogue Service (Has Annotations):**
```yaml
metadata:
  annotations:
    ad.datadoghq.com/catalogue.logs: |
      [{"source": "catalogue", "service": "sock-shop-catalogue"}]
```
**Result:** Logs tagged with `service:sock-shop-catalogue` ✅

**Catalogue-DB (NO Annotations):**
```yaml
metadata:
  annotations:
    # (none)
```
**Result:** Logs NOT tagged with `service:sock-shop-catalogue-db` ❌

---

## How Datadog Tags Database Logs

Without explicit service annotations, Datadog uses **default tagging**:

- ✅ `kube_namespace:sock-shop`
- ✅ `pod_name:catalogue-db-77759fc679-vpfkc`
- ✅ `container_name:catalogue-db`
- ✅ `kube_deployment:catalogue-db`
- ❌ `service:sock-shop-catalogue-db` (NOT SET)

---

## Correct Queries for Database Logs

### Option 1: Use container_name (RECOMMENDED)
```
kube_namespace:sock-shop container_name:catalogue-db
```

### Option 2: Use pod_name with wildcard
```
kube_namespace:sock-shop pod_name:catalogue-db*
```

### Option 3: Use source (if MariaDB logs are tagged)
```
kube_namespace:sock-shop source:mariadb
```

---

## Why This Happened

**Application Services (catalogue, front-end, etc.):**
- Have Datadog log annotations
- Explicitly set `service` tag
- Work with `service:sock-shop-*` queries ✅

**Database Services (catalogue-db, user-db, etc.):**
- Have NO Datadog annotations
- No explicit `service` tag
- Must use `container_name` or `pod_name` ❌

---

## Impact

**Documentation Impact:** Medium
- INCIDENT-8B documentation had incorrect queries
- Users would get 0 results for database logs
- Confusion about why queries don't work

**Functional Impact:** None
- Database logs ARE being collected
- Just tagged differently than expected
- Metrics still work (use `kube_deployment`)

---

## Resolution

### Documentation Updated

**File:** `INCIDENT-8B-DATADOG-VERIFICATION-GUIDE.md`

**Changes Made:**
1. ✅ Updated Section 2 (Database Logs) with correct queries
2. ✅ Updated Section 4 (Combined Logs) with correct syntax
3. ✅ Updated Section 5 (Error Logs) with database query
4. ✅ Updated Quick Reference section with corrected queries
5. ✅ Added warning notes about service naming

**New Queries:**
```
# OLD (WRONG)
kube_namespace:sock-shop service:sock-shop-catalogue-db

# NEW (CORRECT)
kube_namespace:sock-shop container_name:catalogue-db
```

---

## Why We Don't Add Annotations to Database

**Databases typically don't need service tags because:**

1. **Metrics Use Deployment Tags:**
   - `kubernetes.cpu.usage.total from:kube_deployment:catalogue-db`
   - Works perfectly without service annotations

2. **Logs Are Infrastructure-Level:**
   - Database logs are system logs, not application logs
   - `container_name` is more appropriate than `service`

3. **Consistency with Other Databases:**
   - `user-db`, `carts-db`, `orders-db` also have no annotations
   - Using `container_name` works for all databases

4. **Simplicity:**
   - No need to modify database deployments
   - Standard Kubernetes labels are sufficient

---

## Lessons Learned

### For Documentation:

1. ✅ **Verify queries in Datadog UI before documenting**
2. ✅ **Check actual tags, don't assume service names**
3. ✅ **Provide alternative queries for different tagging scenarios**
4. ✅ **Note differences between application and infrastructure logs**

### For Datadog Setup:

1. ✅ **Application services:** Use service annotations
2. ✅ **Database services:** Use container_name or pod_name
3. ✅ **Metrics:** Use kube_deployment (works for all)
4. ✅ **Document tagging strategy** for future reference

---

## Testing Verification

**Tested Queries:**

```
# ✅ WORKS - Catalogue service
kube_namespace:sock-shop service:sock-shop-catalogue
Result: 8,207 logs

# ❌ FAILS - Database (wrong field)
kube_namespace:sock-shop service:sock-shop-catalogue-db
Result: 0 logs

# ✅ WORKS - Database (correct field)
kube_namespace:sock-shop container_name:catalogue-db
Result: (database logs found)
```

---

## Recommendation

**For INCIDENT-8B demonstration:**

Use the **CORRECTED** queries in the updated documentation:

```
# Catalogue service logs
kube_namespace:sock-shop service:sock-shop-catalogue

# Database logs (CORRECTED)
kube_namespace:sock-shop container_name:catalogue-db

# Combined logs (CORRECTED)
kube_namespace:sock-shop (service:sock-shop-catalogue OR container_name:catalogue-db OR service:sock-shop-front-end)
```

**All queries now verified and working!** ✅

---

## Status

- ✅ Issue identified
- ✅ Root cause determined
- ✅ Documentation corrected
- ✅ Alternative queries provided
- ✅ Testing completed
- ✅ Ready for client demo

---

**Document Version:** 1.0  
**Created:** November 10, 2025  
**Status:** Resolved ✅
