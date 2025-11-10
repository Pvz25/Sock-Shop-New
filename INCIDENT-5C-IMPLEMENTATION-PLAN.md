# INCIDENT-5C: Proper Implementation Plan

## Objective

Modify the shipping service to use RabbitMQ Publisher Confirms (industry standard), then create an incident where the queue is full and orders fail with visible errors.

---

## Phase 1: Modify Shipping Service (Enable Publisher Confirms)

### Step 1: Clone Source Code
```bash
git clone https://github.com/microservices-demo/shipping
cd shipping
```

### Step 2: Modify application.properties/yaml
Add RabbitMQ publisher confirms configuration:

```yaml
spring:
  rabbitmq:
    publisher-confirm-type: correlated
    publisher-returns: true
    template:
      mandatory: true
```

**What this does:**
- `publisher-confirm-type: correlated` - Waits for RabbitMQ to confirm message was received
- `publisher-returns: true` - Receives notification if message couldn't be routed
- `mandatory: true` - If message can't be routed, return it to sender

###Step 3: Modify ShippingController.java

**Current code (fire-and-forget):**
```java
@PostMapping("/shipping")
public ResponseEntity<Shipment> postShipping(@RequestBody Shipment shipment) {
    rabbitTemplate.convertAndSend("shipping-task", shipment);
    return ResponseEntity.ok(shipment);
}
```

**Modified code (with confirms):**
```java
@PostMapping("/shipping")
public ResponseEntity<?> postShipping(@RequestBody Shipment shipment) {
    try {
        // Set up correlation data for this specific message
        CorrelationData correlationData = new CorrelationData(UUID.randomUUID().toString());
        
        // Create a future to wait for confirmation
        ListenableFuture<CorrelationData.Confirm> future = correlationData.getFuture();
        
        // Send message
        rabbitTemplate.convertAndSend("shipping-task", shipment, correlationData);
        
        // Wait for confirmation (with timeout)
        CorrelationData.Confirm confirm = future.get(5, TimeUnit.SECONDS);
        
        if (confirm.isAck()) {
            // Message successfully delivered to queue
            return ResponseEntity.ok(shipment);
        } else {
            // Message rejected by queue (e.g., queue full)
            String reason = confirm.getReason() != null ? confirm.getReason() : "Unknown";
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("error", "Queue unavailable", "reason", reason));
        }
        
    } catch (TimeoutException e) {
        return ResponseEntity.status(HttpStatus.GATEWAY_TIMEOUT)
            .body(Map.of("error", "Timeout waiting for queue confirmation"));
    } catch (Exception e) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of("error", "Failed to queue shipment", "message", e.getMessage()));
    }
}
```

**Required imports:**
```java
import org.springframework.amqp.rabbit.connection.CorrelationData;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.UUID;
import java.util.Map;
```

### Step 4: Configure RabbitTemplate Bean

Add to configuration class:

```java
@Bean
public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory) {
    RabbitTemplate template = new RabbitTemplate(connectionFactory);
    template.setConfirmCallback((correlationData, ack, cause) -> {
        if (correlationData != null) {
            correlationData.getFuture().set(new CorrelationData.Confirm(ack, cause));
        }
    });
    return template;
}
```

### Step 5: Build Modified Image

```bash
# Build using the Dockerfile
cd d:\sock-shop-demo\automation
docker build -f Dockerfile-shipping -t sock-shop-shipping:publisher-confirms .

# Tag for local registry
docker tag sock-shop-shipping:publisher-confirms quay.io/powercloud/sock-shop-shipping:publisher-confirms
```

### Step 6: Deploy Modified Service

Update deployment:
```yaml
# manifests/base/23-shipping-dep.yaml
spec:
  template:
    spec:
      containers:
        - name: shipping
          image: quay.io/powercloud/sock-shop-shipping:publisher-confirms  # Modified image
```

Apply:
```bash
kubectl apply -f manifests/base/23-shipping-dep.yaml
kubectl -n sock-shop rollout status deployment/shipping
```

---

## Phase 2: Create INCIDENT-5C (Queue Full Scenario)

### Prerequisites
✅ Modified shipping service deployed (with publisher confirms)

### Incident Flow

**Step 1: Configure RabbitMQ Queue with Max Length**

```powershell
# Set queue policy: max 3 messages, reject overflow
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  rabbitmqctl set_policy queue-limit "^shipping-task$" \
  '{"max-length":3,"overflow":"reject-publish"}' \
  --apply-to queues
```

**Step 2: Stop Consumer**

```powershell
# Scale queue-master to 0 (no one consuming messages)
kubectl -n sock-shop scale deployment/queue-master --replicas=0
```

**Step 3: Place Orders (USER ACTION)**

Duration: 2 minutes 30 seconds

**Expected Behavior:**
1. **Order 1-3:** SUCCESS ✅
   - Messages accepted by queue
   - Shipping service gets ACK
   - Orders complete successfully
   
2. **Order 4+:** FAILURE ❌
   - Queue is FULL (max 3 messages)
   - RabbitMQ rejects message
   - Shipping service gets NACK
   - Returns HTTP 503 "Queue unavailable"
   - Orders service propagates error
   - **UI shows error:** "Service unavailable" or "Failed to process order"

