# INCIDENT 6 · Payment Gateway Timeout / Failure (Third-Party API Down)

## Executive Summary
| Item | Details |
| --- | --- |
| **Customer Impact** | Checkout fails; orders cannot be completed because payment authorization is refused. |
| **Root Cause** | External payment gateway (Stripe mock) is unreachable – manifests as TCP connection refused/timeouts. |
| **Distinguishing Signal** | Payment service pods remain healthy (1/1 running) while calls to `http://stripe-mock/v1/charges` fail. |
| **Business Severity** | High – no revenue can be captured while the gateway is down. |
| **Related Incidents** | Incident 3 (payment service scaled to 0). Incident 6 focuses on *external dependency* failure vs. internal service outage. |

---

## Architecture Overview
```
Browser → front-end → orders service → payment service → (HTTP POST)
                                                │
                                                └──> stripe-mock (Stripe API simulator)
```
* **Payment service image:** `sock-shop-payment-gateway:v2`
* **External gateway:** `stripe-mock` deployment (ClusterIP service). When scaled to zero, the payment service cannot reach the gateway and returns gateway errors without crashing.

### Normal Operation Flow
1. Orders service calls `POST /paymentAuth` on the payment service.
2. The payment service converts the amount to cents and sends a form-encoded request to `http://stripe-mock/v1/charges`.
3. Stripe-mock returns HTTP 200 with a Stripe-like charge object.
4. Orders service marks the order as `PAID` → shipping workflow proceeds and status becomes `SHIPPED`.

### Incident Behaviour (Gateway Down)
1. Stripe-mock deployment scaled to 0 (or otherwise unreachable).
2. Payment service HTTP calls fail (connection refused / timeout).
3. Payment service responds with `authorised: false` and `message: "Payment gateway error: ... connection refused"`.
4. Orders service sets order status to `PAYMENT_FAILED`; UI displays red banner error. Payment service pod stays healthy.

---

## Preconditions
- Kubernetes namespace: `sock-shop`
- Payment deployment using image `sock-shop-payment-gateway:v2`
- Stripe-mock deployed via `stripe-mock-deployment.yaml`
- Port-forward for UI (optional): `kubectl -n sock-shop port-forward svc/front-end 2025:80`

---

## Activation Procedure
> Use the automation script whenever possible.

```powershell
# From repo root
./incident-6-activate.ps1
```

**What the script does**
1. Validates current payment + stripe-mock replica counts.
2. Scales `deployment/stripe-mock` to 0.
3. Waits for pods to terminate and prints verification commands.

**Manual activation (fallback)**
```powershell
kubectl -n sock-shop scale deployment stripe-mock --replicas=0
kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'
```

### Expected Symptoms (after activation)
| Layer | Signal |
| --- | --- |
| **UI** | Checkout page shows `Error: Payment declined. Payment gateway error ... connection refused`. No order receipt is generated. |
| **Orders service logs** | `Payment authorization failed` entries increase. |
| **Payment service logs** | `❌ Payment gateway error: Post "http://stripe-mock/v1/charges": dial tcp ... connection refused`. |
| **Stripe-mock pods** | 0 running (deployment scaled to zero). |
| **Datadog / Metrics** | Payment service up, request latency spikes, external HTTP dependency failures increase, orders with `PAYMENT_FAILED` status appear. |
| **APM Trace** | Orders → payment→ (external call) shows outgoing HTTP client span ending in error with `connect ECONNREFUSED`. |

---

## Observability Checklist
- `kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'`
- `kubectl -n sock-shop logs deployment/payment -f`
- `kubectl -n sock-shop logs deployment/orders -f`
- Datadog dashboards:
  - Payment service dashboard → External call error rate.
  - Orders error rate / failed checkouts.
  - APM trace search: `service:payment error:true`.
- Mongo `orders-db` documents show `status: PAYMENT_FAILED` for recent orders.

---

## Recovery Procedure
```powershell
# From repo root
./incident-6-recover.ps1
```

**Script actions**
1. Scales `deployment/stripe-mock` back to 1.
2. Waits for the pod to become Ready.
3. Validates pod status and (best effort) gateway reachability.

**Manual recovery alternative**
```powershell
kubectl -n sock-shop scale deployment stripe-mock --replicas=1
kubectl -n sock-shop wait --for=condition=ready pod -l name=stripe-mock --timeout=60s
kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'
```

### Post-Recovery Validation
1. Place a test order via UI – should succeed and display `SHIPPED`.
2. Payment logs show `✅ Payment authorized: ch_...`.
3. Stripe-mock logs a 200 response for `/v1/charges` (form-encoded body).
4. Datadog APM traces show successful external HTTP dependency calls.
5. No new orders with status `PAYMENT_FAILED` after recovery.

---

## Rollback / Cleanup
- To revert to factory state, deploy the original payment image (`quay.io/powercloud/sock-shop-payment:latest`) and delete the custom payment-gateway-service image if required.
- Remove stripe-mock by deleting `stripe-mock-deployment.yaml` when the incident is no longer needed.

---

## AI SRE Detection Guidance
- **Healthy pods + failed external calls** is the key signature.
- SRE agent should classify as *Third-party dependency outage*, not internal pod crash.
- Recommended remediation playbook: failover to backup gateway or introduce retry/circuit breaker; in our sandbox we simulate recovery by scaling the gateway back up.

---

## Change Log
| Date | Change | Notes |
| --- | --- | --- |
| 2025-11-07 | Introduced stripe-mock deployment and custom payment service v2 | Enables realistic external gateway behaviour. |
| 2025-11-07 | Added automation scripts (`incident-6-activate.ps1`, `incident-6-recover.ps1`) | Provides one-command activation / recovery. |
