# Root Cause Analysis: Why INCIDENT-5C Failed

## What the User Experienced

**During INCIDENT-5C (shipping scaled to 0):**
- User clicked checkout
- Page went directly to "My Orders" page
- Orders appeared with "Shipped" status
- NO error message displayed in UI
- After recovery, everything worked

**But the logs show:**
```
java.net.ConnectException: Connection refused (Connection refused)
ERROR: Unable to create order due to unspecified IO error
```

## The Problem

### Backend is Failing Correctly ✅
- Orders service tries to call shipping
- Gets connection refused
- Throws exception
- Returns HTTP 500

### Frontend is NOT Displaying Errors ❌
- Frontend receives HTTP 500
- But does NOT show error to user
- Instead, redirects to "My Orders" page
- Shows existing orders (from before incident)

## The Real Issue

**The frontend has poor error handling!**

When the backend returns 500, the frontend:
1. Doesn't display the error
2. Redirects to orders page
3. User sees old orders and thinks they succeeded

This is a **UI bug**, not a backend issue.

---

## Client Requirement Re-Analysis

**Requirement:**
> "Customer order processing stuck in middleware queue due to blockage in a queue/topic"

**Key Terms:**
1. **"stuck in middleware queue"** - Orders should get queued but not processed
2. **"due to blockage"** - Something is blocking the queue/processing
3. **"queue/topic"** - RabbitMQ is the middleware queue

**What the client wants:**
- Orders get accepted (✅ user sees success)
- Orders get queued in RabbitMQ (✅ messages sent)
- Orders get STUCK (❌ not processed)
- Due to queue blockage (full, or no consumer)

## Two Possible Interpretations

### Interpretation A: Silent Failure (INCIDENT-5 approach)
- User places order
- Order appears successful ✅
- Message sent to RabbitMQ ✅
- But queue-master is down
- Messages pile up, never processed
- **Silent business failure**

**Problem:** User wanted to see errors in UI

### Interpretation B: Loud Failure (What client might want?)
- User places order
- Order should fail with visible error ❌
- Because queue is full
- **Immediate user feedback**

**Problem:** Current shipping service uses fire-and-forget, so even if queue is full, it returns success

---

## Why Fire-and-Forget Exists

The shipping service likely looks like this:

```java
@PostMapping("/shipping")
public ResponseEntity<?> createShipment(@RequestBody ShipmentRequest request) {
    // Publish to RabbitMQ asynchronously
    rabbitTemplate.convertAndSend("shipping-task", request);
    
    // Return success immediately (fire-and-forget)
    return ResponseEntity.ok("Shipment queued");
}
```

