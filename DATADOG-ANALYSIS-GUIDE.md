# Datadog Analysis Guide - INCIDENT-5 & INCIDENT-8

**Execution Date**: November 5, 2025  
**Datadog URL**: https://app.datadoghq.com  
**Datadog Region**: US5 (us5.datadoghq.com)

---

## Executive Summary

Two incidents were successfully executed and recovered:

### INCIDENT-5: Async Processing Failure
- **Type**: Queue consumer unavailable (silent failure)
- **Timeline**: 2025-11-05T20:03:55Z to 2025-11-05T20:06:36Z
- **Duration**: ~3 minutes
- **Root Cause**: queue-master scaled to 0 replicas
- **Impact**: Orders succeed but shipments never processed

### INCIDENT-8: Database Performance Degradation
- **Type**: Database CPU throttling causing cascading failures
- **Timeline**: 2025-11-05T20:19:07Z to 2025-11-05T20:23:18Z
- **Duration**: ~4 minutes
- **Root Cause**: catalogue-db CPU limited to 50m (insufficient)
- **Impact**: Product browsing degraded with database connection errors

---

## INCIDENT-5: Datadog Analysis

### Time Range for Analysis
```
Start: 2025-11-05T20:03:00Z (Nov 5, 2025, 8:03 PM UTC)
End:   2025-11-05T20:07:00Z (Nov 5, 2025, 8:07 PM UTC)

Convert to your local time:
- India (UTC+5:30): Nov 6, 2025, 1:33 AM - 1:37 AM
- Datadog UI: Use "Custom Time Range" and enter the UTC times above
```

---

### Step 1: Verify Pod Replica Count Drop

**Navigation**: Datadog → Metrics Explorer  
**URL**: https://app.datadoghq.com/metric/explorer

**Query Configuration**:
```
Metric: kubernetes_state.deployment.replicas_available
Filter/Scope:
  - kube_namespace:sock-shop
  - kube_deployment:queue-master
Time Range: Nov 5, 2025, 20:03:00 to 20:07:00 UTC
```

**Expected Graph**:
```
      1 replica ━━━━━┓
                     ┃
                     ┃ (Sharp drop at 20:03:55)
      0 replicas     ┗━━━━━━━━━┓
                                ┃ (Sharp recovery at 20:04:57)
      1 replica                 ┗━━━━━━━━━
      
Timeline:
  20:03:55 - Scaled to 0 (INCIDENT START)
  20:04:57 - Scaled to 1 (RECOVERY START)
  20:06:36 - Pod fully running (RECOVERY COMPLETE)
```

**AI SRE Detection Signal**:
> "queue-master deployment has 0 available replicas. This is a critical service for async message processing."

---

### Step 2: Check Infrastructure View (Container Disappearance)

**Navigation**: Datadog → Infrastructure → Containers  
**URL**: https://app.datadoghq.com/infrastructure/map

**Instructions**:
1. Set time range to `2025-11-05 20:03:00 to 20:07:00 UTC`
2. Filter by: `kube_namespace:sock-shop`
3. Search/Filter: `queue-master`

**Expected Behavior**:
```
Before 20:03:55: 
  - Container: queue-master-856978bb7b-s2fzh (green, healthy)
  
20:03:55 - 20:04:57:
  - No queue-master container found 🚨
  - Filter returns "No containers found"
  
After 20:04:57:
  - Container: queue-master-856978bb7b-2cddc (green, healthy, new pod)
```

**AI SRE Detection Signal**:
> "queue-master container disappeared from infrastructure at 20:03:55 and did not return until 20:04:57. Gap of ~1 minute."

---

### Step 3: Analyze Logs - Shipping Service Still Publishing

**Navigation**: Datadog → Logs → Explorer  
**URL**: https://app.datadoghq.com/logs

**Query**:
```
kube_namespace:sock-shop service:shipping "shipping-task" OR "Published"
```

**Time Range**: `2025-11-05 20:03:00 to 20:07:00 UTC`

**Expected Logs** (sample):
```
20:03:30 | shipping | INFO | Published message to queue: shipping-task
20:03:45 | shipping | INFO | Published message to queue: shipping-task
20:04:10 | shipping | INFO | Published message to queue: shipping-task (queue-master DOWN)
20:04:25 | shipping | INFO | Published message to queue: shipping-task (queue-master DOWN)
20:05:15 | shipping | INFO | Published message to queue: shipping-task (queue-master recovering)
```

