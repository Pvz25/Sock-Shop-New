# 🚨 CRITICAL BUG: Payment Bypass & Cart Persistence Vulnerability

## Executive Summary

| Attribute | Details |
|-----------|---------|
| **Severity** | 🔴 **CRITICAL** - Payment can be bypassed |
| **Bug Type** | Race Condition + Missing Idempotency + Cart State Management |
| **Discovered** | 2025-11-07 during INCIDENT-6 testing |
| **Impact** | Orders can be completed without payment; duplicate orders possible; cart never clears |
| **Business Risk** | HIGH - Revenue loss, inventory issues, customer confusion |
| **Attack Vector** | User can retry failed payment when gateway recovers |
| **Affected Component** | Orders Service + Front-End + Carts Service |

---

## 🐛 Bug Description

### User-Observed Behavior

**During INCIDENT-6 testing, the following sequence occurred:**

1. ✅ **Click 1 (Gateway Down):** Payment fails with error message
2. ❌ **Click 2 (Gateway Recovered):** Order succeeds and shows as SHIPPED
3. ❌ **Cart State:** Cart items remain, not cleared
4. ❌ **Result:** Successful order despite initial payment failure

### What Should Happen

1. Click 1: Payment fails → Order marked PAYMENT_FAILED → Cart remains → User sees error
2. Click 2: Should prevent duplicate order OR require explicit retry → Clear cart only on success

### What Actually Happens

1. Click 1: Payment fails → Order saved with PAYMENT_FAILED → Exception thrown → Cart remains
2. Click 2: **NEW order created** → Payment succeeds (gateway recovered) → Order SHIPPED → **Cart still not cleared**

---

## 🔍 Root Cause Analysis

### Issue #1: Order Created BEFORE Payment Validation

**File:** `d:\sock-shop-orders\src\main\java\works\weave\socks\orders\controllers\OrdersController.java`

**Problematic Code Flow:**

```java
// Line ~90: Create order BEFORE payment with status=CREATED (default)
CustomerOrder order = new CustomerOrder(
    null,
    customerId,
    c,
    ar,
    cr,
    itemsFuture.get(timeout, TimeUnit.SECONDS),
    null,  // No shipment yet
    Calendar.getInstance().getTime(),
    amount);

// Line ~96: Save order with initial status=CREATED
CustomerOrder savedOrder = customerOrderRepository.save(order);
LOG.info("Order created with ID: " + savedOrder.getId() + " and status: " + savedOrder.getStatus());

// Line ~99: Update status to PENDING before payment attempt
savedOrder.setStatus(OrderStatus.PENDING);
savedOrder = customerOrderRepository.save(savedOrder);
LOG.info("Order " + savedOrder.getId() + " status updated to PENDING");

// Line ~103: NOW TRY PAYMENT (order already in database!)
try {
    PaymentRequest paymentRequest = new PaymentRequest(ar, cr, c, amount);
    // ... payment call ...
    PaymentResponse paymentResponse = paymentFuture.get(timeout, TimeUnit.SECONDS);
    
    if (!paymentResponse.isAuthorised()) {
        throw new PaymentDeclinedException(paymentResponse.getMessage());
    }
    
    // If we get here, payment succeeded
    savedOrder.setStatus(OrderStatus.PAID);
    // ... ship order ...
    
} catch (TimeoutException | InterruptedException | ExecutionException e) {
    // Payment failed - update status to PAYMENT_FAILED
    LOG.error("Payment failed for order " + savedOrder.getId() + ": " + e.getMessage());
    savedOrder.setStatus(OrderStatus.PAYMENT_FAILED);
    savedOrder = customerOrderRepository.save(savedOrder);
    
    // Re-throw exception - front-end gets 500 error
    throw new IllegalStateException("Payment service unavailable for order " + savedOrder.getId());
}
```

**Problems:**

1. ❌ **Order persisted in database BEFORE payment** (status=CREATED, then PENDING)
2. ❌ **If payment fails, order exists with status=PAYMENT_FAILED**
3. ❌ **Exception thrown to front-end, but order already saved**
4. ❌ **No cleanup of failed order from database**

---

### Issue #2: No Idempotency Check

**Problem:** When user clicks "Place Order" again:
- NO check for existing pending/failed orders
- NO dedupe based on cart contents
- NO correlation between clicks
- **Result:** NEW order created each time

**Evidence:**
```java
// OrdersController.java - newOrder() method
// NO code like:
// if (existingPendingOrder(customerId, cartItems)) {
//     return existingOrder; // or throw exception
// }
```

**Impact:**
- Click button 10 times = 10 orders created
- If gateway recovered between clicks 1 and 2:
  - Order 1: PAYMENT_FAILED (gateway down)
  - Order 2: PAID → SHIPPED (gateway up) ✅ SUCCESSFUL
