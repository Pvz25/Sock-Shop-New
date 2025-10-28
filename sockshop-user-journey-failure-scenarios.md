# Sock Shop User Journey Failure Scenarios

This document outlines 10 realistic user journey failure scenarios for the Sock Shop e-commerce application. Each scenario includes:
- User impact
- Steps to reproduce
- Expected behavior vs. actual behavior
- Potential root causes
- Relevant metrics to monitor
- Suggested remediation steps

## 1. High Login Latency During Peak Traffic

**User Impact**: Users experience slow login times during peak traffic periods.

**Reproduction Methods**:

### Method 1: Simulate Traffic with Locust
```bash
# Deploy Locust to simulate traffic
kubectl create -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.0/deploy/static/provider/cloud/deploy.yaml

# Create Locust configuration for login endpoint
cat <<EOF > locustfile.py
from locust import HttpUser, task, between

class LoginUser(HttpUser):
    wait_time = between(1, 2.5)
    
    @task
    def login(self):
        self.client.post("/login", {"username":"user", "password":"password"})
EOF

# Run Locust test
kubectl run locust --image=locustio/locust -n sock-shop -- \
  --host=http://front-end.sock-shop.svc.cluster.local:80 \
  --locustfile=/mnt/locustfile.py \
  --users=5000 --spawn-rate=100 --run-time=10m
```

### Method 2: Induce MongoDB CPU Pressure
```bash
# Scale down MongoDB resources
kubectl patch statefulset mongo -n sock-shop --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "100m"}]'

# Create CPU-intensive query
kubectl exec -it mongo-0 -n sock-shop -- mongo --eval "
  db.getSiblingDB('users').getCollection('users').createIndex({email: 1});
  for(i=0; i<1000000; i++) { 
    db.getSiblingDB('users').users.find({
      email: { $regex: '.*' + Math.random().toString(36).substring(7) + '@example.com' }
    }).explain('executionStats'); 
  }"
```

### Method 3: Network Latency Injection
```bash
# Install Chaos Mesh if not present
curl -sSL https://mirrors.chaos-mesh.org/v2.1.5/install.sh | bash

# Add network latency between frontend and user service
cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: frontend-user-latency
  namespace: sock-shop
spec:
  action: delay
  mode: one
  selector:
    namespaces:
      - sock-shop
    labelSelectors:
      app.kubernetes.io/name: front-end
  delay:
    latency: "2s"
    correlation: "100"
    jitter: "0ms"
  duration: "1h"
  scheduler:
    cron: "@every 1h"
  direction: to
  target:
    selector:
      namespaces:
        - sock-shop
      labelSelectors:
        app.kubernetes.io/name: user
    mode: all
EOF
```

**Expected vs Actual**:
- Expected: Login completes in < 1s
- Actual: Login takes > 5s with increased failure rate

**Potential Root Causes**:
- MongoDB user database CPU saturation
- Inefficient authentication queries
- Missing database indexes on user collection
- Service mesh/API gateway overload

**Key Metrics**:
- MongoDB CPU/Memory usage
- Login endpoint latency (p50, p95, p99)
- Authentication service error rate
- Database query execution time
  
**Validation**:
```bash
# Monitor login latency
kubectl exec -it $(kubectl get pods -n monitoring -l app=prometheus -o name | head -1) -n monitoring -- \
  curl -s 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="front-end", path="/login"}[1m])) by (le))'
```

## 2. Failed Order Processing

**User Impact**: Users receive "Order Failed" message after checkout.

**Reproduction Steps**:
1. Add items to cart and proceed to checkout
2. During payment processing, simulate network partition to payment service
3. Observe order status

**Expected vs Actual**:
- Expected: Order is processed successfully or clearly fails with retry option
- Actual: Order appears to fail but payment is processed

**Potential Root Causes**:
- Payment service timeout
- Inconsistent transaction handling
- Failed message in RabbitMQ queue
- Insufficient retry logic

**Key Metrics**:
- Payment service availability
- Order service error rate
- RabbitMQ queue depth
- Failed transaction count

## 3. Shopping Cart Data Loss

**User Impact**: Users report items disappearing from cart between sessions.

**Reproduction Steps**:
1. Add items to cart
2. Wait 30+ minutes
3. Refresh page or return to site

**Expected vs Actual**:
- Expected: Cart items persist between sessions
- Actual: Cart is empty or partially empty

**Potential Root Causes**:
- Session timeout too short
- Cart service database connection issues
- Data eviction from cache
- Failed cart synchronization between services

**Key Metrics**:
- Cart service response time
- Cache hit/miss ratio
- Database connection pool usage
- Session expiration events

## 4. Product Catalog Staleness

**User Impact**: Users see outdated product information or stock levels.

**Reproduction Steps**:
1. Update product information in admin panel
2. Browse catalog from multiple regions
3. Check if updates are consistent