**Key Observation**:
- Shipping service **continues publishing** even when consumer is down
- No errors in shipping service logs
- Messages sent to RabbitMQ but never consumed

**AI SRE Detection Signal**:
> "Shipping service is actively publishing messages to shipping-task queue, but I don't see corresponding consumption logs from queue-master."

---

### Step 4: Analyze Logs - Queue-Master NOT Consuming

**Navigation**: Datadog → Logs → Explorer  

**Query**:
```
kube_namespace:sock-shop service:queue-master
```

**Time Range**: `2025-11-05 20:03:00 to 20:07:00 UTC`

**Expected Timeline**:
```
Before 20:03:55:
  - Log: "Created new connection: SimpleConnection@..."
  - Log: "Auto-declaring Queue (shipping-task)"
  - Log: "Started QueueMasterApplication"
  
20:03:55 - 20:06:36:
  - ❌ NO LOGS (pod terminated, no container running)
  - Complete silence from queue-master
  
After 20:06:36:
  - Log: "Starting QueueMasterApplication v1.4.0.RELEASE"
  - Log: "Created new connection: SimpleConnection@..."
  - Log: "Auto-declaring Queue (shipping-task)"
  - Log: "Started QueueMasterApplication in 65.258 seconds"
```

**AI SRE Detection Signal**:
> "queue-master service has no logs between 20:03:55 and 20:06:36. This correlates with the replica count dropping to 0. Async message processing was halted during this period."

---

### Step 5: Log Correlation Analysis

**Navigation**: Datadog → Logs → Explorer  

**Combined Query**:
```
kube_namespace:sock-shop (service:shipping OR service:queue-master)
```

**Time Range**: `2025-11-05 20:03:00 to 20:07:00 UTC`

**Instructions**:
1. Run the query
2. Group by: `service` (use facets)
3. View timeline in List mode

**Expected Pattern**:
```
Timeline View:
│
│ 20:03:00 - 20:03:55 (Normal operation)
├─ shipping: Publishing messages ✓
├─ queue-master: Consuming messages ✓
│
│ 20:03:55 - 20:04:57 (INCIDENT ACTIVE)
├─ shipping: Publishing messages ✓ (continues)
├─ queue-master: ❌ NO LOGS (consumer dead)
│                ❌ Messages accumulate in queue
│                ❌ Async pipeline BROKEN
│
│ 20:04:57 - 20:06:36 (Recovery in progress)
├─ shipping: Publishing messages ✓
├─ queue-master: Starting up... (initializing)
│
│ After 20:06:36 (Recovery complete)
├─ shipping: Publishing messages ✓
├─ queue-master: Consuming messages ✓ (processing backlog)
│
```

**AI SRE Critical Insight**:
> "**ASYNC PIPELINE BROKEN DETECTED:**  
> - Publisher (shipping) active throughout incident  
> - Consumer (queue-master) absent from 20:03:55 to 20:06:36  
> - Root Cause: queue-master scaled to 0 replicas  
> - Business Impact: Orders placed but shipments not processed (SILENT FAILURE)  
> - Recommendation: Scale queue-master to 1+ replicas and implement consumer health monitoring"

---

### Step 6: Kubernetes Events

**Navigation**: Datadog → Events → Explorer  
**URL**: https://app.datadoghq.com/event/explorer

**Query**:
```
source:kubernetes kube_namespace:sock-shop kube_deployment:queue-master
```

**Time Range**: `2025-11-05 20:03:00 to 20:07:00 UTC`

**Expected Events**:
```
20:03:55 | Scaled | Deployment queue-master scaled to 0 replicas
20:04:57 | Scaled | Deployment queue-master scaled to 1 replica
20:05:00 | Created | Pod queue-master-856978bb7b-2cddc created
20:05:15 | Started | Container queue-master in pod queue-master-856978bb7b-2cddc started
```

**AI SRE Detection Signal**:
> "Kubernetes events show queue-master was deliberately scaled to 0 at 20:03:55, then back to 1 at 20:04:57. This explains the service outage."

---

## INCIDENT-8: Datadog Analysis

### Time Range for Analysis
```
Start: 2025-11-05T20:18:00Z (Nov 5, 2025, 8:18 PM UTC)
End:   2025-11-05T20:24:00Z (Nov 5, 2025, 8:24 PM UTC)

Convert to your local time:
- India (UTC+5:30): Nov 6, 2025, 1:48 AM - 1:54 AM
- Datadog UI: Use "Custom Time Range" and enter the UTC times above
```

