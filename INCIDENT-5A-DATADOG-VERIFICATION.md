# INCIDENT-5A: Datadog Verification Guide

**Incident Window:** November 8, 2025, 11:33:06 - 11:48:47 UTC (17:03:06 - 17:18:47 IST)  
**Test Duration:** ~15 minutes  
**Orders Placed:** 20 orders (11:35:19 - 11:38:58 UTC)

---

## 🎯 Quick Reference: Key Timestamps

| Event | Local Time (IST) | UTC Time | What to Look For |
|-------|------------------|----------|------------------|
| **Incident Start** | 17:03:06 | 11:33:06 | queue-master scaled to 0 |
| **First Order** | 17:05:19 | 11:35:19 | Queue starts filling |
| **Queue Capacity Reached** | 17:05:53 | 11:35:53 | Queue stuck at 3 (order #3) |
| **Last Order** | 17:08:58 | 11:38:58 | Still stuck at 3 |
| **Recovery Start** | 17:11:23 | 11:41:23 | Policy removed |
| **Consumer Restored** | 17:11:53 | 11:41:53 | queue-master scaled to 1 |
| **Queue Drained** | 17:12:35 | 11:42:35 | Messages processed |
| **Verification Test** | 17:18:21 | 11:48:21 | Normal operation confirmed |

---

## 📊 PART 1: Metrics Explorer Queries

### Access Metrics Explorer
```
URL: https://us5.datadoghq.com/metric/explorer
```

---

### Metric 1: Queue Depth (CRITICAL - Shows Blockage)

**Configuration:**
```
Metric:     rabbitmq.queue.messages
Filter:     queue:shipping-task
Aggregation: avg
Group by:   queue
Time Range: Nov 8, 2025 11:30 - 11:50 UTC (Past 4 Hours works too)
```

**Direct Link:**
```
https://us5.datadoghq.com/metric/explorer?exp_metric=rabbitmq.queue.messages&exp_scope=queue%3Ashipping-task&exp_agg=avg&exp_row_type=metric
```

**Expected Pattern:**
```
11:30 - 11:35:  Value = 0 (baseline)
11:35:19:       Value = 1 (first order queued)
11:35:40:       Value = 2 (second order queued)
11:35:53:       Value = 3 (third order queued - CAPACITY REACHED)
11:36 - 11:42:  Value = 3 (FLAT LINE - BLOCKAGE! ⚠️)
11:42:35:       Value = 0 (queue drained after recovery)
11:43+:         Value = 0 (normal operation)
```

**🚨 KEY INDICATOR:** Flat line at exactly 3 for ~7 minutes = QUEUE BLOCKAGE

---

### Metric 2: Consumer Count (Shows Consumer Failure)

**Configuration:**
```
Metric:     rabbitmq.queue.consumers
Filter:     queue:shipping-task
Aggregation: avg
Group by:   queue
Time Range: Nov 8, 2025 11:30 - 11:50 UTC
```

**Direct Link:**
```
https://us5.datadoghq.com/metric/explorer?exp_metric=rabbitmq.queue.consumers&exp_scope=queue%3Ashipping-task&exp_agg=avg&exp_row_type=metric
```

**Expected Pattern:**
```
11:30 - 11:33:  Value = 1 (consumer active)
11:33:06:       Value = 0 (consumer stopped - queue-master scaled down)
11:33 - 11:42:  Value = 0 (no consumer for ~9 minutes)
11:42:34:       Value = 1 (consumer restored)
11:43+:         Value = 1 (normal operation)
```

**🚨 KEY INDICATOR:** Consumer = 0 while queue depth = 3 = messages stuck

---

### Metric 3: Deployment Replicas (Root Cause)

**Configuration:**
```
Metric:     kubernetes_state.deployment.replicas_available
Filter:     kube_namespace:sock-shop AND kube_deployment:queue-master
Aggregation: avg
Group by:   kube_deployment
Time Range: Nov 8, 2025 11:30 - 11:50 UTC
```

**Direct Link:**
```
https://us5.datadoghq.com/metric/explorer?exp_metric=kubernetes_state.deployment.replicas_available&exp_scope=kube_namespace%3Asock-shop%20kube_deployment%3Aqueue-master&exp_agg=avg&exp_row_type=metric
```

**Expected Pattern:**
```
11:30 - 11:33:  Value = 1 (normal operation)
11:33:06:       Value = 0 (scaled down - ROOT CAUSE!)
11:33 - 11:42:  Value = 0 (deployment at 0 replicas)
11:41:53:       Value = 1 (scaled back up)
11:42+:         Value = 1 (normal operation)
```

**🚨 KEY INDICATOR:** Deployment replicas = 0 explains why consumer count = 0

---






## 📝 PART 2: Logs Explorer Queries

### Access Logs Explorer
```
URL: https://us5.datadoghq.com/logs
```

**⚠️ IMPORTANT:** Set time range to **Nov 8, 2025 11:30 - 11:50 UTC** for all queries below.

---

### Query 1: Queue-Master Pod Termination

**Query:**
```
kube_namespace:sock-shop service:sock-shop-queue-master "Stopping" OR "Killed" OR "Terminated"
```

**Time Range:** Nov 8, 11:33:00 - 11:33:30 UTC

**Expected Logs:**
```
11:33:06 | INFO | Stopping container queue-master
11:33:10 | INFO | Container queue-master terminated
```

**What This Shows:** Moment when consumer was stopped (incident trigger)

---

### Query 2: Shipping Service Publishing Messages

**Query:**
```
kube_namespace:sock-shop service:sock-shop-shipping
```

**Time Range:** Nov 8, 11:35:00 - 11:39:00 UTC

**Expected Logs:**
```
11:35:19 | INFO | POST /shipping
11:35:40 | INFO | POST /shipping
11:35:53 | INFO | POST /shipping
... (20 total shipping requests)
11:38:58 | INFO | POST /shipping
```

**What This Shows:** Shipping service receiving requests (orders being placed)

**⚠️ Note:** You may NOT see explicit "406 PRECONDITION_FAILED" errors because:
1. Spring AMQP may silently handle rejections
2. Fire-and-forget pattern suppresses errors
3. Shipping service logs may not have error-level logging enabled

**Alternative Check - Shipping Errors:**
```
kube_namespace:sock-shop service:sock-shop-shipping status:error
```

If errors are logged, you'll see:
```
11:36:03+ | ERROR | Failed to publish to queue: PRECONDITION_FAILED
```

---

### Query 3: Queue-Master Consumer Restart

**Query:**
```
kube_namespace:sock-shop service:sock-shop-queue-master "Started" OR "Connection" OR "Consumer"
```

**Time Range:** Nov 8, 11:41:30 - 11:43:00 UTC

**Expected Logs:**
```
11:42:34 | INFO | Created new connection: SimpleConnection@... [delegate=amqp://guest@10.96.191.196:5672/]
11:42:34 | INFO | Auto-declaring a non-durable, auto-delete, or exclusive Queue (shipping-task)
11:42:35 | INFO | Started QueueMasterApplication in 57.226 seconds
```

**What This Shows:** Consumer restarted and connected to RabbitMQ

---

### Query 4: Queue-Master Processing Messages

**Query:**
```
kube_namespace:sock-shop service:sock-shop-queue-master "Received shipment task"
```

**Time Range:** Nov 8, 11:42:30 - 11:43:00 UTC

**Expected Logs:**
```
11:42:35 | INFO | Received shipment task: 690f2ac19c10d30001ca3362
11:42:36 | INFO | Received shipment task: 690f2ac19c10d30001ca3362
11:42:37 | INFO | Received shipment task: 690f2ac19c10d30001ca3362
```

**What This Shows:** The 3 stuck messages being processed after recovery

---

### Query 5: All Sock-Shop Errors During Incident

**Query:**
```
kube_namespace:sock-shop status:error
```

**Time Range:** Nov 8, 11:35:00 - 11:42:00 UTC

**Expected Result:** Likely ZERO errors (this is the silent failure!)

**What This Shows:** Fire-and-forget pattern means NO application errors logged even though orders are failing

---

## 📅 PART 3: Events Explorer Queries

### Access Events Explorer
```
URL: https://us5.datadoghq.com/event/explorer
```

**Time Range:** Nov 8, 2025 11:30 - 11:50 UTC

---

### Query 1: Queue-Master Deployment Scaling

**Query:**
```
source:kubernetes kube_namespace:sock-shop kube_deployment:queue-master
```

**OR:**

**Query:**
```
kube_namespace:sock-shop "queue-master" "Scaled"
```

**Expected Events:**

**Event 1 - Scale Down (Incident Trigger):**
```
Time:     Nov 8, 11:33:06 UTC
Type:     Normal
Reason:   ScalingReplicaSet
Message:  Scaled down replica set queue-master-856978bb7b from 1 to 0
Source:   deployment-controller
```

**Event 2 - Scale Up (Recovery):**
```
Time:     Nov 8, 11:41:53 UTC
Type:     Normal
Reason:   ScalingReplicaSet
Message:  Scaled up replica set queue-master-856978bb7b from 0 to 1
Source:   deployment-controller
```

**What This Shows:** Root cause evidence - deployment manually scaled down/up

---

### Query 2: Pod Termination Events

**Query:**
```
source:kubernetes kube_namespace:sock-shop pod_name:queue-master* "Killing" OR "Stopped"
```

**Expected Events:**
```
Time:     Nov 8, 11:33:10 UTC
Type:     Normal
Reason:   Killing
Message:  Stopping container queue-master
Pod:      queue-master-856978bb7b-9dqtn
```

---

### Query 3: Pod Creation Events

**Query:**
```
source:kubernetes kube_namespace:sock-shop pod_name:queue-master* "Created" OR "Started"
```

**Expected Events:**
```
Time:     Nov 8, 11:42:00 UTC
Type:     Normal
Reason:   Created
Message:  Created container queue-master
Pod:      queue-master-856978bb7b-p25t7

Time:     Nov 8, 11:42:05 UTC
Type:     Normal
Reason:   Started
Message:  Started container queue-master
Pod:      queue-master-856978bb7b-p25t7
```

---

## 🖥️ PART 4: Infrastructure View

### Access Infrastructure List
```
URL: https://us5.datadoghq.com/infrastructure
```

---

### Check 1: Queue-Master Pod Status

**Search:** `queue-master`

**Filter:** `kube_namespace:sock-shop`

**Expected Timeline:**
```
11:30 - 11:33:  Pod visible, Running, 1/1 Ready
11:33 - 11:42:  Pod MISSING (scaled to 0)
11:42+:         Pod visible again, Running, 1/1 Ready
```

**How to Verify:**
1. Search for "queue-master" in the filter box
2. Click on the pod
3. Click "Metrics" tab
4. Look for CPU/Memory graphs - you'll see a GAP during the incident window

---

### Check 2: RabbitMQ Pod (Should Be Stable)

**Search:** `rabbitmq`

**Filter:** `kube_namespace:sock-shop`

**Expected:** Pod running continuously (no restarts during incident)

---

## 📈 PART 5: Dashboard View (Optional)

### Create Custom Dashboard

If you want a single-pane view, create a dashboard with these widgets:

**Widget 1: Queue Depth**
```
Metric: rabbitmq.queue.messages{queue:shipping-task}
Visualization: Timeseries
```

**Widget 2: Consumer Count**
```
Metric: rabbitmq.queue.consumers{queue:shipping-task}
Visualization: Timeseries
```

**Widget 3: Deployment Replicas**
```
Metric: kubernetes_state.deployment.replicas_available{kube_deployment:queue-master}
Visualization: Timeseries
```

**Widget 4: Recent Events**
```
Query: source:kubernetes kube_namespace:sock-shop deployment:queue-master
Visualization: Event Stream
```

---

## 🔍 PART 6: Advanced Analysis - Correlation

### Multi-Metric Graph (Best View!)

**URL:** https://us5.datadoghq.com/dashboard/lists

Create a new dashboard with all 3 metrics overlaid:

**Configuration:**
```yaml
Graph 1 (Combined):
  - Metric 1: rabbitmq.queue.messages{queue:shipping-task} (Line, Blue)
  - Metric 2: rabbitmq.queue.consumers{queue:shipping-task} (Line, Red)
  - Metric 3: kubernetes_state.deployment.replicas_available{kube_deployment:queue-master} (Line, Green)
  
Time Range: Nov 8, 11:30 - 11:50 UTC
```

**What You'll See:**
```
11:33: Green line (replicas) drops to 0 → Red line (consumers) drops to 0
11:35: Blue line (queue depth) rises to 3
11:36-11:42: Blue line STUCK at 3 (flat line - blockage!)
11:42: Green line rises to 1 → Red line rises to 1 → Blue line drops to 0
```

**This is the "smoking gun" visualization showing the complete incident lifecycle!**

---

## ✅ Verification Checklist

Use this checklist to confirm you've found all the evidence:

### Metrics ✅
- [ ] Queue depth metric shows flat line at 3 (11:35 - 11:42 UTC)
- [ ] Consumer count dropped to 0 at 11:33 UTC
- [ ] Deployment replicas dropped to 0 at 11:33 UTC
- [ ] All metrics returned to normal after 11:42 UTC

### Logs ✅
- [ ] Queue-master pod termination logs found (~11:33 UTC)
- [ ] Shipping service received 20 requests (11:35 - 11:39 UTC)
- [ ] Queue-master restart logs found (~11:42 UTC)
- [ ] Message processing logs found after recovery (~11:42 UTC)

### Events ✅
- [ ] "Scaled down from 1 to 0" event found (11:33 UTC)
- [ ] "Scaled up from 0 to 1" event found (11:41 UTC)
- [ ] Pod killing/creation events found

### Infrastructure ✅
- [ ] queue-master pod shows as missing during 11:33 - 11:42 UTC
- [ ] CPU/Memory graphs show gap during incident
- [ ] RabbitMQ pod remained stable throughout

---

## 🎯 AI SRE Detection Signals Summary

An AI SRE system analyzing this incident should detect:

1. **Primary Signal:** Queue depth stuck at 3 (flat line for 7 minutes)
2. **Correlation 1:** Consumer count = 0 (no processing)
3. **Correlation 2:** Deployment replicas = 0 (root cause)
4. **Business Impact:** 20 orders placed, only 3 queued (17 lost)
5. **Silent Failure:** Zero application errors logged
6. **Recovery Proof:** Queue drained immediately after consumer restored

**Expected AI Diagnosis:**
> "Queue blockage detected: RabbitMQ shipping-task queue stuck at capacity (3 messages) for 7 minutes. Root cause: queue-master deployment scaled to 0 replicas, causing consumer count to drop to 0. Business impact: 17 of 20 orders failed silently (rejected by queue capacity limit). Recommend: Restore queue-master deployment and remove capacity policy."

---

## 📞 Support Queries

If you don't see expected data, try these troubleshooting queries:

### Check Datadog Agent Health
```
Query: service:datadog-agent status:error
Time: Nov 8, 11:30 - 11:50 UTC
```

### Check RabbitMQ Metrics Collection
```
Metric: rabbitmq.overview.object_totals.queues
Filter: kube_namespace:sock-shop
Expected: Value = 2 (aliveness-test + shipping-task)
```

### Check Kubernetes State Metrics
```
Metric: kubernetes_state.deployment.replicas
Filter: kube_namespace:sock-shop
Expected: Multiple deployments visible
```

---

## 📊 Expected Visualization Examples

### Perfect Incident Evidence Graph

```
Queue Messages (Blue Line):
     3 ━━━━━━━━━━━━━━━━━━━━━━━ (FLAT LINE - BLOCKAGE!)
     2 ╱
     1 ╱
     0 ━━━━━━                  ╲━━━━━━━━━━
       11:30  11:35  11:40  11:45  11:50

Consumers (Red Line):
     1 ━━━━╲                    ╱━━━━━━━━━━
     0      ━━━━━━━━━━━━━━━━━━━━ (NO CONSUMER!)
       11:30  11:35  11:40  11:45  11:50

Replicas (Green Line):
     1 ━━━━╲                    ╱━━━━━━━━━━
     0      ━━━━━━━━━━━━━━━━━━━━ (ROOT CAUSE!)
       11:30  11:35  11:40  11:45  11:50
```

---

## 🎓 Key Takeaways for Datadog Analysis

1. **Flat line metrics are critical:** More important than spikes
2. **Correlate multiple metrics:** Queue + Consumer + Deployment tells full story
3. **Silent failures need metrics:** Logs may show NOTHING
4. **Time alignment is key:** All 3 metrics show issues at same time
5. **Recovery proof:** All metrics return to normal simultaneously

---

## Document Information

**Created:** November 8, 2025  
**Incident ID:** INCIDENT-5A  
**Datadog Instance:** us5.datadoghq.com  
**Namespace:** sock-shop  
**Test Duration:** 11:33 - 11:48 UTC (15 minutes)

---

## Quick Copy-Paste Queries

### Metrics Explorer (3 queries)
```
1. rabbitmq.queue.messages{queue:shipping-task}
2. rabbitmq.queue.consumers{queue:shipping-task}
3. kubernetes_state.deployment.replicas_available{kube_deployment:queue-master}
```

### Logs Explorer (5 queries)
```
1. kube_namespace:sock-shop service:sock-shop-queue-master "Stopping"
2. kube_namespace:sock-shop service:sock-shop-shipping
3. kube_namespace:sock-shop service:sock-shop-queue-master "Started"
4. kube_namespace:sock-shop service:sock-shop-queue-master "Received shipment task"
5. kube_namespace:sock-shop status:error
```

### Events Explorer (1 query)
```
source:kubernetes kube_namespace:sock-shop kube_deployment:queue-master
```

**Set Time Range for All:** Nov 8, 2025 11:30 - 11:50 UTC

---

✅ **Ready to verify in Datadog!**
