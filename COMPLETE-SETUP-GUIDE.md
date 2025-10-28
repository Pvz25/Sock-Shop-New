# Sock Shop Observability Demo — Complete Setup Guide

**Version:** 1.0  
**Last Updated:** October 21, 2025  
**Environment:** Windows 11 + kind + Docker Desktop (WSL2)  
**Repository:** https://github.com/ocp-power-demos/sock-shop-demo  
**Local Path:** `D:\sock-shop-demo`

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Prerequisites](#prerequisites)
4. [Environment Configuration](#environment-configuration)
5. [Cluster Setup](#cluster-setup)
6. [Application Deployment](#application-deployment)
7. [Monitoring Stack Setup](#monitoring-stack-setup)
8. [Datadog Agent Configuration](#datadog-agent-configuration)
9. [Port Forwarding](#port-forwarding)
10. [Verification & Testing](#verification--testing)
11. [Troubleshooting](#troubleshooting)
12. [Advanced Topics](#advanced-topics)
13. [Reference](#reference)

---

## Overview

### Purpose

This setup demonstrates a **production-grade microservices observability platform** using the Sock Shop e-commerce application. It showcases:

- **Multi-architecture compute** (amd64, ppc64le, s390x, arm64)
- **Cloud-native monitoring** with Prometheus & Grafana
- **Centralized logging** with Datadog
- **Message queue observability** with RabbitMQ metrics
- **Real-world microservices patterns** (Spring Boot, Go, Node.js)

### What is Sock Shop?

Sock Shop is a microservices reference application that simulates an online sock store. Originally created by WeaveWorks, this is a **multi-architecture port** supporting IBM Power, x86, ARM, and s390x platforms.

**Business Flow:**
1. Users browse a catalog of socks
2. Add items to cart (session-based)
3. Login/register
4. Checkout and pay
5. Orders are queued via RabbitMQ
6. Shipping service processes fulfillment

---

## System Architecture

### High-Level Architecture

```mermaid
flowchart LR
  subgraph UI
    FE[front-end]
  end

  subgraph Catalogue
    CAT[catalogue]
    CATDB[(catalogue-db\nMariaDB)]
  end

  subgraph Users
    USR[user]
    UDB[(user-db\nMongoDB)]
  end

  subgraph Carts
    CRT[carts]
    CDB[(carts-db\nMongoDB)]
  end

  subgraph Orders
    ORD[orders]
    ODB[(orders-db\nMongoDB)]
  end

  subgraph Payments_MQ["Payments & MQ"]
    PAY[payment]
    RMQ[(rabbitmq)]
  end

  subgraph Infra
    REDIS[(session-db\nRedis)]
  end

  FE -- REST --> CAT
  FE -- REST --> USR
  FE -- REST --> CRT
  FE -- REST --> ORD
  FE -- REST --> PAY
  FE -- TCP:6379 --> REDIS

  CAT --- CATDB
  USR --- UDB
  CRT --- CDB
  ORD --- ODB
  PAY --- RMQ
```

### Components

#### Application Services

| Service | Technology | Purpose | Port | Database |
|---------|-----------|---------|------|----------|
| **front-end** | Node.js | Web UI, shopping interface | 8079 | Redis (sessions) |
| **catalogue** | Go | Product catalog service | 8080 | MariaDB |
| **user** | Go | User authentication & profiles | 8080 | MongoDB |
| **carts** | Java/Spring Boot | Shopping cart service | 8080 | MongoDB |
| **orders** | Java/Spring Boot | Order processing | 8080 | MongoDB |
| **payment** | Go | Payment processing | 8080 | None |
| **shipping** | Java/Spring Boot | Shipping & fulfillment | 8080 | None |
| **queue-master** | Java/Spring Boot | RabbitMQ consumer | 8080 | None |

#### Infrastructure Services

| Service | Type | Purpose | Image |
|---------|------|---------|-------|
| **rabbitmq** | Message Broker | Async order processing | `quay.io/powercloud/rabbitmq:latest` |
| **session-db** | Redis | Session storage | `registry.redhat.io/rhel9/redis-7:1-29` |
| **catalogue-db** | MariaDB | Product data | `quay.io/powercloud/sock-shop-catalogue-db:latest` |
| **user-db** | MongoDB | User data | `quay.io/powercloud/sock-shop-user-db:latest` |
| **carts-db** | MongoDB | Cart data | `quay.io/mongodb/mongodb:org-4.4-standalone-ubuntu2204` |
| **orders-db** | MongoDB | Order data | `quay.io/mongodb/mongodb:org-4.4-standalone-ubuntu2204` |

#### Monitoring Stack

| Component | Purpose | Access URL |
|-----------|---------|------------|
| **Prometheus** | Metrics collection & storage | `http://localhost:4025` |
| **Grafana** | Metrics visualization | `http://localhost:3025` |
| **Datadog Agent** | Log collection & forwarding | N/A (us5.datadoghq.com) |
| **RabbitMQ Exporter** | RabbitMQ metrics | `http://localhost:5025/metrics` |

### Multi-Architecture Support

- **AMD64** (x86_64): Default architecture, full support
- **PPC64LE** (IBM Power): Supported via custom overlays
- **ARM64** (AArch64): Supported via manifest lists
- **S390X** (IBM Z): Supported via manifest lists

Note: `catalogue-db` and some MongoDB images are AMD64-only in the current configuration.

---

## Prerequisites

### System Requirements

**Operating System:** Windows 10/11 (with WSL2)

**Minimum Hardware:**
- **CPU:** 4 cores (8 recommended)
- **RAM:** 8 GB (16 GB recommended)
- **Disk:** 40 GB free space

**Software Requirements:**

| Tool | Version | Purpose | Installation |
|------|---------|---------|-------------|
| **Docker Desktop** | 4.x+ | Container runtime | [Download](https://www.docker.com/products/docker-desktop/) |
| **kind** | 0.20+ | Local Kubernetes | `choco install kind` or download binary |
| **kubectl** | 1.28+ | Kubernetes CLI | `choco install kubernetes-cli` |
| **Helm** | 3.12+ | Kubernetes package manager | `choco install kubernetes-helm` |
| **PowerShell** | 7.x+ | Scripting | Built-in on Windows 11 |

### Verify Prerequisites

```powershell
# Check Docker
docker version
# Expected Output:
# Client: Docker Engine - Community
#  Version:           24.x.x
# Server: Docker Desktop
#  Version:           24.x.x

# Check kind
kind version
# Expected Output:
# kind v0.20.0 go1.20.4 windows/amd64

# Check kubectl
kubectl version --client
# Expected Output:
# Client Version: v1.28.x

# Check Helm
helm version
# Expected Output:
# version.BuildInfo{Version:"v3.12.x"}

# Check current context
kubectl config current-context
```

**Expected Output:**
```
Docker version: OK
kind version: OK  
kubectl version: OK
Helm version: OK
```

---

## Environment Configuration

### Network & Port Allocation

**Stable Local Port Forwards:**

| Service | Local Port | Target | Namespace |
|---------|------------|--------|----------|
| Sock Shop UI | **2025** | `front-end:80` | `sock-shop` |
| Grafana | **3025** | `kps-grafana:80` | `monitoring` |
| Prometheus | **4025** | `kps-kube-prometheus-stack-prometheus:9090` | `monitoring` |
| RabbitMQ Exporter | **5025** | `rabbitmq:9090` | `sock-shop` |

**Note:** These ports are chosen to avoid common conflicts. Original setup used NodePort 30001 for front-end, but port-forward is more reliable on Windows.

### Kubernetes Namespaces

| Namespace | Purpose | Created By |
|-----------|---------|------------|
| `sock-shop` | Application services | Manifest deployment |
| `monitoring` | Prometheus & Grafana | Helm (kube-prometheus-stack) |
| `datadog` | Datadog Agent DaemonSet | Helm (datadog/datadog) |

### Credentials & Secrets

**Grafana:**
- Username: `admin`
- Password: `prom-operator`

**MongoDB Credentials:**
- Stored in `manifests/base/env.secret`
- Auto-generated secret: `mongodb-creds` in `sock-shop` namespace

**Datadog API Key:**
- Stored in Kubernetes secret: `datadog-secret` in `datadog` namespace
- Required for log forwarding to us5.datadoghq.com

---

## Cluster Setup

### Create kind Cluster

**Cluster Name:** `sockshop`  
**Topology:** 2 nodes (1 control-plane + 1 worker)  
**Kubernetes Version:** v1.32.0

```powershell
# Check if cluster already exists
kind get clusters
```

**Expected Output (if exists):**
```
sockshop
```

**If cluster does NOT exist, create it:**

```powershell
# Create kind cluster configuration
@'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: sockshop
nodes:
- role: control-plane
- role: worker
'@ | Set-Content -Encoding UTF8 .\kind-sockshop.yaml

# Create cluster
kind create cluster --config .\kind-sockshop.yaml
```

**Expected Output:**
```
Creating cluster "sockshop" ...
 ✓ Ensuring node image (kindest/node:v1.32.0) 🖼
 ✓ Preparing nodes 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-sockshop"
You can now use your cluster with:

kubectl cluster-info --context kind-sockshop
```

### Verify Cluster

```powershell
# Get cluster info
kubectl cluster-info
```

**Expected Output:**
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

```powershell
# List all nodes
kubectl get nodes -o wide
```

**Expected Output:**
```
NAME                     STATUS   ROLES           AGE   VERSION   INTERNAL-IP   OS-IMAGE
sockshop-control-plane   Ready    control-plane   2m    v1.32.0   172.18.0.2    Debian GNU/Linux 11
sockshop-worker          Ready    <none>          2m    v1.32.0   172.18.0.3    Debian GNU/Linux 11
```

---

## Application Deployment

### Overview

The application uses **Kustomize** for declarative configuration management. All manifests are located in `D:\sock-shop-demo\manifests\`.

**Directory Structure:**
```
manifests/
├── base/                      # Base configurations
│   ├── 00-sock-shop-ns.yaml   # Namespace (OpenShift Project)
│   ├── 01-carts-dep.yaml      # Carts deployment
│   ├── 02-carts-svc.yaml      # Carts service
│   ├── ...                    # All service YAMLs
│   ├── kustomization.yaml     # Base kustomization
│   └── env.secret             # MongoDB credentials
└── overlays/
    ├── local-kind/            # KIND-specific overlay
    ├── multi/                 # Multi-arch compute
    ├── fyre/                  # IBM Fyre environment
    └── ...
```

### Deploy Sock Shop Application

**Step 1: Check for Existing Deployment**

```powershell
# Check if namespace exists
kubectl get ns sock-shop 2>$null

# Check for existing deployments
kubectl -n sock-shop get deploy,svc,pod -o wide 2>$null
```

**Step 2: Deploy Using Kustomize**

For a **local kind cluster**, use the `local-kind` overlay:

```powershell
# Navigate to repository root
cd D:\sock-shop-demo

# Apply manifests via kubectl with kustomize
kubectl apply -k manifests/overlays/local-kind/
```

**Expected Output:**
```
namespace/sock-shop created
deployment.apps/carts created
service/carts created
deployment.apps/carts-db created
persistentvolumeclaim/carts-db-temp-pvc created
service/carts-db created
deployment.apps/catalogue created
service/catalogue created
deployment.apps/catalogue-db created
service/catalogue-db created
deployment.apps/front-end created
service/front-end created
deployment.apps/orders created
service/orders created
deployment.apps/orders-db created
persistentvolumeclaim/orders-db-temp-pvc created
service/orders-db created
deployment.apps/payment created
service/payment created
deployment.apps/queue-master created
service/queue-master created
deployment.apps/rabbitmq created
service/rabbitmq created
deployment.apps/session-db created
service/session-db created
deployment.apps/shipping created
service/shipping created
deployment.apps/user created
service/user created
deployment.apps/user-db created
persistentvolumeclaim/user-db-temp-pvc created
service/user-db created
secret/mongodb-creds created
```

**Step 3: Wait for Pods to be Ready**

```powershell
# Watch pod status
kubectl -n sock-shop get pods -w
```

**Expected Final State (all Running):**
```
NAME                            READY   STATUS    RESTARTS   AGE
carts-5d7f9b8d4f-xxxxx          1/1     Running   0          2m
carts-db-6b8c5d9f7c-xxxxx       1/1     Running   0          2m
catalogue-7d8f9c6b5d-xxxxx      1/1     Running   0          2m
catalogue-db-5c7d8f9b6c-xxxxx   1/1     Running   0          2m
front-end-6d9f8c7b5d-xxxxx      1/1     Running   0          2m
orders-5c8d9f7b6c-xxxxx         1/1     Running   0          2m
orders-db-7d9f8c6b5d-xxxxx      1/1     Running   0          2m
payment-6c9d8f7b5c-xxxxx        1/1     Running   0          2m
queue-master-7d8f9c6b5d-xxxxx   1/1     Running   0          2m
rabbitmq-5d9f8c7b6d-xxxxx       2/2     Running   0          2m
session-db-6c8d9f7b5c-xxxxx     1/1     Running   0          2m
shipping-7d9f8c6b5d-xxxxx       1/1     Running   0          2m
user-5c9d8f7b6c-xxxxx           1/1     Running   0          2m
user-db-6d8f9c7b5c-xxxxx        1/1     Running   0          2m
```

**Note:** `catalogue` and `user` services have **extended readiness probe delays** (180s) because they wait for their databases to be fully ready.

**Step 4: Verify RabbitMQ**

```powershell
# Check RabbitMQ pod (should have 2 containers: rabbitmq + rabbitmq-exporter)
$POD = kubectl -n sock-shop get pod -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
kubectl -n sock-shop get pod $POD
```

**Expected Output:**
```
NAME                        READY   STATUS    RESTARTS   AGE
rabbitmq-5d9f8c7b6d-xxxxx   2/2     Running   0          3m
```

```powershell
# Check RabbitMQ listeners (AMQP :5672 and exporter :9419)
kubectl -n sock-shop exec $POD -- sh -lc 'netstat -lnt | egrep ":5672|:9419" || true'
```

**Expected Output:**
```
tcp        0      0 0.0.0.0:5672            0.0.0.0:*               LISTEN
tcp        0      0 :::5672                 :::*                    LISTEN
tcp6       0      0 :::9419                 :::*                    LISTEN
```

---

## Monitoring Stack Setup

### kube-prometheus-stack (Prometheus + Grafana)

**Step 1: Add Helm Repository**

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

**Expected Output:**
```
"prometheus-community" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "prometheus-community" chart repository
```

**Step 2: Create monitoring Namespace**

```powershell
kubectl create namespace monitoring
```

**Expected Output:**
```
namespace/monitoring created
```

**Step 3: Create Helm Values File**

This file is already present at `D:\sock-shop-demo\values-kps-kind-clean.yml`:

```yaml
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeEtcd:
  enabled: false
kubeProxy:
  enabled: false
```

**Note:** We disable these components because kind doesn't expose them in a scrapable way.

**Step 4: Install kube-prometheus-stack**

```powershell
helm upgrade --install kps `
  -n monitoring `
  prometheus-community/kube-prometheus-stack `
  -f D:\sock-shop-demo\values-kps-kind-clean.yml `
  --set grafana.adminPassword='prom-operator'
```

**Expected Output:**
```
Release "kps" does not exist. Installing it now.
NAME: kps
LAST DEPLOYED: [timestamp]
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

**Step 5: Wait for Deployment**

```powershell
# Wait for Grafana
kubectl -n monitoring rollout status deploy/kps-grafana --timeout=5m

# Wait for Prometheus
kubectl -n monitoring rollout status statefulset/prometheus-kps-kube-prometheus-stack-prometheus --timeout=5m

# List all pods
kubectl -n monitoring get pods -o wide
```

**Expected Output:**
```
NAME                                                     READY   STATUS    AGE
alertmanager-kps-kube-prometheus-stack-alertmanager-0    2/2     Running   2m
kps-grafana-xxxxxxxxxx-xxxxx                             3/3     Running   2m
kps-kube-prometheus-stack-operator-xxxxxxxxxx-xxxxx      1/1     Running   2m
kps-kube-state-metrics-xxxxxxxxxx-xxxxx                  1/1     Running   2m
prometheus-kps-kube-prometheus-stack-prometheus-0        2/2     Running   2m
```

**Step 6: (Optional) Create ServiceMonitor for RabbitMQ**

A ServiceMonitor already exists at `D:\sock-shop-demo\servicemonitor-rabbitmq.yaml`:

```powershell
kubectl apply -f D:\sock-shop-demo\servicemonitor-rabbitmq.yaml
```

**Expected Output:**
```
servicemonitor.monitoring.coreos.com/sm-rabbitmq created
```

This tells Prometheus to scrape the RabbitMQ exporter on port `9090` (mapped to container port `9419`).

---

## Datadog Agent Configuration

### Overview

The Datadog Agent is configured for **logs-only collection** from the `sock-shop` namespace. It forwards logs to **us5.datadoghq.com**.

**Configuration Modes:**

- **PASS-A** (`datadog-values-pass-a.yaml`): Collect logs from **all** containers (troubleshooting mode)
- **PASS-B** (`datadog-values-pass-b-clean.yaml`): Collect logs **only** from `sock-shop` namespace (production mode)

### Step 1: Add Helm Repository

```powershell
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

**Expected Output:**
```
"datadog" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "datadog" chart repository
```

### Step 2: Create datadog Namespace & Secret

```powershell
# Create namespace
kubectl create namespace datadog

# Set your Datadog API key
$DD_API_KEY = "YOUR_DATADOG_API_KEY_HERE"

# Create secret
kubectl -n datadog create secret generic datadog-secret --from-literal=api-key=$DD_API_KEY
```

**Expected Output:**
```
namespace/datadog created
secret/datadog-secret created
```

**Verify Secret:**
```powershell
kubectl -n datadog get secret datadog-secret
```

**Expected Output:**
```
NAME             TYPE     DATA   AGE
datadog-secret   Opaque   1      10s
```

### Step 3: Install Datadog Agent (PASS-B Mode)

```powershell
helm upgrade --install datadog-agent `
  -n datadog `
  datadog/datadog `
  -f D:\sock-shop-demo\datadog-values-pass-b-clean.yaml
```

**Expected Output:**
```
Release "datadog-agent" does not exist. Installing it now.
NAME: datadog-agent
LAST DEPLOYED: [timestamp]
NAMESPACE: datadog
STATUS: deployed
REVISION: 1
```

**Step 4: Verify Agent Pods**

```powershell
# Watch pods (should be 2: one per node)
kubectl -n datadog get pods -o wide -w
```

**Expected Output:**
```
NAME                  READY   STATUS    NODE
datadog-agent-xxxxx   2/2     Running   sockshop-control-plane
datadog-agent-xxxxx   2/2     Running   sockshop-worker
```

**Step 5: Verify Log Collection on Worker Node**

```powershell
# Get the worker agent pod
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

# Check that agent sees sock-shop log files
kubectl -n datadog exec $POD -c agent -- sh -lc 'ls -l /var/log/containers | grep -i sock-shop | head -n 10 || true'
```

**Expected Output:**
```
lrwxrwxrwx 1 root root  front-end-xxxxx_sock-shop_front-end-xxxxx.log -> /var/log/pods/sock-shop_front-end-xxxxx/.../3.log
lrwxrwxrwx 1 root root  carts-xxxxx_sock-shop_carts-xxxxx.log -> /var/log/pods/sock-shop_carts-xxxxx/.../2.log
...
```

**Step 6: Check Agent Status**

```powershell
# Wait 10-20 seconds after deployment, then check status
Start-Sleep -Seconds 15
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,70 -Pattern 'Logs Agent'
```

**Expected Output (healthy):**
```
Logs Agent
==========
  Reliable: Sending compressed logs in HTTPS to agent-http-intake.logs.us5.datadoghq.com on port 443
  BytesSent: 1234567
  EncodedBytesSent: 123456
  LogsProcessed: 1234
  LogsSent: 1234
  RetryCount: 0
  RetryTimeSpent: 0
```

### Step 7: Verify in Datadog UI

1. Go to **Datadog Logs Explorer**: https://us5.datadoghq.com/logs
2. Set time range: **Past 15 minutes**
3. Query:
   ```
   kube_cluster_name:sockshop-kind kube_namespace:sock-shop
   ```
4. You should see live logs from all sock-shop services

**Test Queries:**
- Search for specific order IDs: `68f35ed59c10d300018b7011`
- Filter by service: `service:front-end`
- Filter by pod: `pod_name:carts-*`

### Troubleshooting: Switch to PASS-A (Collect All Logs)

If you need to prove the pipeline works end-to-end:

```powershell
# Upgrade to PASS-A mode (collect everything)
helm upgrade --install datadog-agent `
  -n datadog `
  datadog/datadog `
  -f D:\sock-shop-demo\datadog-values-pass-a.yaml

# Wait for rollout
kubectl -n datadog rollout status daemonset/datadog-agent --timeout=2m

# Check status (LogsProcessed should increase rapidly)
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,70 -Pattern 'Logs Agent'

# Revert back to PASS-B
helm upgrade --install datadog-agent `
  -n datadog `
  datadog/datadog `
  -f D:\sock-shop-demo\datadog-values-pass-b-clean.yaml
```

---

## Port Forwarding

### Why Port Forwarding?

On Windows + kind, NodePort services can be blocked by firewalls and are inconsistent. **Port forwarding** provides stable, reliable access to services.

### Start All Port Forwards

```powershell
# Free up ports first (kill any existing forwards)
$ports = 2025,3025,4025,5025
(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }).OwningProcess | Sort-Object -Unique | ForEach-Object { taskkill /PID $_ /F } 2>$null

# Start forwards in separate windows
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'
Start-Process powershell -ArgumentList 'kubectl -n monitoring port-forward svc/kps-grafana 3025:80'
Start-Process powershell -ArgumentList 'kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 4025:9090'
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/rabbitmq 5025:9090'

# Wait for forwards to establish
Start-Sleep -Seconds 5

# Quick check
Write-Host "Port forwards started. Testing..."
Invoke-WebRequest -UseBasicParsing http://localhost:2025 | Out-Null
Write-Host "✓ Sock Shop UI: http://localhost:2025"
Invoke-WebRequest -UseBasicParsing http://localhost:3025 | Out-Null
Write-Host "✓ Grafana: http://localhost:3025"
Invoke-WebRequest -UseBasicParsing http://localhost:4025 | Out-Null
Write-Host "✓ Prometheus: http://localhost:4025"
Invoke-WebRequest -UseBasicParsing http://localhost:5025/metrics | Out-Null
Write-Host "✓ RabbitMQ Exporter: http://localhost:5025/metrics"
Write-Host "All port forwards are healthy!"
```

**Expected Output:**
```
Port forwards started. Testing...
✓ Sock Shop UI: http://localhost:2025
✓ Grafana: http://localhost:3025
✓ Prometheus: http://localhost:4025
✓ RabbitMQ Exporter: http://localhost:5025/metrics
All port forwards are healthy!
```

### Stop All Port Forwards

```powershell
$ports = 2025,3025,4025,5025
(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }).OwningProcess | Sort-Object -Unique | ForEach-Object { taskkill /PID $_ /F } 2>$null
Write-Host "Port forwards stopped."
```

---

## Verification & Testing

### End-to-End User Journey

**Step 1: Access Sock Shop UI**

```powershell
Start-Process 'http://localhost:2025'
```

You should see the Sock Shop homepage with a catalog of socks.

**Step 2: Register a New User**

1. Click **Login** (top right)
2. Click **Register**
3. Fill in:
   - **Username:** `testuser`
   - **Password:** `password123`
   - **Email:** `test@example.com`
4. Click **Register**

**Expected:** You're logged in and see your username in the header.

**Step 3: Add Items to Cart**

1. Browse the catalog
2. Click on any sock (e.g., "Weave special")
3. Click **Add to cart**
4. Repeat for 2-3 different socks

**Expected:** Cart icon shows item count.

**Step 4: Place an Order**

1. Click **Cart** icon
2. Click **Proceed to checkout**
3. Fill in shipping details:
   - **Address:** `123 Main St`
   - **City:** `Springfield`
   - **Postcode:** `12345`
   - **Country:** `USA`
4. Click **Next**
5. Use default payment card
6. Click **Place order**

**Expected:** Order confirmation page, order ID displayed.

**Step 5: Verify Order in Logs**

```powershell
# Get recent front-end logs
$FE_POD = kubectl -n sock-shop get pod -l name=front-end -o jsonpath='{.items[0].metadata.name}'
kubectl -n sock-shop logs $FE_POD --tail=50 | Select-String -Pattern "order"
```

**Expected:** You'll see log entries related to the order placement.

### Verify RabbitMQ Metrics

```powershell
# Open RabbitMQ exporter in browser
Start-Process 'http://localhost:5025/metrics'
```

**Expected Metrics (sample):**
```
# HELP rabbitmq_queue_messages_ready Number of messages ready to be delivered to clients
rabbitmq_queue_messages_ready{queue="shipping-task",vhost="/"} 0

# HELP rabbitmq_queue_messages_published_total Count of messages published
rabbitmq_queue_messages_published_total{queue="shipping-task",vhost="/"} 5

# HELP rabbitmq_queue_messages_delivered_total Count of messages delivered
rabbitmq_queue_messages_delivered_total{queue="shipping-task",vhost="/"} 5
```

### Verify Prometheus Targets

```powershell
Start-Process 'http://localhost:4025/targets'
```

**Expected:** All targets with label `namespace="sock-shop"` should be **UP** (green).

**Run PromQL Queries:**

1. Go to **Graph** tab: http://localhost:4025/graph
2. Try these queries:

```promql
# Check all sock-shop pods are up
up{namespace="sock-shop"}

# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{namespace="sock-shop"}[2m])) by (pod)

# Memory usage by pod
container_memory_working_set_bytes{namespace="sock-shop"}

# RabbitMQ queue depth
sum by (queue) (rabbitmq_queue_messages_ready)

# RabbitMQ message publish rate
sum(rate(rabbitmq_queue_messages_published_total[1m]))

# RabbitMQ message delivery rate
sum(rate(rabbitmq_queue_messages_delivered_total[1m]))
```

### Verify Grafana

```powershell
Start-Process 'http://localhost:3025'
```

**Login:**
- Username: `admin`
- Password: `prom-operator`

**Create a Dashboard:**

1. Click **+ → Dashboard**
2. Click **Add visualization**
3. Select **Prometheus** data source
4. Query:
   ```promql
   sum(rate(rabbitmq_queue_messages_published_total[1m]))
   ```
5. Set panel title: "RabbitMQ Message Publish Rate"
6. Click **Apply**

**Expected:** You'll see a graph showing message publish activity.

### Verify Datadog Logs

1. Go to: https://us5.datadoghq.com/logs
2. Time range: **Past 15 minutes**
3. Query:
   ```
   kube_cluster_name:sockshop-kind kube_namespace:sock-shop
   ```
4. You should see logs from all services

**Search for Your Order:**

If you placed an order, search for order-related logs:
```
kube_cluster_name:sockshop-kind service:orders "order"
```

---

## Troubleshooting

### Common Issues

#### 1. Pods Stuck in `Pending` or `ContainerCreating`

**Check:**
```powershell
kubectl -n sock-shop get pods
kubectl -n sock-shop describe pod <pod-name>
```

**Common Causes:**
- Image pull issues
- Insufficient resources
- PVC not bound

**Fix:**
```powershell
# Check events
kubectl -n sock-shop get events --sort-by='.lastTimestamp'

# Check PVCs
kubectl -n sock-shop get pvc

# Restart Docker Desktop if needed
```

#### 2. `catalogue` or `user` Not Ready (Stuck > 3 minutes)

**Issue:** These services wait for database readiness (180s probe delay).

**Check Database:**
```powershell
# Check catalogue-db
kubectl -n sock-shop logs deployment/catalogue-db --tail=50

# Check user-db
kubectl -n sock-shop logs deployment/user-db --tail=50
```

**Fix:**
```powershell
# Restart the database pod
kubectl -n sock-shop delete pod -l name=catalogue-db
kubectl -n sock-shop delete pod -l name=user-db
```

#### 3. RabbitMQ Exporter Shows No Metrics

**Check:**
```powershell
$POD = kubectl -n sock-shop get pod -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
kubectl -n sock-shop get pod $POD
```

**Expected:** `READY 2/2` (rabbitmq + exporter containers)

**Verify Listeners:**
```powershell
kubectl -n sock-shop exec $POD -- sh -lc 'netstat -lnt | egrep ":5672|:9419"'
```

**Expected:**
- `:5672` - AMQP
- `:9419` - Exporter

#### 4. Datadog Agent: `LogsProcessed: 0`

**Critical Issue:** Configuration problem preventing log collection.

**Root Cause:** The agent is configured with `containerCollectAll: false` but the namespace filter is not being properly applied, resulting in zero logs being processed despite log files existing.

**Quick Check:**
```powershell
# Get the WORKER agent
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

# Check if logs are being processed
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,20 -Pattern 'Logs Agent'
```

**If you see `LogsProcessed: 0`:**

⚠️ **SEE COMPLETE FIX:** Refer to `DATADOG-FIX-GUIDE.md` for the comprehensive solution.

**Quick Fix (Resolves $setElementOrder Error):**
```powershell
cd D:\sock-shop-demo

# Upgrade with FIXED production configuration
helm upgrade datadog-agent datadog/datadog `
  --namespace datadog `
  --values datadog-values-production-fixed.yaml `
  --wait

# Wait 2-3 minutes, then verify
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"
```

**Expected After Fix:** `LogsProcessed: [non-zero number]`

**Note:** If you encounter a `$setElementOrder` Helm error, it means duplicate environment variables exist. Use `datadog-values-production-fixed.yaml` which removes duplicates and relies on Helm chart auto-configuration.

See `DATADOG-FIX-GUIDE.md` for detailed explanation, alternative solutions, and troubleshooting steps.

---

## Advanced Topics

### Optional: Synthetic Load Testing

**Create RabbitMQ Test User:**

```powershell
$POD = kubectl -n sock-shop get pod -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
kubectl -n sock-shop exec $POD -- /opt/rabbitmq/sbin/rabbitmqctl add_user perf perfpass 2>$null
kubectl -n sock-shop exec $POD -- /opt/rabbitmq/sbin/rabbitmqctl set_permissions -p / perf ".*" ".*" ".*"
```

**Run Load Test (60s @ 20 msg/s):**

```powershell
kubectl -n sock-shop delete pod perf-rabbit --now 2>$null
kubectl -n sock-shop run perf-rabbit `
  --image=pivotalrabbitmq/perf-test:latest `
  --image-pull-policy=IfNotPresent `
  --restart=Never `
  -- "--uri" "amqp://perf:perfpass@rabbitmq.sock-shop.svc.cluster.local:5672/%2F" `
     "--queue" "perf-shipping" "--producers" "1" "--consumers" "1" "--autoack" `
     "--rate" "20" "--id" "sockshop-demo" "--time" "60"

kubectl -n sock-shop logs perf-rabbit -f
```

### Cleanup

**Delete Application:**
```powershell
kubectl delete namespace sock-shop
```

**Delete Entire Cluster:**
```powershell
kind delete cluster --name sockshop
```

---

## Reference

### Quick Commands

```powershell
# Cluster status
kubectl get nodes
kubectl -n sock-shop get pods -o wide

# Logs
kubectl -n sock-shop logs <pod-name> --tail=100 -f

# Port forwards
kubectl -n sock-shop port-forward svc/front-end 8080:80

# Delete and restart
kubectl -n sock-shop delete pod <pod-name>
```

### External References

- **GitHub:** https://github.com/ocp-power-demos/sock-shop-demo
- **Sock Shop Demo:** https://microservices-demo.github.io/
- **kind Documentation:** https://kind.sigs.k8s.io/

---

## Summary

You now have a **complete microservices observability platform**:

✅ **Application:** 14 microservices + 5 databases  
✅ **Monitoring:** Prometheus + Grafana  
✅ **Logging:** Datadog Agent → us5.datadoghq.com  
✅ **Message Queue:** RabbitMQ with metrics exporter  
✅ **Platform:** Windows 11 + kind + Docker Desktop

### Quick Start Checklist

- [ ] Create kind cluster
- [ ] Deploy app: `kubectl apply -k manifests/overlays/local-kind/`
- [ ] Install Prometheus/Grafana
- [ ] Install Datadog
- [ ] Start port forwards
- [ ] Open UI: http://localhost:2025

---

**Document Version:** 1.0  
**Created:** October 21, 2025  
**Environment:** Windows 11, kind v0.20+, Kubernetes v1.32.0

**End of Guide**
