# RabbitMQ Datadog Integration - Quick Verification Guide

**Purpose**: Step-by-step guide to verify RabbitMQ logs and metrics in Datadog UI  
**Date**: November 12, 2025  
**Status**: ✅ System Verified Working

---

## 🔍 STEP 1: Verify Logs in Datadog

### Access Datadog Logs

1. **Navigate to Logs**
   - URL: `https://us5.datadoghq.com/logs`
   - Or click: Logs → Explorer

2. **Search for RabbitMQ Logs**
   ```
   Query: kube_namespace:sock-shop AND service:sock-shop-rabbitmq
   Time Range: Last 15 minutes
   ```

3. **Expected Results**
   - You should see RabbitMQ startup logs
   - Connection establishment messages
   - Plugin initialization logs
   - Recent timestamps (within last 15 min)

4. **Verify RabbitMQ Exporter Logs**
   ```
   Query: kube_namespace:sock-shop AND service:sock-shop-rabbitmq-exporter
   Time Range: Last 15 minutes
   ```

5. **Expected Results**
   - Metrics collection logs
   - HTTP endpoint access logs
   - Successful scrape messages

---

## 📊 STEP 2: Verify Metrics in Datadog

### Access Metrics Explorer

1. **Navigate to Metrics**
   - URL: `https://us5.datadoghq.com/metric/explorer`
   - Or click: Metrics → Explorer

2. **Search for Queue Consumer Metric**
   ```
   Metric: rabbitmq_queue_consumers
   Filter: kube_namespace:sock-shop
   Group by: queue
   ```

3. **Expected Results**
   - Metric should be found ✅
   - Value: 1 (normal state)
   - Queue: shipping-task
   - Graph showing consistent value of 1

4. **Verify Queue Depth Metric**
   ```
   Metric: rabbitmq_queue_messages
   Filter: kube_namespace:sock-shop AND queue:shipping-task
   ```

5. **Expected Results**
   - Value: 0 or very low (< 5) in normal state
   - Graph showing stable low values

6. **Verify Node Health Metrics**
   ```
   Metric: rabbitmq_node_mem_used
   Filter: kube_namespace:sock-shop
   ```

7. **Expected Results**
   - Should show memory usage in bytes
   - Stable values over time

---

## 🎯 STEP 3: Test Incident Detection (Optional)

### Trigger Incident-5 to Verify Metrics Change

1. **Scale Down Queue Master**
   ```powershell
   kubectl scale deployment queue-master -n sock-shop --replicas=0
   ```

2. **Wait 30 Seconds**

3. **Check Metrics in Datadog**
   ```
   Metric: rabbitmq_queue_consumers
   Filter: kube_namespace:sock-shop AND queue:shipping-task
   Expected: Value should drop to 0 ✅
   ```

4. **Place Test Orders**
   - Go to: `http://localhost:2025`
   - Add items to cart
   - Complete checkout

5. **Check Queue Depth**
   ```
   Metric: rabbitmq_queue_messages
   Filter: kube_namespace:sock-shop AND queue:shipping-task
   Expected: Value should increase (1, 2, 3, ...) ✅
   ```

6. **Recover**
   ```powershell
   kubectl scale deployment queue-master -n sock-shop --replicas=1
   ```

7. **Verify Recovery**
   ```
   Metric: rabbitmq_queue_consumers
   Expected: Value should return to 1 ✅
   
   Metric: rabbitmq_queue_messages
   Expected: Value should decrease back to 0 ✅
   ```

---

## 📋 COMPLETE METRICS LIST

### Queue Metrics (Available in Datadog)

```
rabbitmq_queue_consumers
  Purpose: Number of consumers on queue
  Normal: 1 (shipping-task)
  Alert: = 0 (consumer failure)

rabbitmq_queue_messages
  Purpose: Total messages in queue
  Normal: 0-5
  Alert: > 50 (backlog building)

rabbitmq_queue_messages_ready
  Purpose: Messages ready to be delivered
  Normal: 0-2
  Alert: > 20 (consumer can't keep up)

rabbitmq_queue_messages_unacknowledged
  Purpose: Messages delivered but not acked
  Normal: 0-5
  Alert: > 10 (consumer processing issues)

rabbitmq_queue_message_stats_publish_total
  Purpose: Total messages published (counter)
  Normal: Increasing over time
  Alert: Rate = 0 (publisher failure)

rabbitmq_queue_message_stats_deliver_total
  Purpose: Total messages delivered (counter)
  Normal: Increasing over time
  Alert: Rate = 0 (consumer failure)

rabbitmq_queue_message_stats_redeliver_total
  Purpose: Total messages redelivered (counter)
  Normal: 0 or very low
  Alert: Increasing (message processing failures)
```

### Node Metrics (Available in Datadog)