- Customer charged ONCE but has TWO orders in system

---

### Issue #3: Cart Never Cleared

**File:** Front-End service (cart handling logic)

**Problem:** Cart clearing appears to only happen on SUCCESSFUL order completion, NOT on ANY order creation.

**Evidence from Architecture Doc:**
```
Line 479: "Ord-->>FE: 500 Error (but order saved!)"
```

**Expected Behavior:**
- Cart should be cleared when order is CREATED (optimistic)
- OR cart should be cleared when order reaches PAID status
- Cart items should be "reserved" to prevent reuse

**Actual Behavior:**
- Cart remains intact after payment failure
- User can retry with same cart
- Multiple orders created from same cart items

**Front-End API:**
```
DELETE /carts/:customerId  # Should be called after order creation
```

**Missing Logic:**
```javascript
// Front-end order submission (MISSING)
orders.create(orderData)
  .then(response => {
    // SHOULD call: carts.delete(customerId)
    // BUT this might not happen on error
  })
  .catch(error => {
    // Error path - cart NOT cleared
    displayError(error);
  });
```

---

## 🎯 Attack Scenario

### Malicious User Exploitation

1. **Setup:** Add expensive items to cart ($1000 worth)
2. **Execute:**
   - Wait for payment gateway timeout/failure
   - Click "Place Order" → Payment fails → Order saved as PAYMENT_FAILED
   - Wait a few seconds for gateway recovery
   - Click "Place Order" again → Payment succeeds → Order SHIPPED
3. **Result:**
   - User charged once
   - Two orders in system (one PAYMENT_FAILED, one SHIPPED)
   - Inventory decremented twice
   - User receives shipment

### Accidental User Impact

1. **Impatient User:** Clicks "Place Order" multiple times due to slow response
2. **Result:**
   - Multiple orders created
   - If payment gateway has intermittent issues, some succeed, some fail
   - Customer confusion: "Why do I have 3 orders?"
   - Customer service nightmare

---

## 📊 Evidence from INCIDENT-6 Test

### Timeline

| Time (IST) | Event | Status |
|------------|-------|--------|
| 20:45:53 | INCIDENT-6 activated | stripe-mock scaled to 0 |
| 20:47:04 | User clicks "Place Order" (Click 1) | Payment FAILS (connection refused) |
| 20:48:15 | INCIDENT-6 recovered | stripe-mock scaled to 1 |
| 20:48:42 | User clicks "Place Order" (Click 2) | Payment SUCCEEDS → Order SHIPPED |

### Payment Service Logs

```log
# Click 1 - Payment Failed
2025-11-07T15:17:04Z 💳 Payment auth request: amount=50.00
2025-11-07T15:17:04Z 🌐 Calling payment gateway: http://stripe-mock/v1/charges (amount=5000 cents)
2025-11-07T15:17:04Z ❌ Payment gateway error: Post "http://stripe-mock/v1/charges": dial tcp 10.96.196.183:80: connect: connection refused (0.21s)

# Click 2 - Payment Succeeded (after recovery)
2025-11-07T15:19:04Z 💳 Payment auth request: amount=75.00
2025-11-07T15:19:04Z 🌐 Calling payment gateway: http://stripe-mock/v1/charges (amount=7500 cents)
2025-11-07T15:19:05Z ✅ Gateway response: HTTP 200 (0.72s)
2025-11-07T15:19:05Z ✅ Payment authorized: ch_PfECoEmld0tCCge
```

**Analysis:**
- Click 1: Failed as expected (gateway down)
- Click 2: Succeeded (gateway recovered)
- **Two different amounts** ($50 vs $75) suggest two different orders created

---

## 🔧 Proposed Solutions

### Solution 1: Implement Idempotency (RECOMMENDED)

**Add idempotency token to order creation:**

```java
// OrdersController.java - Modified newOrder() method

@RequestMapping(value = "/orders", consumes = MediaType.APPLICATION_JSON_VALUE, method = RequestMethod.POST)
public @ResponseBody
ResponseEntity<CustomerOrder> newOrder(
        @RequestBody NewOrderResource item,
        @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) throws Exception {
    
    try {
        // Check for existing order with same idempotency key
        if (idempotencyKey != null && !idempotencyKey.isEmpty()) {
            CustomerOrder existingOrder = customerOrderRepository.findByIdempotencyKey(idempotencyKey);
            if (existingOrder != null) {
                LOG.info("Duplicate order request detected, returning existing order: " + existingOrder.getId());
                
                // If order is PAYMENT_FAILED, allow retry
                if (existingOrder.getStatus() == OrderStatus.PAYMENT_FAILED) {
                    LOG.info("Existing order " + existingOrder.getId() + " has PAYMENT_FAILED, allowing retry");
                    // Fall through to create new order
                } else {
                    // Return existing order (SUCCESS or PENDING)
                    return ResponseEntity.status(HttpStatus.OK).body(existingOrder);
                }
            }
        }
        
        // ... rest of order creation logic ...
        
        // Before saving, set idempotency key
        order.setIdempotencyKey(idempotencyKey);
        CustomerOrder savedOrder = customerOrderRepository.save(order);
        
        // ... rest of payment/shipping logic ...
        
    } catch (Exception e) {
        // Handle errors
    }
}
```

