# 🎯 Demo Quick Reference Card

**Print this page for easy reference during presentation**

---

## ⚡ Port Reference

| Service | Port | URL |
|---------|------|-----|
| **Sock Shop** | 2025 | http://localhost:2025 |
| **Grafana** | 3025 | http://localhost:3025 (admin/prom-operator) |
| **Prometheus** | 4025 | http://localhost:4025 |
| **RabbitMQ** | 5025 | http://localhost:5025/metrics |

---

## 📊 Datadog URLs

| View | URL |
|------|-----|
| **Infrastructure** | https://us5.datadoghq.com/infrastructure |
| **Containers** | https://us5.datadoghq.com/containers |
| **Kubernetes** | https://us5.datadoghq.com/orchestration/explorer |
| **Logs** | https://us5.datadoghq.com/logs |
| **Metrics** | https://us5.datadoghq.com/metric/explorer |

---

## 🔍 Key Prometheus Queries

```promql
# Container CPU
rate(container_cpu_usage_seconds_total{namespace="sock-shop"}[5m])

# Memory Usage (MB)
container_memory_usage_bytes{namespace="sock-shop"} / 1024 / 1024

# RabbitMQ Queue Depth
rabbitmq_queue_messages{queue="orders"}
```

---

## 🔎 Key Datadog Log Searches

```
# All sock-shop logs
kube_namespace:sock-shop

# Orders service only
kube_namespace:sock-shop service:orders

# Errors only
kube_namespace:sock-shop status:error

# Specific order ID
68f35ed59c10d300018b7011
```

---

## 🚀 Demo User Journey

1. **Browse** → Click 3 socks
2. **Register** → demo-user / password123 (or Login: user/password)
3. **Add to Cart** → Weave special, Holy, Crossed
4. **Checkout** → 123 Demo St, Springfield, 12345, USA
5. **Place Order** → **COPY ORDER ID!**
6. **Track** → Search order ID in Datadog logs

---

## 🛠️ Emergency Commands

### Restart Port Forwards
```powershell
$ports = 2025,3025,4025,5025
(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }).OwningProcess | Sort-Object -Unique | ForEach-Object { taskkill /PID $_ /F }

Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'
Start-Process powershell -ArgumentList 'kubectl -n monitoring port-forward svc/kps-grafana 3025:80'
Start-Process powershell -ArgumentList 'kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 4025:9090'
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/rabbitmq 5025:9090'
```

### Check Pod Status
```powershell
kubectl get pods -n sock-shop
kubectl get pods -n monitoring
kubectl get pods -n datadog
```

### Check Datadog Logs
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/component=agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
kubectl -n datadog exec $POD -c agent -- agent status | Select-String "LogsProcessed"
```

---

## 💡 Key Talking Points

### Architecture
- **8 microservices** (Node.js, Go, Java)
- **4 databases** (MariaDB, MongoDB x3, Redis)
- **RabbitMQ** for async messaging
- **Multi-arch** (AMD64, ARM, Power, Z)

### Monitoring Stack
- **Prometheus:** 15s scrape, self-hosted
- **Grafana:** Visualization, dashboards
- **Datadog:** 5,500+ logs, full observability

### Business Value
- **Faster troubleshooting** (minutes vs hours)
- **Proactive monitoring** (alerts before issues)
- **Complete audit trail** (compliance ready)
- **Scalable** (hundreds of services)

---

## 📝 Closing Statement Template

> "We've demonstrated:
> - **Application:** 8-service microservices architecture
> - **Monitoring:** Real-time metrics with Prometheus/Grafana
> - **Observability:** Centralized logging with Datadog (5,500+ logs)
> - **DevOps:** Production-ready troubleshooting workflow
> 
> This platform enables fast debugging, proactive monitoring, and complete visibility for cloud-native applications."

---

## 🎯 Success Metrics

- ✅ All 14 sock-shop pods Running
- ✅ All 4 port forwards accessible
- ✅ Datadog LogsProcessed > 5000
- ✅ Order placed and tracked end-to-end
- ✅ Logs, metrics, and infrastructure all demoed

---

**Print this card and keep it handy during the demo!**
