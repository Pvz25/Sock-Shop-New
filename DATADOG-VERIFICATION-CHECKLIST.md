# Datadog Log Collection - Verification Checklist

After running `helm upgrade` with `datadog-values-production-fixed.yaml`, follow this checklist:

---

## ✅ Verification Steps

### 1. Pods Running
```powershell
kubectl -n datadog get pods
```
**✓ PASS:** All pods show `Running` and `1/1` READY

---

### 2. Get Worker Pod
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
echo $POD
```
**✓ PASS:** Returns pod name like `datadog-agent-xxxxx`

---

### 3. Verify Configuration
```powershell
kubectl -n datadog exec $POD -c agent -- env | Select-String -Pattern "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL"
```
**✓ PASS:** Shows `DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true`

---

### 4. Check for Duplicates
```powershell
kubectl -n datadog exec $POD -c agent -- env | Select-String -Pattern "DD_LOGS_ENABLED"
```
**✓ PASS:** Only ONE occurrence (no duplicates)

---

### 5. Wait for Processing
```powershell
Start-Sleep -Seconds 180
Write-Host "Wait complete"
```
**✓ PASS:** Waited 3 minutes

---

### 6. Check Log Processing (CRITICAL)
```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,15 -Pattern "Logs Agent"
```
**✓ PASS:** `LogsProcessed: > 0` (any non-zero number)
**✓ PASS:** `LogsSent: > 0`
**✗ FAIL:** `LogsProcessed: 0` (see troubleshooting)

---

### 7. Verify API Key
```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "API Key"
```
**✓ PASS:** Shows "API Key valid"

---

### 8. Check Log File Detection
```powershell
kubectl -n datadog exec $POD -c agent -- sh -c 'ls -lh /var/log/containers/*sock-shop* 2>/dev/null | wc -l'
```
**✓ PASS:** Returns number > 0 (typically 14-20)

---

### 9. Generate Traffic
```powershell
Start-Process "http://localhost:2025"
```
**Manual:** Login, browse, add to cart, place order

---

### 10. Verify Increased Processing
```powershell
Start-Sleep -Seconds 30
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"
```
**✓ PASS:** Number increased from Step 6

---

### 11. Check Datadog UI
```powershell
Start-Process "https://us5.datadoghq.com/logs"
```
**Manual:** Filter by `kube_namespace:sock-shop`
**✓ PASS:** See logs from front-end, catalogue, user, carts, etc.

---

## 🎯 Success Criteria

Your Datadog is **FULLY CONNECTED** if:
- [x] LogsProcessed > 0
- [x] LogsSent > 0
- [x] API Key valid
- [x] Logs visible in Datadog UI

---

## 🔧 Troubleshooting (If Any Step Fails)

### Issue: LogsProcessed = 0

**Check Agent Logs:**
```powershell
kubectl -n datadog logs $POD -c agent --tail=100 | Select-String -Pattern "error|ERROR"
```

**Check DaemonSet Config:**
```powershell
kubectl -n datadog get daemonset datadog-agent -o yaml | Select-String -Pattern "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL" -Context 3
```
Should show: `value: "true"`

**Check for Duplicate Env Vars:**
```powershell
kubectl -n datadog get daemonset datadog-agent -o yaml | Select-String -Pattern "DD_LOGS_ENABLED"
```
Should appear ONLY ONCE

---

### Issue: API Key Invalid

**Check Secret:**
```powershell
kubectl -n datadog get secret datadog-secret -o yaml
```

**Recreate Secret (if needed):**
```powershell
kubectl -n datadog delete secret datadog-secret
kubectl -n datadog create secret generic datadog-secret --from-literal=api-key=YOUR_API_KEY_HERE
kubectl -n datadog rollout restart daemonset datadog-agent
```

---

### Issue: No Logs in Datadog UI

**Verify Site Configuration:**
```powershell
kubectl -n datadog exec $POD -c agent -- env | Select-String -Pattern "DD_SITE"
```
Should show: `DD_SITE=us5.datadoghq.com`

**Check Network Connectivity:**
```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "agent-http-intake"
```
Should show: `Sending compressed logs in HTTPS to agent-http-intake.logs.us5.datadoghq.com`

---

## 📊 Expected Metrics After 5 Minutes

| Metric | Expected Value |
|--------|----------------|
| LogsProcessed | 500 - 3000 |
| LogsSent | 50 - 300 |
| BytesSent | 2MB - 20MB |
| EncodedBytesSent | 500KB - 5MB |
| LogsTruncated | 0 |
| RetryCount | 0 |

---

## 🔄 Quick Recheck Command

Run this anytime to check status:
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed|LogsSent|API Key"
```

---

**Last Updated:** Oct 22, 2025  
**Configuration File:** `datadog-values-production-fixed.yaml`  
**Helm Revision:** 8
