# Sock Shop User Journey Failure Scenarios

## Executive Summary

- The Sock Shop platform comprises eight microservices, four data stores, and RabbitMQ-backed asynchronous flows that collectively deliver browse → cart → checkout → fulfillment experiences for end users.@README.md#48-125
- Comprehensive incident guides already exist for middleware queue blockage (Incident 5A), autoscaling misconfiguration (Incident 7), and database performance degradation (Incident 8). Each aligns exactly with the requested user-journey failure modes and contains deterministic reproduction instructions.@INCIDENT-5A-QUEUE-BLOCKAGE.md#1-354 @INCIDENT-7-AUTOSCALING-FAILURE.md#1-607 @INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#1-656
- This report synthesizes architectural understanding, validates incident coverage against requirements, and consolidates reproduction and observability plans so the SRE agent can prove rapid MTTR on user-facing degradations.

## Methodological Approach

1. **Inventory & context mapping** – Parsed repository documentation, deployment manifests, and incident runbooks to catalogue components, dependencies, and observability hooks.
2. **Framework-driven analysis** – Evaluated incidents through the Four Golden Signals (latency, traffic, errors, saturation) and socio-technical lenses (business impact, infrastructure misconfiguration, data tier health).
3. **Cross-verification** – Matched requirements word-for-word against incident narratives, reproduction steps, and evidence artifacts to eliminate ambiguity or hallucination.
4. **Counterfactual testing** – Considered alternate root causes and validation steps to ensure scenarios truly exercise the specified failure class.

## Core Architecture & Workflow

### Microservices and Responsibilities

- **front-end (Node.js)** – Traffic ingress, renders catalogue, checkout, order history.@README.md#81-124
- **catalogue (Go)** – Product listing/search API backed by MariaDB.@README.md#95-124
- **user (Go)** – Authentication and profile management over MongoDB.@README.md#95-124
- **carts (Java)** – Shopping cart persistence via Redis.@README.md#95-124
- **orders (Java)** – Order lifecycle orchestration and RabbitMQ publisher.@README.md#95-124
- **payment (Go)** – Gateway simulator invoked synchronously by orders.@README.md#95-124
- **shipping (Java)** and **queue-master (Java)** – Asynchronous fulfillment consumers driven by RabbitMQ queues.@README.md#95-124

### Data Stores & Messaging

- **MariaDB (catalogue-db)** for product catalogue content.@README.md#100-107
- **MongoDB replicas** for user, carts, and orders state.@README.md#95-124
- **Redis session-db** for cart/session caching.@README.md#100-106
- **RabbitMQ** mediates order fulfillment via the `shipping-task` queue.@README.md#108-110

### Observability Fabric

- Prometheus, Grafana, and Datadog capture metrics, logs, and Kubernetes events for all services, including RabbitMQ queue depth and HPA metrics.@README.md#56-136
- Incident runbooks leverage Datadog metrics such as `rabbitmq.queue.messages`, `kubernetes.cpu.usage.total`, and Kubernetes events for deployments/HPA to drive SRE agent investigations.@INCIDENT-5A-QUEUE-BLOCKAGE.md#109-148 @INCIDENT-7-AUTOSCALING-FAILURE.md#161-343 @INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#272-393

### End-to-End Order Journey Baseline

1. Customer submits order through front-end.
2. Orders service validates payment, persists state in Mongo, and publishes to RabbitMQ.
3. Queue-master consumes messages, invokes shipping, which finalizes fulfillment and updates status back to orders DB.@INCIDENT-5-ASYNC-PROCESSING-FAILURE.md#48-110

Understanding this base flow is essential for reasoning about queue blockages, HPA failures, and catalogue bottlenecks.

## Incident Alignment Review

### Incident 5A – Middleware Queue Blockage

**Requirement:** “Customer order processing stuck in middleware queue due to blockage in a queue/topic.”

**Runbook Evidence:** Incident 5A explicitly constrains RabbitMQ (`max-length:3`, `overflow:reject-publish`) and simultaneously removes the consumer, producing a queue at capacity with rejected publishes and no downstream shipping progress.@INCIDENT-5A-QUEUE-BLOCKAGE.md#56-105

**Alignment Verdict:** **Exact match.** Orders 1–3 remain stranded in the queue, orders 4+ are rejected, and the UI continues to report success, modeling a real middleware blockage with user-visible fulfillment failure.@INCIDENT-5A-QUEUE-BLOCKAGE.md#14-32

**Reproduction Blueprint:**
1. Apply restrictive policy on `shipping-task` queue.
2. Scale `queue-master` deployment to zero replicas.
3. Generate ≥5 orders through UI or provided Locust job.
4. Verify queue depth stuck at three and consumer count at zero.@INCIDENT-5A-QUEUE-BLOCKAGE.md#56-105