**Database Changes:**
```java
// CustomerOrder.java - Add field

@Indexed(unique = true, sparse = true)
private String idempotencyKey;

// Getter/Setter
public String getIdempotencyKey() { return idempotencyKey; }
public void setIdempotencyKey(String key) { this.idempotencyKey = key; }
```

**Front-End Changes:**
```javascript
// Generate idempotency key on first click
const idempotencyKey = generateUUID(); // or use existing order ID

fetch('/orders', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey
    },
    body: JSON.stringify(orderData)
});
```

---

### Solution 2: Clear Cart Immediately on Order Creation

**Orders Service - Call cart deletion:**

```java
// OrdersController.java - After order creation

// Save order with initial status
CustomerOrder savedOrder = customerOrderRepository.save(order);
LOG.info("Order created with ID: " + savedOrder.getId());

// Clear cart immediately (optimistic)
try {
    String cartUrl = config.getCartsUri() + "/" + customerId;
    asyncGetService.deleteResource(cartUrl);
    LOG.info("Cart cleared for customer " + customerId);
} catch (Exception e) {
    LOG.warn("Failed to clear cart for customer " + customerId + ": " + e.getMessage());
    // Continue anyway - don't fail order creation due to cart clearing issue
}

// Continue with payment...
```

**Alternative: Clear cart only on PAID status:**

```java
// After payment success
if (paymentResponse.isAuthorised()) {
    savedOrder.setStatus(OrderStatus.PAID);
    savedOrder = customerOrderRepository.save(savedOrder);
    
    // Clear cart NOW
    try {
        String cartUrl = config.getCartsUri() + "/" + customerId;
        asyncGetService.deleteResource(cartUrl);
        LOG.info("Cart cleared after successful payment for customer " + customerId);
    } catch (Exception e) {
        LOG.warn("Failed to clear cart: " + e.getMessage());
    }
    
    // Continue with shipping...
}
```

---

### Solution 3: Prevent Multiple Pending Orders

**Add check before creating order:**

```java
// OrdersController.java - Before creating order

// Check for existing PENDING or CREATED orders
List<CustomerOrder> pendingOrders = customerOrderRepository.findByCustomerIdAndStatusIn(
    customerId, 
    Arrays.asList(OrderStatus.CREATED, OrderStatus.PENDING)
);

if (!pendingOrders.isEmpty()) {
    CustomerOrder existingOrder = pendingOrders.get(0);
    LOG.warn("Customer " + customerId + " already has pending order: " + existingOrder.getId());
    
    // Return 409 Conflict with existing order
    return ResponseEntity
        .status(HttpStatus.CONFLICT)
        .body(existingOrder);
}

// Proceed with new order creation...
```

---

### Solution 4: Transaction Rollback on Payment Failure (COMPLEX)

**Use Spring @Transactional with proper rollback:**

```java
@Transactional(rollbackFor = {PaymentDeclinedException.class, TimeoutException.class})
public CustomerOrder createOrderWithPayment(NewOrderResource item) throws Exception {
    // Create and save order
    CustomerOrder order = createOrder(item);
    
    // Attempt payment
    PaymentResponse payment = attemptPayment(order);
    
    if (!payment.isAuthorised()) {
        // Rollback transaction - order NOT saved
        throw new PaymentDeclinedException(payment.getMessage());
    }
    
    // Ship order
    shipOrder(order);
    
    return order;
}
```

**Problem:** This requires distributed transaction support (2PC) which is complex in microservices.

---

## 🎯 Recommended Fix (Combination Approach)

### Phase 1: Immediate Fix (Low Risk)

1. ✅ **Add idempotency check** (Solution 1)
   - Prevents duplicate orders
   - Allows retry of PAYMENT_FAILED orders
   - Low risk, high impact

2. ✅ **Clear cart on successful payment** (Solution 2 - variant B)
   - Only clear cart when payment succeeds
   - Safe approach, no data loss risk

### Phase 2: Medium-Term Improvement

3. ✅ **Add pending order check** (Solution 3)
   - UI shows "You have a pending order" message
   - Prevents confusion from multiple clicks

4. ✅ **Add exponential backoff on retry**
   - Disable button for 2s after click
   - Show loading spinner
   - Prevent accidental double-clicks

### Phase 3: Long-Term Architecture Improvement

5. ✅ **Implement Saga pattern**
   - Orders service as saga coordinator
   - Compensation logic for failures
   - Proper distributed transaction handling

