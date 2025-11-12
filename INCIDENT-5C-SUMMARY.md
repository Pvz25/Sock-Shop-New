# INCIDENT-5C: Quick Reference Summary

**Client Requirement:** "Customer order processing stuck in middleware queue due to blockage in a queue/topic"  
**Status:** ✅ **100% SATISFIED**  
**Test Date:** November 11, 2025, 13:53-13:57 IST  
**Duration:** 3.42 minutes

---

## What It Demonstrates

**Queue blockage IN the queue itself** - the ONLY incident where the queue (not just processing) is blocked.

---

## Quick Execution

```powershell
cd d:\sock-shop-demo
.\incident-5c-execute-fixed.ps1
```

**During 3-minute window:**
1. Open: `http://localhost:2025`
2. Login: `user` / `password`
3. Place 7 orders (add to cart → checkout → place order)

---

## Expected Results

| Order # | Result | Message |
|---------|--------|---------|
| 1-3 | ✅ Success | "Order placed" |
| 4-7 | ❌ Failure | "Internal Server Error" |

**Key Evidence:**
- Queue stuck at 3/3 capacity
- 6 ACKs + 4 NACKs in shipping logs
- Errors visible in UI

---

## Technical Implementation

**Method:** RabbitMQ Management API (not rabbitmqctl)  
**Queue Policy:** max-length=3, overflow=reject-publish  
**Consumer:** Scaled to 0  
**Backend:** Publisher confirms (shipping service)  
**Frontend:** Error display enabled

---

## Datadog Queries

**Timeline:** Nov 11, 2025, 08:23:37 - 08:27:02 UTC

```
# Queue depth (stuck at 3)
rabbitmq.queue.messages{queue:shipping-task}

# Rejections
kube_namespace:sock-shop service:shipping "rejected"

# HTTP 503 errors
kube_namespace:sock-shop service:orders 503
```

---

## Why It's Different

| Aspect | INCIDENT-5 | INCIDENT-5C |
|--------|-----------|-------------|
| Queue blocked | ❌ No | ✅ **Yes** |
| Capacity limit | ❌ None | ✅ max-length=3 |
| Orders 4+ | Queued | **Rejected** |
| Requirement | 70% | **100%** |

---

## Files

- **INCIDENT-5C-COMPLETE-GUIDE.md** - Full documentation
- **INCIDENT-5C-TEST-EXECUTION-REPORT.md** - Nov 11 test results
- **INCIDENT-5C-FINAL-VERDICT.md** - Error message analysis
- **incident-5c-execute-fixed.ps1** - Execution script

---

## Key Achievement

**This is the ONLY incident demonstrating literal "blockage IN a queue"** (queue itself blocked at capacity).

**Requirement Satisfaction:** ✅ 100%