**Expected vs Actual**:
- Expected: All users see updated product info within 1 minute
- Actual: Stale data persists for some users

**Potential Root Causes**:
- CDN cache TTL too high
- Cache invalidation failures
- Eventual consistency delays
- Service mesh routing issues

**Key Metrics**:
- Cache hit ratio
- Catalog update propagation time
- CDN cache age
- Service mesh health

## 5. Payment Processing Timeout

**User Impact**: Payment takes too long, causing user to abandon purchase.

**Reproduction Steps**:
1. Start a large number of concurrent checkouts
2. Introduce network latency to payment processor
3. Monitor checkout completion rate

**Expected vs Actual**:
- Expected: Payment processes in < 3s
- Actual: Payment times out after 30s

**Potential Root Causes**:
- Third-party payment gateway latency
- Circuit breaker tripping
- Connection pool exhaustion
- Inefficient payment validation

**Key Metrics**:
- Payment processing time
- Timeout error rate
- Circuit breaker state
- External API response times

## 6. Search Functionality Degradation

**User Impact**: Product search returns incomplete or slow results.

**Reproduction Steps**:
1. Index 10,000+ products
2. Execute complex search queries
3. Monitor search performance

**Expected vs Actual**:
- Expected: Search results in < 1s
- Actual: Search takes > 5s or returns partial results

**Potential Root Causes**:
- Missing search indexes
- Search cluster health issues
- Query optimization needed
- Resource constraints

**Key Metrics**:
- Search query latency
- Search error rate
- Indexing queue depth
- Search cluster health

## 7. Checkout Page Timeout

**User Impact**: Checkout page fails to load during high traffic.

**Reproduction Steps**:
1. Simulate 1000+ concurrent checkouts
2. Monitor frontend and API response times

**Expected vs Actual**:
- Expected: Checkout page loads in < 2s
- Actual: Page times out after 30s

**Potential Root Causes**:
- Frontend service overload
- API gateway timeouts
- Backend service degradation
- Resource exhaustion

**Key Metrics**:
- Frontend response time
- API gateway latency
- Error rate by endpoint
- Container/VM resource usage

## 8. Order Status Inconsistency

**User Impact**: Order status doesn't reflect actual state.

**Reproduction Steps**:
1. Place an order
2. Check status from different devices/regions
3. Compare order status information

**Expected vs Actual**:
- Expected: Consistent order status across all views
- Actual: Different statuses shown in different places

**Potential Root Causes**:
- Eventual consistency delays
- Failed state transitions
- Cache invalidation issues
- Service communication failures

**Key Metrics**:
- Order status update latency
- Event processing lag
- Inconsistent state events
- Service-to-service call success rate

## 9. User Profile Update Failures

**User Impact**: User profile updates are not saved or partially applied.

**Reproduction Steps**:
1. Update multiple profile fields
2. Save and verify changes
3. Check from different sessions

**Expected vs Actual**:
- Expected: All changes saved successfully
- Actual: Some changes lost or not persisted

**Potential Root Causes**:
- Data validation failures
- Service timeouts
- Database constraint violations
- Concurrent modification issues

**Key Metrics**:
- Profile update success rate
- Database write latency
- Validation error rate
- Concurrent update conflicts

## 10. Shipping Calculation Errors

**User Impact**: Incorrect shipping costs shown at checkout.

**Reproduction Steps**:
1. Add items to cart from different regions
2. Proceed to checkout
3. Verify shipping calculations

**Expected vs Actual**:
- Expected: Accurate shipping costs based on location
- Actual: Incorrect or missing shipping options

**Potential Root Causes**:
- Third-party shipping API failures
- Cached shipping rates
- Geocoding inaccuracies
- Service configuration errors

**Key Metrics**:
- Shipping API response time
- Calculation error rate
- Geocoding accuracy
- Cache hit/miss ratio

## Implementation Notes for Testing

1. **Load Testing**:
   - Use Locust or similar tools to simulate user traffic
   - Gradually ramp up from normal to peak load
   - Monitor system metrics during tests

2. **Chaos Engineering**:
   - Introduce network latency between services
   - Simulate service failures
   - Test circuit breakers and retry mechanisms

3. **Monitoring**:
   - Set up comprehensive logging and metrics
   - Create dashboards for key user journeys
   - Configure alerts for SLO violations

4. **Remediation**:
   - Document common failure patterns
   - Create runbooks for each scenario
   - Implement automated remediation where possible

## Conclusion

These scenarios provide a comprehensive test suite for evaluating SRE agent capabilities in identifying and resolving real-world e-commerce issues. By systematically reproducing these failure modes, you can validate your SRE agent's ability to detect, diagnose, and suggest remediation for complex, user-impacting issues in a microservices environment.
