# Datadog Metrics - Correct Names for INCIDENT-3

**Issue**: The metric `kubernetes.pods.running` does NOT exist in modern Datadog agents  
**Solution**: Use `kubernetes_state.*` metrics instead

---

## 🎯 **WORKING METRICS (CONFIRMED)**

### **Metric #1: Deployment Replicas Available (BEST)**

**Metric Name**:
```
kubernetes_state.deployment.replicas_available
```

**Full Query for Metrics Explorer**:
```
avg:kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop,kube_deployment:payment}
```

**What it shows**: Number of pods actually running and available

**Expected graph**:
```
Replicas
   1.0 ├──────────────────┐
       │                  │
       │                  │
   0.5 │                  │
       │                  └──────────────┐
   0.0 ├──────────────────────────────────┴─────
       13:00  13:54     14:05      14:30
              ↑          ↑
           Scaled     Restored
           to 0       to 1
```

---

### **Metric #2: Deployment Desired Replicas**

**Metric Name**:
```
kubernetes_state.deployment.replicas_desired
```

**Full Query**:
```
avg:kubernetes_state.deployment.replicas_desired{kube_namespace:sock-shop,kube_deployment:payment}
```

**What it shows**: How many pods SHOULD be running (what you set with scale command)

---

### **Metric #3: Deployment Ready Replicas**

**Metric Name**:
```
kubernetes_state.deployment.replicas_ready
```

**Full Query**:
```
avg:kubernetes_state.deployment.replicas_ready{kube_namespace:sock-shop,kube_deployment:payment}
```

**What it shows**: Number of pods that passed readiness checks

---

## 📊 **ALTERNATIVE: USE FORMULAS**

You can also create a formula to show % availability:

**Formula**:
```
(a / b) * 100
```

**Where**:
- `a` = `kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop,kube_deployment:payment}`
- `b` = `kubernetes_state.deployment.replicas_desired{kube_namespace:sock-shop,kube_deployment:payment}`

**Result**: Shows 100% when healthy, 0% when scaled to 0

---

## 🔍 **OTHER USEFUL METRICS**

### **ReplicaSet Metrics**

**Metric**:
```
kubernetes_state.replicaset.replicas_ready
```

**Query**:
```
avg:kubernetes_state.replicaset.replicas_ready{kube_namespace:sock-shop,kube_replicaset:payment-*}
```

**Note**: Use wildcard `payment-*` because ReplicaSet has hash suffix

---

### **Pod Phase Metrics**

**Metric**:
```
kubernetes_state.pod.status_phase
```

**Query**:
```
count:kubernetes_state.pod.status_phase{kube_namespace:sock-shop,pod_phase:running,kube_deployment:payment}
```

**Note**: This counts pods in "running" phase

---

## 🚫 **METRICS THAT DON'T EXIST**

These metrics DO NOT exist in modern Datadog:
- ❌ `kubernetes.pods.running` (you tried this)
- ❌ `kubernetes.deployment.replicas`
- ❌ `kube.pod.running`

**Always use** `kubernetes_state.` prefix!

---

## ✅ **EXACT STEPS TO SEE YOUR INCIDENT**

### **Step 1**: Open Metrics Explorer
https://us5.datadoghq.com/metric/explorer

### **Step 2**: Clear Query
Delete any existing query

### **Step 3**: Paste This
```
avg:kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop,kube_deployment:payment}
```

### **Step 4**: Set Time Range
- Click time dropdown
- Select "Past 4 hours"
- OR use Custom: Oct 30, 1:45 PM - 2:30 PM IST

### **Step 5**: Expected Result
You SHOULD see:
- **Flat line at 1** from 13:00 - 13:54
- **Sharp drop to 0** at 13:54 (1:54 PM IST)
- **Flat line at 0** from 13:54 - 14:05
- **Sharp rise to 1** at 14:05 (2:05 PM IST)
- **Flat line at 1** after 14:05

### **Step 6**: If Still Flat
Reasons and solutions:

**Reason 1**: Metric name typo
- **Check**: Exact spelling `kubernetes_state.deployment.replicas_available`
- **Check**: No spaces in query

**Reason 2**: Wrong tags
- **Check**: `kube_deployment:payment` (not `deployment:payment`)
- **Check**: `kube_namespace:sock-shop` (not `namespace:sock-shop`)

**Reason 3**: Time range
- **Solution**: Zoom to exactly 1:45-2:15 PM IST (Oct 30)

**Reason 4**: Metrics delay
- **Solution**: Wait 5-10 minutes, refresh page (Ctrl+F5)

**Reason 5**: Wrong Datadog site
- **Check**: URL is https://us5.datadoghq.com (not us1, eu1, etc.)

---

## 🎬 **ALTERNATIVE: GRAPH MULTIPLE METRICS**

Create a comprehensive view:

**Query A** (Desired):
```
avg:kubernetes_state.deployment.replicas_desired{kube_namespace:sock-shop,kube_deployment:payment}
```

**Query B** (Available):
```
avg:kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop,kube_deployment:payment}
```

**Query C** (Ready):
```
avg:kubernetes_state.deployment.replicas_ready{kube_namespace:sock-shop,kube_deployment:payment}
```

**All three should overlap and drop together**, showing the deployment was scaled down.

---

## 📋 **TAG NAMES REFERENCE**

Common tag naming confusion:

| Wrong Tag | Correct Tag |
|-----------|-------------|
| `namespace:sock-shop` | `kube_namespace:sock-shop` |
| `deployment:payment` | `kube_deployment:payment` |
| `pod:payment-*` | `kube_pod:payment-*` OR `pod_name:payment-*` |
| `replicaset:payment-*` | `kube_replicaset:payment-*` |

**Always check tag names** in Datadog facets/filters dropdown!

---

## 🔧 **TROUBLESHOOTING COMMAND**

Run this to verify kubernetes_state check is working:

```powershell
kubectl -n datadog exec deployment/datadog-agent-cluster-agent -- agent status | Select-String -Pattern "kubernetes_state_core" -Context 5
```

**Expected output**: Should show the check is running and configured

---

## 📚 **DATADOG DOCUMENTATION**

Official metric names:
- https://docs.datadoghq.com/integrations/kubernetes_state_core/
- Search for "kubernetes_state.deployment" to see all available metrics

---

## 💡 **WHY THIS HAPPENED**

1. **Old Documentation**: Some guides use old metric names (`kubernetes.*`)
2. **Agent Version**: Modern agents (v7+) use `kubernetes_state.*`
3. **Integration Name**: Changed from `kubernetes` to `kubernetes_state_core`

**Your agent is running kubernetes_state_core check** (confirmed in agent status), so use `kubernetes_state.*` metrics!

---

## 🎯 **FINAL ANSWER**

**Copy this EXACT query and paste it in Metrics Explorer**:

```
avg:kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop,kube_deployment:payment}
```

**Time**: Past 4 hours  
**Expected**: Drop from 1 to 0 at 1:54 PM IST, rise back to 1 at 2:05 PM IST

**This WILL work.** If it doesn't, the metric isn't being collected (but agent status shows it should be).