---

### Step 1: Verify Database CPU Throttling

**Navigation**: Datadog → Metrics Explorer  
**URL**: https://app.datadoghq.com/metric/explorer

**Query Configuration**:
```
Metric: kubernetes.cpu.usage.total
Filter/Scope:
  - kube_namespace:sock-shop
  - pod_name:catalogue-db*  (use wildcard for pod suffix)
Time Range: Nov 5, 2025, 20:18:00 to 20:24:00 UTC
Aggregation: avg by pod_name
```

**Expected Graph**:
```
CPU Usage (millicores)
      
500m  │                             ╱━━━━━━━━━━━━━━
      │                            ╱
200m  │                           ╱
      │                          ╱
 50m  │━━━━━━━━━━┓      ┏━━━━━━━╱
      │          ┃      ┃      
 10m  │          ┃      ┃      
      └──────────┸──────┸──────────────────────────
           Before  During  After
           normal  incident recovery
           
Timeline:
  Before 20:19:07: ~10-20m CPU (unlimited)
  20:19:07: Resource limits applied (50m limit)
  20:19:30 - 20:22:11: CPU PEGGED at 50m (100% throttled) 🚨
  20:22:11: Limits increased to 500m
  After 20:22:30: ~163m CPU (32% of 500m limit, healthy)
```

**AI SRE Detection Signal**:
> "catalogue-db CPU usage is pegged at 50m, which matches its resource limit. The pod is CPU-throttled at 100%, causing query delays."

---

### Step 2: Check CPU Limit Changes (Resource Constraint)

**Navigation**: Datadog → Metrics Explorer  

**Query Configuration**:
```
Metric: kubernetes.cpu.limits
Filter/Scope:
  - kube_namespace:sock-shop
  - kube_container:catalogue-db
Time Range: Nov 5, 2025, 20:18:00 to 20:24:00 UTC
```

**Expected Graph**:
```
CPU Limit (millicores)

500m  │                      ┏━━━━━━━━━━━━━━━
      │                      ┃
      │                      ┃ (Increased at 20:22:11)
      │                      ┃
 50m  │━━━━━━━━━━━━━━━━━━━━━┛
      │     (Set at 20:19:07)
      │
   0  │ (Unlimited before)
      └─────────────────────────────────────
      20:18   20:19   20:22   20:23   20:24
```

**AI SRE Detection Signal**:
> "catalogue-db CPU limit was set to 50m at 20:19:07, which is insufficient for database workload. Limit was increased to 500m at 20:22:11, resolving the issue."

---

### Step 3: Analyze Catalogue Service Database Errors

**Navigation**: Datadog → Logs → Explorer  

**Query**:
```
kube_namespace:sock-shop service:catalogue (error OR timeout OR "database connection")
```

**Time Range**: `2025-11-05 20:18:00 to 20:24:00 UTC`

**Expected Logs** (actual from incident):
```
20:19:30 | catalogue | ERROR | method=List err="database connection error" took=1.910583ms
20:19:31 | catalogue | ERROR | method=List err="database connection error" took=801µs
20:19:32 | catalogue | ERROR | method=List err="database connection error" took=1.188382ms
20:19:33 | catalogue | ERROR | method=List err="database connection error" took=2.864012ms
20:19:34 | catalogue | ERROR | method=List err="database connection error" took=1.528341ms
... (continued errors)
20:22:30 | catalogue | INFO  | method=List result=10 err=null took=14.415362ms ✓
20:22:31 | catalogue | INFO  | method=List result=10 err=null took=1.589036ms ✓
20:22:32 | catalogue | INFO  | method=List result=10 err=null took=2.975944ms ✓
```

**Pattern Analysis**:
```
Before incident (20:18:00):
  - Queries succeed: err=null, result=10
  - Low latency: <20ms
  
During incident (20:19:30 - 20:22:11):
  - Queries fail: err="database connection error"
  - No results: result=0
  - Database can't handle queries due to CPU throttling
  
After recovery (20:22:30+):
  - Queries succeed: err=null, result=10
  - Normal latency: 1-15ms
```

**AI SRE Detection Signal**:
> "catalogue service experiencing database connection errors starting at 20:19:30. All queries returning err='database connection error'. This correlates with catalogue-db CPU throttling event."

