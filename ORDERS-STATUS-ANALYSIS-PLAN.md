# Orders Service Status Lifecycle - Complete Analysis & Fix Plan

## ✅ **STATUS: IMPLEMENTATION COMPLETE**

**This plan has been successfully executed. For complete implementation details, see:**  
👉 **[ORDERS-STATUS-IMPLEMENTATION-COMPLETE.md](./ORDERS-STATUS-IMPLEMENTATION-COMPLETE.md)**

**Quick Summary:**
- ✅ OrderStatus enum created with full lifecycle states
- ✅ CustomerOrder entity updated with status field
- ✅ OrdersController refactored with complete status transitions
- ✅ Deployed to KIND cluster (no registry credentials needed)
- ✅ Verified in production - 7 orders displaying with status in UI
- ✅ Database confirmed: `data` (not `orders`) with `customerOrder` collection

---

## 🎯 **Original Objective**

Implement a **complete, production-grade order status lifecycle** with proper state management and zero regression risk.

---

## 📊 **Current State vs. Desired State**

### **Current (Broken):**
```
Order Created → Payment Called → Exception → Order saved with NO STATUS ❌
```

### **Desired (Fixed):**
```
Order Created (status=CREATED) → 
Payment Processing (status=PENDING) → 
    ├─ Success (status=PAID) → Shipping (status=SHIPPED) → Delivered (status=DELIVERED)
    └─ Failure (status=PAYMENT_FAILED)
```

---

## 🔍 **PHASE 1: SOURCE CODE ANALYSIS (Do This First)**

### **Step 1.1: Clone Repository**

```powershell
# Clone the orders service source code
cd d:\
git clone https://github.com/ocp-power-demos/sock-shop-orders.git
cd sock-shop-orders

# Check out the current version (if needed)
git log --oneline -10
```

### **Step 1.2: Locate Key Files**

**Files to find and analyze:**

```
sock-shop-orders/
├─ src/main/java/works/weave/socks/orders/
│  ├─ entities/
│  │  └─ CustomerOrder.java           ← ORDER ENTITY (defines status field)
│  ├─ controllers/
│  │  └─ OrdersController.java        ← ORDER CREATION LOGIC (line ~95 has bug)
│  ├─ repositories/
│  │  └─ CustomerOrderRepository.java ← DATABASE ACCESS
│  ├─ services/
│  │  └─ AsyncGetService.java         ← PAYMENT SERVICE CALL
│  └─ resources/
│     └─ NewOrderResource.java        ← ORDER REQUEST DTO
├─ pom.xml                             ← BUILD CONFIGURATION
└─ Dockerfile                          ← CONTAINER BUILD
```

### **Step 1.3: Analyze Current Implementation**

**Key questions to answer:**

1. **CustomerOrder.java:**
   - Does `status` field exist?
   - What type is it? (String? Enum?)
   - Is there a default value?
   - Are there getter/setter methods?

2. **OrdersController.java:**
   - Line ~95: Where exactly is the bug?
   - How is `CustomerOrder` object created?
   - When is `customerOrderRepository.save()` called?
   - Where is payment service called?
   - Is there error handling?

3. **Status Management:**
   - Is there an enum for status values?
   - Are statuses hardcoded strings?
   - Is there status validation?

**Commands to run:**

```powershell
# Find all mentions of "status" in the codebase
cd d:\sock-shop-orders
Get-ChildItem -Recurse -Include "*.java" | Select-String -Pattern "status" -Context 2,2

# Find CustomerOrder class
Get-ChildItem -Recurse -Filter "CustomerOrder.java"

# Find OrdersController class  
Get-ChildItem -Recurse -Filter "OrdersController.java"

# Check if there's an OrderStatus enum
Get-ChildItem -Recurse -Filter "*Status.java"
```

---

## 🎯 **PHASE 2: DESIGN PROPER STATUS LIFECYCLE**

### **Status Enum Design (Recommended)**

**Create:** `src/main/java/works/weave/socks/orders/entities/OrderStatus.java`

