# INCIDENT-3 EXECUTION REPORT
## Payment Transaction Failure - October 30, 2025

**Incident ID**: INCIDENT-3-PAYMENT-FAILURE  
**Execution Date**: 2025-10-30  
**Execution Time**: 08:24:46 - 08:28:32 UTC  
**Duration**: ~4 minutes  
**Severity**: P1 - Critical  
**Operator**: parvaiz

---

## 📊 EXECUTIVE SUMMARY

Successfully simulated a **distributed transaction failure** in the Sock Shop microservices application by scaling the payment service to 0 replicas. During the 4-minute incident window, **5 orders failed** with `PAYMENT_FAILED` status due to payment service unavailability, while the UI incorrectly displayed them as "Shipped" due to caching issues.

### Impact Assessment
- **Total Orders Attempted**: 5
- **Failed Orders**: 5 (100% failure rate during outage)
- **Customers Affected**: 2 users (Rayaan, parvaiz)
- **Revenue at Risk**: $374.21
- **System Behavior**: Orders created but payment processing failed
- **User Experience**: No error messages displayed (critical UX issue)

---

## 🔍 INCIDENT TIMELINE

| Time (UTC) | Event | Order ID | Customer | Amount | Status |
|------------|-------|----------|----------|--------|--------|
| 08:24:00 | 🔴 Payment service scaled to 0 replicas | - | - | - | Service DOWN |
| 08:24:46 | Order placement attempted | 690320cee2c84800016ceb4a | Rayaan | $104.98 | PAYMENT_FAILED |
| 08:25:14 | Order placement attempted | 690320eae2c84800016ceb4b | Rayaan | $19.99 | PAYMENT_FAILED |
| 08:26:40 | Order placement attempted | 69032142e2c84800016ceb4c | parvaiz | $104.98 | PAYMENT_FAILED |
| 08:28:19 | Order placement attempted | 690321a3e2c84800016ceb4d | parvaiz | $122.13 | PAYMENT_FAILED |
| 08:28:32 | Order placement attempted | 690321b0e2c84800016ceb4e | parvaiz | $22.14 | PAYMENT_FAILED |

---

## 📋 FAILED ORDER DETAILS

### Order 1: 690320cee2c84800016ceb4a
- **Customer**: Rayaan (6902f3f39c10d30001a04809)
- **Time**: 2025-10-30T08:24:46.328+0000
- **Items**: Holy Cringle Socks (1x $99.99)
- **Total**: $104.98
- **Status**: PAYMENT_FAILED
- **Shipment**: null
- **Issue**: Payment service connection refused

### Order 2: 690320eae2c84800016ceb4b
- **Customer**: Rayaan (6902f3f39c10d30001a04809)
- **Time**: 2025-10-30T08:25:14.525+0000
- **Items**: Colourful Socks (1x $15.00)
- **Total**: $19.99
- **Status**: PAYMENT_FAILED
- **Shipment**: null
- **Issue**: Payment service connection refused

### Order 3: 69032142e2c84800016ceb4c
- **Customer**: parvaiz (690321149c10d30001a0480a)
- **Time**: 2025-10-30T08:26:40.964+0000
- **Items**: Holy Cringle Socks (1x $99.99)
- **Total**: $104.98
- **Status**: PAYMENT_FAILED
- **Shipment**: null
- **Issue**: Payment service connection refused

### Order 4: 690321a3e2c84800016ceb4d
- **Customer**: parvaiz (690321149c10d30001a0480a)
- **Time**: 2025-10-30T08:28:19.933+0000
- **Items**: Holy Cringle Socks (1x $99.99), Crossed Socks (1x $17.15)
- **Total**: $122.13
- **Status**: PAYMENT_FAILED
- **Shipment**: null
- **Issue**: Payment service connection refused

### Order 5: 690321b0e2c84800016ceb4e
- **Customer**: parvaiz (690321149c10d30001a0480a)
- **Time**: 2025-10-30T08:28:32.045+0000
- **Items**: Crossed Socks (1x $17.15)
- **Total**: $22.14
- **Status**: PAYMENT_FAILED
- **Shipment**: null
- **Issue**: Payment service connection refused

---

## 🔧 ROOT CAUSE ANALYSIS

### Immediate Cause
Payment service deployment scaled to 0 replicas, simulating total service unavailability.

### Technical Details
1. **Service Failure**: Payment pods terminated, resulting in DNS resolution succeeding but connection being refused (Connection refused to 10.96.100.12:80)
2. **Order Service Behavior**: Orders service correctly:
   - Created orders with CREATED status
   - Transitioned to PENDING status
   - Attempted payment authorization via HTTP POST to `http://payment:80/paymentAuth`
   - Received `java.net.ConnectException: Connection refused`
   - Correctly updated orders to PAYMENT_FAILED status
   - Did NOT create shipments (shipment: null)