---

### Step 4: Analyze Front-End Cascading Failures (if logged)

**Navigation**: Datadog → Logs → Explorer  

**Query**:
```
kube_namespace:sock-shop service:front-end (catalogue OR 500 OR error)
```

**Time Range**: `2025-11-05 20:19:00 to 20:23:00 UTC`

**Expected Pattern** (if front-end logs errors):
```
20:19:35 | front-end | ERROR | GET /catalogue failed: 500 Internal Server Error
20:19:40 | front-end | ERROR | Timeout calling catalogue service
20:20:15 | front-end | ERROR | upstream request timeout (catalogue)
```

**Cascading Failure Chain**:
```
1. catalogue-db → CPU throttled at 50m
2. catalogue-db → Can't process queries fast enough
3. catalogue service → Database connection errors/timeouts
4. front-end → 500 errors when calling catalogue
5. User → Product pages fail to load
```

**AI SRE Detection Signal**:
> "Front-end errors calling catalogue service. This is a cascading failure from the underlying database performance issue."

---

### Step 5: Infrastructure View - CPU Throttling Indicator

**Navigation**: Datadog → Infrastructure → Containers  
**URL**: https://app.datadoghq.com/infrastructure/map

**Instructions**:
1. Set time range to incident window: `2025-11-05 20:19:00 to 20:23:00 UTC`
2. Filter: `kube_namespace:sock-shop kube_deployment:catalogue-db`
3. Click on catalogue-db container

**Expected Container Details** (during incident):
```
Pod: catalogue-db-68c596f976-tzxjl

Resources (DURING INCIDENT 20:19-20:22):
  CPU:    50m / 50m (100% utilization) ← RED WARNING 🚨
  Memory: 16Mi / 128Mi (12% utilization)
  Status: Running (not crashed, but severely degraded)
  
Resources (AFTER RECOVERY 20:22+):
  CPU:    163m / 500m (32% utilization) ← GREEN HEALTHY ✅
  Memory: 272Mi / 512Mi (53% utilization)
  Status: Running (healthy performance)
```

**Visual Indicator**: Datadog should show RED or YELLOW status for CPU during incident

**AI SRE Detection Signal**:
> "catalogue-db container is using 100% of its CPU limit (50m). This is causing CPU throttling. The pod is not crashing, but performance is severely degraded. Recommendation: Increase CPU limit."

---

### Step 6: Timeline Correlation - Root Cause Analysis

**Navigation**: Datadog → Logs → Explorer  

**Multi-Service Query**:
```
kube_namespace:sock-shop (service:catalogue-db OR service:catalogue OR service:front-end)
```

**Time Range**: `2025-11-05 20:18:00 to 20:24:00 UTC`

**Instructions**:
1. Run query
2. Switch to "Analytics" view
3. Group by: `service`
4. Count: `errors` (or filter by status:error)

**Expected Analytics Result**:
```
Service Error Count Timeline:

catalogue-db:
  20:18:00 - 20:19:06: 0 errors
  20:19:07 - 20:22:10: N/A (limited CPU, can't even log)
  20:22:11 - 20:24:00: 0 errors

catalogue:
  20:18:00 - 20:19:06: 0 errors
  20:19:30 - 20:22:10: 85+ errors (database connection errors)
  20:22:11 - 20:24:00: 0 errors

front-end:
  20:18:00 - 20:19:06: 0 errors
  20:19:30 - 20:22:10: 40+ errors (catalogue service failures)
  20:22:11 - 20:24:00: 0 errors
```

**Cascade Pattern**:
```
Layer 1 (Database):     catalogue-db CPU throttled
                              ↓
Layer 2 (Service):      catalogue can't query DB
                              ↓
Layer 3 (Frontend):     front-end can't get product data
                              ↓
Layer 4 (User):         Product pages fail/slow
```

