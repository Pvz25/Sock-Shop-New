# Datadog Quick Reference - INCIDENT-3
## Copy-Paste Queries for Payment Failure Investigation

**Incident Window**: 2025-10-30 08:24:46 - 08:28:32 UTC  
**Failed Orders**: 5 orders  
**Datadog Region**: US5

---

## 🔥 TOP 5 ESSENTIAL QUERIES

### 1️⃣ Find ALL Payment Failures
```
kube_namespace:sock-shop service:sock-shop-orders "status updated to PAYMENT_FAILED"
```
**Expected**: 5 WARN logs  
**Time**: Past 3 hours

---

### 2️⃣ Find Connection Errors
```
kube_namespace:sock-shop service:sock-shop-orders "Connection refused"
```
**Expected**: 5 ERROR logs with stack traces  
**Time**: Past 3 hours

---

### 3️⃣ Specific Order Timeline (Replace ORDER_ID)
```
kube_namespace:sock-shop "690320cee2c84800016ceb4a"
```
**Use for each failed order**:
- 690320cee2c84800016ceb4a
- 690320eae2c84800016ceb4b
- 69032142e2c84800016ceb4c
- 690321a3e2c84800016ceb4d
- 690321b0e2c84800016ceb4e

---

### 4️⃣ Payment Service Downtime
```
kube_namespace:sock-shop service:sock-shop-payment
```
**Expected**: NO logs between 08:24 - 08:29  
**Time**: Past 3 hours

---

### 5️⃣ All Orders Service Errors
```
kube_namespace:sock-shop service:sock-shop-orders "ERROR"
```
**Expected**: Multiple ERROR logs including payment failures  
**Time**: Past 3 hours

---

## 📊 METRICS QUERIES

### Payment Pod Count (Should Drop to 0)
**Navigate**: Metrics Explorer → https://us5.datadoghq.com/metric/explorer

**Metric**: `kubernetes.pods.running`  
**Filter**: `kube_namespace:sock-shop deployment:payment`  
**Expected**: Drops from 1 to 0 at 08:24

---

### Orders Service CPU
**Metric**: `kubernetes.cpu.usage`  
**Filter**: `kube_namespace:sock-shop pod_name:orders*`  
**Expected**: Spikes during order processing

---

## 🔍 NAVIGATION LINKS

### Logs Explorer
https://us5.datadoghq.com/logs

### Kubernetes Explorer
https://us5.datadoghq.com/orchestration/explorer  
**Filter**: `kube_namespace:sock-shop`

### Container View
https://us5.datadoghq.com/containers  
**Filter**: `kube_namespace:sock-shop`

### Infrastructure
https://us5.datadoghq.com/infrastructure  
**Filter**: `kube_cluster_name:sockshop-kind`

---

## 📝 SPECIFIC ORDER QUERIES

### Order 1: $104.98 (Rayaan)
```
kube_namespace:sock-shop "690320cee2c84800016ceb4a"
```

### Order 2: $19.99 (Rayaan)
```
kube_namespace:sock-shop "690320eae2c84800016ceb4b"
```

### Order 3: $104.98 (parvaiz) - FIRST ONE IN UI
```
kube_namespace:sock-shop "69032142e2c84800016ceb4c"
```

### Order 4: $122.13 (parvaiz) - SECOND ONE IN UI
```
kube_namespace:sock-shop "690321a3e2c84800016ceb4d"
```

### Order 5: $22.14 (parvaiz) - THIRD ONE IN UI
```
kube_namespace:sock-shop "690321b0e2c84800016ceb4e"
```

---

## 🎯 WHAT TO LOOK FOR IN EACH LOG

### Successful Order Pattern (BEFORE incident)
1. ✅ `Order created with ID: XXX and status: Created`
2. ✅ `Order XXX status updated to PENDING`
3. ✅ `Sending payment request for order XXX`
4. ✅ `Received payment response: authorised=true`
5. ✅ `Order XXX payment successful, status updated to PAID`
6. ✅ `Order XXX shipped successfully`

### Failed Order Pattern (DURING incident)
1. ✅ `Order created with ID: XXX and status: Created`
2. ✅ `Order XXX status updated to PENDING`
3. ✅ `Sending payment request for order XXX`
4. ❌ `Payment failed for order XXX: Connection refused`
5. ⚠️ `Order XXX status updated to PAYMENT_FAILED`
6. ❌ NO shipment created

---

## 🔧 ADVANCED ANALYSIS

### Compare Success Rate Over Time
**Query 1** (Success):
```
kube_namespace:sock-shop service:sock-shop-orders "payment successful"
```

**Query 2** (Failure):
```
kube_namespace:sock-shop service:sock-shop-orders "Payment failed"
```

**Graph Type**: Timeseries, Group by: 5-minute intervals  
**Analysis**: Should show spike in failures at 08:24-08:29

---

### Multi-Service View
```
kube_namespace:sock-shop ("690321a3e2c84800016ceb4d" OR "orders" OR "front-end" OR "user")
```
**Expected**: See how order flows through multiple services

---

### Error Rate by Service
**Facet**: `service`  
**Filter**: `kube_namespace:sock-shop "ERROR"`  
**Group By**: service  
**Expected**: orders service shows highest error count

---

## 💡 TROUBLESHOOTING TIPS

### If No Results Found
1. ✅ Check time range (set to "Past 3 hours" or custom 08:00-09:00)
2. ✅ Verify service tag: `sock-shop-orders` NOT just `orders`
3. ✅ Use text search, not status facets (log parsing issue)
4. ✅ Check you're in US5 region: https://us5.datadoghq.com

### If Too Many Results
1. Add more specific filters: `service:sock-shop-orders "690320"`
2. Narrow time range to incident window only
3. Use exact order ID for specific investigation

### If Logs Seem Old
1. Clear browser cache
2. Refresh Datadog page
3. Wait 1-2 minutes for log ingestion
4. Check Datadog agent status: `kubectl -n datadog get pods`

---

## 📋 CHECKLIST: What to Screenshot

- [ ] Query 1 results (5 PAYMENT_FAILED logs)
- [ ] Query 2 results (Connection refused errors)
- [ ] One complete order timeline (all 5 logs)
- [ ] Metrics graph showing payment pod count dropping to 0
- [ ] Kubernetes Explorer showing 0 payment replicas
- [ ] Container view showing no payment containers

---

## 🎓 KEY LEARNINGS

1. **Service Tags**: Use full tag `sock-shop-orders` not just `orders`
2. **Log Parsing**: Search by message text due to Spring Boot format issue
3. **Order IDs**: Use 24-character hex IDs to track transactions
4. **Time Zones**: All Datadog times in UTC, match with your logs
5. **Facets**: Don't rely on status facets, use text search

---

**Quick Start**: Copy Query #1 → Open Datadog Logs → Paste → Set time to "Past 3 hours" → Search

**Full Report**: See INCIDENT-3-EXECUTION-REPORT-2025-10-30.md for complete details
