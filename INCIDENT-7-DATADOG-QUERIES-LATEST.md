# INCIDENT: AUTOSCALING FAILURE (INCIDENT-7)

**Time Window:** Nov 10, 2025 — 13:35 to 14:00 IST (08:05 to 08:30 UTC)  
**Environment:** Datadog `us5.datadoghq.com`, namespace `sock-shop`

---

## Datadog Facets
- `kube_namespace:sock-shop`
- `service:(sock-shop-front-end OR sock-shop-orders OR sock-shop-catalogue OR sock-shop-user OR sock-shop-payment)`
- `kube_container_name:(front-end OR orders OR catalogue OR user OR payment)`
- `source:(sock-shop-front-end OR sock-shop-orders OR sock-shop-catalogue OR sock-shop-user OR sock-shop-payment)`
- Time range: **Nov 10, 13:35–14:00 IST**

> APM (`trace.http.*`) is not instrumented. Ignore APM queries to avoid empty results.

---

## Datadog Logs — Commands & Expectations
1. `kube_namespace:sock-shop service:sock-shop-front-end status:error`  
   **Expected:** Error logs filtered by status. Timeline shows a clear spike.  
   **Examples:** ❌ `npm ERR! signal SIGTERM`, ❌ `npm ERR! command failed`, ❌ `Error with login: true`, ❌ `Error: path /usr/src/app`

2. `kube_namespace:sock-shop service:sock-shop-front-end (SIGTERM OR "Exit status" OR crashed OR error)`  
   **Expected:** Crash-focused subset confirming liveness-probe triggered restarts.

3. `kube_namespace:sock-shop service:sock-shop-catalogue`  
   **Expected:** Healthy catalogue logs; proves non-impacted services.

4. `kube_namespace:sock-shop (service:sock-shop-front-end OR service:sock-shop-orders OR service:sock-shop-catalogue)`  
   **Expected:** Combined logs; front-end dominates error volume.

5. `kube_namespace:sock-shop status:error`  
   **Expected:** Multi-service error list with Watchdog Insights attribution.

6. `kube_namespace:sock-shop service:locust`  
   **Expected:** Load test telemetry (`Slow response`, `Timeout`) confirming 750-user Locust run.

> Kubernetes liveness probe failures appear under **Infrastructure → Kubernetes → Events** (filter by `front-end`). They are not stored in the log index.

---

## Datadog Metrics — Queries & Observation Expectations
1. **CPU Saturation (Root Cause)**  
   Metric: `kubernetes.cpu.usage.total`  
   Filters: `kube_namespace:sock-shop`, `kube_deployment:front-end`  
   Aggregation: `avg by kube_deployment`  
   **Observation:** CPU hits 300m (100% limit), 10–16× baseline, drops after load stops.

2. **Memory Stability (Not the Issue)**  
   Metric: `kubernetes.memory.usage`  
   Filters/Aggregation: same as above  
   **Observation:** Baseline ≈80 MiB → incident ≈95 MiB (+15 MiB) → recovery ≈48–64 MiB.

3. **Crash Counter**  
   Metric: `kubernetes.containers.restarts`  
   Filters: same  
   Aggregation: `sum`  
   **Observation:** Step increase from 3 to 10 (7 new crashes).

4. **CPU Throttling Proof**  
   Metric: `kubernetes.cpu.cfs.throttled.seconds`  
   Filters: same  
   Aggregation: `rate`  
   **Observation:** Sharp spike during incident period.

5. **Traffic Spike Confirmation**  
   Metric: `kubernetes.network.rx_bytes`  
   Filters: same  
   Aggregation: `rate`, then `sum`  
   **Observation:** Large ingress spike aligned with Locust traffic.

6. **Replica Count (HPA Failure)**  
   Metric: `kubernetes.pods.running`  
   Filters: same  
   Aggregation: `avg`  
   **Observation:** Flatline at 1 replica—HPA never scaled out.

---

## Verification Checklist
- [ ] Error spike for `service:sock-shop-front-end` within incident window.  
- [ ] Crash signatures (`SIGTERM`, `command failed`) visible.  
- [ ] Catalogue and orders services show normal logs.  
- [ ] CPU reaches 300m while memory stays ≈30% utilized.  
- [ ] Container restarts jump from 3 → 10.  
- [ ] CPU throttling metric spikes.  
- [ ] Network RX bytes surge during Locust run.  
- [ ] Running pods remain at 1 replica.

Once all boxes are checked, Incident-7 observability evidence is complete.

---

**Document:** `INCIDENT-7-DATADOG-QUERIES-LATEST.md`  
**Last Updated:** Nov 10, 2025 — 15:13 IST
