# Datadog Complete Setup - Metrics + Logs
**Date:** October 27, 2025  
**Configuration:** `datadog-values-metrics-logs.yaml`  
**API Key:** Set and verified (32 characters)

---

## ✅ What's Enabled

### Logs Collection
- ✅ Container logs from all namespaces (excluding system namespaces)
- ✅ Kubernetes event logs
- ✅ Auto multi-line detection

### Metrics Collection
- ✅ **DogStatsD** (port 8125) - Application metrics endpoint
- ✅ **Process Agent** - Container and process-level metrics
- ✅ **Orchestrator Explorer** - Kubernetes resource metrics (pods, deployments, services)
- ✅ **Kube State Metrics** - Cluster state metrics
- ✅ **System Metrics** - CPU, Memory, Disk, Network from nodes

### Kubernetes Integration
- ✅ Kubernetes metadata tagging
- ✅ Event collection
- ✅ Cluster Agent for cluster-level checks

---

## 🎯 What You'll See in Datadog

### Infrastructure Tab
- 2 hosts: `sockshop-control-plane` and `sockshop-worker`
- System metrics (CPU, memory, disk, network)
- Tags: `kube_cluster_name:sockshop-kind`

### Containers Tab
- All running containers with metrics
- Filter by: `kube_namespace:sock-shop`
- Container resource usage

### Kubernetes Explorer
- Cluster: `sockshop-kind`
- Namespaces: sock-shop, monitoring, datadog
- All pods, deployments, services, and their metrics

### Logs Tab
- Real-time logs from all sock-shop services
- Filter: `kube_namespace:sock-shop`
- Services: front-end, catalogue, user, carts, orders, payment, shipping, queue-master

### Metrics Explorer
- Search any metric: `kubernetes.cpu.usage`, `kubernetes.memory.usage`
- Filter by cluster, namespace, pod, container
- Create custom dashboards

---

## 📊 Key Metrics Available

### Node-Level Metrics
- `system.cpu.user`
- `system.cpu.system`
- `system.mem.used`
- `system.disk.used`
- `system.net.bytes_sent`
- `system.net.bytes_rcvd`

### Kubernetes Metrics
- `kubernetes.cpu.usage`
- `kubernetes.memory.usage`
- `kubernetes.pods.running`
- `kubernetes.containers.running`
- `kubernetes.deployments.available`

### Container Metrics
- `container.cpu.usage`
- `container.memory.usage`
- `container.io.read_bytes`
- `container.io.write_bytes`

### Process Metrics
- `process.cpu.user`
- `process.memory.rss`
- `process.open_file_descriptors`

---

## 🔍 Quick Verification Commands

### Check Logs Processing
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/component=agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"
```
**Success:** `LogsProcessed: > 0`

### Check Metrics Collection
```powershell
kubectl -n datadog exec $POD -c process-agent -- agent status | Select-String -Pattern "Metrics"
```
**Success:** Shows "Enabled"

### Check API Key
```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "API Key"
```
**Success:** "API Key valid"

---

## 🌐 Datadog UI Links

| Feature | URL |
|---------|-----|
| Infrastructure List | https://us5.datadoghq.com/infrastructure |
| Containers | https://us5.datadoghq.com/containers |
| Kubernetes Explorer | https://us5.datadoghq.com/orchestration/explorer |
| Logs | https://us5.datadoghq.com/logs |
| Metrics Explorer | https://us5.datadoghq.com/metric/explorer |
| Dashboards | https://us5.datadoghq.com/dashboard/lists |

---

## 📈 Recommended First Dashboard

Create a dashboard with these widgets:

1. **Timeseries: Sock Shop CPU Usage**
   - Metric: `kubernetes.cpu.usage`
   - Filter: `kube_namespace:sock-shop`
   - Aggregation: avg by `pod_name`

2. **Timeseries: Sock Shop Memory Usage**
   - Metric: `kubernetes.memory.usage`
   - Filter: `kube_namespace:sock-shop`
   - Aggregation: avg by `pod_name`

3. **Query Value: Running Pods**
   - Metric: `kubernetes.pods.running`
   - Filter: `kube_namespace:sock-shop`
   - Aggregation: sum

4. **Log Stream: Front-End Logs**
   - Filter: `kube_namespace:sock-shop service:front-end`
   - Show: Last 50 logs

5. **Timeseries: Container Restarts**
   - Metric: `kubernetes.containers.restarts`
   - Filter: `kube_namespace:sock-shop`
   - Alert if > 0

---

## 🔧 Resource Usage

### Node Agent (per node)
- **Containers:** 3 (agent, process-agent, trace-agent)
- **CPU Request:** 200m
- **Memory Request:** 256Mi
- **CPU Limit:** 500m
- **Memory Limit:** 512Mi

### Cluster Agent
- **Replicas:** 1
- **CPU Request:** 200m
- **Memory Request:** 256Mi
- **CPU Limit:** 500m
- **Memory Limit:** 512Mi

### Total Cluster Impact
- **Total CPU Request:** ~600m (across all agents)
- **Total Memory Request:** ~768Mi
- **Total CPU Limit:** ~1500m
- **Total Memory Limit:** ~1536Mi

---

## ⚠️ Important Notes

1. **API Key Security:** Never commit the API key to Git
2. **Cost Management:** Monitor log volume in Datadog to avoid unexpected costs
3. **Namespace Exclusions:** System namespaces are excluded to reduce noise
4. **Cluster Agent:** Running with 1 replica (sufficient for demo, use 2+ in production)
5. **KIND-Specific:** `tlsVerify: false` and `useApiServer: true` required for KIND clusters

---

## 🆚 Difference from Previous Setup

### OLD (Logs Only)
- ❌ Only collected logs
- ❌ No process metrics
- ❌ No Kubernetes resource visibility
- ❌ No cluster-level checks
- ❌ No application metrics endpoint

### NEW (Metrics + Logs)
- ✅ Logs collected
- ✅ Process and container metrics
- ✅ Full Kubernetes visibility
- ✅ Cluster-level checks
- ✅ DogStatsD endpoint for custom metrics
- ✅ Orchestrator Explorer enabled

---

## 📞 Support

If issues arise:
1. Check agent status: `kubectl -n datadog exec $POD -c agent -- agent status`
2. Check logs: `kubectl -n datadog logs $POD -c agent --tail=100`
3. Verify API key: Check secret `datadog-secret` in namespace `datadog`
4. Restart agents: `kubectl -n datadog rollout restart daemonset datadog-agent`

---

**Configuration File:** `D:\sock-shop-demo\datadog-values-metrics-logs.yaml`  
**Deployment Command:** See command sequence below
