# Sock Shop: Production-Grade Microservices Observability Demo

<div align="center">

![Sock Shop](https://raw.githubusercontent.com/microservices-demo/microservices-demo.github.io/master/assets/Architecture.png)

**A complete microservices reference application with enterprise-grade observability, multi-architecture support, and incident simulation capabilities.**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Multi-Arch](https://img.shields.io/badge/Multi--Arch-AMD64%20%7C%20ARM64%20%7C%20PPC64LE%20%7C%20S390X-green)](https://www.docker.com/blog/multi-arch-build-and-images-the-simple-way/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus%20%2B%20Grafana-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Datadog](https://img.shields.io/badge/Observability-Datadog-632CA6?logo=datadog&logoColor=white)](https://www.datadoghq.com/)

[Features](#-key-features) •
[Quick Start](#-quick-start) •
[Architecture](#-architecture) •
[Documentation](#-documentation) •
[Demo Guides](#-demo--presentation-guides)

</div>

---

## 📖 Overview

Sock Shop is a **production-ready microservices e-commerce application** designed to demonstrate cloud-native technologies, observability patterns, and SRE practices. This repository extends the original Weaveworks demo with:

- ✅ **Enterprise Observability**: Full-stack monitoring with Prometheus, Grafana, and Datadog
- ✅ **Multi-Architecture Support**: Native builds for AMD64, ARM64, IBM Power (PPC64LE), and IBM Z (S390X)
- ✅ **Incident Simulation**: Realistic failure scenarios for testing SRE agent capabilities
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
- **Logging**: Datadog centralized log collection (5,500+ logs/day)
- **Infrastructure**: Datadog Infrastructure Monitoring, Container Monitoring, Kubernetes Explorer
- **Custom Metrics**: DogStatsD endpoint for application-level metrics

### Incident Simulation
- **Incident 1**: Application crash via resource exhaustion (OOMKilled scenarios)
- **Incident 2**: Performance degradation via high load (latency testing)
- **Incident 3**: Distributed transaction failures (payment service outages)
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

### Monitoring Stack

| Component | Purpose | Port/Access |
|-----------|---------|-------------|
| **Prometheus** | Metrics collection & storage | `:4025` (port-forward) |
| **Grafana** | Visualization dashboards | `:3025` (port-forward) |
| **Datadog Agent** | Log collection & forwarding | us5.datadoghq.com |
| **RabbitMQ Exporter** | RabbitMQ metrics | `:5025/metrics` |

---

## 🚀 Quick Start

### Prerequisites

- **Kubernetes Cluster**: kind 0.20+, Minikube, or OpenShift 4.12+
- **kubectl**: v1.28+
- **Helm**: v3.12+
- **Docker**: 24.x+ (for kind/Minikube)
- **OS**: Linux, macOS, or Windows 11 with WSL2

### Option 1: KIND Cluster (Local Development)

```bash
# 1. Create KIND cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: sockshop
nodes:
- role: control-plane
- role: worker
EOF

# 2. Deploy Sock Shop
kubectl apply -k manifests/overlays/local-kind/

# 3. Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n sock-shop --timeout=300s

# 4. Access the application
kubectl port-forward -n sock-shop svc/front-end 8080:80

# Visit http://localhost:8080
```

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

### Option 3: Complete Setup with Observability

For a **production-grade setup** with Prometheus, Grafana, and Datadog, follow the comprehensive guide:

```bash
# See COMPLETE-SETUP-GUIDE.md for detailed instructions
# Includes:
# - KIND cluster setup
# - Application deployment
# - Prometheus + Grafana installation
# - Datadog agent configuration
# - Port forwarding setup
# - Verification steps
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

### Datadog Integration

**Setup centralized logging and advanced metrics:**

```bash
# Add Datadog Helm repository
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Create namespace and secret
kubectl create namespace datadog
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  -n datadog

# Install Datadog Agent
helm install datadog-agent datadog/datadog \
  -n datadog \
  -f datadog-values-metrics-logs.yaml

# Verify
kubectl get pods -n datadog
```

**Features Enabled:**
- ✅ Container log collection (5,500+ logs/day)
- ✅ Kubernetes metrics (CPU, memory, network)
- ✅ Process-level metrics
- ✅ Orchestrator Explorer (full cluster visibility)
- ✅ Infrastructure monitoring
- ✅ DogStatsD endpoint (port 8125)

📘 **Datadog Setup Guide**: [DATADOG-METRICS-LOGS-SETUP.md](./DATADOG-METRICS-LOGS-SETUP.md)

---

## 🔥 Incident Simulation

Test SRE agent capabilities with realistic production failure scenarios:

### Incident 1: Application Crash (Resource Exhaustion)

**Simulates**: OOMKilled pod crashes under extreme load

```bash
cd load
kubectl apply -f locust-crash-test.yaml

# Monitor pods crashing
kubectl get pods -n sock-shop -w

# Expected: Front-end pods CrashLoopBackOff, OOMKilled events
```

**SRE Test Query**: *"What caused the application crash at 10:23 AM?"*

### Incident 2: Performance Degradation (High Latency)

**Simulates**: Severe slowness without crashes (750 concurrent users)

```bash
kubectl apply -f locust-latency-test.yaml

# Monitor response times
kubectl logs -f -n sock-shop deployment/front-end | grep "response_time"

# Expected: P95 latency >3 seconds, no pod restarts
```

**SRE Test Query**: *"Users report site slowness. Investigate and recommend fixes."*

### Incident 3: Payment Transaction Failure

**Simulates**: Distributed transaction failures (payment service down)

```bash
kubectl apply -f locust-payment-failure-test.yaml

# Scale payment service to 0
kubectl scale deployment payment --replicas=0 -n sock-shop

# Expected: Orders created with "PAYMENT_FAILED" status
```

**SRE Test Query**: *"Customer says they were charged but order failed. Investigate order ID: 68f35ed59c10d300018b7011"*

📘 **Incident Guides**: 
- [INCIDENT-SIMULATION-MASTER-GUIDE.md](./INCIDENT-SIMULATION-MASTER-GUIDE.md)
- [INCIDENT-1-APP-CRASH.md](./INCIDENT-1-APP-CRASH.md)
- [INCIDENT-2-HYBRID-CRASH-LATENCY.md](./INCIDENT-2-HYBRID-CRASH-LATENCY.md) - Frontend crashes + backend latency
- [INCIDENT-4-APP-LATENCY.md](./INCIDENT-4-APP-LATENCY.md) - Pure latency, no crashes
- [INCIDENT-3-PAYMENT-FAILURE.md](./INCIDENT-3-PAYMENT-FAILURE.md)

---

## 🎤 Demo & Presentation Guides

Professional presentation materials for showcasing the platform:

| Guide | Purpose | Duration |
|-------|---------|----------|
| [SOCK-SHOP-COMPLETE-DEMO-GUIDE.md](./SOCK-SHOP-COMPLETE-DEMO-GUIDE.md) | Complete demo script with timing | 30-45 min |
| [DEMO-QUICK-REFERENCE-CARD.md](./DEMO-QUICK-REFERENCE-CARD.md) | One-page cheat sheet | Print & use |
| [DEMO-CHECKLIST.md](./DEMO-CHECKLIST.md) | Interactive checklist | Print & check |
| [DEMO-PRESENTATION-GUIDE.md](./DEMO-PRESENTATION-GUIDE.md) | Talking points summary | Quick ref |

**Demo Flow:**
1. Introduction & Architecture (5 min)
2. Application Demo (10 min) - Complete user journey
3. Prometheus/Grafana (10 min) - Metrics & dashboards
4. Datadog (10 min) - Logs, infrastructure, Kubernetes explorer
5. Troubleshooting (5-10 min) - Real-world scenarios
6. Q&A (5 min)

---

## 📚 Documentation

### Setup & Configuration

| Document | Description |
|----------|-------------|
| [COMPLETE-SETUP-GUIDE.md](./COMPLETE-SETUP-GUIDE.md) | Complete setup from scratch (KIND + app + monitoring) |
| [DATADOG-COMMANDS-TO-RUN.md](./DATADOG-COMMANDS-TO-RUN.md) | Step-by-step Datadog deployment commands |
| [DATADOG-METRICS-LOGS-SETUP.md](./DATADOG-METRICS-LOGS-SETUP.md) | Datadog features and configuration reference |
| [DATADOG-FIX-GUIDE.md](./DATADOG-FIX-GUIDE.md) | Troubleshooting LogsProcessed=0 issues |

### Operations & Troubleshooting

| Document | Description |
|----------|-------------|
| [ORDERS-QUICK-REFERENCE.md](./ORDERS-QUICK-REFERENCE.md) | Orders service analysis and debugging |
| [QUICK-FIX.md](./QUICK-FIX.md) | Common issues and quick solutions |
| [SOLUTION-SUMMARY.md](./SOLUTION-SUMMARY.md) | Architecture decisions and solutions |

### Testing & Scenarios

| Document | Description |
|----------|-------------|
| [INCIDENT-SIMULATION-MASTER-GUIDE.md](./INCIDENT-SIMULATION-MASTER-GUIDE.md) | Complete incident testing framework |
| [sockshop-user-journey-failure-scenarios.md](./sockshop-user-journey-failure-scenarios.md) | User journey failure testing |

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
├── docs/                  # Additional documentation
└── Makefile              # Build automation

# Configuration Files
├── datadog-values-*.yaml      # Datadog agent configurations
├── values-kps-kind-clean.yml  # Prometheus stack values
├── servicemonitor-rabbitmq.yaml
└── coredns-fixed.yaml
```

### Local Development

```bash
# Run application locally
kubectl apply -k manifests/overlays/local-kind/

# Enable port forwards
kubectl port-forward -n sock-shop svc/front-end 8080:80
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
- **Issues**: [GitHub Issues](https://github.com/ocp-power-demos/sock-shop-demo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ocp-power-demos/sock-shop-demo/discussions)

### Resources

- **Original Sock Shop**: https://microservices-demo.github.io/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Datadog Documentation**: https://docs.datadoghq.com/

---

## 📊 Project Status

**Current Version**: 1.0  
**Last Updated**: October 2025  
**Status**: ✅ Production Ready

### Roadmap

- [ ] Add APM/distributed tracing integration
- [ ] Implement service mesh (Istio/Linkerd) variant
- [ ] Add chaos engineering scenarios
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

[Report Bug](https://github.com/ocp-power-demos/sock-shop-demo/issues) •
[Request Feature](https://github.com/ocp-power-demos/sock-shop-demo/issues) •
[Documentation](./COMPLETE-SETUP-GUIDE.md)

</div>
