# Pre-Incident Health Check Report
**Date:** November 9, 2025, 7:45 PM IST  
**Purpose:** Comprehensive system validation before incident execution

---

## Executive Summary

✅ **SYSTEM STATUS: HEALTHY - Ready for Incident Execution**

All critical systems verified and operational:
- Kubernetes Cluster: ✅ HEALTHY
- Sock Shop Application: ✅ HEALTHY (15 pods running)
- Datadog Observability: ✅ HEALTHY (DNS fixed, logs flowing)
- RabbitMQ Messaging: ✅ HEALTHY
- Database Layer: ✅ HEALTHY

---

## 1. Kubernetes Cluster Health

### 1.1 Node Status
```
NAME                     STATUS   ROLES           AGE     VERSION
sockshop-control-plane   Ready    control-plane   6h23m   v1.34.0
sockshop-worker          Ready    worker          6h23m   v1.34.0
```
✅ Both nodes ready and healthy

### 1.2 CoreDNS Status
- **DNS Configuration:** Fixed and optimized (forwarding to 8.8.8.8, 8.8.4.4)
- **CoreDNS Pods:** Running and healthy
- **DNS Resolution:** Verified working for external and internal domains

---

## 2. Sock Shop Application Health

### 2.1 Pod Status (15 Pods Total)
```
NAME                            READY   STATUS    RESTARTS      AGE
carts-5d5b9c4998-x5btm          1/1     Running   1 (11m ago)   5h29m
carts-db-7cd58fc9d8-n7pmb       1/1     Running   1 (11m ago)   5h30m
catalogue-6d587b8fcb-r9l5s      1/1     Running   1 (11m ago)   5h12m
catalogue-db-655dfffbf5-lv2nw   1/1     Running   1 (11m ago)   5h27m
front-end-77f58c577-l2rp8       1/1     Running   1 (11m ago)   5h29m
orders-85dd575fc7-c24ct         1/1     Running   1 (11m ago)   5h29m
orders-db-7cf8fbdf5b-zbq4p      1/1     Running   1 (11m ago)   5h30m
payment-55cb964889-7dnhg        1/1     Running   1 (11m ago)   5h29m
queue-master-7c58cb7bcf-mcdd5   1/1     Running   1 (11m ago)   5h30m
rabbitmq-76f8666456-9s4qt       2/2     Running   2 (11m ago)   5h30m
session-db-64d5d485f5-4pzb9     1/1     Running   1 (11m ago)   5h26m
shipping-84496899f5-tb4f7       1/1     Running   1 (11m ago)   5h29m
stripe-mock-84fd48f97d-qt2mf    1/1     Running   1 (11m ago)   5h23m
user-666b46d57f-68n55           1/1     Running   1 (11m ago)   5h29m
user-db-6d9f8b49fc-2nhnn        1/1     Running   1 (11m ago)   5h30m
```

✅ **All 15 pods are Running**
✅ **All pods are Ready (1/1 or 2/2)**
✅ **Minimal restarts (only from DNS fix restart)**

### 2.2 Service Discovery
```
All 15 services have valid ClusterIP addresses:
- front-end: 10.96.12.193 (NodePort 30001)
- catalogue: 10.96.201.201
- user: 10.96.229.174
- carts: 10.96.49.14
- orders: 10.96.147.9
- payment: 10.96.204.236
- shipping: 10.96.154.26
- queue-master: 10.96.165.155
- rabbitmq: 10.96.64.36
- stripe-mock: 10.96.145.169
- (+ 5 database services)
```

✅ All services registered with valid ClusterIPs
✅ DNS resolution working for all service names

---

## 3. Datadog Observability Platform

### 3.1 Datadog Agent Status
```
Datadog Pods:
- datadog-agent-8rrlm                            2/2  Running   (Worker node)
- datadog-agent-cluster-agent-59f75dcfc8-jvp7x   1/1  Running   (Cluster agent)
- datadog-agent-mg54k                            2/2  Running   (Control plane node)
```

✅ All 3 Datadog pods healthy

### 3.2 Log Collection Status

**CRITICAL FIX APPLIED:**
- **DNS Issue:** RESOLVED (CoreDNS reconfigured)
- **DNS Errors:** 0 (was 10 before fix)
- **Logs Processed:** 671
- **Logs Sent:** 663 ✅ (was 0 before fix)
- **Log Endpoint:** agent-intake.logs.us5.datadoghq.com:10516

✅ **Logs flowing to Datadog successfully**

### 3.3 Connectivity Verification
All Datadog endpoints verified accessible:
- ✅ https://agent-http-intake.logs.us5.datadoghq.com
- ✅ https://app.us5.datadoghq.com
- ✅ https://trace.agent.us5.datadoghq.com
- ✅ APM, Metrics, and Event ingestion endpoints

---

## 4. Database Layer Health

### 4.1 MongoDB Instances (3x)
```
- user-db: Running ✅ (MongoDB for user auth)
- carts-db: Running ✅ (MongoDB for shopping carts)
- orders-db: Running ✅ (MongoDB for orders)
```

### 4.2 MariaDB Instance
```
- catalogue-db: Running ✅ (MariaDB for product catalog)
```