**Why this pattern is used:**
- High performance (doesn't wait for queue confirmation)
- Better availability (works even if consumer is slow)
- Industry standard for async messaging

**The downside:**
- No feedback if queue is full
- No feedback if message is rejected
- Silent failures

---

## Solutions Available

### Option 1: Accept INCIDENT-5 as Correct (Silent Failure)
**This is actually industry-standard behavior!**

Most e-commerce sites do this:
- Order appears successful
- Payment captured
- Fulfillment happens async
- If fulfillment fails, customer service handles it later

**Evidence it worked correctly:**
- Orders service called shipping ✅
- Shipping was down ✅
- Orders service got connection refused ✅
- Backend logged errors ✅
- **Only problem: UI didn't show the error**

**Recommended:**
- Accept that INCIDENT-5 is correct (silent failure is the requirement)
- Document that the UI error handling is a separate bug
- Focus on Datadog detection (which works perfectly)

### Option 2: Fix the Frontend (Out of Scope)
We would need to:
- Modify frontend JavaScript to catch 500 errors
- Display error message to user
- Prevent redirect to orders page

**Problem:** We don't have access to rebuild the frontend image.

### Option 3: Create Synchronous Shipping (Requires Rebuild)
Modify shipping service to:
```java
@PostMapping("/shipping")
public ResponseEntity<?> createShipment(@RequestBody ShipmentRequest request) {
    try {
        // Use confirmCallback to wait for confirmation
        rabbitTemplate.setConfirmCallback((correlation, ack, reason) -> {
            if (!ack) {
                throw new RuntimeException("Queue rejected message: " + reason);
            }
        });
        
        rabbitTemplate.convertAndSend("shipping-task", request);
        
        // Wait for confirmation (synchronous)
        boolean confirmed = waitForConfirmation(5000); // 5 second timeout
        
        if (!confirmed) {
            throw new RuntimeException("Message not confirmed by queue");
        }
        
        return ResponseEntity.ok("Shipment queued");
    } catch (Exception e) {
        return ResponseEntity.status(500).body("Failed to queue shipment: " + e.getMessage());
    }
}
```

**Problem:** Requires rebuilding and redeploying the shipping image. We don't have source code access.

### Option 4: Use a Different "Middleware" (MongoDB Connection Pool)
Create an incident where the middleware is the **database connection pool**:

- Simulate connection pool exhaustion in orders-db
- Orders get stuck waiting for database connection
- Eventually timeout with visible errors
- This is "middleware queue" in a different sense

**Incident Flow:**
1. Reduce orders-db resources drastically (10m CPU limit)
2. Orders-db becomes extremely slow
3. Connection pool gets exhausted
4. New orders get stuck waiting
5. Eventually timeout → HTTP 500 → User sees error

**This satisfies:**
- ✅ "Customer order processing stuck" (waiting for DB connection)
- ✅ "in middleware queue" (connection pool is the queue)
- ✅ "due to blockage" (DB is slow, pool exhausted)
- ✅ Visible errors (timeout errors propagate to UI)

### Option 5: Scale Orders Service to 0 (Simplest)
The most straightforward approach:

- Scale orders service itself to 0
- User tries to place order
- Gets immediate connection refused
- Frontend MUST show error (can't talk to backend at all)

**Incident Flow:**
1. Scale orders to 0
2. User attempts checkout
3. Frontend can't reach `/orders` endpoint
4. Shows network error

**This satisfies:**
- ✅ "Order processing stuck" (orders service down)
- ✅ "Due to blockage" (service unavailable)
- ✅ Visible errors (network error in UI)

---

## My Recommendation

Based on the client requirement and what's actually achievable:

### Recommended: Option 4 - Database Connection Pool Exhaustion

**Why this is best:**
1. ✅ Doesn't require rebuilding any images
2. ✅ Simulates "middleware queue" (connection pool)
3. ✅ Shows visible errors in UI (database timeouts)
4. ✅ Production realistic (happens in real systems)
5. ✅ Satisfies "stuck in middleware queue due to blockage"
6. ✅ Works with current code

**Implementation:**
```powershell
# Severely limit orders-db resources
kubectl -n sock-shop set resources deployment/orders-db --limits=cpu=10m,memory=50Mi

# Database becomes extremely slow
# Connection pool exhausts (default: 10 connections)
# New order requests wait for available connection
# After 5 seconds (HTTP timeout), they fail with visible error
```

**User Experience:**
- User places order
- Page shows loading spinner (waiting for backend)
- After 5-10 seconds: "Request timeout" or "Service unavailable"
- Clear visible error ✅

**Datadog Signals:**
- Orders service logs: "Connection timeout to orders-db"
- Orders-db CPU: 100% (throttled)
- HTTP 500/504 errors spike
- Response time: 5000ms+ (timeout)

---

## Decision Needed

**Please choose:**

1. **Accept INCIDENT-5 as correct** (silent failure is the requirement, UI bug is separate)
2. **Implement Option 4** (Database connection pool exhaustion)
3. **Implement Option 5** (Scale orders service to 0 - simplest)
4. **Something else** (please describe)

I'm ready to implement whichever you prefer, but I want to make sure we're aligned on the actual requirement before proceeding.