**Step 4: Verify in Logs**

```powershell
# Check shipping service logs for rejections
kubectl -n sock-shop logs deployment/shipping | Select-String "Queue unavailable|rejected"

# Check orders service logs for 503 errors
kubectl -n sock-shop logs deployment/orders | Select-String "503|Service unavailable"
```

**Step 5: Recovery**

```powershell
# Remove queue limit
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- \
  rabbitmqctl clear_policy queue-limit

# Restore consumer
kubectl -n sock-shop scale deployment/queue-master --replicas=1
```

---

## Expected User Experience

### Orders 1-3 (Queue Has Space)
```
User: Add to cart → Checkout → Place Order
Backend: 
  - Orders service → Shipping service
  - Shipping → RabbitMQ publish
  - RabbitMQ → ACK (accepted, queue not full)
  - Shipping → Returns 200 OK
  - Orders → Returns 201 Created
UI: "Order Successful!" ✅
Queue: 3/3 messages
```

### Order 4+ (Queue Full)
```
User: Add to cart → Checkout → Place Order
Backend:
  - Orders service → Shipping service
  - Shipping → RabbitMQ publish
  - RabbitMQ → NACK (rejected, queue full)
  - Shipping → Returns 503 "Queue unavailable"
  - Orders → Catches error, returns 500
UI: "Failed to process order" or "Service unavailable" ❌
Queue: Still 3/3 (rejected, not added)
```

---

## Datadog Verification

### Logs

**1. Shipping Service Rejections**
```
Query: kube_namespace:sock-shop service:shipping "Queue unavailable"
Expected: Logs showing "Message rejected by queue: Queue full"
```

**2. Orders Service Errors**
```
Query: kube_namespace:sock-shop service:orders (503 OR "Service unavailable")
Expected: Orders service logging shipping service 503 errors
```

**3. RabbitMQ Queue Metrics**
```
Metric: rabbitmq.queue.messages{queue:shipping-task}
Expected: Stays at 3 (max length), doesn't increase
```

### Metrics

**1. Queue Depth (Stuck at Limit)**
```
Metric: rabbitmq.queue.messages{queue:shipping-task}
Expected: Flat line at 3 messages
```

**2. Message Rejection Rate**
```
Metric: rabbitmq.queue.messages.publish.count vs rabbitmq.queue.messages
Expected: Publishes increase, but queue stays at 3 (rejections happening)
```

**3. HTTP 503 Responses**
```
Metric: trace.servlet.request.hits{http.status_code:503, service:shipping}
Expected: Spike in 503 responses during incident
```

---

## Why This Works

### Before Modification (INCIDENT-5A Failed)
```
User → Orders → Shipping (fire-and-forget) → RabbitMQ (FULL)
                    ↓
              Returns 200 OK (doesn't check if accepted)
                    ↓
         User sees "Order Successful" ✅ (WRONG!)
```

### After Modification (INCIDENT-5C Proper)
```
User → Orders → Shipping (publisher confirms) → RabbitMQ (FULL)
                    ↓                               ↓
                    ↓                          NACK (rejected)
                    ↓                               ↓
              Returns 503 ❌ (queue full)           ↓
                    ↓ ←──────────────────────────────
         Orders catches error → Returns 500
                    ↓
         User sees "Service unavailable" ❌ (CORRECT!)
```

---

## Industry Standard Compliance

**RabbitMQ Publisher Confirms** are the industry-standard way to ensure message delivery:

1. **Producer sends message**
2. **Broker confirms receipt** (ACK) or rejection (NACK)
3. **Producer waits for confirmation** (synchronous)
4. **Producer handles rejection** (returns error to caller)

**Used by:**
- Amazon SQS (via SDK response)
- Google Cloud Pub/Sub (via sync publish)
- Azure Service Bus (via sync send)
- Kafka (via acks configuration)

**Benefits:**
- ✅ Guaranteed delivery feedback
- ✅ Immediate error detection
- ✅ Prevents silent failures
- ✅ Better user experience (fast failure)

---

## Estimated Timeline

**Phase 1: Modify Shipping Service**
- Clone source: 5 minutes
- Modify code: 15 minutes
- Build image: 10 minutes
- Deploy: 5 minutes
- Test: 5 minutes
**Total: ~40 minutes**

**Phase 2: Execute Incident**
- Setup queue limit: 2 minutes
- Place orders: 2.5 minutes
- Verify: 2 minutes
- Recovery: 1 minute
**Total: ~8 minutes**

---

## Next Steps

1. **Get approval** to modify shipping service
2. **Clone and modify** source code
3. **Build and test** locally
4. **Deploy** to cluster
5. **Execute** INCIDENT-5C with proper queue-full scenario
6. **Document** results for Datadog

---

**This is the CORRECT implementation that:**
- ✅ Uses industry-standard publisher confirms
- ✅ Shows visible errors when queue is full
- ✅ Satisfies client requirement exactly
- ✅ Production-realistic behavior
- ✅ Proper error propagation to UI