```java
package works.weave.socks.orders.entities;

/**
 * Order Status Lifecycle
 * 
 * CREATED → PENDING → PAID → SHIPPED → DELIVERED
 *            ↓         ↓
 *      PAYMENT_FAILED  CANCELLED
 */
public enum OrderStatus {
    /**
     * Order has been created but payment not yet attempted.
     * Initial state when order object is first created.
     */
    CREATED("Created"),
    
    /**
     * Payment is being processed by payment service.
     * Temporary state while waiting for payment response.
     */
    PENDING("Pending"),
    
    /**
     * Payment has been successfully processed.
     * Order is ready for fulfillment/shipping.
     */
    PAID("Paid"),
    
    /**
     * Payment processing failed.
     * This could be due to payment service unavailability,
     * invalid card, insufficient funds, etc.
     */
    PAYMENT_FAILED("Payment Failed"),
    
    /**
     * Order has been shipped to customer.
     * Tracking information should be available.
     */
    SHIPPED("Shipped"),
    
    /**
     * Order has been delivered to customer.
     * Terminal state - order lifecycle complete.
     */
    DELIVERED("Delivered"),
    
    /**
     * Order was cancelled by user or system.
     * Terminal state - no further processing.
     */
    CANCELLED("Cancelled");
    
    private final String displayName;
    
    OrderStatus(String displayName) {
        this.displayName = displayName;
    }
    
    public String getDisplayName() {
        return displayName;
    }
    
    /**
     * Validate if transition from current status to new status is allowed.
     */
    public boolean canTransitionTo(OrderStatus newStatus) {
        switch (this) {
            case CREATED:
                return newStatus == PENDING || newStatus == CANCELLED;
            case PENDING:
                return newStatus == PAID || newStatus == PAYMENT_FAILED || newStatus == CANCELLED;
            case PAID:
                return newStatus == SHIPPED || newStatus == CANCELLED;
            case SHIPPED:
                return newStatus == DELIVERED;
            case PAYMENT_FAILED:
            case DELIVERED:
            case CANCELLED:
                return false; // Terminal states
            default:
                return false;
        }
    }
}
```

### **CustomerOrder.java Changes**

**Current (likely):**
```java
public class CustomerOrder {
    private String id;
    private String customerId;
    // ... other fields ...
    private String status;  // ❌ Problem: String type, no validation
    
    // No default value set!
}
```

**Fixed (proposed):**
```java
public class CustomerOrder {
    private String id;
    private String customerId;
    // ... other fields ...
    private OrderStatus status = OrderStatus.CREATED;  // ✅ Default value!
    
    public void setStatus(OrderStatus newStatus) {
        if (this.status != null && !this.status.canTransitionTo(newStatus)) {
            throw new IllegalStateException(
                String.format("Invalid status transition from %s to %s for order %s",
                    this.status, newStatus, this.id)
            );
        }
        this.status = newStatus;
    }
    
    public OrderStatus getStatus() {
        return status;
    }
}
```

---

## 🔧 **PHASE 3: FIX OrdersController.java**

### **Current Buggy Code (Conceptual - Based on Stack Trace):**

```java
@PostMapping(path = "/orders", consumes = MediaType.APPLICATION_JSON_VALUE)
public CustomerOrder newOrder(@RequestBody NewOrderResource resource) {
    LOG.info("Starting calls addressFuture");
    // ... async calls to get customer data ...
    
    // ❌ BUG 1: Order created without status
    CustomerOrder order = new CustomerOrder(
        customerId,
        customer.getContent(),
        address.getContent(),
        card.getContent(),
        items
    );
    
    // ❌ BUG 2: Order saved BEFORE payment check
    CustomerOrder savedOrder = customerOrderRepository.save(order);
    
    LOG.info("Sending payment request: ...");
    
    // ❌ BUG 3: No try-catch, exception thrown leaves order in bad state
    Future<Resource<Authorisation>> authFuture = asyncGetService.postResource(...);
    Authorisation auth = authFuture.get();  // Throws if payment fails!
    
    // This line only runs if payment succeeds
    savedOrder.setStatus(OrderStatus.PAID);
    
    return savedOrder;
}
```

### **Fixed Code (Surgical Changes):**

