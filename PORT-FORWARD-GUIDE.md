# Sock Shop Port-Forward Reference Guide

## Standard Port Allocation

For consistent external access to services running in the KIND cluster, use the following port-forward mappings:

| Service | External Port | Internal Port | Namespace | Command |
|---------|---------------|---------------|-----------|---------|
| **Sock Shop UI** | 2025 | 80 | sock-shop | `kubectl -n sock-shop port-forward svc/front-end 2025:80` |
| **Payment Service** | 2026 | 80 | sock-shop | `kubectl -n sock-shop port-forward svc/payment 2026:80` |
| **Grafana** | 3025 | 80 | monitoring | `kubectl -n monitoring port-forward svc/kps-grafana 3025:80` |
| **Prometheus** | 4025 | 9090 | monitoring | `kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 4025:9090` |
| **RabbitMQ Management** | 5025 | 15672 | sock-shop | `kubectl -n sock-shop port-forward svc/rabbitmq-management 5025:15672` |

## Quick Start Script

```powershell
# Start all port-forwards in separate windows
# Copy and paste this entire block

# Sock Shop UI
Start-Process pwsh -ArgumentList "-NoExit", "-Command", "kubectl -n sock-shop port-forward svc/front-end 2025:80" -WindowStyle Minimized

# Payment Service (for testing/debugging)
Start-Process pwsh -ArgumentList "-NoExit", "-Command", "kubectl -n sock-shop port-forward svc/payment 2026:80" -WindowStyle Minimized

# Grafana
Start-Process pwsh -ArgumentList "-NoExit", "-Command", "kubectl -n monitoring port-forward svc/kps-grafana 3025:80" -WindowStyle Minimized

# Prometheus
Start-Process pwsh -ArgumentList "-NoExit", "-Command", "kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 4025:9090" -WindowStyle Minimized

# RabbitMQ Management
Start-Process pwsh -ArgumentList "-NoExit", "-Command", "kubectl -n sock-shop port-forward svc/rabbitmq-management 5025:15672" -WindowStyle Minimized

Write-Host "`n✅ All port-forwards started!" -ForegroundColor Green
Write-Host "`nAccess URLs:" -ForegroundColor Cyan
Write-Host "  • Sock Shop UI:       http://localhost:2025" -ForegroundColor White
Write-Host "  • Payment API:        http://localhost:2026" -ForegroundColor White
Write-Host "  • Grafana:            http://localhost:3025" -ForegroundColor White
Write-Host "  • Prometheus:         http://localhost:4025" -ForegroundColor White
Write-Host "  • RabbitMQ:           http://localhost:5025" -ForegroundColor White
```

## Testing Payment Service via Port 2026

Once port-forward is active, you can test the payment service directly:

### Test Payment Authorization

```powershell
# Successful payment
curl -X POST http://localhost:2026/paymentAuth `
  -H "Content-Type: application/json" `
  -d '{"amount":50.00}'

# Expected response:
# {"authorised":true,"message":"Payment authorized (charge: ch_...)"}
```

### Test Health Endpoint

```powershell
curl http://localhost:2026/health

# Expected response:
# {"status":"UP","time":"2025-11-07T..."}
```

### During INCIDENT-6 (Gateway Down)

```powershell
# Payment will fail with gateway error
curl -X POST http://localhost:2026/paymentAuth `
  -H "Content-Type: application/json" `
  -d '{"amount":50.00}'

# Expected response:
# {"authorised":false,"message":"Payment gateway error: ... connection refused"}
```

## Port Architecture Explanation

### Why This Port Scheme?

The 20XX series ports are allocated for application services, while 30XX-50XX are for monitoring/infrastructure:

- **2025-2099**: Application services (front-end, payment, orders, etc.)
- **3000-3999**: Visualization tools (Grafana, dashboards)
- **4000-4999**: Metrics collection (Prometheus, monitoring APIs)
- **5000-5999**: Message queues and async systems (RabbitMQ, Kafka, etc.)

### Internal vs External Ports

| Layer | Payment Service Example |
|-------|------------------------|
| **Container Port** | 8080 (internal to pod) |
| **Service Port** | 80 (ClusterIP, for internal k8s routing) |
| **External Port** | 2026 (port-forward for local access) |

**Flow:**
```
localhost:2026 
  → (port-forward) 
    → svc/payment:80 
      → (service routes to) 
        → pod:8080
```

## Troubleshooting

### Check if Port-Forward is Running

```powershell
Get-Process -Name kubectl -ErrorAction SilentlyContinue | 
  Where-Object {$_.StartInfo.Arguments -like "*port-forward*"}
```

### Kill All Port-Forwards

```powershell
Get-Process -Name kubectl -ErrorAction SilentlyContinue | 
  Where-Object {$_.StartInfo.Arguments -like "*port-forward*"} | 
  Stop-Process -Force
```

### Port Already in Use

```powershell
# Find what's using port 2026
netstat -ano | findstr :2026

# Kill the process using the port
Stop-Process -Id <PID> -Force
```

## CI/CD Considerations

In CI/CD pipelines, avoid port-forwards. Instead, use:

```bash
# Direct pod access (no port-forward needed)
kubectl -n sock-shop exec -it deployment/payment -- /bin/sh

# Or use service ClusterIP directly from another pod
kubectl -n sock-shop run test-pod --image=curlimages/curl --rm -i --restart=Never \
  --command -- curl http://payment:80/health
```

## Production Notes

⚠️ **Port-forwards are for development/testing only!**

In production:
- Use **Ingress** or **LoadBalancer** services for external access
- Configure proper **DNS** entries
- Implement **API Gateway** for routing
- Add **TLS/SSL** termination
- Set up **authentication** and **authorization**

---

**Last Updated:** 2025-11-07  
**Maintainer:** Sock Shop Demo Team