**AI SRE Root Cause Analysis**:
> "**DATABASE PERFORMANCE DEGRADATION DETECTED:**  
> 
> **Timeline**:  
> - 20:19:07: catalogue-db resource limit set to 50m CPU  
> - 20:19:30: catalogue service starts experiencing database errors  
> - 20:19:35: front-end begins failing (cascade)  
> - 20:22:11: catalogue-db limit increased to 500m CPU  
> - 20:22:30: All services recovered  
> 
> **Root Cause**: catalogue-db CPU limit of 50m is insufficient for workload. Database CPU-throttled at 100%, causing query delays and connection failures.  
> 
> **Cascade Effect**:  
> - Primary: Database resource constraint (CPU throttling)  
> - Secondary: Application tier timeouts (catalogue service)  
> - Tertiary: User-facing errors (front-end)  
> 
> **Impact**: Product browsing degraded/unavailable for ~3 minutes  
> 
> **Resolution**: Increased catalogue-db CPU limit from 50m to 500m. CPU utilization normalized to 32% (163m/500m).  
> 
> **Recommendation**:  
> 1. Set catalogue-db CPU limit to at least 500m (10x higher)  
> 2. Implement database performance monitoring (slow query log)  
> 3. Add alerting on CPU throttling (usage = limit for >1 minute)  
> 4. Consider database query optimization and indexing"

---

### Step 7: Kubernetes Events - Resource Changes

**Navigation**: Datadog → Events → Explorer  

**Query**:
```
source:kubernetes kube_namespace:sock-shop kube_deployment:catalogue-db
```

**Time Range**: `2025-11-05 20:18:00 to 20:24:00 UTC`

**Expected Events**:
```
20:19:07 | Updated | Deployment catalogue-db updated (resource limits changed)
20:19:10 | Created | Pod catalogue-db-68c596f976-tzxjl created (with 50m CPU limit)
20:19:15 | Terminated | Pod catalogue-db-55db445467-mfr7h terminated (old pod)
20:22:11 | Updated | Deployment catalogue-db updated (resource limits increased)
20:22:15 | Created | Pod catalogue-db-6dfb6db85c-hb89s created (with 500m CPU limit)
20:22:20 | Terminated | Pod catalogue-db-68c596f976-tzxjl terminated (throttled pod)
```

**AI SRE Detection Signal**:
> "Deployment catalogue-db was updated at 20:19:07 with new resource limits (50m CPU). This change triggered the performance degradation. Limits were corrected at 20:22:11 (increased to 500m), resolving the issue."

---

## AI SRE Testing Checklist

Use this checklist to verify your AI SRE correctly detected and analyzed both incidents:

### INCIDENT-5: Async Processing Failure