```java
@PostMapping(path = "/orders", consumes = MediaType.APPLICATION_JSON_VALUE)
public CustomerOrder newOrder(@RequestBody NewOrderResource resource) {
    LOG.info("Starting calls addressFuture");
    
    // Get customer data (async calls)
    Future<Resource<Address>> addressFuture = asyncGetService.getResource(...);
    Future<Resource<Card>> cardFuture = asyncGetService.getResource(...);
    Future<Resource<Customer>> customerFuture = asyncGetService.getResource(...);
    Future<Resource<Items>> itemsFuture = asyncGetService.getResource(...);
    
    // Wait for results
    Resource<Address> address = addressFuture.get();
    Resource<Card> card = cardFuture.get();
    Resource<Customer> customer = customerFuture.get();
    Resource<Items> items = itemsFuture.get();
    
    LOG.info("End of calls.");
    
    // ✅ FIX 1: Create order with CREATED status (default from entity)
    CustomerOrder order = new CustomerOrder(
        resource.getCustomer().getId(),
        customer.getContent(),
        address.getContent(),
        card.getContent(),
        items.getContent()
    );
    // Status is automatically CREATED due to default value in entity
    
    // ✅ FIX 2: Save order with initial status
    CustomerOrder savedOrder = customerOrderRepository.save(order);
    LOG.info("Order created with ID: {} and status: {}", savedOrder.getId(), savedOrder.getStatus());
    
    // ✅ FIX 3: Set PENDING status before payment attempt
    savedOrder.setStatus(OrderStatus.PENDING);
    customerOrderRepository.save(savedOrder);
    LOG.info("Order {} status updated to PENDING", savedOrder.getId());
    
    // ✅ FIX 4: Wrap payment call in try-catch
    try {
        LOG.info("Sending payment request: {}", paymentRequest);
        
        Future<Resource<Authorisation>> authFuture = asyncGetService.postResource(
            payment,
            paymentRequest,
            MediaType.APPLICATION_JSON_VALUE
        );
        
        // Wait for payment response
        Resource<Authorisation> authResponse = authFuture.get();
        Authorisation auth = authResponse.getContent();
        
        // ✅ FIX 5: Payment succeeded - update to PAID
        if (auth.isAuthorised()) {
            savedOrder.setStatus(OrderStatus.PAID);
            customerOrderRepository.save(savedOrder);
            LOG.info("Order {} payment successful, status updated to PAID", savedOrder.getId());
        } else {
            // Payment declined (valid response but not authorized)
            savedOrder.setStatus(OrderStatus.PAYMENT_FAILED);
            customerOrderRepository.save(savedOrder);
            LOG.warn("Order {} payment declined by payment service", savedOrder.getId());
            throw new PaymentDeclinedException("Payment was declined: " + auth.getMessage());
        }
        
    } catch (ExecutionException e) {
        // ✅ FIX 6: Payment service error - update to PAYMENT_FAILED
        LOG.error("Payment service error for order {}: {}", savedOrder.getId(), e.getCause().getMessage());
        
        savedOrder.setStatus(OrderStatus.PAYMENT_FAILED);
        customerOrderRepository.save(savedOrder);
        
        // Throw specific exception with clear message
        throw new PaymentServiceException(
            "Payment service unavailable: " + e.getCause().getMessage(),
            e
        );
        
    } catch (InterruptedException e) {
        // Thread interrupted
        Thread.currentThread().interrupt();
        
        savedOrder.setStatus(OrderStatus.PAYMENT_FAILED);
        customerOrderRepository.save(savedOrder);
        
        throw new PaymentServiceException("Payment processing interrupted", e);
    }
    
    return savedOrder;
}
```

---

## 🛡️ **PHASE 4: REGRESSION PREVENTION**

### **Unit Tests Required:**

**File:** `src/test/java/works/weave/socks/orders/controllers/OrdersControllerTest.java`