```
rabbitmq_node_mem_used
  Purpose: Memory usage in bytes
  Normal: Stable
  Alert: Increasing rapidly (memory leak)

rabbitmq_node_fd_used
  Purpose: File descriptors in use
  Normal: Low percentage of total
  Alert: Near fd_total (file descriptor exhaustion)

rabbitmq_node_sockets_used
  Purpose: Network sockets in use
  Normal: Low percentage of total
  Alert: Near sockets_total (connection exhaustion)

rabbitmq_node_proc_used
  Purpose: Erlang processes in use
  Normal: Stable
  Alert: Near proc_total (process exhaustion)

rabbitmq_node_disk_free
  Purpose: Free disk space in bytes
  Normal: > 50GB
  Alert: < 10GB (disk space running low)

rabbitmq_node_uptime_seconds
  Purpose: Node uptime in seconds
  Normal: Increasing continuously
  Alert: Drops to near 0 (node restart)
```

---

## 🔎 TROUBLESHOOTING

### Issue: "Metric not found in Datadog"

**Diagnosis:**
1. Check metric is being collected:
   ```powershell
   $agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
   kubectl exec -n datadog $agentPod -- agent status | Select-String -Pattern "openmetrics.*rabbitmq" -Context 0,15
   ```

2. Look for:
   - Instance ID: `openmetrics:rabbitmq:XXX [OK]`
   - Metric Samples: Should be > 0
   - Last Successful Execution: Recent timestamp

**Solutions:**
- If check not found: Apply fix with `.\apply-rabbitmq-fix.ps1`
- If check shows [ERROR]: Check RabbitMQ pod is running
- If metrics = 0: Check exporter container is healthy

### Issue: "Logs not appearing in Datadog"

**Diagnosis:**
1. Check logs agent status:
   ```powershell
   $agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
   kubectl exec -n datadog $agentPod -- agent status | Select-String -Pattern "Logs Agent" -Context 0,10
   ```

2. Look for:
   - BytesSent: Should be > 0
   - LogsSent: Should be > 0
   - RetryCount: Should be 0

**Solutions:**
- If BytesSent = 0: Check HTTP transport is enabled
- If DNS errors: Verify force_use_http: true in values
- If RetryCount > 0: Check API key is valid

### Issue: "Old rabbitmq check showing ERROR"

**This is NORMAL and EXPECTED:**
- Datadog auto-discovery loads both checks
- Old check (port 15692): Expected to fail
- New check (port 9090): Should show [OK]
- Only the OpenMetrics check matters
- Ignore the old rabbitmq check error

---

## ✅ VERIFICATION CHECKLIST

### Logs Verification
- [ ] Accessed Datadog Logs UI
- [ ] Searched for `kube_namespace:sock-shop`
- [ ] Found RabbitMQ logs (service:sock-shop-rabbitmq)
- [ ] Found RabbitMQ exporter logs (service:sock-shop-rabbitmq-exporter)
- [ ] Logs have recent timestamps (last 15 min)

### Metrics Verification
- [ ] Accessed Datadog Metrics Explorer
- [ ] Found `rabbitmq_queue_consumers` metric
- [ ] Metric shows value = 1 for shipping-task queue
- [ ] Found `rabbitmq_queue_messages` metric
- [ ] Metric shows low values (0-5) in normal state
- [ ] Found node metrics (rabbitmq_node_mem_used, etc.)

### Agent Health Verification
- [ ] Ran `.\apply-rabbitmq-fix.ps1 -Verify`
- [ ] Output shows: "✅ OpenMetrics check found"
- [ ] Output shows: "✅ Datadog annotations are configured"
- [ ] Output shows: "✅ RabbitMQ pod is running"

---

## 🎯 QUICK COMMANDS

### Check Agent Status
```powershell
$agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n datadog $agentPod -- agent status
```

### Check RabbitMQ Metrics Collection
```powershell
$agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n datadog $agentPod -- agent status | Select-String -Pattern "openmetrics" -Context 5,10
```

### Check Logs Collection
```powershell
$agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n datadog $agentPod -- agent status | Select-String -Pattern "rabbitmq" -Context 3,5
```

### Verify RabbitMQ Pod
```powershell
kubectl get pods -n sock-shop -l name=rabbitmq
kubectl describe pod -n sock-shop -l name=rabbitmq | Select-String -Pattern "annotation"
```

### Run Full Verification
```powershell
.\apply-rabbitmq-fix.ps1 -Verify
```

---

## 📊 CURRENT STATUS (Nov 12, 2025)

### Agent Status: ✅ HEALTHY
- Datadog agent pods: 2/2 Running
- Cluster agent: 1/1 Running
- RabbitMQ pod: 2/2 Running (rabbitmq + exporter)

### Logs: ✅ FLOWING
- Total logs sent: 2,379
- Bytes sent: 2.6 MB
- RabbitMQ logs: ✅ Collecting
- RabbitMQ exporter logs: ✅ Collecting

### Metrics: ✅ COLLECTING
- OpenMetrics check: [OK]
- Total runs: 30
- Metric samples per run: 105
- Total samples collected: 3,150

### Configuration: ✅ OPTIMAL
- HTTP transport: Enabled
- OpenMetrics annotations: Applied
- Port 9090: Correctly configured
- Namespace: rabbitmq
- Tags: Properly configured

---

**Document Version**: 1.0  
**Last Verified**: November 12, 2025, 7:45 AM IST  
**Status**: ✅ All Systems Operational  
**Next Steps**: Verify in Datadog UI using queries above
