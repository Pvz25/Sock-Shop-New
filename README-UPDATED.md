# Sock Shop: Production-Grade Microservices Observability Demo

<div align="center">

![Sock Shop](https://raw.githubusercontent.com/microservices-demo/microservices-demo.github.io/master/assets/Architecture.png)

**A complete microservices reference application with enterprise-grade observability, multi-architecture support, and comprehensive incident simulation capabilities.**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Multi-Arch](https://img.shields.io/badge/Multi--Arch-AMD64%20%7C%20ARM64%20%7C%20PPC64LE%20%7C%20S390X-green)](https://www.docker.com/blog/multi-arch-build-and-images-the-simple-way/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus%20%2B%20Grafana-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Datadog](https://img.shields.io/badge/Observability-Datadog-632CA6?logo=datadog&logoColor=white)](https://www.datadoghq.com/)

[Features](#-key-features) •
[Quick Start](#-quick-start) •
[Architecture](#-architecture) •
[Incidents](#-incident-simulation) •
[Documentation](#-documentation)

</div>

---

## 📖 Overview

Sock Shop is a **production-ready microservices e-commerce application** designed to demonstrate cloud-native technologies, observability patterns, and SRE practices. This repository extends the original Weaveworks demo with:

- ✅ **Enterprise Observability**: Full-stack monitoring with Prometheus, Grafana, and Datadog
- ✅ **Multi-Architecture Support**: Native builds for AMD64, ARM64, IBM Power (PPC64LE), and IBM Z (S390X)
- ✅ **9 Incident Scenarios**: Realistic failure scenarios for testing SRE agent capabilities
- ✅ **Complete Documentation**: Step-by-step guides for setup, demo, and troubleshooting
- ✅ **Load Testing**: Integrated Locust-based load testing framework
- ✅ **Production Patterns**: RabbitMQ async messaging, distributed databases, service mesh ready

### 🎯 Use Cases

| Audience | Purpose |
|----------|---------|
| **DevOps Engineers** | Learn Kubernetes observability and monitoring best practices |
| **SRE Teams** | Test incident response workflows and agent capabilities |
| **Platform Architects** | Evaluate multi-architecture compute strategies |
| **Sales/Presales** | Demonstrate cloud-native platform capabilities |
| **Students/Learners** | Hands-on microservices and observability training |

---

## 🌟 Key Features

### Application Features
- **8 Microservices**: Front-end (Node.js), Catalogue (Go), User (Go), Carts (Java), Orders (Java), Payment (Go), Shipping (Java), Queue-Master (Java)
- **4 Databases**: MariaDB, MongoDB (×3), Redis
- **Message Queue**: RabbitMQ for asynchronous order processing
- **Complete E-commerce Flow**: Browse → Add to Cart → Checkout → Payment → Fulfillment

### Observability Stack
- **Metrics**: Prometheus with kube-state-metrics, node-exporter, RabbitMQ exporter
- **Visualization**: Grafana dashboards for Kubernetes resource monitoring
- **Logging**: Datadog centralized log collection (3,000+ logs/day)
- **Infrastructure**: Datadog Infrastructure Monitoring, Container Monitoring, Kubernetes Explorer
- **Custom Metrics**: DogStatsD endpoint for application-level metrics
- **RabbitMQ Metrics**: 50+ metrics via Prometheus exporter (queue depth, consumers, message rates)

### Incident Simulation (9 Scenarios)
- **Incident 1**: Application crash via resource exhaustion (OOMKilled)
- **Incident 2**: Hybrid crash + latency (frontend crashes, backend slow)
- **Incident 3**: Payment service failure (internal service outage)
- **Incident 4**: Pure application latency (CPU throttling)
- **Incident 5**: Async processing failure (consumer down)
- **Incident 5C**: Queue blockage (middleware queue capacity limit)
- **Incident 6**: Payment gateway timeout (third-party API failure)
- **Incident 7**: Autoscaling failure (HPA misconfiguration)
- **Incident 8**: Database performance degradation (resource limits)
- **Load Testing**: Configurable Locust tests with 10-3000 concurrent users

### Multi-Architecture
- **AMD64/x86_64**: Full support across all services
- **ARM64/AArch64**: All services with manifest-listed images
- **PPC64LE (IBM Power)**: Custom overlays with database support
- **S390X (IBM Z)**: Full support via manifest lists

---

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Browser                         │
└────────────────────────────┬──────────────────────────────────┘
                             │
                   ┌─────────▼──────────┐
                   │   Front-End        │
                   │   (Node.js)        │
                   │   Port: 8079       │
                   └──┬──────┬──────┬───┘
                      │      │      │
         ┌────────────┼──────┼──────┼─────────────┐
         │            │      │      │             │
    ┌────▼────┐  ┌───▼───┐ │ ┌────▼────┐   ┌────▼────┐
    │Catalogue│  │  User │ │ │  Carts  │   │ Orders  │
    │  (Go)   │  │  (Go) │ │ │ (Java)  │   │ (Java)  │
    └────┬────┘  └───┬───┘ │ └────┬────┘   └────┬────┘
         │           │     │      │             │
    ┌────▼────┐ ┌───▼───┐ │ ┌────▼────┐   ┌────▼────┐
    │MariaDB  │ │MongoDB│ │ │MongoDB  │   │MongoDB  │
    └─────────┘ └───────┘ │ └─────────┘   └─────────┘
                           │
                      ┌────▼────┐
                      │  Redis  │
                      │(Session)│
                      └─────────┘
                           
    Payment (Go) ──┬── RabbitMQ ──┬── Queue-Master (Java)
                   │              │
    Shipping (Java)─┘              └── Async Processing
```

### Technology Stack

| Component | Technology | Purpose | Image Registry |
|-----------|-----------|---------|----------------|
| **front-end** | Node.js 16 | Web UI, shopping interface | `quay.io/powercloud/sock-shop-front-end` |
| **catalogue** | Go 1.19 | Product catalog service | `quay.io/powercloud/sock-shop-catalogue` |
| **user** | Go 1.19 | User authentication & profiles | `quay.io/powercloud/sock-shop-user` |
| **carts** | Java 11 (Spring Boot) | Shopping cart service | `quay.io/powercloud/sock-shop-carts` |
| **orders** | Java 11 (Spring Boot) | Order processing | `quay.io/powercloud/sock-shop-orders` |
| **payment** | Go 1.19 | Payment gateway simulation | `quay.io/powercloud/sock-shop-payment` |
| **shipping** | Java 11 (Spring Boot) | Shipping & fulfillment | `quay.io/powercloud/sock-shop-shipping` |
| **queue-master** | Java 11 (Spring Boot) | RabbitMQ consumer | `quay.io/powercloud/sock-shop-queue-master` |
| **rabbitmq** | RabbitMQ 3.12 | Message broker | `quay.io/powercloud/rabbitmq` |
| **session-db** | Redis 7 | Session storage | `registry.redhat.io/rhel9/redis-7` |
| **stripe-mock** | Stripe Mock | Payment gateway simulator | `stripe/stripe-mock` |

### Monitoring Stack

| Component | Purpose | Port/Access |
|-----------|---------|-------------|
| **Prometheus** | Metrics collection & storage | `:4025` (port-forward) |
| **Grafana** | Visualization dashboards | `:3025` (port-forward) |
| **Datadog Agent** | Log collection & forwarding | us5.datadoghq.com |
| **RabbitMQ Exporter** | RabbitMQ metrics (50+ metrics) | `:9090/metrics` |

---

## 🏁 Getting Started

### Step 1: Clone the Repository

First, get a copy of the Sock Shop code on your computer:

```bash
# Clone the repository
git clone https://github.com/Pvz25/Sock-Shop-New.git

# Navigate into the directory
cd Sock-Shop-New
```

**Don't have Git?**
- **Windows**: Download from [git-scm.com](https://git-scm.com/download/win)
- **macOS**: `brew install git` or download from [git-scm.com](https://git-scm.com/download/mac)
- **Linux**: `sudo apt-get install git` (Ubuntu/Debian) or `sudo yum install git` (RHEL/CentOS)

### Step 2: Install Prerequisites

Before you can run Sock Shop, you need to install some tools. Don't worry - we'll guide you through each one!

#### 📦 Docker Desktop (Required)

Docker runs containers on your computer. Think of it as a lightweight virtual machine.

**Windows**:
1. Download [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. Run the installer
3. **IMPORTANT**: During installation, enable "Use WSL 2 instead of Hyper-V"
4. Restart your computer when prompted
5. Open Docker Desktop and wait for it to start (you'll see a green icon in the system tray)
6. Verify installation:
   ```powershell
   docker --version
   # Should show: Docker version 24.x.x or higher
   
   docker ps
   # Should show: Empty list (or running containers)
   ```

**macOS**:
1. Download [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
2. Drag Docker.app to Applications folder
3. Open Docker Desktop from Applications
4. Wait for Docker to start (whale icon in menu bar)
5. Verify installation:
   ```bash
   docker --version
   docker ps
   ```

**Linux**:
1. Follow the official guide for your distribution:
   - [Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
   - [Debian](https://docs.docker.com/engine/install/debian/)
   - [Fedora](https://docs.docker.com/engine/install/fedora/)
2. Verify installation:
   ```bash
   docker --version
   docker ps
   ```

#### 🎯 KIND (Kubernetes in Docker)

KIND creates a Kubernetes cluster using Docker containers. It's perfect for local development.

**Windows**:
```powershell
# Option 1: Using Chocolatey (recommended)
choco install kind

# Option 2: Manual download
# Download from: https://github.com/kubernetes-sigs/kind/releases
# Rename to kind.exe and add to PATH
```

**macOS**:
```bash
# Using Homebrew (recommended)
brew install kind

# Verify installation
kind version
# Should show: kind v0.20.0 or higher
```

**Linux**:
```bash
# Download and install
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
```

#### ☸️ kubectl (Kubernetes Command-Line Tool)

kubectl lets you control your Kubernetes cluster.

**Windows**:
```powershell
# Option 1: Using Chocolatey (recommended)
choco install kubernetes-cli

# Option 2: Manual download
# Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

**macOS**:
```bash
# Using Homebrew (recommended)
brew install kubectl

# Verify installation
kubectl version --client
# Should show: Client Version v1.28.0 or higher
```

**Linux**:
```bash
# Download latest version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make it executable
chmod +x kubectl

# Move to PATH
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

#### ⎈ Helm (Kubernetes Package Manager) - Optional for basic setup

Helm is needed only if you want to install Prometheus and Grafana monitoring.

**Windows**:
```powershell
choco install kubernetes-helm
```

**macOS**:
```bash
brew install helm
```

**Linux**:
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

#### 💻 PowerShell 7+ (Windows users only)

Required for running incident simulation scripts.

**Windows**:
```powershell
# Check current version
$PSVersionTable.PSVersion

# If version is less than 7.0, install:
winget install --id Microsoft.Powershell --source winget
```

### Step 3: Verify All Tools Are Installed

Run these commands to make sure everything is ready:

```bash
# Check Docker
docker --version
docker ps
# ✅ Should show version and running containers (or empty list)

# Check KIND
kind version
# ✅ Should show: kind v0.20.0 or higher

# Check kubectl
kubectl version --client
# ✅ Should show: Client Version v1.28.0 or higher

# Check Helm (optional)
helm version
# ✅ Should show: version.BuildInfo
```

**All checks passed?** Great! You're ready to deploy Sock Shop! 🎉

**Something failed?** See the [Troubleshooting](#-troubleshooting) section below.

### Step 4: Choose Your Setup Path

Now decide which setup you want:

| Option | Time | What You Get | Best For |
|--------|------|--------------|----------|
| **Option 1: Basic** | ⏱️ 10 min | Sock Shop application only | Quick demo, learning Kubernetes |
| **Option 2: OpenShift** | ⏱️ 15 min | OpenShift deployment | Enterprise environments |
| **Option 3: Full Stack** | ⏱️ 45 min | App + Prometheus + Grafana + Datadog | Production-like observability |

**Recommendation for beginners**: Start with **Option 1** to verify everything works, then add monitoring later if needed.

---

## 🚀 Quick Start

### Prerequisites

- **Kubernetes Cluster**: KIND 0.20+, Minikube, or OpenShift 4.12+
- **kubectl**: v1.28+
- **Helm**: v3.12+
- **Docker**: 24.x+ (for KIND/Minikube)
- **OS**: Linux, macOS, or Windows 11 with WSL2
- **PowerShell**: 7.0+ (for Windows users running incident scripts)

### Option 1: KIND Cluster (Local Development) - ⏱️ 10 minutes

**What you'll do**: Create a local Kubernetes cluster and deploy Sock Shop.

**Prerequisites**: Docker Desktop running, KIND and kubectl installed (see [Getting Started](#-getting-started) above)

#### Step-by-Step Instructions

**Step 1: Create KIND Cluster**

```bash
# Create a 2-node Kubernetes cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: sockshop
nodes:
- role: control-plane
- role: worker
EOF
```

**Windows PowerShell users**: Use this syntax instead:
```powershell
@"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: sockshop
nodes:
- role: control-plane
- role: worker
"@ | kind create cluster --config=-
```

**Expected output**:
```
Creating cluster "sockshop" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-sockshop"
```

✅ **Success indicator**: You see "Set kubectl context to 'kind-sockshop'"

❌ **If it fails**: See [Troubleshooting - KIND cluster creation fails](#kind-cluster-creation-fails)

---

**Step 2: Deploy Sock Shop**

```bash
# Deploy all Sock Shop services
kubectl apply -k manifests/overlays/local-kind/
```

**Expected output**:
```
namespace/sock-shop created
service/carts created
service/catalogue created
...
deployment.apps/carts created
deployment.apps/catalogue created
...
```

✅ **Success indicator**: You see multiple "created" messages

---

**Step 3: Wait for Pods to Start** (takes 2-3 minutes)

```bash
# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n sock-shop --timeout=300s
```

**Expected output**:
```
pod/carts-xxx condition met
pod/catalogue-xxx condition met
pod/front-end-xxx condition met
...
```

✅ **Success indicator**: All pods show "condition met"

❌ **If timeout occurs**: Some pods may be slow to start. Check status:
```bash
kubectl get pods -n sock-shop
```

See [Troubleshooting - Pods stuck in Pending](#pods-stuck-in-pending-or-imagepullbackoff) if needed.

---

**Step 4: Access the Application**

```bash
# Forward port 2025 on your computer to the front-end service
kubectl port-forward -n sock-shop svc/front-end 2025:80
```

**Expected output**:
```
Forwarding from 127.0.0.1:2025 -> 8079
Forwarding from [::1]:2025 -> 8079
```

✅ **Success indicator**: You see "Forwarding from 127.0.0.1:2025"

**IMPORTANT**: Keep this terminal window open! The port forward only works while this command is running.

---

**Step 5: Open Sock Shop in Your Browser**

1. Open your web browser
2. Go to: **http://localhost:2025**
3. You should see the Sock Shop homepage with colorful socks!

**Test the application**:
1. Click **"Login"** (top right)
2. Use these credentials:
   - **Username**: `user`
   - **Password**: `password`
3. Click **"Login"**
4. ✅ You should see "Logged in as user" in the top right

**Try shopping**:
1. Click on any sock to view details
2. Click **"Add to cart"**
3. Click the **shopping cart icon** (top right)
4. Click **"Proceed to checkout"**
5. Click **"Place order"**
6. ✅ You should see "Order placed successfully!"

🎉 **Congratulations!** Sock Shop is running on your computer!

---

#### Verify Installation

Run these commands in a **new terminal** (keep port-forward running in the first one):

```bash
# Check all pods are running
kubectl get pods -n sock-shop
```

**Expected output**: All pods should show `1/1` in READY column and `Running` in STATUS:
```
NAME                            READY   STATUS    RESTARTS   AGE
carts-xxx                       1/1     Running   0          5m
catalogue-xxx                   1/1     Running   0          5m
front-end-xxx                   1/1     Running   0          5m
...
```

✅ **Success**: All 15 pods showing "Running"

❌ **Issues**: See [Verification Checklist](#-verification-checklist) below

---

#### What's Running?

You now have:
- ✅ **15 pods** (8 microservices + 4 databases + 3 infrastructure)
- ✅ **15 services** (networking between pods)
- ✅ **1 namespace** (sock-shop)
- ✅ **Full e-commerce application** (browse, cart, checkout, payment, shipping)

**Next steps**:
- Try the [Incident Simulations](#-incident-simulation) to test failure scenarios
- Add [Monitoring](#-monitoring--observability) with Prometheus and Grafana
- Explore the [Architecture](#-architecture) to understand how it works

### Option 2: OpenShift Cluster

```bash
# 1. Update credentials
cat > manifests/base/env.secret <<EOF
username=your-username
password=your-password
EOF

# 2. Deploy with Kustomize
kustomize build manifests/overlays/multi | oc apply -f -

# 3. Get the route
oc get route -n sock-shop

# Visit the provided URL
```

### Option 3: Complete Setup with Observability (Production-Grade)

For a **production-grade setup** with Prometheus, Grafana, and Datadog, follow the comprehensive guide:

```bash
# See COMPLETE-SETUP-GUIDE.md for detailed instructions
# Includes:
# - KIND cluster setup (2-node configuration)
# - Application deployment (15 pods)
# - Prometheus + Grafana installation
# - Datadog agent configuration (logs + metrics)
# - RabbitMQ metrics setup (50+ metrics)
# - Port forwarding setup
# - Verification steps
# - Troubleshooting guide
```

📘 **Full Guide**: [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md)

---

## 📊 Monitoring & Observability

### Prometheus + Grafana

**Install kube-prometheus-stack:**

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values-kps-kind-clean.yml \
  --set grafana.adminPassword='prom-operator'

# Access Grafana
kubectl port-forward -n monitoring svc/kps-grafana 3025:80
# Visit http://localhost:3025 (admin/prom-operator)

# Access Prometheus
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 4025:9090
# Visit http://localhost:4025
```

### Datadog Integration (OPTIONAL)

**Note**: Datadog is **optional**. You can use Prometheus and Grafana for monitoring without Datadog. Datadog provides additional features like centralized logging and advanced analytics.

**To use Datadog, you need**:
1. A Datadog account (free trial available at [datadoghq.com](https://www.datadoghq.com/))
2. An API key from your Datadog account

**Setup centralized logging and advanced metrics:**

```bash
# Step 1: Get your Datadog API key
# 1. Sign up at https://www.datadoghq.com/ (free trial available)
# 2. Go to: Organization Settings > API Keys
# 3. Copy your API key

# Step 2: Add Datadog Helm repository
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Step 3: Create namespace and secret
kubectl create namespace datadog
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_ACTUAL_API_KEY \
  -n datadog
# Replace YOUR_ACTUAL_API_KEY with the key you copied in Step 1

# Step 4: Install Datadog Agent
helm install datadog-agent datadog/datadog \
  -n datadog \
  -f datadog-values-metrics-logs.yaml

# Step 5: Verify installation
kubectl get pods -n datadog
# Should show datadog-agent pods in Running status
```

**Features Enabled:**
- ✅ Container log collection (3,000+ logs/day)
- ✅ Kubernetes metrics (CPU, memory, network)
- ✅ Process-level metrics
- ✅ Orchestrator Explorer (full cluster visibility)
- ✅ Infrastructure monitoring
- ✅ DogStatsD endpoint (port 8125)
- ✅ RabbitMQ metrics (50+ metrics via OpenMetrics)

📘 **Datadog Setup Guide**: [RABBITMQ-DATADOG-PERMANENT-FIX.md](./RABBITMQ-DATADOG-PERMANENT-FIX.md)

---

## ✅ Verification Checklist

Use this checklist to verify your Sock Shop installation is working correctly.

### Basic Health Checks

```bash
# 1. Check all pods are running
kubectl get pods -n sock-shop
```
**Expected**: All 15 pods show `1/1 Running`

```bash
# 2. Check services are created
kubectl get svc -n sock-shop
```
**Expected**: 15 services listed

```bash
# 3. Test front-end is accessible
curl http://localhost:2025
```
**Expected**: HTML response containing "Sock Shop"

### Application Functionality Tests

**Test 1: Homepage Loads**
- ✅ Visit http://localhost:2025
- ✅ See colorful sock images
- ✅ See "Sock Shop" in the title

**Test 2: Login Works**
- ✅ Click "Login" (top right)
- ✅ Enter: user / password
- ✅ See "Logged in as user"

**Test 3: Shopping Cart Works**
- ✅ Click any sock
- ✅ Click "Add to cart"
- ✅ Cart icon shows "1"
- ✅ Click cart icon
- ✅ See sock in cart

**Test 4: Checkout Works**
- ✅ In cart, click "Proceed to checkout"
- ✅ Click "Place order"
- ✅ See "Order placed successfully!"

**All tests passed?** 🎉 Your installation is working perfectly!

**Some tests failed?** See [Troubleshooting](#-troubleshooting) below.

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### KIND cluster creation fails

**Error**: `ERROR: failed to create cluster: ...`

**Solutions**:

1. **Check Docker is running**:
   ```bash
   docker ps
   ```
   If error, start Docker Desktop and wait for it to be ready (green icon).

2. **Delete any existing cluster**:
   ```bash
   kind delete cluster --name sockshop
   ```
   Then try creating again.

3. **Check Docker has enough resources**:
   - Open Docker Desktop
   - Go to Settings > Resources
   - Ensure:
     - **CPUs**: 4 or more
     - **Memory**: 8GB or more
     - **Disk**: 20GB or more
   - Click "Apply & Restart"

---

#### Pods stuck in "Pending" or "ImagePullBackOff"

**Check pod status**:
```bash
kubectl get pods -n sock-shop
kubectl describe pod <pod-name> -n sock-shop
```

**Common causes and solutions**:

**1. Insufficient resources**:
```bash
# Check if error message contains "Insufficient cpu" or "Insufficient memory"
kubectl describe pod <pod-name> -n sock-shop | grep -i insufficient
```
**Solution**: Increase Docker Desktop resources (Settings > Resources > Memory: 8GB+)

**2. Image pull errors**:
```bash
# Check if error message contains "ImagePullBackOff" or "ErrImagePull"
kubectl describe pod <pod-name> -n sock-shop | grep -i image
```
**Solution**: 
- Check internet connection
- Wait a few minutes and check again (images are large)
- Verify image exists: `docker pull quay.io/powercloud/sock-shop-front-end:latest`

**3. Slow startup**:
Some pods (especially databases) can take 3-5 minutes to start.

**Solution**: Wait and check again:
```bash
watch kubectl get pods -n sock-shop
# Press Ctrl+C to exit
```

---

#### Port forward fails

**Error**: `error: unable to listen on port 2025: Listeners failed to create with the following errors: [unable to create listener: Error listen tcp4 127.0.0.1:2025: bind: address already in use]`

**Solutions**:

**1. Port 2025 is already in use**:

**Windows**:
```powershell
# Find what's using port 2025
netstat -ano | findstr :2025

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

**macOS/Linux**:
```bash
# Find what's using port 2025
lsof -i :2025

# Kill the process (replace PID with actual process ID)
kill -9 <PID>
```

**2. Use a different port**:
```bash
# Use port 8080 instead
kubectl port-forward -n sock-shop svc/front-end 8080:80

# Then visit: http://localhost:8080
```

---

#### Application not accessible at localhost:2025

**Checklist**:

1. **Is port-forward still running?**
   - Check the terminal where you ran `kubectl port-forward`
   - Should show: "Forwarding from 127.0.0.1:2025 -> 8079"
   - If not, run the command again

2. **Are all pods running?**
   ```bash
   kubectl get pods -n sock-shop
   ```
   All should show `1/1 Running`

3. **Is front-end pod healthy?**
   ```bash
   kubectl logs -n sock-shop deployment/front-end --tail=20
   ```
   Should not show errors

4. **Are you using the correct URL?**
   - ✅ Correct: `http://localhost:2025` (http, not https)
   - ❌ Wrong: `https://localhost:2025`

5. **Try a different browser**:
   - Sometimes browser cache causes issues
   - Try incognito/private mode

---

#### "connection refused" when accessing localhost:2025

**Solutions**:

1. **Restart port-forward**:
   - Press `Ctrl+C` in the port-forward terminal
   - Run again: `kubectl port-forward -n sock-shop svc/front-end 2025:80`

2. **Check front-end service exists**:
   ```bash
   kubectl get svc front-end -n sock-shop
   ```
   Should show the service details

3. **Check front-end pod is running**:
   ```bash
   kubectl get pods -n sock-shop -l name=front-end
   ```
   Should show `1/1 Running`

---

#### Prometheus/Grafana installation fails

**Error**: `Error: values.yaml file not found` or `Error: INSTALLATION FAILED`

**Solutions**:

**1. Verify values file exists**:
```bash
ls values-kps-kind-clean.yml
```

**2. If file is missing, use default values**:
```bash
# Install without custom values
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword='prom-operator'
```

**3. Verify Helm repository is added**:
```bash
helm repo list | grep prometheus-community

# If not found, add it:
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

---

#### Datadog agent not collecting logs

**Error**: No logs appearing in Datadog UI

**Solutions**:

**1. Check agent pods are running**:
```bash
kubectl get pods -n datadog
```
All should show `Running`

**2. Check for errors in agent logs**:
```bash
kubectl logs -n datadog <datadog-agent-pod> | grep -i error
```

**3. Verify API key is correct**:
```bash
kubectl get secret datadog-secret -n datadog -o jsonpath='{.data.api-key}' | base64 -d
```
Should show your actual API key (not YOUR_API_KEY)

**4. Check Datadog site is correct**:
In `datadog-values-metrics-logs.yaml`, verify:
```yaml
site: us5.datadoghq.com  # Should match your Datadog account region
```

**5. Datadog is optional**:
If you don't need Datadog, you can skip it and use only Prometheus/Grafana.

---

### Getting More Help

If you're still stuck after trying these solutions:

1. **Check the detailed setup guide**:
   - [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md) - Step-by-step instructions with screenshots

2. **Search existing issues**:
   - [GitHub Issues](https://github.com/Pvz25/Sock-Shop-New/issues)
   - Someone may have had the same problem

3. **Open a new issue**:
   - Go to: [New Issue](https://github.com/Pvz25/Sock-Shop-New/issues/new)
   - Include:
     - Your OS (Windows/macOS/Linux)
     - Tool versions: `docker --version`, `kind version`, `kubectl version`
     - Complete error message
     - Output of: `kubectl get pods -n sock-shop`
     - What you were trying to do

4. **Check documentation**:
   - [Kubernetes Docs](https://kubernetes.io/docs/)
   - [KIND Docs](https://kind.sigs.k8s.io/docs/user/quick-start/)
   - [Docker Docs](https://docs.docker.com/)

---

## 🔥 Incident Simulation

Test SRE agent capabilities with **9 realistic production failure scenarios**:

### Incident 1: Application Crash (Resource Exhaustion)

**Simulates**: OOMKilled pod crashes under extreme load (3000 users)

```bash
cd load
kubectl apply -f locust-crash-test.yaml

# Monitor pods crashing
kubectl get pods -n sock-shop -w

# Expected: Front-end pods CrashLoopBackOff, OOMKilled events
```

**SRE Test Query**: *"What caused the application crash at 10:23 AM?"*

### Incident 2: Hybrid Crash + Latency

**Simulates**: Frontend crashes (OOMKilled) + backend latency (750 users)

```bash
kubectl apply -f locust-hybrid-test.yaml

# Expected: Frontend crashes, catalogue/user services slow
```

**SRE Test Query**: *"Application is crashing AND slow. What's happening?"*

### Incident 3: Payment Service Failure

**Simulates**: Internal payment service outage (scaled to 0)

```bash
# Scale payment service to 0
kubectl scale deployment payment --replicas=0 -n sock-shop

# Place orders - they will fail with PAYMENT_FAILED status
```

**SRE Test Query**: *"Payments are failing. Investigate and fix."*

### Incident 4: Pure Application Latency

**Simulates**: Severe slowness without crashes (500 users, CPU throttling)

```bash
kubectl apply -f locust-latency-test.yaml

# Monitor response times
kubectl logs -f -n sock-shop deployment/front-end | grep "response_time"

# Expected: P95 latency >3 seconds, no pod restarts
```

**SRE Test Query**: *"Users report site slowness. Investigate and recommend fixes."*

### Incident 5: Async Processing Failure

**Simulates**: Queue consumer down, messages not processing

```bash
# Execute incident script
.\incident-5-activate.ps1

# Expected: Orders stuck at "SHIPPED" status, queue backlog grows
```

**SRE Test Query**: *"Orders are placed but not shipping. What's wrong?"*

### Incident 5C: Queue Blockage (Middleware Queue Capacity)

**Simulates**: RabbitMQ queue at capacity, rejecting new messages

```bash
# Execute incident script (5-minute duration)
.\incident-5c-execute-fixed.ps1 -DurationSeconds 300

# Expected: First 3 orders succeed, orders 4+ fail with "Queue unavailable"
```

**Client Requirement**: *"Customer order processing stuck in middleware queue due to blockage in a queue/topic"*

**SRE Test Query**: *"Orders are failing with queue errors. Investigate."*

📘 **Definitive Guide**: [INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md](./INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md)

### Incident 6: Payment Gateway Timeout

**Simulates**: Third-party payment API (Stripe) unavailable

```bash
# Execute incident script (5-minute duration)
.\incident-6-activate-timed.ps1 -DurationSeconds 300

# Expected: Payment pods healthy, but gateway unreachable
# Orders fail with "Payment gateway error: connection refused"
```

**SRE Test Query**: *"Payments failing but payment service is healthy. Why?"*

📘 **Observability Guide**: [INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md](./INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md)

### Incident 7: Autoscaling Failure

**Simulates**: HPA misconfiguration preventing scale-up under load

```bash
# Apply broken HPA
kubectl apply -f incident-7-broken-hpa.yaml

# Run load test - pods won't scale despite high CPU
```

**SRE Test Query**: *"Application is slow but not scaling. Check HPA."*

📘 **Observability Guide**: [INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md](./INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md)

### Incident 8: Database Performance Degradation

**Simulates**: Database slowness due to resource limits

```bash
# Incident details in documentation
```

**SRE Test Query**: *"Database queries are slow. Investigate performance."*

### 📘 Complete Incident Documentation

| Incident | Guide | Type |
|----------|-------|------|
| **Master Guide** | [INCIDENT-SIMULATION-MASTER-GUIDE.md](./INCIDENT-SIMULATION-MASTER-GUIDE.md) | Overview of all 9 incidents |
| **Incident 1** | [INCIDENT-1-APP-CRASH.md](./INCIDENT-1-APP-CRASH.md) | Resource exhaustion |
| **Incident 2** | [INCIDENT-2-HYBRID-CRASH-LATENCY.md](./INCIDENT-2-HYBRID-CRASH-LATENCY.md) | Hybrid failure |
| **Incident 3** | [INCIDENT-3-PAYMENT-FAILURE.md](./INCIDENT-3-PAYMENT-FAILURE.md) | Service outage |
| **Incident 4** | [INCIDENT-4-APP-LATENCY.md](./INCIDENT-4-APP-LATENCY.md) | Performance degradation |
| **Incident 5** | [INCIDENT-5-ASYNC-PROCESSING-FAILURE.md](./INCIDENT-5-ASYNC-PROCESSING-FAILURE.md) | Consumer failure |
| **Incident 5C** | [INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md](./INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md) | Queue blockage |
| **Incident 6** | [INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md](./INCIDENT-6-PAYMENT-GATEWAY-TIMEOUT.md) | External API failure |
| **Incident 7** | [INCIDENT-7-AUTOSCALING-FAILURE.md](./INCIDENT-7-AUTOSCALING-FAILURE.md) | HPA misconfiguration |
| **Incident 8** | [INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md](./INCIDENT-8-DATABASE-PERFORMANCE-DEGRADATION.md) | Database slowness |

---

## 🎤 Demo & Presentation Guides

Professional presentation materials for showcasing the platform:

| Guide | Purpose | Duration |
|-------|---------|----------|
| [SOCK-SHOP-COMPLETE-DEMO-GUIDE.md](./SOCK-SHOP-COMPLETE-DEMO-GUIDE.md) | Complete demo script with timing | 30-45 min |
| [SOCK-SHOP-COMPLETE-ARCHITECTURE.md](./SOCK-SHOP-COMPLETE-ARCHITECTURE.md) | Detailed architecture documentation | Reference |

**Demo Flow:**
1. Introduction & Architecture (5 min)
2. Application Demo (10 min) - Complete user journey
3. Prometheus/Grafana (10 min) - Metrics & dashboards
4. Datadog (10 min) - Logs, infrastructure, Kubernetes explorer
5. Incident Simulation (10 min) - Live failure scenario
6. Q&A (5 min)

---

## 📚 Documentation

### Setup & Configuration

| Document | Description |
|----------|-------------|
| [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md) | **START HERE** - Complete setup from scratch (KIND + app + monitoring) |
| [RABBITMQ-DATADOG-PERMANENT-FIX.md](./RABBITMQ-DATADOG-PERMANENT-FIX.md) | RabbitMQ metrics integration (50+ metrics) |
| [DATADOG-ANALYSIS-GUIDE.md](./DATADOG-ANALYSIS-GUIDE.md) | Datadog features and query reference |
| [PORT-MAPPING-REFERENCE.md](./PORT-MAPPING-REFERENCE.md) | All service ports and access methods |

### Incident Simulation

| Document | Description |
|----------|-------------|
| [INCIDENT-SIMULATION-MASTER-GUIDE.md](./INCIDENT-SIMULATION-MASTER-GUIDE.md) | **Master guide** - All 9 incidents overview |
| [INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md](./INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md) | Queue blockage incident (definitive analysis) |
| [INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md](./INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md) | Payment gateway timeout observability |
| [INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md](./INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md) | Autoscaling failure observability |

### Architecture & Design

| Document | Description |
|----------|-------------|
| [SOCK-SHOP-COMPLETE-ARCHITECTURE.md](./SOCK-SHOP-COMPLETE-ARCHITECTURE.md) | Complete architecture documentation |
| [SOCK-SHOP-COMPLETE-DEMO-GUIDE.md](./SOCK-SHOP-COMPLETE-DEMO-GUIDE.md) | Demo presentation guide |

---

## 🏗️ Multi-Architecture Build

### Building Images

All services support cross-platform builds using Podman/Docker manifest lists:

```bash
# Set variables
export ARCH=ppc64le  # or amd64, arm64, s390x
export REGISTRY=quay.io/powercloud
export APP=front-end

# Build for specific architecture
make cross-build-${ARCH}

# Push individual architecture image
podman push ${REGISTRY}/sock-shop-${APP}:${ARCH}

# Create and push manifest list (all architectures)
make APP=${APP} push-ml
```

**Supported Architectures:**
- ✅ **AMD64/x86_64**: All services
- ✅ **ARM64/AArch64**: All services
- ✅ **PPC64LE (IBM Power)**: All services (custom database images)
- ✅ **S390X (IBM Z)**: All services

### Custom Repositories

Enhanced services with additional observability features:

- **front-end**: https://github.com/ocp-power-demos/sock-shop-front-end
- **user**: https://github.com/ocp-power-demos/sock-shop-user
- **orders**: https://github.com/ocp-power-demos/sock-shop-orders

---

## 🔧 Development

### Project Structure

```
sock-shop-demo/
├── manifests/              # Kubernetes manifests
│   ├── base/              # Base configurations
│   └── overlays/          # Environment-specific overlays
│       ├── local-kind/    # KIND cluster configuration
│       ├── multi/         # Multi-architecture OpenShift
│       ├── fyre/          # IBM Fyre environment
│       └── multi-hpa/     # With Horizontal Pod Autoscaler
├── load/                  # Locust load testing files
│   ├── locust-crash-test.yaml
│   ├── locust-latency-test.yaml
│   └── locust-payment-failure-test.yaml
├── automation/            # Dockerfiles for multi-arch builds
├── incident-*.ps1         # Incident simulation scripts
└── Makefile              # Build automation

# Configuration Files
├── datadog-values-*.yaml      # Datadog agent configurations
├── values-kps-kind-clean.yml  # Prometheus stack values
├── rabbitmq-datadog-fix-permanent.yaml  # RabbitMQ metrics fix
└── stripe-mock-deployment.yaml  # Payment gateway simulator
```

### Local Development

```bash
# Run application locally
kubectl apply -k manifests/overlays/local-kind/

# Enable port forwards
kubectl port-forward -n sock-shop svc/front-end 2025:80
kubectl port-forward -n monitoring svc/kps-grafana 3025:80
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 4025:9090

# View logs
kubectl logs -f -n sock-shop deployment/front-end

# Execute commands in pods
kubectl exec -it -n sock-shop deployment/orders -- /bin/sh

# Scale services
kubectl scale deployment front-end --replicas=3 -n sock-shop
```

### Testing

```bash
# Run quick smoke test
cd load
kubectl apply -f locust-quick-test.yaml

# Monitor test progress
kubectl logs -f -n sock-shop job/locust-quick-test

# Run full load test
kubectl apply -f locust-load-test.yaml
```

---

## 🤝 Contributing

Contributions are welcome! This project aims to provide a comprehensive microservices reference implementation.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**: Add features, fix bugs, improve documentation
4. **Test thoroughly**: Ensure all services still function
5. **Commit**: `git commit -m 'Add amazing feature'`
6. **Push**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### Contribution Guidelines

- **Code Quality**: Follow existing code style and patterns
- **Documentation**: Update relevant docs for any changes
- **Testing**: Include tests for new features
- **Commits**: Write clear, descriptive commit messages
- **Multi-Arch**: Ensure changes work across all architectures

### Areas for Contribution

- 🐛 Bug fixes and issue resolution
- 📝 Documentation improvements
- ✨ New incident simulation scenarios
- 🎨 Enhanced Grafana dashboards
- 🔧 CI/CD pipeline improvements
- 🌍 Multi-language support
- 🔐 Security enhancements

---

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

```
Copyright 2025 OCP Power Demos

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## 🙏 Acknowledgments

This project builds upon the excellent work of:

- **[Weaveworks](https://www.weave.works/)** - Original Sock Shop microservices demo
- **[Microservices Demo Organization](https://github.com/microservices-demo)** - Base application architecture
- **[Prometheus Community](https://prometheus.io/community/)** - Monitoring tools and exporters
- **[Datadog](https://www.datadoghq.com/)** - Enterprise observability platform
- **[Kubernetes Community](https://kubernetes.io/community/)** - Container orchestration platform

### Special Thanks

- The original Sock Shop contributors and maintainers
- IBM Power and Z teams for multi-architecture support
- OpenShift community for platform guidance
- All contributors who have helped improve this demo

---

## 📞 Support & Community

### Getting Help

- **Documentation**: Start with [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md)
- **Issues**: [GitHub Issues](https://github.com/Pvz25/Sock-Shop-New/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Pvz25/Sock-Shop-New/discussions)

### Resources

- **Original Sock Shop**: https://microservices-demo.github.io/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Datadog Documentation**: https://docs.datadoghq.com/

---

## 📊 Project Status

**Current Version**: 2.0  
**Last Updated**: November 2025  
**Status**: ✅ Production Ready

### What's New in v2.0

- ✅ **9 Incident Scenarios** (expanded from 3)
- ✅ **RabbitMQ Metrics** (50+ metrics via Prometheus exporter)
- ✅ **Payment Gateway Simulator** (Stripe Mock integration)
- ✅ **Enhanced Datadog Integration** (logs + metrics + RabbitMQ)
- ✅ **Automated Incident Scripts** (PowerShell with auto-recovery)
- ✅ **Comprehensive Documentation** (35+ guides)

### Roadmap

- [ ] Add APM/distributed tracing integration (Datadog APM)
- [ ] Implement service mesh (Istio/Linkerd) variant
- [ ] Add chaos engineering scenarios (Chaos Mesh)
- [ ] Create Terraform/Pulumi IaC modules
- [ ] Enhance security with Pod Security Standards
- [ ] Add cost analysis dashboard
- [ ] Create video tutorials and demos
- [ ] Multi-cluster deployment guide

---

<div align="center">

**⭐ Star this repository if you find it useful!**

**📢 Share it with your team and community**

Made with ❤️ by the OCP Power Demos Team

[Report Bug](https://github.com/Pvz25/Sock-Shop-New/issues) •
[Request Feature](https://github.com/Pvz25/Sock-Shop-New/issues) •
[Documentation](./COMPLETE-SETUP-GUIDE.md)

</div>