```java
@Test
public void testOrderCreated_WithDefaultStatus() {
    // When: New order is created
    CustomerOrder order = new CustomerOrder(...);
    
    // Then: Status should be CREATED by default
    assertEquals(OrderStatus.CREATED, order.getStatus());
}

@Test
public void testOrderPaymentSuccess_StatusUpdatedToPaid() {
    // Given: Order in PENDING status
    // When: Payment succeeds
    // Then: Status should be PAID
}

@Test
public void testOrderPaymentFailure_StatusUpdatedToPaymentFailed() {
    // Given: Payment service is down
    // When: Payment is attempted
    // Then: Status should be PAYMENT_FAILED
    // And: Order should be saved with failed status
    // And: Appropriate exception should be thrown
}

@Test
public void testOrderStatusTransition_ValidTransitions() {
    // Test all valid state transitions
    CustomerOrder order = new CustomerOrder(...);
    
    // CREATED → PENDING (valid)
    order.setStatus(OrderStatus.PENDING);
    assertEquals(OrderStatus.PENDING, order.getStatus());
    
    // PENDING → PAID (valid)
    order.setStatus(OrderStatus.PAID);
    assertEquals(OrderStatus.PAID, order.getStatus());
    
    // PAID → SHIPPED (valid)
    order.setStatus(OrderStatus.SHIPPED);
    assertEquals(OrderStatus.SHIPPED, order.getStatus());
}

@Test(expected = IllegalStateException.class)
public void testOrderStatusTransition_InvalidTransitions() {
    // CREATED → PAID (invalid - must go through PENDING)
    CustomerOrder order = new CustomerOrder(...);
    order.setStatus(OrderStatus.PAID);  // Should throw
}

@Test
public void testPaymentServiceDown_OrderExistsWithFailedStatus() {
    // Given: Payment service is unavailable
    when(paymentService.postResource(...)).thenThrow(new ConnectException());
    
    // When: Order is placed
    try {
        ordersController.newOrder(newOrderResource);
    } catch (PaymentServiceException e) {
        // Expected
    }
    
    // Then: Order should exist in database
    CustomerOrder savedOrder = customerOrderRepository.findById(orderId);
    assertNotNull(savedOrder);
    assertEquals(OrderStatus.PAYMENT_FAILED, savedOrder.getStatus());
}
```

### **Integration Tests Required:**

```java
@Test
@Transactional
public void testEndToEndOrderFlow_PaymentSuccess() {
    // 1. Create order via REST API
    // 2. Verify status = CREATED
    // 3. Verify status transitions to PENDING
    // 4. Verify payment is called
    // 5. Verify status = PAID after payment success
    // 6. Verify order can be retrieved with correct status
}

@Test
@Transactional
public void testEndToEndOrderFlow_PaymentFailure() {
    // 1. Scale payment service to 0
    // 2. Create order via REST API
    // 3. Verify status = CREATED
    // 4. Verify status transitions to PENDING
    // 5. Verify payment call fails
    // 6. Verify status = PAYMENT_FAILED
    // 7. Verify order exists in database with failed status
    // 8. Verify appropriate error message returned
}
```

---

## 📋 **PHASE 5: DEPLOYMENT CHECKLIST**

### **Before Deployment:**

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code review completed
- [ ] Status enum created with validation
- [ ] CustomerOrder entity updated with default status
- [ ] OrdersController fixed with proper error handling
- [ ] Exception classes created (PaymentServiceException, PaymentDeclinedException)
- [ ] Database migration script ready (if needed)

### **Deployment Steps:**

```powershell
# 1. Build new Docker image
cd d:\sock-shop-orders
docker build -t your-registry/sock-shop-orders:v1.0-status-fix .

# 2. Tag with version
docker tag your-registry/sock-shop-orders:v1.0-status-fix your-registry/sock-shop-orders:latest

# 3. Push to registry
docker push your-registry/sock-shop-orders:v1.0-status-fix
docker push your-registry/sock-shop-orders:latest

# 4. Update Kubernetes deployment
kubectl -n sock-shop set image deployment/orders orders=your-registry/sock-shop-orders:v1.0-status-fix

# 5. Wait for rollout
kubectl -n sock-shop rollout status deployment/orders

# 6. Verify new pod is running
kubectl -n sock-shop get pods -l name=orders
```

### **Post-Deployment Verification:**

```powershell
# 1. Test successful order (payment up)
kubectl -n sock-shop scale deployment payment --replicas=1
# Place order via UI - verify status = PAID

# 2. Test failed order (payment down)
kubectl -n sock-shop scale deployment payment --replicas=0
# Place order via UI - verify status = PAYMENT_FAILED

# 3. Verify all orders have status
kubectl -n sock-shop exec -it deployment/orders -- curl -s http://localhost:8080/orders | 
    ConvertFrom-Json | 
    Select-Object -ExpandProperty _embedded | 
    Select-Object -ExpandProperty customerOrders | 
    ForEach-Object { 
        if (-not $_.status) { 
            Write-Host "❌ ERROR: Order $($_.id) has no status!" -ForegroundColor Red 
        } 
    }

# 4. Check status distribution
kubectl -n sock-shop exec -it deployment/orders -- curl -s http://localhost:8080/orders | 
    ConvertFrom-Json | 
    Select-Object -ExpandProperty _embedded | 
    Select-Object -ExpandProperty customerOrders | 
    Group-Object status | 
    Select-Object Count, Name
```

