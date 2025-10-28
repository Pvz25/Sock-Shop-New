# Datadog Log Collection - Quick Fix

## 🚨 Problem
```
LogsProcessed: 0
```

## ✅ Solution (2 commands)

```powershell
# 1. Deploy the fix
cd D:\sock-shop-demo
helm upgrade datadog-agent datadog/datadog --namespace datadog --values datadog-values-production.yaml --wait

# 2. Verify (wait 2-3 minutes first)
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"
```

## 📊 Expected Result

**Before:**
```
LogsProcessed: 0
```

**After (2-3 minutes):**
```
LogsProcessed: 847  ← Non-zero = SUCCESS
```

## 🔍 Check Datadog UI

1. Go to https://us5.datadoghq.com/logs
2. Filter: `kube_namespace:sock-shop`
3. See logs from: front-end, catalogue, user, carts, etc.

## 📚 More Info

- **Detailed Guide:** `DATADOG-FIX-GUIDE.md`
- **Executive Summary:** `SOLUTION-SUMMARY.md`
- **Main Setup:** `COMPLETE-SETUP-GUIDE.md`

---

**That's it!** Two commands and you're done.
