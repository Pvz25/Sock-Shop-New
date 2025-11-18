# INCIDENT-8B: Database Performance Degradation - Datadog Verification Guide

## Incident Overview

**Incident Type:** Database Performance Degradation (Connection Pool Exhaustion)  
**Incident ID:** INCIDENT-8B  
**Severity:** High (P2)  
**Method:** Load Testing (60 concurrent requests)

---

## Incident Timeline

### Date & Time

**Date:** November 10, 2025  

**IST (Indian Standard Time):**
- **Incident Start:** 4:25 PM IST (16:25:22 IST)
- **Incident End:** 4:27 PM IST (16:27:04 IST)
- **Duration:** ~2 minutes

**UTC (Coordinated Universal Time):**
- **Incident Start:** 10:55 AM UTC (10:55:22 UTC)
- **Incident End:** 10:57 AM UTC (10:57:04 UTC)
- **Duration:** ~2 minutes

**Conversion:** IST = UTC + 5:30

---

## Datadog Service Names (From Screenshots)

Based on the Datadog UI screenshots, the exact service names are:

### Application Services:
- `sock-shop-front-end`
- `sock-shop-catalogue`
- `sock-shop-user`
- `sock-shop-carts`
- `sock-shop-orders`
- `sock-shop-payment`
- `sock-shop-shipping`
- `sock-shop-queue-master`

### Database Services:
- `sock-shop-catalogue-db` (MariaDB - **PRIMARY TARGET**)
- `sock-shop-user-db`
- `sock-shop-carts-db`
- `sock-shop-orders-db`

### Infrastructure:
- Namespace: `sock-shop`
- Host: `sockshop-worker`
- Cluster: `sockshop-control-plane`
## 🎯 Key Point: Focus on METRICS, Not Logs

**Database logs will be mostly EMPTY during this incident - this is normal!**

MariaDB only logs during startup, errors, or shutdowns. During normal operation (even under heavy load), it produces minimal logs. **Use metrics for analysis.**


---


## 📊 Datadog Logs Query

### Catalogue Service Logs

**Query:**
```
kube_namespace:sock-shop service:sock-shop-catalogue
```

**What to Look For:**
```
caller=logging.go method=List
caller=server.go
database connection
query execution
```

**Expected Observations:**
- ✅ High volume of logs during incident window (4:25-4:27 PM)
- ✅ Database query patterns visible
- ⚠️ Logs may be sparse - **this is normal**

**Note:** Database logs (`catalogue-db`) will likely be empty during the incident. This is expected behavior for MariaDB under load.

---

## 📈 Datadog Metrics Queries

**⚠️ METRICS ARE THE PRIMARY EVIDENCE FOR THIS INCIDENT**

### Time Range:
```
Nov 10, 4:20 PM - 4:30 PM IST
(Nov 10, 10:50 AM - 11:00 AM UTC)
```

---

### 1. Database CPU Usage (Primary Indicator)

**Metric:**
```
kubernetes.cpu.usage.total
```

**Filter:**
```
from: kube_namespace:sock-shop, kube_deployment:catalogue-db
avg by: kube_deployment
```

**Expected Observations:**

**Baseline:**
- CPU usage: ~5-20m (0.005-0.02 cores)
- Stable, low utilization

**During Incident:**
- CPU usage: ~100-200m (0.1-0.2 cores)
- **10-20x increase** from baseline
- Spike correlates with incident start time (4:25 PM IST)

**After Recovery:**
- CPU usage: Returns to ~5-20m
- Immediate drop after job termination (4:27 PM IST)

**Conclusion:**
✅ **Spike in CPU usage during incident**

---

### 2. Database Memory Usage

**Metric:**
```
kubernetes.memory.usage
```

**Filter:**
```
from: kube_namespace:sock-shop, kube_deployment:catalogue-db
avg by: kube_deployment
```

**Expected Observations:**

**Baseline:**
- Memory: ~200-300 MiB
- Stable

**During Incident:**
- Memory: ~250-350 MiB
- Slight increase (+50-100 MiB)

**After Recovery:**
- Memory: Returns to baseline

**Conclusion:**
✅ **Stable line** - Memory NOT the bottleneck

---

### 3. Network Traffic (Load Indicator)

**Metric:**
```
kubernetes.network.rx_bytes
```

**Filter:**
```
from: kube_namespace:sock-shop, kube_deployment:catalogue-db
rate, sum
```

**Expected Observations:**

**Baseline:**
- Network RX: ~1-10 KB/s
- Low traffic

**During Incident:**
- Network RX: ~100-500 KB/s
- **10-50x increase**
- 60 concurrent queries generating traffic

**After Recovery:**
- Network RX: Returns to ~1-10 KB/s
- Immediate drop

**Conclusion:**
✅ **Network traffic spike confirms heavy database load**

---

## 📋 Quick Reference: Copy-Paste Queries

### Logs Query:
```
kube_namespace:sock-shop service:sock-shop-catalogue
```

### Metrics Queries:
```
# Database CPU (PRIMARY INDICATOR)
kubernetes.cpu.usage.total
from: kube_namespace:sock-shop, kube_deployment:catalogue-db
avg by: kube_deployment

# Database Memory
kubernetes.memory.usage
from: kube_namespace:sock-shop, kube_deployment:catalogue-db
avg by: kube_deployment

# Database Network Traffic
kubernetes.network.rx_bytes
from: kube_namespace:sock-shop, kube_deployment:catalogue-db
rate, sum
```

---

## ✅ Summary

**Incident Type:** Product search slowness due to database latency or connection pool exhaustion

**Evidence in Datadog:**
- ✅ **Logs:** Catalogue service shows database query patterns (sparse, normal for MariaDB)
- ✅ **CPU Metric:** 10-20x spike during incident (5-20m → 100-200m)
- ✅ **Memory Metric:** Stable line (slight increase, not the bottleneck)
- ✅ **Network Metric:** 10-50x traffic spike confirming heavy database load

**Key Insight:** Focus on **METRICS** for this incident. Database logs will be mostly empty - this is expected behavior for MariaDB under load.

---

**Document Version:** 2.0  
**Last Updated:** November 10, 2025  
**Status:** Production Ready ✅