---

## 🎯 **EXACT FILES TO MODIFY**

Based on typical Spring Boot structure (to be confirmed after cloning):

### **1. NEW FILE: OrderStatus.java**
```
Location: src/main/java/works/weave/socks/orders/entities/OrderStatus.java
Purpose: Define all possible order statuses as enum
Lines: ~80 lines
Risk: LOW (new file, no existing code affected)
```

### **2. MODIFY: CustomerOrder.java**
```
Location: src/main/java/works/weave/socks/orders/entities/CustomerOrder.java
Changes:
  - Line ~XX: Change status field from String to OrderStatus
  - Line ~XX: Add default value = OrderStatus.CREATED
  - Line ~XX: Update setStatus() to validate transitions
Risk: MEDIUM (core entity, need thorough testing)
```

### **3. MODIFY: OrdersController.java**
```
Location: src/main/java/works/weave/socks/orders/controllers/OrdersController.java
Changes:
  - Line ~95: Wrap payment call in try-catch
  - Line ~90: Set status to PENDING before payment
  - Line ~100: Set status to PAID on success
  - Line ~105: Set status to PAYMENT_FAILED on error
Risk: HIGH (main business logic, needs extensive testing)
```

### **4. NEW FILE: PaymentServiceException.java**
```
Location: src/main/java/works/weave/socks/orders/exceptions/PaymentServiceException.java
Purpose: Custom exception for payment service errors
Lines: ~20 lines
Risk: LOW (new exception class)
```

### **5. NEW FILE: PaymentDeclinedException.java**
```
Location: src/main/java/works/weave/socks/orders/exceptions/PaymentDeclinedException.java
Purpose: Custom exception for declined payments
Lines: ~20 lines
Risk: LOW (new exception class)
```

### **6. UPDATE: pom.xml (if needed)**
```
Location: pom.xml
Changes: May need to update dependencies if adding new testing libraries
Risk: LOW
```

---

## 🚨 **REGRESSION PREVENTION STRATEGY**

### **Critical Checks:**

1. **Backward Compatibility:**
   - [ ] Existing orders in database still readable
   - [ ] API responses maintain same structure
   - [ ] Front-end doesn't break with new status values

2. **Database Migration:**
   - [ ] Existing orders with null status handled gracefully
   - [ ] Migration script updates old orders to appropriate status
   - [ ] No data loss during migration

3. **Error Handling:**
   - [ ] All exception paths tested
   - [ ] No uncaught exceptions
   - [ ] Proper logging at all decision points

4. **Performance:**
   - [ ] No additional database calls introduced
   - [ ] Status transitions are fast
   - [ ] No performance degradation

---

## 📊 **SUCCESS METRICS**

After deployment, verify:

```
✅ 100% of new orders have status field populated
✅ 0% regression in existing functionality
✅ Payment failures properly recorded as PAYMENT_FAILED
✅ Successful payments properly recorded as PAID
✅ No orders with null/empty status
✅ All status transitions are valid
✅ Exception messages are clear and actionable
```

---

## 🎯 **NEXT IMMEDIATE STEPS**

1. **Clone Repository:**
   ```powershell
   cd d:\
   git clone https://github.com/ocp-power-demos/sock-shop-orders.git
   cd sock-shop-orders
   ```

2. **Analyze Current Code:**
   ```powershell
   # Find CustomerOrder.java
   Get-ChildItem -Recurse -Filter "CustomerOrder.java"
   
   # Find OrdersController.java
   Get-ChildItem -Recurse -Filter "OrdersController.java"
   
   # Read both files to understand current implementation
   ```

3. **Report Back:**
   - Share the current implementation
   - Confirm file locations
   - Validate proposed changes match actual code structure

---

**Ready to clone the repository and analyze the actual code?**

This document provides the complete roadmap, but we need the actual source code to make precise, surgical changes with zero regression risk.
