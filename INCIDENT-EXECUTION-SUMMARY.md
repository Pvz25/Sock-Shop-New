# INCIDENT EXECUTION SUMMARY

**Execution Date:** November 29, 2025  
**Status:** ✅ ALL INCIDENTS COMPLETE

---

## INCIDENT-6: PAYMENT GATEWAY TIMEOUT

**Incident Number:** 6

**Incident Name:** Payment Gateway Timeout / Failure (Third-Party API Down)

**Time and Date of Incident:**
- **Start:** 2025-11-29 22:42:39 IST (2025-11-29 17:12:39 UTC)
- **End:** 2025-11-29 23:02:35 IST (2025-11-29 17:32:35 UTC)
- **Duration:** 19.95 minutes

**What the Incident Does:**
- Simulates external payment gateway (Stripe) becoming unavailable
- Stripe-mock deployment scaled to 0 replicas (no gateway pods running)
- Payment service remains healthy (1/1 Running) throughout incident
- All customer orders fail with "connection refused" errors
- Payment service cannot reach external gateway endpoint
- Orders marked as PAYMENT_FAILED
- Revenue blocked during outage
- Demonstrates external dependency failure vs internal service failure

**Commands to Check Logs in Datadog:**

```
kube_namespace:sock-shop pod_name:payment* "Payment gateway error"
```

```
kube_namespace:sock-shop pod_name:payment* "connection refused" "stripe-mock"
```

```
kube_namespace:sock-shop service:sock-shop-orders "PaymentResponse{authorised=false"
```

```
kube_namespace:sock-shop (pod_name:payment* OR pod_name:orders* OR pod_name:stripe-mock*) status:error
```

```
kube_namespace:sock-shop source:kubernetes kube_deployment:stripe-mock (Scaled OR ScalingReplicaSet)
```

**Commands to Check Metrics in Datadog:**

```
Metric: kubernetes_state.deployment.replicas_available
Filters: kube_namespace:sock-shop, kube_deployment:stripe-mock
Expected: 1 → 0 → 1 (drops to 0 during incident)
```

```
Metric: kubernetes.pods.running
Filters: kube_namespace:sock-shop, kube_deployment:payment
Expected: Flat line at 1 (payment service stays healthy)
```

```
Metric: kubernetes.containers.restarts
Filters: kube_namespace:sock-shop, kube_deployment:payment
Expected: Flat line (zero restarts, service stable)
```

---

## INCIDENT-5C: QUEUE BLOCKAGE

**Incident Number:** 5C

**Incident Name:** Order Processing Stuck in Middleware Queue

**Time and Date of Incident:**
- **Start:** 2025-11-30 00:05:19 IST (2025-11-29 18:35:19 UTC)
- **End:** 2025-11-30 00:22:26 IST (2025-11-29 18:52:26 UTC)
- **Duration:** 17.12 minutes

**What the Incident Does:**
- RabbitMQ queue capacity limited to 3 messages maximum
- Queue-master consumer scaled to 0 (no message processing)
- First 3 orders succeed and fill the queue to capacity (3/3)
- Queue becomes blocked at maximum capacity
- Orders 4+ are rejected by RabbitMQ with visible errors
- Users see "Due to high demand, we're experiencing delays. Your order is being processed." alerts for rejected orders
- Demonstrates literal queue blockage (queue itself blocked, not just processing)
- Automatic recovery after test window

**Commands to Check Logs in Datadog:**

```
kube_namespace:sock-shop service:shipping "rejected" OR "Message rejected"
```

```
kube_namespace:sock-shop service:orders "503" OR "HttpServerErrorException"
```

```
kube_namespace:sock-shop service:shipping ("confirmed" OR "rejected")
```

```
kube_namespace:sock-shop kube_deployment:queue-master "Scaled"
```

**Commands to Check Metrics in Datadog:**

```
Metric: rabbitmq.queue.messages
Filters: queue:shipping-task, kube_namespace:sock-shop
Expected: 0 → 1 → 2 → 3 (stays flat at 3, blocked at capacity)
```

```
Metric: rabbitmq.queue.consumers
Filters: queue:shipping-task, kube_namespace:sock-shop
Expected: 1 → 0 (consumer scaled down, stays at 0 during incident)
```

```
Metric: kubernetes.pods.running
Filters: kube_namespace:sock-shop, kube_deployment:queue-master
Expected: 1 → 0 → 1 (drops to 0 during incident, recovers to 1)
```

---

## EXECUTION STATUS

| Incident | Status | Start Time | End Time | Duration |
|----------|--------|------------|----------|----------|
| INCIDENT-6 | ✅ COMPLETE | 2025-11-29 22:42:39 IST | 2025-11-29 23:02:35 IST | 19.95 min |
| INCIDENT-5C | ✅ COMPLETE | 2025-11-30 00:05:19 IST | 2025-11-30 00:22:26 IST | 17.12 min |
| INCIDENT-5C (Run 2) | ✅ COMPLETE | 2025-11-30 11:55:00 IST | 2025-11-30 12:16:00 IST | 21.00 min |

**Status:** ✅ ALL INCIDENTS COMPLETED SUCCESSFULLY