3. **Front-End Issue**: UI displayed orders as "Shipped" despite database showing PAYMENT_FAILED (caching/state management issue)

### Underlying Issues
1. **No Retry Logic**: Orders service doesn't retry failed payment calls
2. **No Circuit Breaker**: No protection against cascading failures
3. **Poor Error Propagation**: Users didn't see error messages about payment failure
4. **UI Caching**: Front-end displays incorrect status from cache
5. **No Idempotency**: No mechanism to safely retry payments
6. **No User Notification**: Customers not informed about payment failure

---

## 📈 OBSERVABILITY VERIFICATION

### Kubernetes State
```powershell
kubectl -n sock-shop get pods
# Payment pod count: 0 (expected: 1)
# All other pods: Running
```

### Database State
```powershell
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders
# Total orders: 8
# PAYMENT_FAILED: 5 orders
# PAID: 2 orders (pre-incident)
# Old PAYMENT_FAILED: 1 order (from 05:14:24)
```

### Logs Evidence
Orders service logs show consistent pattern for each failure:
1. Order creation (CREATED status)
2. Status update to PENDING
3. Payment authorization attempt
4. Connection refused error
5. Status update to PAYMENT_FAILED

---

## 🎯 DATADOG INVESTIGATION COMMANDS

### SECTION 1: LOGS ANALYSIS

#### Query 1: Find All Payment Failures (Today's Incident)
**Datadog URL**: https://us5.datadoghq.com/logs

**Query**:
```
kube_namespace:sock-shop service:sock-shop-orders "status updated to PAYMENT_FAILED"
```

**Time Range**: Past 3 hours (or 08:00 - 09:00 UTC)

**Expected Results**: 5 WARN logs showing status transitions to PAYMENT_FAILED

**What to Look For**:
- Order IDs: 690320ce, 690320ea, 69032142, 690321a3, 690321b0
- Timestamps matching the incident window (08:24:46 - 08:28:32)
- Error reason: "Connection refused"

---

#### Query 2: Find Connection Refused Errors
**Query**:
```
kube_namespace:sock-shop service:sock-shop-orders "Connection refused"
```

**Time Range**: Past 3 hours

**Expected Results**: 5 ERROR logs showing `java.net.ConnectException: Connection refused`

**What to Look For**:
- Full stack traces showing connection attempts to payment service
- POST request to `http://payment:80/paymentAuth`
- Target IP: 10.96.100.12:80 (payment service ClusterIP)

---

#### Query 3: Specific Order Timeline (Example: First Failed Order)
**Query**:
```
kube_namespace:sock-shop "690320cee2c84800016ceb4a"
```

**Time Range**: Past 3 hours

**Expected Results**: Complete lifecycle logs for this specific order

**What to Look For**:
1. `Order created with ID: 690320cee2c84800016ceb4a and status: Created`
2. `Order 690320cee2c84800016ceb4a status updated to PENDING`
3. `Sending payment request for order 690320cee2c84800016ceb4a`
4. `Payment failed for order 690320cee2c84800016ceb4a: Connection refused`
5. `Order 690320cee2c84800016ceb4a status updated to PAYMENT_FAILED`

---

#### Query 4: All Orders Service Errors
**Query**:
```
kube_namespace:sock-shop service:sock-shop-orders "ERROR"
```

**Time Range**: Past 3 hours

**Expected Results**: All ERROR-level logs from orders service (not just payment failures)

**Note**: Due to log parsing issue, use text search for "ERROR" instead of status:error facet

---

#### Query 5: Payment Service Downtime Evidence
**Query**:
```
kube_namespace:sock-shop service:sock-shop-payment
```

**Time Range**: Past 3 hours

**Expected Results**: 
- **NO logs** during incident window (08:24 - 08:29)
- Last logs before scaling down
- First logs after scaling back up (when recovery happens)

**What to Look For**:
- Gap in logs corresponding to payment service downtime
- Pod termination/startup events

---

#### Query 6: Front-End Order Processing
**Query**:
```
kube_namespace:sock-shop service:sock-shop-front-end "order"
```

**Time Range**: Past 3 hours

**Expected Results**: Front-end logs showing order POST requests

**What to Look For**:
- POST /orders requests
- Response codes (should be 500 for failed orders)
- Response times (may be higher due to connection timeout)

---