**Diagnostics & Observability:**
- RabbitMQ metrics flatline at capacity and consumer count drops to zero.@INCIDENT-5A-QUEUE-BLOCKAGE.md#109-133
- Datadog events confirm queue-master scale-down; logs show absence of consumer activity.
- Orders DB retains `pending` status, confirming business backlog.

**SRE Agent Reasoning Path:**
1. Correlate missing queue-master replicas with queue saturation.
2. Interpret silent failure (no HTTP errors) as asynchronous pipeline issue.
3. Recommend removing policy and restoring consumer replicas, followed by queue drain validation.@INCIDENT-5A-QUEUE-BLOCKAGE.md#256-304

**Counterarguments Addressed:**
- *What if only the consumer is down?* That is Incident 5; 5A adds capacity enforcement to ensure actual blockage (rejections + stuck messages).
- *Could network issues mimic this?* The policy + consumer shutdown create deterministic RabbitMQ errors (406 PRECONDITION_FAILED) proving queue-level root cause.

**Trade-offs & Mitigations:** Increasing queue capacity or adding dead-lettering mitigates the immediate symptom but must be paired with better error propagation and autoscaling to prevent silent failures.@INCIDENT-5A-QUEUE-BLOCKAGE.md#223-252

### Incident 7 – Autoscaling Failure During Traffic Spike

**Requirement:** “Autoscaling not triggering during traffic spikes (Kubernetes-based; load can be simulated with JMeter).”

**Runbook Evidence:** Incident 7 deploys an HPA misconfigured to watch memory instead of CPU. Under a 750-user load test, CPU saturates at 300m while memory stays near 60%, so replicas never scale beyond one and the pod repeatedly crashes.@INCIDENT-7-AUTOSCALING-FAILURE.md#12-143

**Alignment Verdict:** **Exact match.** The HPA is present but ineffective, capturing the scenario where autoscaling fails despite traffic surge because the wrong metric is targeted.@INCIDENT-7-AUTOSCALING-FAILURE.md#12-27

**Reproduction Blueprint:**
1. Apply `incident-7-broken-hpa.yaml` to monitor memory.
2. Launch high-concurrency load (Locust job equivalent to JMeter) at 750 users.
3. Observe CPU pegged at 100% with no replica increase while pods crash/restart.
4. Capture HPA status showing low memory utilization and replicas stuck at one.@INCIDENT-7-AUTOSCALING-FAILURE.md#73-143

**Diagnostics & Observability:**
- Datadog metrics show CPU saturating and replicas flat at one.@INCIDENT-7-AUTOSCALING-FAILURE.md#161-211
- HPA telemetry reveals monitored metric `memory` with current values below target.@INCIDENT-7-AUTOSCALING-FAILURE.md#214-250
- Logs expose Node.js OOM / timeout errors confirming user impact.@INCIDENT-7-AUTOSCALING-FAILURE.md#273-299

**SRE Agent Reasoning Path:**
1. Validate user-facing failures via log spikes and restarts.
2. Inspect HPA configuration to detect metric mismatch.
3. Recommend switching to CPU-based HPA and retesting to confirm automatic horizontal scaling.@INCIDENT-7-AUTOSCALING-FAILURE.md#366-472

**Counterarguments Addressed:**
- *Could traffic simply exceed cluster capacity?* The remedial run with the fixed HPA scales to eight replicas and restores performance, proving misconfiguration rather than capacity shortage.@INCIDENT-7-AUTOSCALING-FAILURE.md#395-472
- *Is manual scaling sufficient?* Manual scaling masks the underlying control-plane gap; the scenario validates HPA governance and alerting needs.

**Trade-offs & Mitigations:** Permanent fix involves reviewing HPA metrics, setting alerts for “high CPU + no scaling events,” and load-testing autoscaling profiles ahead of peak traffic.@INCIDENT-7-AUTOSCALING-FAILURE.md#490-553

### Incident 8 – Catalogue Database Performance Degradation

**Requirement:** “Product search slowness due to database latency or connection pool exhaustion.”

**Runbook Evidence:** Incident 8 caps catalogue-db CPU at 50m, driving sustained 100% CPU usage, multi-second query latency, catalogue service timeouts, and front-end 500/504 errors. User experience degrades for product browsing/search.
@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#12-27 @INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#141-269

**Alignment Verdict:** **Exact match.** Slow catalogue queries originate from deliberate database resource starvation, reproducing the targeted product search latency failure.

**Reproduction Blueprint:**
1. Patch catalogue-db deployment with restrictive CPU/memory limits.
2. Generate sustained catalogue traffic (manual browsing or provided Locust script).
3. Observe query latency spikes, connection timeouts, and front-end errors.
4. Record incident window for observability correlation.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#141-269

