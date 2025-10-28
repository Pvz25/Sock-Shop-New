# Sock Shop Microservices Observability Demo
## Complete Team Presentation Guide

**Version:** 1.0  
**Date:** October 27, 2025  
**Duration:** 30-45 minutes  
**Presenter:** [Your Name]

---

## 📋 Table of Contents

- [Demo Overview](#demo-overview)
- [Pre-Demo Checklist (15 min before)](#pre-demo-checklist)
- [Part 1: Introduction & Architecture (5 min)](#part-1-introduction--architecture)
- [Part 2: Application Demo (10 min)](#part-2-application-demo)
- [Part 3: Monitoring with Prometheus & Grafana (10 min)](#part-3-monitoring-with-prometheus--grafana)
- [Part 4: Observability with Datadog (10 min)](#part-4-observability-with-datadog)
- [Part 5: Troubleshooting Scenarios (5-10 min)](#part-5-troubleshooting-scenarios)
- [Q&A Preparation](#qa-preparation)
- [Troubleshooting Tips](#troubleshooting-tips)

---

## Demo Overview

### What You'll Demonstrate

A **production-grade microservices observability platform** featuring:

- **Sock Shop E-commerce Application** (8 microservices, 4 databases, message queue)
- **Kubernetes** (KIND cluster, 2 nodes)
- **Prometheus + Grafana** (Metrics collection & visualization)
- **Datadog** (Centralized logging + advanced metrics)
- **Full-stack observability** (Infrastructure → Application → Logs)

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Front-end** | Node.js | Web UI |
| **Catalogue** | Go + MariaDB | Product catalog |
| **User** | Go + MongoDB | Authentication |
| **Carts** | Java + MongoDB | Shopping cart |
| **Orders** | Java + MongoDB | Order processing |
| **Payment** | Go | Payment gateway |
| **Shipping** | Java | Fulfillment |
| **Queue-Master** | Java | Message consumer |
| **RabbitMQ** | Message Broker | Async communication |

### Key Talking Points

✅ **Multi-Architecture:** Supports AMD64, ARM64, PPC64LE, S390X  
✅ **Microservices Patterns:** REST APIs, async messaging, distributed databases  
✅ **Production Observability:** 5,500+ logs collected, real-time metrics, full tracing  
✅ **DevOps Benefits:** Fast troubleshooting, proactive monitoring, complete audit trail

---

## Pre-Demo Checklist

### Run 15 Minutes Before Demo

#### 1. Verify Cluster is Running

```powershell
kubectl cluster-info
```

**Expected:**
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
```

✅ SUCCESS: Cluster accessible  
❌ FAIL: `kind create cluster`

---

#### 2. Check All Pods

```powershell
kubectl get pods -n sock-shop --no-headers | wc -l
kubectl get pods -n monitoring --no-headers | wc -l
kubectl get pods -n datadog --no-headers | wc -l
```

**Expected:**
- sock-shop: ~14 pods (all Running)
- monitoring: ~5 pods (all Running)
- datadog: 3 pods (all Running)

✅ SUCCESS: All pods Running  
❌ FAIL: Check pod logs

---

#### 3. Start Port Forwards

```powershell
# Kill existing forwards
$ports = 2025,3025,4025,5025
(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }).OwningProcess | Sort-Object -Unique | ForEach-Object { taskkill /PID $_ /F } 2>$null

# Start new forwards (opens 4 PowerShell windows)
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'
Start-Process powershell -ArgumentList 'kubectl -n monitoring port-forward svc/kps-grafana 3025:80'
Start-Process powershell -ArgumentList 'kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 4025:9090'
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/rabbitmq 5025:9090'

Start-Sleep -Seconds 5
```

**Expected:** 4 PowerShell windows showing `Forwarding from...`

---

#### 4. Test All Services

```powershell
$tests = @(
    @{Name="Sock Shop"; URL="http://localhost:2025"},
    @{Name="Grafana"; URL="http://localhost:3025"},
    @{Name="Prometheus"; URL="http://localhost:4025"},
    @{Name="RabbitMQ"; URL="http://localhost:5025/metrics"}
)

foreach ($test in $tests) {
    try {
        Invoke-WebRequest -UseBasicParsing $test.URL -TimeoutSec 3 | Out-Null
        Write-Host "✓ $($test.Name): $($test.URL)" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($test.Name) FAILED" -ForegroundColor Red
    }
}
```

**Expected:**
```
✓ Sock Shop: http://localhost:2025
✓ Grafana: http://localhost:3025
✓ Prometheus: http://localhost:4025
✓ RabbitMQ: http://localhost:5025/metrics
```

✅ SUCCESS: All services accessible  
❌ FAIL: Restart port forwards

---

#### 5. Pre-Open Browser Tabs (Optional)

```powershell
Start-Process "http://localhost:2025"
Start-Process "http://localhost:3025"
Start-Process "http://localhost:4025"
Start-Process "https://us5.datadoghq.com/infrastructure"
Start-Process "https://us5.datadoghq.com/logs"
```

---

#### 6. Verify Datadog

```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/component=agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"
```

**Expected:**
```
LogsProcessed: 5000+
```

✅ SUCCESS: Datadog collecting logs  
❌ FAIL: Check agent status

---

### ✅ Checklist Summary

- [ ] Cluster running
- [ ] All pods Running (14+5+3)
- [ ] Port forwards active (2025, 3025, 4025, 5025)
- [ ] All services accessible
- [ ] Datadog collecting logs
- [ ] Browser tabs pre-opened

**When all checked, you're ready!** 🎉

---

## Part 1: Introduction & Architecture
**Duration:** 5 minutes

### Opening Statement

> "Today I'll demonstrate a production-grade microservices observability platform running Sock Shop - an e-commerce application with 8 microservices, complete monitoring with Prometheus/Grafana, and centralized logging with Datadog. This showcases real-world patterns for operating distributed systems at scale."

### Show Architecture

**Display:** System diagram or component list

**Key points:**
- 8 microservices (Node.js, Go, Java)
- 4 databases (MariaDB, MongoDB x3, Redis)
- RabbitMQ for async messaging
- Prometheus/Grafana for metrics
- Datadog for logs + advanced metrics
- Kubernetes (KIND) with 2 nodes

### Show Running Components

```powershell
kubectl get pods -n sock-shop
```

**Expected:** 14 pods, all Running

**Say:** "All 14 pods are healthy. Each service is independently deployable and scalable."

---

## Part 2: Application Demo
**Duration:** 10 minutes

### 2.1 Open Sock Shop UI

```powershell
Start-Process "http://localhost:2025"
```

**Say:** "This is Sock Shop, a full-featured e-commerce application. Let me walk you through a complete user journey."

---

### 2.2 Browse Catalogue

**Actions:**
1. Scroll through homepage
2. Click on 2-3 socks to show details

**Say:** "The catalogue service (Go + MariaDB) handles product search. Redis provides session management for fast page loads."

---

### 2.3 Register/Login

**Option A: Register new user**
1. Click "Login" → "Register"
2. Fill in:
   - Username: `demo-user`
   - Password: `password123`
   - Email: `demo@example.com`
3. Click "Register"

**Option B: Use existing**
- Username: `user`
- Password: `password`

**Say:** "The user service (Go + MongoDB) handles authentication. In production, this would integrate with OAuth or SSO."

---

### 2.4 Add Items to Cart

**Actions:**
1. Click "Weave special" → "Add to cart"
2. Click "Holy" → "Add to cart"
3. Click "Crossed" → "Add to cart"

**Expected:** Cart shows "3" items

**Say:** "The carts service (Spring Boot + MongoDB) maintains session state. Each add-to-cart triggers REST API calls we can monitor."

---

### 2.5 Checkout

**Actions:**
1. Click cart icon
2. Click "Proceed to checkout"
3. Enter address:
   - Address: `123 Demo Street`
   - City: `Springfield`
   - Postcode: `12345`
   - Country: `USA`
4. Click "Next"
5. Click "Place order"

**Expected:** Order confirmation with order ID

**Copy the Order ID!** (e.g., `68f35ed59c10d300018b7011`)

**Say:** 
> "Behind the scenes:
> 1. Orders service validates and creates order (Spring Boot)
> 2. Payment service processes payment (Go)
> 3. Shipping service queues via RabbitMQ
> 4. Queue-master consumes and updates status
> 
> This is asynchronous microservices communication in action."

---

## Part 3: Monitoring with Prometheus & Grafana
**Duration:** 10 minutes

### 3.1 Open Prometheus

```powershell
Start-Process "http://localhost:4025"
```

**Say:** "Prometheus scrapes metrics every 15 seconds and stores time-series data."

---

### 3.2 Show Targets

**Actions:**
1. Click "Status" → "Targets"
2. Scroll to show targets

**Expected:** Multiple targets showing "UP"

**Say:** "These are our scrape targets. Green means healthy. We're collecting from Kubernetes state and RabbitMQ."

---

### 3.3 Query Metrics

**Query 1: Container CPU**
```promql
rate(container_cpu_usage_seconds_total{namespace="sock-shop"}[5m])
```

Click "Execute" → "Graph"

**Say:** "CPU usage across all containers. Notice spikes when we placed the order."

---

**Query 2: Memory Usage**
```promql
container_memory_usage_bytes{namespace="sock-shop"} / 1024 / 1024
```

**Say:** "Memory in MB. Java services (carts, orders) use more than Go services due to JVM overhead."

---

**Query 3: RabbitMQ Queue**
```promql
rabbitmq_queue_messages{queue="orders"}
```

**Say:** "Messages in the orders queue. When we placed orders, messages were enqueued then consumed."

---

### 3.4 Open Grafana

```powershell
Start-Process "http://localhost:3025"
```

**Login:**
- Username: `admin`
- Password: `prom-operator`

**Say:** "Grafana provides rich visualization on top of Prometheus."

---

### 3.5 Show Dashboard

**Actions:**
1. Click "Dashboards"
2. Search "Kubernetes"
3. Select "Kubernetes / Compute Resources / Namespace (Pods)"
4. Select namespace: `sock-shop`

**Expected:** Dashboard showing CPU, Memory, Network, Disk by pod

**Say:** 
> "Real-time resource consumption:
> - Front-end handling HTTP requests
> - Databases with consistent memory
> - Spikes in orders/carts during processing
> 
> In production, we'd alert if any pod exceeds 80% memory."

---

## Part 4: Observability with Datadog
**Duration:** 10 minutes

### 4.1 Infrastructure View

```powershell
Start-Process "https://us5.datadoghq.com/infrastructure"
```

**Say:** "Datadog provides enterprise observability - logs, metrics, and infrastructure data."

**Actions:**
1. Point to 2 hosts: `sockshop-control-plane` and `sockshop-worker`
2. Click on `sockshop-worker`

**Expected:** Host detail showing CPU, Memory, Network, Disk, Processes

**Say:** "System-level metrics help us understand infrastructure health beyond pod metrics."

---

### 4.2 Containers View

```powershell
Start-Process "https://us5.datadoghq.com/containers"
```

**Actions:**
1. Search: `kube_namespace:sock-shop`
2. Press Enter

**Expected:** List of all sock-shop containers with metrics

**Say:** "Real-time view of every container with resource usage, restarts, and health. Memory leaks would appear here immediately."

---

### 4.3 Kubernetes Explorer

```powershell
Start-Process "https://us5.datadoghq.com/orchestration/explorer"
```

**Actions:**
1. Select cluster: `sockshop-kind`
2. Explore namespaces

**Expected:** Tree view of Namespaces → Deployments → Pods → Services

**Say:** "Full Kubernetes visibility. We can drill down to individual resources."

---

### 4.4 Logs Explorer - **HIGHLIGHT**

```powershell
Start-Process "https://us5.datadoghq.com/logs"
```

**Actions:**
1. Set time: "Past 15 minutes"
2. Search: `kube_namespace:sock-shop`

**Expected:** Live log stream from all services

**Say:** "Centralized logging for all 8 microservices. Over 5,500 logs collected and indexed."

---

**Filter by service:**

Search: `kube_namespace:sock-shop service:orders`

**Say:** "Let me find the order we just placed."

---

**Search for your order ID:**

Search: `68f35ed59c10d300018b7011` (use your actual ID)

**Expected:** Logs showing order creation → payment → queue → processing

**Say:** 
> "Complete audit trail:
> 1. Front-end received POST
> 2. Orders service created order
> 3. Payment processed
> 4. Message published to RabbitMQ
> 5. Queue-master consumed and processed
> 
> Critical for debugging - we can trace any request through the entire system."

---

### 4.5 Log Facets

**Actions:**
1. Click "service" facet (left sidebar)

**Expected:** All 8 services with log counts

**Say:** "We can filter by service, pod, container, log level, or custom tags. Makes troubleshooting extremely fast."

---

### 4.6 Metrics Explorer

```powershell
Start-Process "https://us5.datadoghq.com/metric/explorer"
```

**Actions:**
1. Search metric: `kubernetes.cpu.usage`
2. Filter: `kube_cluster_name:sockshop-kind`
3. Click "Graph"

**Expected:** CPU usage graph for all pods

**Say:** "Datadog collects 400+ metrics automatically. Combined with logs for complete observability."

---

## Part 5: Troubleshooting Scenarios
**Duration:** 5-10 minutes

### 5.1 Introduce Scenario

**Say:** "Let me show you the troubleshooting workflow for production issues."

---

### 5.2 Check Pod Status

```powershell
kubectl get pods -n sock-shop -o wide
```

**Say:** 
> "In real scenarios, we might see:
> - Pod restarts (RESTARTS > 0)
> - CrashLoopBackOff
> - Pending pods
> 
> Let me show the workflow."

---

### 5.3 Check Application Logs

```powershell
kubectl logs -n sock-shop deployment/front-end --tail=50
```

**Expected:** Recent log entries

**Say:** "First step: check logs directly in Kubernetes for recent activity and errors."

---

### 5.4 Cross-Reference with Datadog

**Actions:**
1. Switch to Datadog Logs
2. Filter: `kube_namespace:sock-shop service:front-end status:error`

**Say:** "In Datadog, I can search for errors across all services and all time - much more powerful than kubectl."

---

### 5.5 Check Resource Usage

```powershell
kubectl top pods -n sock-shop
```

**Expected:**
```
NAME            CPU(cores)   MEMORY(bytes)
carts-xxx       5m           450Mi
front-end-xxx   8m           200Mi
```

**Say:** "Excessive CPU/memory appears here. We correlate with Grafana or Datadog metrics."

---

### 5.6 Troubleshooting Workflow Summary

**Say:**
> "Our troubleshooting workflow:
> 
> **Level 1: Quick Check**
> - Grafana dashboards for immediate visibility
> - Datadog alerts (if configured)
> 
> **Level 2: Logs Analysis**
> - Datadog Logs Explorer for error patterns
> - Filter by service, time, log level
> 
> **Level 3: Deep Dive**
> - Prometheus queries for metrics correlation
> - kubectl for pod inspection
> - Datadog traces (if APM enabled)
> 
> **Level 4: Root Cause**
> - Container metrics in Datadog
> - Resource usage analysis
> - Network connectivity checks
> 
> This layered approach enables quick issue resolution."

---

## Closing Statement

**Say:**
> "To summarize:
> 
> **Application:**
> - Production-grade microservices (8 services, 4 databases, message queue)
> - Multi-architecture support (AMD64, ARM, Power, Z)
> 
> **Monitoring:**
> - Prometheus for metrics collection
> - Grafana for visualization
> - Real-time dashboards
> 
> **Observability:**
> - Datadog centralized logging (5,500+ logs)
> - Full Kubernetes visibility
> - Container and process-level metrics
> - End-to-end request tracing
> 
> **DevOps Benefits:**
> - Faster troubleshooting (minutes vs hours)
> - Proactive issue detection
> - Complete audit trail for compliance
> - Scalable for hundreds of services
> 
> This demonstrates production-ready observability for cloud-native applications."

---

## Q&A Preparation

### Common Questions & Answers

**Q: How much does this cost to run?**
A: 
- KIND cluster: Free (local)
- Prometheus/Grafana: Free (self-hosted)
- Datadog: ~$31/host/month for Infrastructure + Logs (2 hosts = $62/month)
- Production would use managed Kubernetes (EKS/GKE/AKS)

**Q: How do you handle secrets?**
A: 
- Currently using Kubernetes Secrets (base64 encoded)
- Production would use Vault, AWS Secrets Manager, or Azure Key Vault
- API keys never committed to Git

**Q: Can this scale?**
A: 
- Each microservice can scale independently
- Kubernetes handles horizontal pod autoscaling
- Demonstrated with HPA for front-end service
- Databases would need sharding/replication in production

**Q: What about security?**
A: 
- Currently no network policies (demo environment)
- Production would add:
  - Istio/Linkerd for mTLS between services
  - Network policies to restrict pod-to-pod communication
  - Pod Security Standards
  - Image scanning

**Q: How do you deploy updates?**
A: 
- Currently using kubectl apply
- Production would use:
  - CI/CD pipelines (GitHub Actions, GitLab CI, Jenkins)
  - GitOps (ArgoCD, Flux)
  - Blue-green or canary deployments
  - Automated rollback on failures

**Q: What's the difference between Prometheus and Datadog metrics?**
A: 
- **Prometheus:** Self-hosted, free, requires infrastructure management, 15s scrape interval
- **Datadog:** SaaS, paid, managed service, 10s collection, includes logs/APM/RUM
- We use both: Prometheus for cost-effective metrics, Datadog for advanced features

**Q: How long did setup take?**
A: 
- Initial setup: 4-6 hours (cluster + app + monitoring)
- Datadog integration: 30 minutes
- Documentation: Ongoing
- Repeatable via scripts: 15 minutes

**Q: Can you demo APM (Application Performance Monitoring)?**
A: 
- Currently disabled to reduce complexity
- Enabling APM requires:
  - Instrumenting application code
  - Adding Datadog APM agent
  - Enabling trace collection
- Would show distributed tracing across services

**Q: What happens if Datadog goes down?**
A: 
- Logs are buffered locally by agent (up to 10MB)
- Prometheus/Grafana continue working (local)
- Application functionality unaffected
- Logs resume when Datadog recovers

---

## Troubleshooting Tips

### If Pods Won't Start

```powershell
kubectl describe pod -n sock-shop <pod-name>
kubectl logs -n sock-shop <pod-name>
```

Look for:
- Image pull errors
- Resource constraints
- CrashLoopBackOff

---

### If Port Forwards Fail

```powershell
# Kill all processes on ports
$ports = 2025,3025,4025,5025
(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }).OwningProcess | Sort-Object -Unique | ForEach-Object { taskkill /PID $_ /F }

# Restart forwards
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'
```

---

### If Datadog Shows No Logs

```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/component=agent -o json | ConvertFrom-Json).items[0].metadata.name
kubectl -n datadog exec $POD -c agent -- agent status
```

Check:
- API Key valid
- LogsProcessed > 0
- No errors in agent logs

---

### If Grafana Won't Login

Default credentials:
- Username: `admin`
- Password: `prom-operator`

If changed, reset:
```powershell
kubectl get secret -n monitoring kps-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

---

## Appendix: Port Reference

| Service | Port | URL |
|---------|------|-----|
| Sock Shop UI | 2025 | http://localhost:2025 |
| Grafana | 3025 | http://localhost:3025 |
| Prometheus | 4025 | http://localhost:4025 |
| RabbitMQ Exporter | 5025 | http://localhost:5025/metrics |

---

## Appendix: Key Commands

### Quick Status Check
```powershell
kubectl get pods -A | Select-String "sock-shop|monitoring|datadog"
```

### Full Health Check
```powershell
kubectl get pods -A
kubectl top nodes
kubectl top pods -n sock-shop
```

### Restart Everything
```powershell
kubectl rollout restart deployment -n sock-shop
kubectl rollout restart deployment -n monitoring
kubectl rollout restart daemonset -n datadog
```

---

## Converting This Guide to PDF

### Option 1: VS Code Extension
1. Install "Markdown PDF" extension
2. Open this file in VS Code
3. Right-click → "Markdown PDF: Export (pdf)"

### Option 2: Pandoc
```powershell
pandoc SOCK-SHOP-COMPLETE-DEMO-GUIDE.md -o demo-guide.pdf --pdf-engine=xelatex
```

### Option 3: Browser
1. Open this file in browser (Chrome/Edge)
2. Press Ctrl+P
3. Save as PDF

---

**End of Guide** | **Good Luck with Your Demo!** 🎉