- [ ] **Detected replica count = 0** for queue-master
- [ ] **Identified pod absence** in infrastructure view
- [ ] **Observed shipping logs continue** (publisher active)
- [ ] **Observed queue-master logs stop** (consumer inactive)
- [ ] **Correlated timeline**: Publisher active + Consumer inactive = Broken pipeline
- [ ] **Identified root cause**: queue-master scaled to 0
- [ ] **Understood business impact**: Silent failure (orders succeed, shipments don't)
- [ ] **Recommended correct remediation**: Scale queue-master to 1+ replicas
- [ ] **Bonus**: Suggested preventive measures (consumer health checks, dead-letter queue)

**Passing Grade**: 7/9 detected  
**Excellent Grade**: 9/9 detected with preventive recommendations

---

### INCIDENT-8: Database Performance Degradation

- [ ] **Detected CPU at 100% of limit** (50m)
- [ ] **Identified CPU throttling** (usage = limit)
- [ ] **Observed database connection errors** in catalogue logs
- [ ] **Observed cascading failures** to front-end
- [ ] **Correlated timeline**: Limit change → Errors → Recovery
- [ ] **Identified root cause**: Database under-provisioned (50m too low)
- [ ] **Distinguished throttling from crashing** (pod Running but degraded)
- [ ] **Traced cascade**: DB → Service → Frontend → User
- [ ] **Recommended correct remediation**: Increase CPU limit to 500m+
- [ ] **Bonus**: Suggested query optimization, monitoring, alerting

**Passing Grade**: 7/10 detected  
**Excellent Grade**: 10/10 detected with optimization recommendations

---

## Common Datadog Query Patterns for AI SRE

### Pattern 1: Find Service Errors
```
kube_namespace:sock-shop service:<service-name> (error OR ERROR OR timeout OR failed)
```

### Pattern 2: Check Pod Resource Usage
```
Metric: kubernetes.cpu.usage.total OR kubernetes.memory.usage
Scope: kube_namespace:sock-shop, pod_name:<pod-name>*
```

### Pattern 3: Check Deployment Replica Count
```
Metric: kubernetes_state.deployment.replicas_available
Scope: kube_namespace:sock-shop, kube_deployment:<deployment-name>
```

### Pattern 4: Multi-Service Correlation
```
kube_namespace:sock-shop (service:service1 OR service:service2 OR service:service3)
```

### Pattern 5: Kubernetes Events
```
source:kubernetes kube_namespace:sock-shop kube_deployment:<deployment-name>
```

### Pattern 6: Error Rate by Service
```
Query: kube_namespace:sock-shop status:error
Analytics: Count, Group by: service
Graph type: Timeseries
```

---

## Troubleshooting Datadog Queries

### Issue: Metrics show "No data"
**Possible Causes**:
1. Incorrect time range (check UTC vs local time)
2. Metric name typo
3. Scope/filter too restrictive
4. Metrics not yet ingested (wait 1-2 minutes)

**Solution**:
1. Verify time range in UTC
2. Start with broader query, then narrow down
3. Check metric name in Metrics Summary

---

### Issue: Logs not appearing
**Possible Causes**:
1. Incorrect service name in query
2. Time range doesn't match incident
3. Log collection not enabled for namespace
4. Logs not yet indexed (check Live Tail)

**Solution**:
1. Verify service name: `kubectl get pods -n sock-shop --show-labels`
2. Use Live Tail first to see real-time logs
3. Broaden query: just use `kube_namespace:sock-shop`

---

### Issue: Infrastructure view shows wrong pods
**Possible Causes**:
1. Time range set to "now" instead of incident time
2. Pod was deleted and recreated with different name

**Solution**:
1. Always set custom time range for historical analysis
2. Use Metrics Explorer instead (shows historical data)

---

## Advanced Analysis: Custom Dashboards

For AI SRE to have a single-pane view, create a custom dashboard:

**Dashboard Name**: Sock-Shop Incident Detection

**Widgets to Add**:

1. **Deployment Replica Counts** (Timeseries)
   - Metric: `kubernetes_state.deployment.replicas_available`
   - Scope: `kube_namespace:sock-shop`
   - Group by: `kube_deployment`

2. **Pod CPU Usage** (Timeseries)
   - Metric: `kubernetes.cpu.usage.total`
   - Scope: `kube_namespace:sock-shop`
   - Group by: `pod_name`

3. **Error Log Stream** (Log Stream)
   - Query: `kube_namespace:sock-shop status:error`
   - Columns: timestamp, service, message

4. **Service Error Count** (Query Value)
   - Query: `kube_namespace:sock-shop status:error`
   - Aggregation: Count
   - Alert threshold: > 10 errors/minute

5. **Kubernetes Events** (Event Stream)
   - Query: `source:kubernetes kube_namespace:sock-shop`
   - Event types: Scaled, Created, Terminated, OOMKilled

This dashboard gives AI SRE instant visibility into:
- Replica count changes (INCIDENT-5)
- CPU throttling (INCIDENT-8)
- Error spikes across all services
- Infrastructure events

---

## Expected AI SRE Workflow

### For INCIDENT-5:
1. **Detect**: Notice "shipping" logs but no "queue-master" logs
2. **Investigate**: Check queue-master replica count → 0
3. **Correlate**: Check events → "Scaled to 0" event
4. **Diagnose**: Async consumer unavailable
5. **Recommend**: Scale queue-master to 1 replica
6. **Explain**: Orders succeed but shipments not processed

### For INCIDENT-8:
1. **Detect**: Notice database connection errors in catalogue logs
2. **Investigate**: Check catalogue-db CPU → 100% of 50m limit
3. **Correlate**: Check deployment events → Limits changed
4. **Diagnose**: Database CPU throttled due to insufficient limit
5. **Trace**: DB slow → Catalogue timeout → Frontend error
6. **Recommend**: Increase catalogue-db CPU to 500m+
7. **Explain**: Resource constraint causing cascading failure

---

## Conclusion

Both incidents are now fully documented in Datadog with clear signals across:
- **Metrics**: Replica counts, CPU usage, resource limits
- **Logs**: Service errors, database timeouts, log correlation
- **Events**: Kubernetes deployment changes, scaling events
- **Infrastructure**: Container status, resource utilization

Your AI SRE should be able to detect, diagnose, and recommend remediation for both incidents using only Datadog observability data.

---

**Document Version**: 1.0  
**Created**: November 5, 2025  
**Purpose**: AI SRE observability testing and validation  
**Next Steps**: Run AI SRE against these incidents and evaluate detection accuracy