**Diagnostics & Observability:**
- Datadog shows CPU pegged at 50m (100% of limit) for catalogue-db, with cascading catalogue/front-end errors.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#272-393
- Logs reveal circuit breaker openings and database connection errors confirming database-origin latency.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#336-399

**SRE Agent Reasoning Path:**
1. Start from user complaint (“slow product pages”), trace front-end logs to catalogue errors, then to database saturation.
2. Quantify latency regression (50ms → 4.5s) and connection pool stress.
3. Recommend increasing resources and adding slow-query observability for prevention.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#450-567

**Counterarguments Addressed:**
- *Could application code cause latency?* Restoring CPU limit to 500m immediately normalizes response time, confirming infrastructure bottleneck.
- *What about connection pool exhaustion?* The runbook notes that slow queries consume connections longer, leading to pool exhaustion—part of the intended failure mode.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#484-505

**Trade-offs & Mitigations:** Balance between cost (resource limits) and performance, add indexes, enable slow-query logging, and consider auto-scaling or caching to absorb spikes.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#640-648

## Comparative Insights & Practical Considerations

- **Business-first detection:** All three incidents manifest as user complaints (orders not shipped, outages during spike, slow search). Monitoring must map business KPIs to technical telemetry.
- **Silent vs. loud failures:** Queue blockage and database throttling are silent/sneaky; autoscaling misconfig presents loudly with crashes. The SRE agent must adapt investigation strategies accordingly.
- **Countermeasure hierarchy:** Immediate remediation (scaling resources, removing policies) must be paired with systemic fixes (alerting, configuration checks, indexing) to prevent recurrence.
- **Resilience validation:** These incidents stress asynchronous pipelines, resource governance, and data-layer capacity—key axes for e-commerce reliability.

## Recommended Actions for SRE Agent Testing

1. **Pre-stage lab environment** with baseline health checks and ensure observability backends retain relevant metrics/logs during experiments.
2. **Automate runbooks** via scripts or GitOps to apply queue policies, HPA configs, and resource patches, reducing manual error.
3. **Instrument guardrail alerts** for RabbitMQ consumer count, HPA no-scale conditions, and catalogue-db CPU saturation, aligning with remediation sections of each incident.@INCIDENT-5A-QUEUE-BLOCKAGE.md#223-252 @INCIDENT-7-AUTOSCALING-FAILURE.md#545-553 @INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#640-648
4. **Capture before/after evidence** (metrics snapshots, log excerpts) to feed the SRE agent for post-incident evaluation and scoring.
5. **Iteratively rehearse** by combining incidents (e.g., queue blockage + database throttling) to challenge multi-signal correlation capabilities once single-fault runs are mastered.

## Appendix A – Quick Command Reference

| Incident | Trigger Commands | Load Generation | Validation Checks |
|----------|------------------|-----------------|-------------------|
| 5A – Queue Blockage | `rabbitmqctl set_policy ... max-length=3`, `kubectl scale deployment/queue-master --replicas=0` | Place 5–7 orders via UI or `load/locust-payment-failure-test.yaml` | `rabbitmqctl list_queues`, Datadog queue metrics, orders status pending.@INCIDENT-5A-QUEUE-BLOCKAGE.md#56-105 @INCIDENT-5A-QUEUE-BLOCKAGE.md#98-148 |
| 7 – Autoscaling Failure | `kubectl apply -f incident-7-broken-hpa.yaml` | `load/locust-hybrid-crash-test.yaml` (750 users) | `kubectl get hpa`, `kubectl top pods`, Datadog CPU vs replicas.@INCIDENT-7-AUTOSCALING-FAILURE.md#73-143 @INCIDENT-7-AUTOSCALING-FAILURE.md#161-211 |
| 8 – Catalogue DB Latency | `kubectl set resources deployment/catalogue-db --limits=cpu=50m,memory=128Mi` | Manual browsing or `load/incident8_db_degradation.py` | `kubectl top pod catalogue-db`, catalogue logs, Datadog latency graphs.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#141-248 @INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#272-393 |

## Appendix B – Dependency Reference

- **Order Fulfillment Pipeline:** front-end → orders → payment → RabbitMQ → queue-master → shipping → orders-db.@INCIDENT-5-ASYNC-PROCESSING-FAILURE.md#48-110
- **Autoscaling Control Plane:** front-end deployment + HPA + metrics-server delivering pod metrics for scaling decisions.@INCIDENT-7-AUTOSCALING-FAILURE.md#34-67
- **Catalogue Query Path:** front-end → catalogue service → catalogue-db (MariaDB) executing unindexed searches under constrained CPU.@INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md#38-76

These references help anchor SRE agent prompts in concrete architecture, ensuring reproducible and explainable incident simulations.