#### Query 7: Multi-Service Transaction View (Specific Order)
**Query**:
```
kube_namespace:sock-shop "690321a3e2c84800016ceb4d"
```

**Time Range**: Past 3 hours

**Expected Results**: Logs from multiple services for this order:
- front-end: Received order request
- orders: Order creation, payment attempt, failure
- user: Address/card/customer lookup
- carts: Cart retrieval

---

### SECTION 2: METRICS ANALYSIS

#### Metric 1: Payment Service Pod Count
**Datadog URL**: https://us5.datadoghq.com/metric/explorer

**Metric**: `kubernetes.pods.running`

**Filter**: 
```
kube_namespace:sock-shop 
deployment:payment
```

**Time Range**: Past 3 hours

**Expected Graph**: 
- Flat line at 1 before incident
- **Drop to 0** at ~08:24
- Remains at 0 during incident
- Return to 1 after recovery

---

#### Metric 2: Orders Service CPU Usage
**Metric**: `kubernetes.cpu.usage`

**Filter**:
```
kube_namespace:sock-shop
pod_name:orders-7f74f9b69c-k7vh5
```

**Time Range**: Past 3 hours

**Expected Graph**:
- Spikes during order processing attempts
- May show increased CPU during connection timeout handling

---

#### Metric 3: Orders Service Memory
**Metric**: `kubernetes.memory.usage`

**Filter**:
```
kube_namespace:sock-shop
pod_name:orders-7f74f9b69c-k7vh5
```

**Time Range**: Past 3 hours

**Expected Graph**: Stable memory usage (no memory leak from failures)

---

#### Metric 4: Network Metrics (Orders Service)
**Metric**: `kubernetes.network.rx_bytes` or `kubernetes.network.tx_bytes`

**Filter**:
```
kube_namespace:sock-shop
pod_name:orders-7f74f9b69c-k7vh5
```

**Time Range**: Past 3 hours

**Expected Graph**: 
- Spikes during order placement attempts
- Lower than normal (no successful payment communication)

---

#### Metric 5: Container Restart Count
**Metric**: `kubernetes.containers.restarts`

**Filter**:
```
kube_namespace:sock-shop
deployment:payment
```

**Time Range**: Past 3 hours

**Expected Graph**: 
- Should remain at 0 (no restarts, deliberate scale-down)

---

### SECTION 3: INFRASTRUCTURE VIEWS

#### View 1: Kubernetes Explorer
**URL**: https://us5.datadoghq.com/orchestration/explorer

**Filters**:
```
kube_cluster_name:sockshop-kind
kube_namespace:sock-shop
```

**What to Check**:
1. **Deployments View**:
   - payment: 0/0 replicas (scaled down)
   - orders: 1/1 replicas (running)
   - All others: Normal

2. **Pods View**:
   - No payment pods during incident
   - Orders pod healthy (no restarts)

3. **Services View**:
   - payment service exists but has no endpoints
   - orders service healthy

---

#### View 2: Container Monitoring
**URL**: https://us5.datadoghq.com/containers

**Filter**:
```
kube_namespace:sock-shop
```

**What to Check**:
1. **Payment Containers**: Should show 0 running containers during incident
2. **Orders Containers**: Should show 1 running container, stable
3. **Resource Usage**: No unusual spikes in orders service

---

#### View 3: Infrastructure List
**URL**: https://us5.datadoghq.com/infrastructure

**Filter**:
```
kube_cluster_name:sockshop-kind
```

**What to Check**:
1. **Hosts**: 
   - sockshop-control-plane (healthy)
   - sockshop-worker (healthy)

2. **Host Metrics**: 
   - CPU/Memory stable across both nodes
   - No host-level issues

---

### SECTION 4: EVENTS (If Configured)

#### Event Stream
**URL**: https://us5.datadoghq.com/event/stream

**Filter**:
```
sources:kubernetes
kube_namespace:sock-shop
tags:deployment:payment
```

**Expected Events**:
- `ScalingReplicaSet` event: Scaled payment from 1 to 0
- Pod termination events
- (After recovery): Scaled payment from 0 to 1
- Pod creation/startup events

---

### SECTION 5: ADVANCED QUERIES

#### Query 8: All Failed Orders Summary
**Query**:
```
kube_namespace:sock-shop service:sock-shop-orders "Order" "status updated to PAYMENT_FAILED"
```

**Time Range**: Past 3 hours

**Action**: Export logs to CSV or JSON for reconciliation report

---

#### Query 9: Payment Authorization Attempts
**Query**:
```
kube_namespace:sock-shop service:sock-shop-orders "Sending payment request for order"
```