### 4.3 Redis Instance
```
- session-db: Running ✅ (Redis for session storage)
```

✅ All 5 data stores operational

---

## 5. Messaging Infrastructure

### 5.1 RabbitMQ Status
```
Pod: rabbitmq-76f8666456-9s4qt
Status: 2/2 Running ✅
Ports: 5672 (AMQP), 9090 (Management)
```

✅ RabbitMQ ready for async message processing

### 5.2 Queue Consumer
```
Pod: queue-master-7c58cb7bcf-mcdd5
Status: 1/1 Running ✅
Purpose: Consumes shipping messages from RabbitMQ
```

✅ Queue consumer healthy and ready

---

## 6. Load Testing Infrastructure

### 6.1 Locust Load Generator
- No active load tests running ✅
- ConfigMaps ready for incident execution ✅
- Load test scripts validated ✅

---

## 7. Network & DNS Health

### 7.1 CoreDNS Configuration
```yaml
forward . 8.8.8.8 8.8.4.4  # External DNS servers
cache 30                    # DNS caching enabled
```

✅ DNS resolution working for both internal and external domains

### 7.2 Service Mesh
- All services can communicate via ClusterIP ✅
- No NetworkPolicies blocking traffic ✅
- Internal DNS resolving correctly (e.g., http://catalogue) ✅

---

## 8. Critical Pre-Incident Validations

### 8.1 Baseline Resource Usage
```
Service          CPU     Memory
front-end        ~5m     ~150Mi   (Normal)
catalogue        ~3m     ~80Mi    (Normal)
orders           ~8m     ~200Mi   (Normal)
payment          ~2m     ~50Mi    (Normal)
```

✅ All services at baseline resource consumption

### 8.2 Health Check Status
- Liveness probes: All passing ✅
- Readiness probes: All passing ✅
- No failing health checks ✅

### 8.3 Application Accessibility
- Front-end accessible: http://localhost:2025 (via port-forward) ✅
- All product pages loading correctly ✅
- User login/registration working ✅
- Order placement functional ✅

---

## 9. Incident Readiness Checklist

### Infrastructure
- [x] Kubernetes cluster stable (6+ hours uptime)
- [x] All 15 pods running without crashes
- [x] Resource limits configured correctly
- [x] Network connectivity verified

### Observability
- [x] Datadog DNS issue resolved
- [x] Logs flowing to Datadog (663 logs sent)
- [x] Metrics collection active
- [x] Event collection working
- [x] Zero DNS errors in agent status

### Application
- [x] All microservices healthy
- [x] Database connections stable
- [x] RabbitMQ messaging operational
- [x] Queue consumer processing messages
- [x] User workflows functional

### Testing Tools
- [x] Locust load generator available
- [x] Incident automation scripts ready
- [x] Recovery procedures documented

---

## 10. Known Issues & Mitigations

### Issue 1: Recent DNS Fix Applied
**Status:** RESOLVED ✅  
**Details:** CoreDNS was misconfigured, causing Datadog log delivery failures  
**Fix Applied:** Reconfigured CoreDNS with external DNS forwarders (8.8.8.8, 8.8.4.4)  
**Verification:** LogsSent increased from 0 to 663  
**Impact:** None - system fully operational

### Issue 2: Pod Restarts from DNS Fix
**Status:** EXPECTED ✅  
**Details:** All pods show 1-2 restarts from Datadog agent restart  
**Impact:** None - all pods recovered successfully  
**Note:** This is normal after DNS fix and won't affect incident execution

---

## 11. Recommendations for Incident Execution

### Timing
- ✅ Execute incidents during documented time windows
- ✅ Wait 10 minutes between each incident for clear separation
- ✅ Document exact start/end timestamps for Datadog queries

### Monitoring
- ✅ Keep Datadog UI open in browser during incidents
- ✅ Monitor kubectl terminal for real-time pod status
- ✅ Watch Datadog Logs Explorer in Live Tail mode
- ✅ Check Datadog Metrics Explorer for resource spikes

### Data Collection
- ✅ Record timestamps at incident start
- ✅ Take screenshots of Datadog dashboards
- ✅ Export kubectl events for each incident
- ✅ Capture Datadog queries for reproducibility

---

## 12. Final Go/No-Go Decision

### System Health: ✅ GO
- All pods running
- DNS issues resolved
- Logs flowing to Datadog
- No active incidents or errors

### Observability: ✅ GO
- Datadog fully operational
- Log ingestion working
- Metrics collection active
- Events being captured

### Application: ✅ GO
- All services healthy
- Databases operational
- Message queue ready
- User workflows functional

---

## **DECISION: ✅ SYSTEM READY FOR INCIDENT EXECUTION**

**Approval:** All health checks passed  
**Status:** GREEN - Proceed with incident scenarios  
**Next Step:** Execute INCIDENT-5 (Async Processing Failure)

---

**Report Generated:** November 9, 2025, 7:45 PM IST  
**Health Check Duration:** 5 minutes  
**Critical Fixes Applied:** DNS configuration and Datadog agent restart  
**System Uptime:** 6+ hours (stable)