6. ✅ **Add order state machine**
   - Strict state transitions
   - Prevent invalid state changes
   - Audit trail of all status changes

---

## 🧪 Testing Plan

### Test Case 1: Duplicate Click Prevention

```bash
# Setup: Normal system state

# Action:
1. User adds items to cart
2. User clicks "Place Order" (Click 1)
3. Immediately clicks "Place Order" again (Click 2)

# Expected Result:
- Click 1: Order created, processing
- Click 2: Returns same order (idempotency) OR shows error "Order already processing"
- Only ONE order in database
- Cart cleared after first order succeeds
```

### Test Case 2: Payment Failure Retry

```bash
# Setup: Activate INCIDENT-6 (gateway down)

# Action:
1. User clicks "Place Order" (Click 1) → Payment fails
2. Recover INCIDENT-6 (gateway up)
3. User clicks "Place Order" again (Click 2) → Payment succeeds

# Expected Result:
- Click 1: Order created with PAYMENT_FAILED, cart NOT cleared
- Click 2: With idempotency - RETRIES same order (updates status)
         Without idempotency - Creates new order
- Cart cleared only after successful payment
- Only ONE order with status=SHIPPED (not two orders)
```

### Test Case 3: Cart State Management

```bash
# Action:
1. Add 3 items to cart
2. Place order → Payment succeeds
3. Check cart

# Expected Result:
- Cart is empty
- Cannot place same order again
```

---

## 📊 Impact Assessment

### Current State (BEFORE Fix)

| Scenario | Current Behavior | Business Impact |
|----------|------------------|-----------------|
| **Double Click** | Multiple orders created | Revenue loss, inventory issues |
| **Gateway Flap** | Failed order + Successful order | Duplicate shipments |
| **Impatient User** | 5 clicks = 5 orders | Customer confusion, CS overhead |
| **Cart State** | Cart never clears | User can reorder same items indefinitely |

### After Fix (Solution 1 + 2)

| Scenario | New Behavior | Business Impact |
|----------|--------------|-----------------|
| **Double Click** | Idempotency returns same order | ✅ No duplicates |
| **Gateway Flap** | Retry updates existing order | ✅ Single order |
| **Impatient User** | All clicks return same order | ✅ One order only |
| **Cart State** | Cart cleared on success | ✅ Proper state management |

---

## 🚀 Implementation Priority

### Priority 1: CRITICAL (Deploy ASAP)
- [ ] Add idempotency key to orders
- [ ] Modify OrdersController to check idempotency
- [ ] Update front-end to send idempotency key

### Priority 2: HIGH (This Sprint)
- [ ] Implement cart clearing on successful payment
- [ ] Add pending order check
- [ ] Add UI button disable/loading state

### Priority 3: MEDIUM (Next Sprint)
- [ ] Add comprehensive order state machine
- [ ] Implement distributed tracing for order flow
- [ ] Add order audit log

### Priority 4: LOW (Backlog)
- [ ] Saga pattern implementation
- [ ] Full transaction compensation logic
- [ ] Advanced retry mechanisms

---

## 📝 Related Issues

- **INCIDENT-6:** This bug was discovered during gateway timeout testing
- **Cart Service:** Needs DELETE endpoint properly integrated
- **Front-End:** Missing error handling and retry logic
- **Orders Service:** Missing transaction boundaries

---

## 📞 Security Considerations

### Potential Exploits

1. **Revenue Loss:** User can place order, payment fails, retry succeeds → shipped without payment
2. **Inventory Manipulation:** Multiple failed orders can reserve inventory
3. **Denial of Service:** Rapid-fire order creation can overload database
4. **Race Conditions:** Concurrent requests can create multiple orders

### Mitigation

- ✅ **Idempotency:** Prevents duplicate orders
- ✅ **Rate Limiting:** Prevent rapid-fire requests
- ✅ **Order Timeout:** Cancel PENDING orders after 5 minutes
- ✅ **Inventory Reservation:** Reserve only on PAID status

---

## 🎓 Lessons Learned

1. **Create-Then-Validate Pattern is Dangerous**
   - Don't persist state before validation
   - Or implement proper cleanup/rollback

2. **Async Operations Need Idempotency**
   - Network issues cause retries
   - Always assume duplicate requests

3. **UI State Management is Critical**
   - Cart clearing must be reliable
   - Button state must prevent double-clicks

4. **Testing Under Failure Conditions**
   - This bug only appeared during gateway failure testing
   - Always test degraded states

---

**Document Status:** 🔴 **ACTIVE BUG - REQUIRES IMMEDIATE ATTENTION**  
**Created:** 2025-11-07  
**Severity:** CRITICAL  
**Assigned To:** Development Team  
**Target Resolution:** Sprint 1 (Priority 1 items)