**Time Range**: Past 3 hours

**Expected Results**: Should show 5 payment authorization attempts during incident

---

#### Query 10: Compare Success vs Failure
**Query for Success** (before incident):
```
kube_namespace:sock-shop service:sock-shop-orders "payment successful"
```

**Query for Failure** (during incident):
```
kube_namespace:sock-shop service:sock-shop-orders "Payment failed"
```

**Time Range**: Past 6 hours

**Analysis**: Compare patterns between successful and failed orders

---

## 📊 KEY DATADOG VISUALIZATIONS TO CREATE

### Dashboard 1: Incident Overview
Create a dashboard with:
1. Payment service pod count (timeseries)
2. Orders service error rate (timeseries)
3. Order status distribution (pie chart: PAID vs PAYMENT_FAILED)
4. Network connectivity to payment service (binary: up/down)

### Dashboard 2: Transaction Flow Health
1. Order creation rate (orders/minute)
2. Payment success rate (%)
3. Average order processing time
4. Failed transaction count

---

## 💡 DATADOG BEST PRACTICES LEARNED

### 1. Service Tag Naming
- ✅ Correct: `service:sock-shop-orders`
- ❌ Incorrect: `service:orders`
- **Lesson**: Always verify actual service tag names in facets

### 2. Log Level Parsing
- **Issue**: Datadog not parsing Spring Boot log format
- **Workaround**: Search by log message content, not status facets
- **Future**: Create custom log pipeline for Spring Boot format

### 3. Source of Truth
- **UI**: Can show cached/incorrect data
- **Database/API**: Always the source of truth
- **Datadog Logs**: Provides complete transaction timeline

### 4. Multi-Service Correlation
- Use order IDs to trace requests across services
- Search by specific order ID to see full lifecycle
- Identify bottlenecks and failure points

---

## 🔧 RECOVERY PROCEDURES

### Step 1: Restore Payment Service (To Be Executed)
```powershell
kubectl -n sock-shop scale deployment payment --replicas=1
kubectl -n sock-shop get pods -l name=payment -w
```

**Expected**: Payment pod starts and reaches Running state

### Step 2: Verify Payment Service Health
```powershell
kubectl -n sock-shop run test-payment-health --rm -it --image=curlimages/curl --restart=Never -- curl -s http://payment:80/health
```

**Expected**: `{"health":[{"service":"payment","status":"OK",...}]}`

### Step 3: Test Successful Order
- Place a new order via UI
- Verify it completes successfully with PAID status
- Check shipment is created

### Step 4: Export Failed Orders
```powershell
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders | Out-File orders-backup.json
```

---

## 📝 RECOMMENDATIONS

### Immediate (Critical)
1. **Implement Retry Logic**: Add exponential backoff retry for payment calls
2. **Add Circuit Breaker**: Prevent cascading failures with Hystrix/Resilience4j
3. **Fix UI Error Display**: Ensure users see payment errors immediately
4. **Fix UI Caching**: Update UI to fetch real-time order status

### Short-Term (High Priority)
1. **Idempotent Payments**: Add idempotency keys to prevent double charges
2. **Payment Queue**: Implement async payment processing with retry queue
3. **Enhanced Monitoring**: Add alerts for payment service availability
4. **User Notifications**: Email customers about payment failures

### Long-Term (Strategic)
1. **Saga Pattern**: Implement distributed transaction compensation
2. **Event Sourcing**: Maintain audit trail of all order state transitions
3. **Payment Gateway Integration**: Add webhook support for async payment status
4. **Datadog Log Pipeline**: Create custom parser for Spring Boot logs

---

## 📄 INCIDENT CLOSURE CHECKLIST

- [x] Incident reproduced successfully
- [x] Failed orders documented
- [x] Root cause identified
- [x] Datadog queries validated
- [ ] Payment service restored (pending)
- [ ] Recovery verified with successful order (pending)
- [ ] Failed orders exported (pending)
- [ ] Incident report shared with team (pending)
- [ ] Post-mortem scheduled (pending)

---

## 🔗 REFERENCES

- **Incident Guide**: INCIDENT-3-PAYMENT-FAILURE.md
- **Orders Service**: d:\sock-shop-demo\manifests\base\orders-deployment.yaml
- **Datadog Dashboard**: https://us5.datadoghq.com/dashboard
- **Kubernetes Cluster**: kind cluster "sockshop"

---

**Report Generated**: 2025-10-30T08:30:00Z  
**Next Action**: Restore payment service and verify recovery  
**Owner**: parvaiz  
**Status**: Investigation Complete, Awaiting Recovery
