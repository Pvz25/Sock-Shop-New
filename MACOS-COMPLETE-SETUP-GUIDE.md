# 🍎 Sock Shop Complete Setup Guide for macOS
## From Zero to Production-Grade Observability in 45 Minutes

<div align="center">

![Sock Shop](https://img.shields.io/badge/Sock_Shop-E--Commerce_Demo-blue?style=for-the-badge)
![macOS](https://img.shields.io/badge/macOS-Compatible-success?style=for-the-badge&logo=apple)
![Time](https://img.shields.io/badge/Setup_Time-45_Minutes-orange?style=for-the-badge)
![Difficulty](https://img.shields.io/badge/Difficulty-Beginner_Friendly-green?style=for-the-badge)

**A complete, step-by-step guide for absolute beginners**

[📖 Read Full Guide](#) | [🚀 Quick Start](#part-2-installing-prerequisites) | [🔧 Troubleshooting](#-common-issues--solutions)

</div>

---

## 📑 Table of Contents

### 🎯 Part 1: Understanding & Preparation (10 minutes)
- [What You'll Build](#-what-youll-build)
- [What You Need](#-what-you-need)
- [Understanding the Basics](#-understanding-the-basics)
- [System Requirements](#️-system-requirements)

### 🛠️ Part 2: Installing Prerequisites (15 minutes)
- [Step 1: Install Homebrew](#step-1-install-homebrew-3-minutes)
- [Step 2: Install Docker Desktop](#step-2-install-docker-desktop-5-minutes)
- [Step 3: Install KIND](#step-3-install-kind-1-minute)
- [Step 4: Install kubectl](#step-4-install-kubectl-1-minute)
- [Step 5: Install Helm](#step-5-install-helm-1-minute)
- [Step 6: Install Git](#step-6-install-git-1-minute)
- [Step 7: Verify All Installations](#step-7-verify-all-installations-1-minute)

### 📦 Part 3: Getting the Code (2 minutes)
- [Step 8: Clone Sock Shop Repository](#step-8-clone-sock-shop-repository-2-minutes)

### 🚀 Part 4: Deploying Sock Shop (5 minutes)
- [Step 9: Create Kubernetes Cluster](#step-9-create-kubernetes-cluster-2-minutes)
- [Step 10: Deploy Sock Shop Application](#step-10-deploy-sock-shop-application-3-minutes)
- [Step 11: Verify Application](#step-11-verify-application-is-running-1-minute)
- [Step 12: Access in Browser](#step-12-access-sock-shop-in-browser-1-minute)

### 📊 Part 5: Installing Monitoring (15 minutes)
- [Step 13: Install Prometheus + Grafana](#step-13-install-prometheus--grafana-10-minutes)
- [Step 14: Access Grafana](#step-14-access-grafana-dashboard-3-minutes)
- [Step 15: Install Datadog (Optional)](#step-15-install-datadog-agent-optional-5-minutes)

### ✅ Part 6: Verification & Testing (5 minutes)
- [Step 16: Complete System Verification](#step-16-complete-system-verification-3-minutes)
- [Step 17: Test All Features](#step-17-test-all-features-2-minutes)

### 🔧 Part 7: Troubleshooting & Help
- [Common Issues & Solutions](#-common-issues--solutions)
- [Understanding What You Built](#-understanding-what-you-built)
- [Next Steps & Learning](#-next-steps--learning-resources)

### 📋 Appendices
- [Quick Reference Commands](#-quick-reference-commands)
- [How to Clean Up](#️-how-to-clean-up)
- [Frequently Asked Questions](#-frequently-asked-questions)

---

## 🎯 What You'll Build

By the end of this guide, you'll have a **complete production-grade e-commerce application** running on your Mac with:

### 🛍️ Sock Shop E-Commerce Application
- ✅ Full online store with product catalog
- ✅ Shopping cart functionality
- ✅ User authentication (login/register)
- ✅ Checkout and payment processing
- ✅ Order fulfillment system

### 📊 Complete Observability Stack
- ✅ **Prometheus**: Collects metrics from all services
- ✅ **Grafana**: Beautiful dashboards to visualize metrics
- ✅ **Datadog** (optional): Advanced monitoring and log analysis
- ✅ **RabbitMQ Metrics**: Message queue monitoring

### 🏗️ What's Running Under the Hood
- **8 Microservices**: Front-end, Catalogue, User, Carts, Orders, Payment, Shipping, Queue-Master
- **4 Databases**: MariaDB, MongoDB (×3), Redis
- **1 Message Queue**: RabbitMQ for async processing
- **15 Total Pods**: All working together seamlessly

**Think of it as**: Building a mini-Amazon on your laptop! 🚀

---

## 🧰 What You Need

### Required (Must Have)
- ✅ **Mac computer** (any Mac from 2015 or newer)
- ✅ **macOS** 11 (Big Sur) or later
- ✅ **Internet connection** (for downloading tools and images)
- ✅ **45 minutes of time** (uninterrupted is best)
- ✅ **Administrator access** (you'll need your password)

### Optional (Nice to Have)
- ⭐ **Datadog account** (free trial) - for advanced monitoring
- ⭐ **Basic terminal knowledge** (we'll teach you!)

### Not Required
- ❌ Previous Kubernetes experience
- ❌ Programming knowledge
- ❌ DevOps background
- ❌ Cloud account (everything runs locally!)

---

## 💡 Understanding the Basics

Before we start, let's understand what we're working with. **Don't worry if these terms are new!**

### 🐳 Docker
**What it is**: A tool that packages applications into "containers"  
**Think of it as**: A shipping container for software  
**Why we need it**: To run applications consistently

### ☸️ Kubernetes (K8s)
**What it is**: A system that manages containers  
**Think of it as**: An orchestra conductor for containers  
**Why we need it**: To run multiple services together

### 🎯 KIND
**What it is**: Creates a Kubernetes cluster using Docker  
**Think of it as**: A mini Kubernetes playground  
**Why we need it**: To practice without needing cloud

### 🎛️ kubectl
**What it is**: Command-line tool to control Kubernetes  
**Think of it as**: A remote control for Kubernetes  
**Why we need it**: To tell Kubernetes what to do

### ⎈ Helm
**What it is**: Package manager for Kubernetes  
**Think of it as**: App Store for Kubernetes  
**Why we need it**: To install Prometheus and Grafana

### 🍺 Homebrew
**What it is**: Package manager for macOS  
**Think of it as**: App store for developer tools  
**Why we need it**: To install all tools easily

---

## ⚙️ System Requirements

### Minimum Requirements
- **CPU**: 4 cores
- **RAM**: 8 GB
- **Disk Space**: 20 GB free
- **macOS**: 11.0 (Big Sur) or later

### Recommended Requirements
- **CPU**: 8 cores
- **RAM**: 16 GB
- **Disk Space**: 30 GB free
- **macOS**: 12.0 (Monterey) or later

### Check Your System

Open **Terminal** (`Cmd + Space`, type "Terminal", press Enter):

```bash
# Check macOS version
sw_vers

# Check CPU cores
sysctl -n hw.ncpu

# Check RAM (in GB)
echo "$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )) GB"

# Check free disk space
df -h / | awk 'NR==2 {print $4 " available"}'
```

✅ **If your numbers meet or exceed minimum requirements, you're ready!**

---

# Part 2: Installing Prerequisites

## Step 1: Install Homebrew (3 minutes)

### 1.1 Open Terminal
1. Press `Cmd + Space`
2. Type "Terminal"
3. Press `Enter`

### 1.2 Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

- Press `Enter` when prompted
- Enter your Mac password (you won't see characters - this is normal!)
- Wait 2-3 minutes

### 1.3 Add Homebrew to PATH

**For Apple Silicon (M1/M2/M3)**:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**For Intel Macs**:
```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

### 1.4 Verify

```bash
brew --version
```

✅ **Expected**: `Homebrew 4.x.x`

---

## Step 2: Install Docker Desktop (5 minutes)

### 2.1 Install via Homebrew

```bash
brew install --cask docker
```

Wait 2-3 minutes for download (~500 MB)

### 2.2 Start Docker Desktop

1. Press `Cmd + Space`
2. Type "Docker"
3. Press `Enter`
4. Click "Accept" on Service Agreement
5. Click "Use recommended settings"
6. Wait for whale icon in menu bar to show "running"

### 2.3 Configure Resources

1. Click whale icon → Settings → Resources
2. Set:
   - **CPUs**: 4
   - **Memory**: 8 GB
   - **Swap**: 2 GB
   - **Disk**: 60 GB
3. Click "Apply & Restart"

### 2.4 Verify

```bash
docker --version
docker ps
```

✅ **Expected**: Version number and empty container list

---

## Step 3: Install KIND (1 minute)

```bash
brew install kind
kind version
```

✅ **Expected**: `kind v0.20.0`

---

## Step 4: Install kubectl (1 minute)

```bash
brew install kubectl
kubectl version --client
```

✅ **Expected**: `Client Version: v1.28.x`

---

## Step 5: Install Helm (1 minute)

```bash
brew install helm
helm version
```

✅ **Expected**: `version.BuildInfo{Version:"v3.x.x"`

---

## Step 6: Install Git (1 minute)

```bash
git --version
```

If not installed:
```bash
brew install git
```

✅ **Expected**: `git version 2.x.x`

---

## Step 7: Verify All Installations (1 minute)

```bash
echo "🔍 Verification:"
brew --version | head -n 1
docker --version
kind version
kubectl version --client --short 2>/dev/null
helm version --short
git --version
echo "✅ All tools installed!"
```

---

# Part 3: Getting the Code

## Step 8: Clone Sock Shop Repository (2 minutes)

```bash
# Go to home directory
cd ~

# Create projects folder
mkdir -p projects && cd projects

# Clone repository
git clone https://github.com/Pvz25/Sock-Shop-New.git

# Enter directory
cd Sock-Shop-New

# Verify
ls
```

✅ **Expected**: You see `README.md`, `manifests/`, etc.

---

# Part 4: Deploying Sock Shop

## Step 9: Create Kubernetes Cluster (2 minutes)

```bash
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: sockshop
nodes:
- role: control-plane
- role: worker
EOF
```

✅ **Expected**: "Set kubectl context to 'kind-sockshop'"

**Verify**:
```bash
kubectl get nodes
```

✅ **Expected**: 2 nodes in "Ready" status

---

## Step 10: Deploy Sock Shop Application (3 minutes)

```bash
kubectl apply -k manifests/overlays/local-kind/
```

✅ **Expected**: Multiple "created" messages

**Wait for pods** (2-3 minutes):
```bash
kubectl wait --for=condition=ready pod --all -n sock-shop --timeout=300s
```

✅ **Expected**: All pods show "condition met"

---

## Step 11: Verify Application is Running (1 minute)

```bash
kubectl get pods -n sock-shop
```

✅ **Expected**: All 15 pods show `1/1 Running`

---

## Step 12: Access Sock Shop in Browser (1 minute)

**Open NEW Terminal** (`Cmd + N`):

```bash
kubectl port-forward -n sock-shop svc/front-end 2025:80
```

✅ **Keep this terminal open!**

**Open browser**: http://localhost:2025

**Test**:
1. See sock images ✅
2. Login: `user` / `password` ✅
3. Add sock to cart ✅
4. Place order ✅

🎉 **Sock Shop is running!**

---

# Part 5: Installing Monitoring Stack

## Step 13: Install Prometheus + Grafana (10 minutes)

**Go back to first terminal** (not port-forward one)

### 13.1 Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 13.2 Create Namespace

```bash
kubectl create namespace monitoring
```

### 13.3 Install Stack

```bash
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword='prom-operator'
```

**Wait 3-5 minutes**:
```bash
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s
```

✅ **Expected**: All monitoring pods ready

---

## Step 14: Access Grafana Dashboard (3 minutes)

**Open ANOTHER new terminal** (`Cmd + N`):

```bash
kubectl port-forward -n monitoring svc/kps-grafana 3025:80
```

✅ **Keep this terminal open too!**

**Open browser**: http://localhost:3025

**Login**:
- Username: `admin`
- Password: `prom-operator`

**Explore**:
1. Click "Dashboards" (left sidebar)
2. Browse → "Kubernetes / Compute Resources / Cluster"
3. See live metrics! 📊

---

## Step 15: Install Datadog Agent (Optional - 5 minutes)

**Skip this if you don't want Datadog**

### 15.1 Get Datadog API Key

1. Sign up: https://www.datadoghq.com/ (free trial)
2. Go to: Organization Settings → API Keys
3. Copy your API key

### 15.2 Install Datadog

```bash
# Add Helm repo
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Create namespace
kubectl create namespace datadog

# Create secret (replace YOUR_API_KEY)
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  -n datadog

# Install agent
helm install datadog-agent datadog/datadog \
  -n datadog \
  -f datadog-values-metrics-logs.yaml
```

**Verify**:
```bash
kubectl get pods -n datadog
```

✅ **Expected**: Datadog pods running

---

# Part 6: Verification & Testing

## Step 16: Complete System Verification (3 minutes)

### 16.1 Check All Pods

```bash
# Sock Shop
kubectl get pods -n sock-shop

# Monitoring
kubectl get pods -n monitoring

# Datadog (if installed)
kubectl get pods -n datadog
```

✅ **All pods should show `Running`**

### 16.2 Check All Services

```bash
kubectl get svc -n sock-shop
kubectl get svc -n monitoring
```

### 16.3 Check Port Forwards

You should have **3 terminals open**:
1. **Terminal 1**: Your main terminal
2. **Terminal 2**: Port-forward for Sock Shop (port 2025)
3. **Terminal 3**: Port-forward for Grafana (port 3025)

---

## Step 17: Test All Features (2 minutes)

### Test Sock Shop
- http://localhost:2025
- ✅ Homepage loads
- ✅ Login works
- ✅ Can add to cart
- ✅ Can place order

### Test Grafana
- http://localhost:3025
- ✅ Login works
- ✅ Dashboards load
- ✅ Metrics visible

### Test Prometheus (Optional)

**Open ANOTHER terminal**:
```bash
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 4025:9090
```

- http://localhost:4025
- ✅ Prometheus UI loads

---

🎉 **CONGRATULATIONS!** You've built a complete production-grade system!

---

# 🔧 Common Issues & Solutions

## Docker Not Running

**Error**: "Cannot connect to Docker daemon"

**Solution**:
1. Check Docker Desktop is running (whale icon in menu bar)
2. Wait 30 seconds
3. Try again

---

## Pods Stuck in "Pending"

**Error**: Pods not starting

**Solution**:
```bash
# Check pod details
kubectl describe pod <pod-name> -n sock-shop

# If "Insufficient resources":
# 1. Open Docker Desktop
# 2. Settings → Resources
# 3. Increase Memory to 8GB+
# 4. Apply & Restart
```

---

## Port Already in Use

**Error**: "address already in use"

**Solution**:
```bash
# Find what's using the port
lsof -i :2025

# Kill the process
kill -9 <PID>

# Or use different port
kubectl port-forward -n sock-shop svc/front-end 8080:80
```

---

## Can't Access Sock Shop

**Checklist**:
1. ✅ Port-forward terminal still running?
2. ✅ All pods showing `1/1 Running`?
3. ✅ Using `http://` not `https://`?
4. ✅ Correct port (2025)?

---

## Helm Install Fails

**Error**: "values.yaml not found"

**Solution**:
```bash
# Install without custom values
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword='prom-operator'
```

---

# 📚 Understanding What You Built

## Architecture Overview

```
┌─────────────────────────────────────────┐
│         Your Mac (localhost)            │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   Docker Desktop                  │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │  KIND Cluster (sockshop)    │ │ │
│  │  │                             │ │ │
│  │  │  ┌─────────────────────┐   │ │ │
│  │  │  │  sock-shop namespace│   │ │ │
│  │  │  │  - 15 pods          │   │ │ │
│  │  │  │  - 15 services      │   │ │ │
│  │  │  └─────────────────────┘   │ │ │
│  │  │                             │ │ │
│  │  │  ┌─────────────────────┐   │ │ │
│  │  │  │ monitoring namespace│   │ │ │
│  │  │  │  - Prometheus       │   │ │ │
│  │  │  │  - Grafana          │   │ │ │
│  │  │  └─────────────────────┘   │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## What Each Component Does

### Sock Shop Services
- **front-end**: Web UI you see in browser
- **catalogue**: Manages product list
- **user**: Handles login/registration
- **carts**: Manages shopping carts
- **orders**: Processes orders
- **payment**: Handles payments
- **shipping**: Manages shipping
- **queue-master**: Processes async tasks

### Databases
- **catalogue-db**: Stores products
- **user-db**: Stores user accounts
- **carts-db**: Stores cart data
- **orders-db**: Stores orders
- **session-db**: Stores user sessions

### Infrastructure
- **rabbitmq**: Message queue for async processing

### Monitoring
- **Prometheus**: Scrapes metrics every 15 seconds
- **Grafana**: Visualizes metrics in dashboards
- **Datadog** (optional): Advanced monitoring

---

# 🎓 Next Steps & Learning Resources

## What to Try Next

### 1. Explore Grafana Dashboards
- Try different dashboards
- Create custom dashboards
- Set up alerts

### 2. Run Load Tests
```bash
cd load
kubectl apply -f locust-quick-test.yaml
```

### 3. Simulate Incidents
```bash
# Scale down payment service
kubectl scale deployment payment --replicas=0 -n sock-shop

# Try to place order - it will fail!
# This is how you test monitoring

# Recover
kubectl scale deployment payment --replicas=1 -n sock-shop
```

### 4. Learn Kubernetes
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### 5. Learn Prometheus
- [Prometheus Docs](https://prometheus.io/docs/introduction/overview/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

# 📋 Quick Reference Commands

## Check Status
```bash
# All pods
kubectl get pods -A

# Sock Shop pods
kubectl get pods -n sock-shop

# Monitoring pods
kubectl get pods -n monitoring

# Logs
kubectl logs -n sock-shop deployment/front-end --tail=20
```

## Port Forwards
```bash
# Sock Shop
kubectl port-forward -n sock-shop svc/front-end 2025:80

# Grafana
kubectl port-forward -n monitoring svc/kps-grafana 3025:80

# Prometheus
kubectl port-forward -n monitoring svc/kps-kube-prometheus-stack-prometheus 4025:9090
```

## Restart Services
```bash
# Restart a deployment
kubectl rollout restart deployment/front-end -n sock-shop

# Scale up/down
kubectl scale deployment front-end --replicas=2 -n sock-shop
```

---

# 🗑️ How to Clean Up

## Stop Port Forwards
Press `Ctrl + C` in each port-forward terminal

## Delete Everything
```bash
# Delete Sock Shop
kubectl delete namespace sock-shop

# Delete Monitoring
helm uninstall kps -n monitoring
kubectl delete namespace monitoring

# Delete Datadog (if installed)
helm uninstall datadog-agent -n datadog
kubectl delete namespace datadog

# Delete Cluster
kind delete cluster --name sockshop
```

## Uninstall Tools (Optional)
```bash
brew uninstall kind kubectl helm
brew uninstall --cask docker
```

---

# ❓ Frequently Asked Questions

## How much disk space does this use?
- Docker images: ~5 GB
- Running containers: ~2 GB
- **Total**: ~7 GB

## Can I run this on an older Mac?
- Yes, but it may be slower
- Minimum: 2015 Mac with 8GB RAM

## Do I need internet after installation?
- No, everything runs locally
- Internet only needed for initial downloads

## Can I run multiple clusters?
- Yes! Just use different cluster names
- `kind create cluster --name cluster2`

## How do I update Sock Shop?
```bash
cd ~/projects/Sock-Shop-New
git pull
kubectl apply -k manifests/overlays/local-kind/
```

## Is this production-ready?
- The architecture is production-grade
- But KIND is for development/testing only
- For production, use real Kubernetes (EKS, GKE, AKS)

---

## 🎉 You Did It!

You've successfully built a complete production-grade e-commerce application with full observability on your Mac!

**What you learned**:
- ✅ How to use Docker and Kubernetes
- ✅ How to deploy microservices
- ✅ How to set up monitoring
- ✅ How to troubleshoot issues

**Share your success**:
- Take a screenshot of Grafana dashboards
- Share on social media with #SockShop
- Help others in the community!

**Need help?**
- [GitHub Issues](https://github.com/Pvz25/Sock-Shop-New/issues)
- [Kubernetes Slack](https://slack.k8s.io/)

---

<div align="center">

**Made with ❤️ for macOS users**

[⬆️ Back to Top](#-sock-shop-complete-setup-guide-for-macos)

</div>
