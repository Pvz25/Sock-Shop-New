# Sock Shop Incident Simulation - Master Guide

## Overview

This guide provides comprehensive instructions for simulating three realistic production incidents in the Sock Shop e-commerce application. These incidents are designed to test and demonstrate SRE agent capabilities in identifying, diagnosing, and resolving real-world microservices issues.

**Version:** 1.0  
**Last Updated:** October 27, 2025  
**Environment:** kind cluster (sockshop) with Datadog monitoring  
**Repository:** D:\sock-shop-demo

---

## Table of Contents

1. [Purpose & Value](#purpose--value)
2. [Prerequisites](#prerequisites)
3. [Incident Overview](#incident-overview)
4. [Quick Reference](#quick-reference)
5. [Execution Workflow](#execution-workflow)
6. [Datadog Integration](#datadog-integration)
7. [SRE Agent Testing Scenarios](#sre-agent-testing-scenarios)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Purpose & Value

### Why These Incidents?

The Sock Shop application serves as a **production-like testbed** for evaluating SRE agent capabilities. These three incidents represent the most common and impactful failure scenarios in e-commerce microservices:

1. **Resource Exhaustion (Crash)** - Tests ability to detect and diagnose catastrophic failures
2. **Performance Degradation (Latency)** - Tests ability to identify subtle degradation before failure
3. **Distributed Transaction Failures (Inconsistency)** - Tests ability to trace complex multi-service issues

### Value for SRE Agent Development

| Capability | Incident 1 | Incident 2 | Incident 3 |
|------------|-----------|-----------|-----------|
| **Log Analysis** | ✅ OOMKilled events | ✅ Slow query warnings | ✅ Connection errors |
| **Metric Correlation** | ✅ CPU/Memory spikes | ✅ Latency increases | ✅ Service availability |
| **Root Cause Analysis** | ✅ Resource limits | ✅ Resource pressure | ✅ Service dependencies |
| **Impact Assessment** | ✅ Total outage | ✅ User frustration | ✅ Financial inconsistency |
| **Remediation Suggestions** | ✅ Scaling, limits | ✅ HPA, optimization | ✅ Retry logic, circuit breakers |

### Demonstration Value

For stakeholders and customers, these incidents demonstrate:
- **Real-world relevance:** These exact scenarios happen in production
- **Complexity handling:** Multi-service, distributed systems challenges
- **Actionable insights:** Not just detection, but root cause and remediation
- **Business context:** Connecting technical issues to user/business impact

---

## Prerequisites

### Infrastructure Requirements

#### 1. Kubernetes Cluster (kind)
```powershell
# Verify cluster is running
kubectl cluster-info

# Expected Output:
# Kubernetes control plane is running at https://127.0.0.1:xxxxx
```

#### 2. Sock Shop Application Deployed
```powershell
# Verify all pods running
kubectl -n sock-shop get pods

# Expected: All pods 1/1 READY, Running status
```

#### 3. Datadog Agent Configured
```powershell
# Verify Datadog agent is collecting logs (select node agent, not cluster agent)
$POD = kubectl -n datadog get pods -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | Where-Object { $_.metadata.name -like "datadog-agent-*" -and $_.metadata.name -notlike "*cluster-agent*" } | Select-Object -First 1 | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"

# Expected: LogsProcessed: [non-zero number]
```

#### 4. Port Forwards Active
```powershell
# Start port forward if not running
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'

# Verify access
Invoke-WebRequest -UseBasicParsing http://localhost:2025 -TimeoutSec 5

# Expected: StatusCode 200
```

### Knowledge Requirements

- Basic Kubernetes commands (kubectl)
- Understanding of microservices architecture
- Familiarity with Datadog UI (logs, metrics)
- PowerShell scripting basics
- HTTP/REST API concepts

### Time Requirements

| Incident | Setup | Execution | Monitoring | Recovery | Total |
|----------|-------|-----------|------------|----------|-------|
| **Incident 1** | 2 min | 5 min | 5 min | 3 min | **~15 min** |
| **Incident 2** | 2 min | 8 min | 8 min | 2 min | **~20 min** |
| **Incident 3** | 2 min | 5 min | 5 min | 3 min | **~15 min** |
| **All Three** | - | - | - | - | **~50 min** |

---

## Incident Overview

### Incident 1: Application Crash via High Load

**File:** [INCIDENT-1-APP-CRASH.md](./INCIDENT-1-APP-CRASH.md)

**Summary:** Simulate extreme user load (3000+ concurrent users) causing resource exhaustion, pod crashes, and complete service unavailability.

**Key Characteristics:**
- User Load: 3000 concurrent users
- CPU Usage: 100% (throttled)
- Memory Usage: 100% (OOMKilled)
- Pod Restarts: Multiple
- User Impact: Complete outage (HTTP 500/503)
- Recovery: Automatic (Kubernetes self-healing)

**Datadog Evidence:**
- `OOMKilled` events
- `CrashLoopBackOff` status
- Connection refused errors
- Pod restart count increases

**Use Case:** Demonstrates SRE agent's ability to identify resource limits as root cause and suggest horizontal scaling.

---

### Incident 2: Application Latency via Moderate Load

**File:** [INCIDENT-2-APP-LATENCY.md](./INCIDENT-2-APP-LATENCY.md)

**Summary:** Simulate moderate user load (750 concurrent users) causing significant performance degradation without crashes.

**Key Characteristics:**
- User Load: 750 concurrent users
- Response Time: 2-5 seconds (normal: <300ms)
- CPU Usage: 80-95% (high pressure)
- Memory Usage: 60-85% (pressure but stable)
- Pod Restarts: 0 (stays running)
- User Impact: Severe slowness, frustration
- Recovery: Automatic (load drops)

**Datadog Evidence:**
- High P95 response times (3000-5000ms)
- "Slow query" warnings
- "Connection pool exhausted" errors
- CPU throttling logs

**Use Case:** Demonstrates SRE agent's ability to detect subtle degradation and recommend performance optimizations before catastrophic failure.

---

### Incident 3: Payment Transaction Failure

**File:** [INCIDENT-3-PAYMENT-FAILURE.md](./INCIDENT-3-PAYMENT-FAILURE.md)

**Summary:** Simulate payment service failure during checkout, creating inconsistent transaction states (payment processed but order shows failed).

**Key Characteristics:**
- Trigger: Payment service scaled to 0 replicas
- Order Status: "PAYMENT_FAILED"
- Payment Status: May be captured (real-world scenario)
- Pod Restarts: 0 (partial failure)
- User Impact: Financial inconsistency, trust damage
- Recovery: Manual (service restoration + reconciliation)

**Datadog Evidence:**
- "Connection refused" to payment service
- Orders marked as "PAYMENT_FAILED"
- Service availability = 0%
- Transaction ID inconsistencies

**Use Case:** Demonstrates SRE agent's ability to trace distributed transactions and identify data inconsistencies requiring manual remediation.

---

## Quick Reference

### Incident Comparison Matrix

| Aspect | Incident 1 (Crash) | Incident 2 (Latency) | Incident 3 (Payment) |
|--------|-------------------|---------------------|---------------------|
| **Load Tool** | Locust (3000 users) | Locust (750 users) | Manual or Locust (10 users) |
| **Duration** | 5 minutes | 8 minutes | 2 minutes |
| **Pods Restart?** | ✅ Yes (multiple) | ❌ No | ❌ No |
| **Error Rate** | 60%+ | <5% | 100% (payment calls) |
| **Recovery Type** | Automatic | Automatic | Manual |
| **Data Consistency** | ✅ Intact | ✅ Intact | ❌ Inconsistent |
| **Financial Impact** | None | None | High (potential) |
| **Complexity** | Low | Medium | High |
| **Demo Value** | High (dramatic) | Medium (subtle) | Critical (realistic) |

### Command Quick Reference

```powershell
# Start an incident
cd d:\sock-shop-demo\load
kubectl apply -f locust-<incident>-test.yaml

# Monitor pods
kubectl -n sock-shop get pods -w

# Monitor resources
kubectl top pods -n sock-shop

# Monitor logs
kubectl -n sock-shop logs -f deployment/<service-name>

# Stop incident
kubectl -n sock-shop delete job locust-<incident>-test

# Force recovery (if needed)
kubectl -n sock-shop rollout restart deployment/<service-name>

# Clean up
kubectl -n sock-shop delete configmap locustfile-<incident>
```

### Datadog Query Quick Reference

```
# Incident 1 - OOMKilled events
source:kubernetes OOMKilled kube_namespace:sock-shop

# Incident 2 - High latency
kube_namespace:sock-shop response_time:>2000

# Incident 3 - Payment failures
kube_namespace:sock-shop service:orders "PAYMENT_FAILED"

# General error search
kube_namespace:sock-shop status:error
```

---

## Execution Workflow

### Recommended Execution Sequence

**For comprehensive SRE agent testing, execute in this order:**

#### Phase 1: Baseline Establishment (5 minutes)
```powershell
# 1. Verify environment
kubectl -n sock-shop get pods
kubectl top pods -n sock-shop
Invoke-WebRequest -UseBasicParsing http://localhost:2025

# 2. Document baseline
# - All pods: 1/1 Running
# - CPU: 3-8m per pod
# - Memory: 50-200Mi per pod
# - Response time: 100-300ms

# 3. Open Datadog
# URL: https://us5.datadoghq.com/logs
# Query: kube_namespace:sock-shop
# Set to "Live Tail"
```

#### Phase 2: Execute Incident 1 - Crash (15 minutes)

**Goal:** Demonstrate catastrophic failure detection and recovery

```powershell
# Navigate to incident guide
cd d:\sock-shop-demo
code INCIDENT-1-APP-CRASH.md

# Execute steps from guide
# Key observation points:
# - Watch pods go from Running → CrashLoopBackOff
# - Monitor resource usage hitting 100%
# - Observe OOMKilled events
# - Verify application becomes unreachable
# - Watch Kubernetes self-healing (pod restarts)

# Recovery verification:
# - Pods return to Running
# - Resources return to baseline
# - Application accessible again
```

**SRE Agent Test Questions:**
1. "Why did the application crash at 10:23 AM?"
2. "How many pod restarts occurred during the incident?"
3. "What resource limits were exceeded?"
4. "How would you prevent this in production?"

#### Phase 3: Execute Incident 2 - Latency (20 minutes)

**Goal:** Demonstrate subtle performance degradation detection

```powershell
# Navigate to incident guide
code INCIDENT-2-APP-LATENCY.md

# Execute steps from guide
# Key observation points:
# - Response times increase but NO crashes
# - CPU/Memory high but stable (not exceeding limits)
# - Users can complete actions but very slowly
# - No pod restarts (RESTARTS=0)
# - Datadog shows "slow query" warnings

# Recovery verification:
# - Response times normalize
# - Resources drop to baseline
# - No restarts occurred throughout
```

**SRE Agent Test Questions:**
1. "Users are complaining the site is slow. What's happening?"
2. "Why are response times 3+ seconds?"
3. "Will the application crash if we don't intervene?"
4. "What optimizations would reduce latency?"

#### Phase 4: Execute Incident 3 - Payment Failure (15 minutes)

**Goal:** Demonstrate distributed transaction failure and data inconsistency

```powershell
# Navigate to incident guide
code INCIDENT-3-PAYMENT-FAILURE.md

# Execute steps from guide
# Key observation points:
# - Payment service goes down (0 replicas)
# - Orders created but marked "PAYMENT_FAILED"
# - No pod crashes (partial failure)
# - Users see payment errors
# - Datadog shows "connection refused" to payment

# Recovery verification:
# - Payment service restored
# - New orders process successfully
# - FAILED orders identified for remediation
```

**SRE Agent Test Questions:**
1. "User says they were charged but no order confirmation. Investigate order ID: 68f35ed59c10d300018b7011"
2. "What caused payment failures between 11:20-11:30?"
3. "How many orders are in PAYMENT_FAILED status?"
4. "What should we do about failed transactions?"

#### Phase 5: SRE Agent Demonstration (30 minutes)

**Now use the collected data to test your SRE agent:**

1. **Log Analysis:** Point agent to Datadog, provide time ranges
2. **Root Cause ID:** Ask "What caused X incident?"
3. **Impact Assessment:** Ask "How many users were affected?"
4. **Remediation:** Ask "How do we prevent this?"
5. **Documentation:** Ask agent to create incident report

---

## Datadog Integration

### Key Datadog Features Utilized

#### 1. Log Collection
- **Source:** All sock-shop namespace containers
- **Filters:** `kube_namespace:sock-shop`
- **Use:** Transaction tracing, error identification, timeline reconstruction

#### 2. Metrics Collection
- **CPU/Memory:** `kubernetes.cpu.usage.total`, `kubernetes.memory.usage`
- **Response Times:** `trace.http.request.duration`
- **Error Rates:** `trace.http.request.errors`

#### 3. Event Collection
- **Kubernetes Events:** Pod crashes, OOMKilled, restarts
- **Filter:** `source:kubernetes kube_namespace:sock-shop`

### Datadog Dashboard Setup (Optional)

Create a custom dashboard for incident monitoring:

**Dashboard Name:** "Sock Shop Incident Monitoring"

**Widget 1: Pod Status**
```
Query: kubernetes.containers.running{kube_namespace:sock-shop}
Type: Timeseries
```

**Widget 2: CPU Usage**
```
Query: avg:kubernetes.cpu.usage.total{kube_namespace:sock-shop} by {pod_name}
Type: Timeseries
Alert: > 250m for 5 minutes
```

**Widget 3: Response Time (P95)**
```
Query: trace.http.request.duration{kube_namespace:sock-shop}.p95
Type: Timeseries
Alert: > 1000ms for 3 minutes
```

**Widget 4: Error Log Count**
```
Query: status:error kube_namespace:sock-shop
Type: Top List (by service)
```

**Widget 5: Pod Restart Count**
```
Query: sum:kubernetes.containers.restarts{kube_namespace:sock-shop} by {pod_name}
Type: Query Value
```

### Saved Datadog Queries

Create these saved views in Datadog Logs:

**View 1: "Incident 1 - Crash Events"**
```
kube_namespace:sock-shop (OOMKilled OR CrashLoopBackOff OR "out of memory")
```

**View 2: "Incident 2 - Performance Issues"**
```
kube_namespace:sock-shop (response_time:>1000 OR "slow query" OR "connection pool")
```

**View 3: "Incident 3 - Payment Failures"**
```
kube_namespace:sock-shop ("PAYMENT_FAILED" OR "connection refused" AND service:payment)
```

**View 4: "All Errors"**
```
kube_namespace:sock-shop status:error
```

---

## SRE Agent Testing Scenarios

### Testing Methodology

For each incident, test the SRE agent's ability to:

1. **Detect:** Identify that an incident is occurring
2. **Diagnose:** Determine root cause from logs/metrics
3. **Assess Impact:** Quantify user/business impact
4. **Remediate:** Suggest concrete fix actions
5. **Prevent:** Recommend architectural improvements

### Sample Agent Prompts

#### Incident 1 Testing Prompts

**Basic Detection:**
> "What happened to the Sock Shop application at [incident time]?"

**Expected Agent Response:**
- Detected pod crashes and restarts
- Identified OOMKilled events
- Found CPU/Memory at limits
- Concluded: Resource exhaustion under high load

**Root Cause Analysis:**
> "Why did front-end pod crash?"

**Expected Agent Response:**
- Memory limit: 1000Mi
- Peak usage: 1000Mi+ (exceeded)
- Contributing factor: 3000 concurrent users
- No horizontal scaling configured

**Remediation:**
> "How do we prevent this crash in production?"

**Expected Agent Response:**
1. Increase resource limits (+50%)
2. Implement HorizontalPodAutoscaler (2-10 replicas)
3. Add request rate limiting
4. Configure resource requests/limits appropriately

---

#### Incident 2 Testing Prompts

**Performance Investigation:**
> "Users are reporting the website is very slow. Can you investigate?"

**Expected Agent Response:**
- Detected high P95 response times (3-5 seconds)
- CPU usage: 80-95% (high pressure, throttling)
- Found "slow query" and "connection pool" warnings
- Pods NOT crashing (stays running)
- Concluded: Resource pressure under moderate load

**Comparison Question:**
> "Is this the same issue as the crash we had earlier?"

**Expected Agent Response:**
- No, different severity
- Crash: 3000 users, 100% resource, pods restart
- Latency: 750 users, 80-95% resource, pods stable
- Both indicate need for scaling, but latency is early warning

---

#### Incident 3 Testing Prompts

**Transaction Investigation:**
> "A customer says they were charged $29.99 but didn't receive order confirmation for order ID 68f35ed59c10d300018b7011. Please investigate."

**Expected Agent Response:**
1. Queried logs for order ID: 68f35ed59c10d300018b7011
2. Found: Order created, status: PAYMENT_FAILED
3. Root cause: Payment service was unavailable (connection refused)
4. Timeline: Order created → Payment call failed → Order marked failed
5. Recommendation: 
   - Verify with payment gateway if charge actually processed
   - If charged: Manually mark order PAID and fulfill
   - If not charged: Notify customer, request re-order

**Architectural Improvement:**
> "How do we prevent payment failures from creating inconsistent states?"

**Expected Agent Response:**
1. Implement retry logic with exponential backoff
2. Add circuit breaker to payment service calls
3. Use idempotency keys to prevent double charges
4. Implement saga pattern for distributed transactions
5. Add payment queue with dead letter queue (DLQ)
6. Daily reconciliation between orders and payment gateway

---

## Best Practices

### Before Running Incidents

1. **Coordinate with Team:**
   - Notify team members about testing
   - Don't run on production or shared environments
   - Schedule during low-activity periods

2. **Snapshot Current State:**
   ```powershell
   # Save current state
   kubectl -n sock-shop get all -o yaml > backup-pre-incident.yaml
   
   # Document resource usage
   kubectl top pods -n sock-shop > baseline-resources.txt
   ```

3. **Verify Monitoring:**
   - Confirm Datadog is collecting logs
   - Test Datadog query access
   - Ensure sufficient Datadog log retention

4. **Prepare Recovery Commands:**
   - Keep recovery commands ready
   - Have rollback plan documented
   - Test recovery in advance

### During Incident Execution

1. **Document Everything:**
   - Screenshot Datadog dashboards
   - Record timestamps of key events
   - Save Locust reports
   - Capture kubectl output

2. **Multiple Windows:**
   - Window 1: Pod monitoring (`kubectl get pods -w`)
   - Window 2: Resource monitoring (`kubectl top pods`)
   - Window 3: Log streaming (`kubectl logs -f`)
   - Window 4: Datadog browser

3. **Controlled Execution:**
   - Follow playbook step-by-step
   - Don't skip verification steps
   - Wait for expected outcomes before proceeding

### After Incident Completion

1. **Verify Complete Recovery:**
   ```powershell
   # All pods running
   kubectl -n sock-shop get pods
   
   # Resources normalized
   kubectl top pods -n sock-shop
   
   # Application accessible
   Invoke-WebRequest -UseBasicParsing http://localhost:2025
   ```

2. **Clean Up Resources:**
   ```powershell
   # Delete test jobs
   kubectl -n sock-shop delete job --all
   
   # Delete test configmaps
   kubectl -n sock-shop delete configmap -l app=locust
   ```

3. **Document Findings:**
   - What worked well?
   - What was unexpected?
   - How did SRE agent perform?
   - What improvements needed?

---

## Troubleshooting

### Common Issues

#### Issue 1: Locust Job Fails to Start

**Symptoms:**
```
Error from server (NotFound): configmaps "locustfile-xxx" not found
```

**Cause:** ConfigMap not created or wrong namespace

**Solution:**
```powershell
# Verify ConfigMap exists
kubectl -n sock-shop get configmap

# If missing, reapply the YAML
kubectl apply -f locust-<incident>-test.yaml
```

---

#### Issue 2: Incident Not Creating Expected Impact

**Symptoms:** Application still responsive, no errors in logs

**Possible Causes:**
1. Load not high enough
2. Cluster has excess capacity
3. Resource limits too generous

**Solutions:**
```powershell
# Option 1: Increase load
# Edit YAML and increase USERS value

# Option 2: Reduce resource limits (temporary)
kubectl -n sock-shop set resources deployment front-end --limits=cpu=100m,memory=200Mi

# Remember to restore after testing!
```

---

#### Issue 3: Can't Access Datadog Logs

**Symptoms:** Datadog shows no logs or "No matching results"

**Cause:** Incorrect query or time range

**Solutions:**
1. Verify time range: Set to "Past 15 minutes"
2. Simplify query: Just use `kube_namespace:sock-shop`
3. Check agent status:
   ```powershell
   kubectl -n datadog get pods
   kubectl -n datadog logs -l app.kubernetes.io/name=datadog-agent -c agent | Select-String "ERROR"
   ```

---

#### Issue 4: Application Won't Recover After Incident

**Symptoms:** Pods stuck in CrashLoopBackOff or Error state

**Solution:**
```powershell
# Force restart all deployments
kubectl -n sock-shop rollout restart deployment --all

# Wait for rollout
kubectl -n sock-shop rollout status deployment/front-end
kubectl -n sock-shop rollout status deployment/user
kubectl -n sock-shop rollout status deployment/orders

# If still failing, check events
kubectl -n sock-shop get events --sort-by='.lastTimestamp' | Select -Last 20
```

---

#### Issue 5: Port Forward Drops During Testing

**Symptoms:** Can't access http://localhost:2025

**Cause:** Port forward process terminated

**Solution:**
```powershell
# Kill existing port forwards
$ports = 2025
(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }).OwningProcess | Sort-Object -Unique | ForEach-Object { taskkill /PID $_ /F } 2>$null

# Restart port forward
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'
Start-Sleep -Seconds 5

# Verify
Invoke-WebRequest -UseBasicParsing http://localhost:2025
```

---

## Summary

This master guide provides everything needed to execute three comprehensive incident scenarios for SRE agent testing. Each incident represents a real-world production failure pattern with distinct characteristics, impacts, and remediation approaches.

### Key Takeaways

1. **Incident 1 (Crash):** Dramatic, easy to detect, demonstrates resource limit analysis
2. **Incident 2 (Latency):** Subtle, requires nuanced analysis, demonstrates performance profiling
3. **Incident 3 (Payment):** Complex, multi-service, demonstrates distributed transaction tracing

### Next Steps

1. **Initial Setup:**
   - Review [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md)
   - Ensure Datadog is configured ([DATADOG-COMMANDS-TO-RUN.md](./DATADOG-COMMANDS-TO-RUN.md))
   - Verify application health

2. **Execute Incidents:**
   - Start with Incident 1 (most straightforward)
   - Progress to Incident 2 (requires more analysis)
   - Complete with Incident 3 (most complex)

3. **Test SRE Agent:**
   - Use provided prompts
   - Evaluate detection, diagnosis, remediation capabilities
   - Document agent performance

4. **Iterate and Improve:**
   - Refine incidents based on findings
   - Add more test scenarios
   - Enhance monitoring and observability

### Additional Resources

- **Application Architecture:** [README.md](./README.md)
- **Setup Guide:** [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md)
- **Datadog Configuration:** [DATADOG-COMMANDS-TO-RUN.md](./DATADOG-COMMANDS-TO-RUN.md)
- **User Journey Scenarios:** [sockshop-user-journey-failure-scenarios.md](./sockshop-user-journey-failure-scenarios.md)

---

**Document Version:** 1.0  
**Last Updated:** October 27, 2025  
**Author:** SRE Team  
**Contact:** For questions or issues, refer to repository documentation

**Remember:** These are controlled test scenarios. Always coordinate with team members and never run on production systems!
