# Datadog Log Collection Fix - Complete Guide

## Problem Summary

**Symptom:** `LogsProcessed: 0` despite Datadog agent running and log files present

**Root Cause:** The agent was configured with `containerCollectAll: false` but the namespace filter (`containerInclude: ["kube_namespace:sock-shop"]`) was not being properly applied by the Helm chart, resulting in no logs being collected.

**Impact:** No application logs from sock-shop reaching Datadog dashboard

---

## Understanding PASS-A vs PASS-B

### PASS-A Configuration (`datadog-values-pass-a.yaml`)
- **Purpose:** Troubleshooting/Testing
- **Behavior:** Collects ALL logs from ALL containers in the cluster
- **Use Case:** Initial setup, debugging, proving end-to-end pipeline works
- **Setting:** `containerCollectAll: true`
- **Pros:** Guaranteed to collect sock-shop logs
- **Cons:** High volume, includes system logs, higher cost

### PASS-B Configuration (`datadog-values-pass-b.yaml`, `datadog-values-pass-b-clean.yaml`)
- **Purpose:** Production use with namespace filtering
- **Behavior:** Intended to collect only from `sock-shop` namespace
- **Use Case:** Production deployment with cost optimization
- **Setting:** `containerCollectAll: false` + `containerInclude: ["kube_namespace:sock-shop"]`
- **Issue:** The `containerInclude` directive was not being translated to agent config correctly

### New Production Configuration (`datadog-values-production.yaml`)
- **Purpose:** Reliable production deployment
- **Behavior:** Collects all logs but excludes system namespaces
- **Use Case:** Best balance of reliability and cost
- **Setting:** `containerCollectAll: true` + `containerExclude: [system namespaces]`
- **Why It Works:** Explicit environment variables ensure proper configuration

---

## Solution Comparison

| Approach | Reliability | Flexibility | Complexity | Recommended For |
|----------|-------------|-------------|------------|----------------|
| **Production Config** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐ Low | **Primary Recommendation** |
| **PASS-A Config** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ Low | Initial testing only |
| **Selective + Annotations** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ High | Advanced users |

---

## Immediate Fix (Recommended)

### Step 1: Upgrade Datadog Agent with Production Configuration

```powershell
# Navigate to your sock-shop-demo directory
cd D:\sock-shop-demo

# Upgrade the Datadog agent with the new configuration
helm upgrade datadog-agent datadog/datadog `
  --namespace datadog `
  --values datadog-values-production.yaml `
  --wait
```

**Expected Output:**
```
Release "datadog-agent" has been upgraded. Happy Helming!
NAME: datadog-agent
LAST DEPLOYED: [timestamp]
NAMESPACE: datadog
STATUS: deployed
REVISION: 2
```

### Step 2: Wait for Agent Pods to Restart

```powershell
# Watch the pods restart
kubectl -n datadog get pods -w
```

Wait until all pods show `Running` and `1/1` ready state. Press `Ctrl+C` to exit watch mode.

### Step 3: Verify Configuration

```powershell
# Get the agent pod name
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

# Check environment variables are set correctly
kubectl -n datadog exec $POD -c agent -- env | Select-String -Pattern "DD_LOGS"
```

**Expected Output:**
```
DD_LOGS_ENABLED=true
DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
DD_LOGS_CONFIG_K8S_CONTAINER_USE_FILE=true
DD_LOG_LEVEL=info
```

### Step 4: Verify Log Processing

Wait 2-3 minutes for the agent to start processing logs, then check status:

```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,20 -Pattern "Logs Agent"
```

**Expected Output (SUCCESS):**
```
Logs Agent
==========

    Reliable: Sending compressed logs in HTTPS to agent-http-intake.logs.us5.datadoghq.com. on port 443
    BytesSent: [increasing number]
    EncodedBytesSent: [increasing number]
    LogsProcessed: [NON-ZERO number]  ← This should be > 0 now!
    LogsSent: [increasing number]
    LogsTruncated: 0
    RetryCount: 0
```

### Step 5: Generate Traffic and Verify Logs in Datadog UI

```powershell
# Open the sock-shop application
Start-Process "http://localhost:2025"

# Generate some activity:
# 1. Browse the catalogue
# 2. Login (user: user, pass: password)
# 3. Add items to cart
# 4. Complete an order
```

**Verify in Datadog UI:**
1. Go to https://us5.datadoghq.com/logs
2. Filter by: `kube_namespace:sock-shop`
3. You should see logs from `front-end`, `catalogue`, `user`, `carts`, etc.

### Step 6: Check Specific Service Logs

```powershell
# Check front-end log volume
kubectl -n datadog exec $POD -c agent -- sh -c 'du -h /var/log/pods/sock-shop_front-end*/*/*.log 2>/dev/null'

# View a sample of front-end logs
kubectl -n datadog exec $POD -c agent -- sh -c 'tail -5 /var/log/pods/sock-shop_front-end*/*/[0-9]*.log 2>/dev/null'
```

---

## Alternative Solution (Advanced): Selective Log Collection

If you want fine-grained control over which pods send logs (lower cost, more control):

### Step 1: Deploy with Selective Configuration

```powershell
helm upgrade datadog-agent datadog/datadog `
  --namespace datadog `
  --values datadog-values-selective.yaml `
  --wait
```

### Step 2: Add Annotations to Sock-Shop Pods

```powershell
# Apply the annotation patch
kubectl apply -k add-datadog-log-annotations.yaml
```

### Step 3: Restart Deployments to Pick Up Annotations

```powershell
kubectl -n sock-shop rollout restart deployment front-end
kubectl -n sock-shop rollout restart deployment catalogue
kubectl -n sock-shop rollout restart deployment user
kubectl -n sock-shop rollout restart deployment carts
kubectl -n sock-shop rollout restart deployment orders
kubectl -n sock-shop rollout restart deployment payment
kubectl -n sock-shop rollout restart deployment shipping
kubectl -n sock-shop rollout restart deployment queue-master
```

---

## Troubleshooting

### Issue: Still Seeing `LogsProcessed: 0`

**Check 1:** Verify agent configuration
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

kubectl -n datadog exec $POD -c agent -- agent configcheck
```

**Check 2:** Look for errors in agent logs
```powershell
kubectl -n datadog logs $POD -c agent --tail=50 | Select-String -Pattern "error|warn" -CaseSensitive:$false
```

**Check 3:** Verify log files are being created
```powershell
kubectl -n datadog exec $POD -c agent -- sh -c 'ls -lh /var/log/containers/*sock-shop* | wc -l'
```

### Issue: Logs Not Appearing in Datadog UI

**Check 1:** Verify API key is valid
```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "API Key"
```

Should show: `API key ending with 73a42: API Key valid`

**Check 2:** Check network connectivity
```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "agent-http-intake"
```

Should show: `Reliable: Sending compressed logs in HTTPS to agent-http-intake.logs.us5.datadoghq.com.`

**Check 3:** Verify site configuration
```powershell
kubectl -n datadog get deployment datadog-agent -o yaml | Select-String -Pattern "DD_SITE"
```

Should show: `DD_SITE=us5.datadoghq.com`

### Issue: High Log Volume

If you're seeing too many logs:

**Option 1:** Switch to selective configuration (see Alternative Solution above)

**Option 2:** Add more namespace exclusions to production config
```yaml
# Edit datadog-values-production.yaml
containerExclude:
  - "kube_namespace:kube-system"
  - "kube_namespace:kube-public"
  - "kube_namespace:kube-node-lease"
  - "kube_namespace:local-path-storage"
  - "kube_namespace:monitoring"  # Add more as needed
  - "image_name:kindest/node"
```

Then upgrade:
```powershell
helm upgrade datadog-agent datadog/datadog --namespace datadog --values datadog-values-production.yaml
```

---

## Best Practices Going Forward

### 1. Regular Monitoring
Check agent status weekly:
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items[0].metadata.name
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed|LogsSent"
```

### 2. Cost Optimization
- Start with `datadog-values-production.yaml` for reliability
- After 1-2 weeks of stable operation, consider switching to selective configuration
- Use Datadog UI to identify high-volume log sources and add exclusions

### 3. Configuration Management
- Keep your active configuration file under version control
- Document any changes to `datadog-values-*.yaml` files
- Test configuration changes in a non-production environment first

### 4. Upgrade Strategy
When deploying to new environments:
1. Start with PASS-A (collectAll=true) to prove end-to-end
2. Once confirmed working, switch to production config
3. Only use selective config if you need fine-grained control

---

## Quick Reference

### Check Agent Status
```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/name=datadog-agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
kubectl -n datadog exec $POD -c agent -- agent status
```

### View Live Logs
```powershell
kubectl -n datadog logs -f $POD -c agent
```

### Restart Agent
```powershell
kubectl -n datadog rollout restart daemonset datadog-agent
```

### View Current Configuration
```powershell
helm get values datadog-agent -n datadog
```

---

## Files Created

| File | Purpose |
|------|---------|
| `datadog-values-production.yaml` | **Recommended** - Reliable production config |
| `datadog-values-selective.yaml` | Optional - For fine-grained control |
| `add-datadog-log-annotations.yaml` | Optional - Kustomize patch for annotations |
| `DATADOG-FIX-GUIDE.md` | This guide |

---

## Summary

**What Was Wrong:**
- PASS-B configuration relied on `containerInclude` which wasn't being applied correctly
- Agent showed `DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=false` but no include filter

**What We Fixed:**
- Created `datadog-values-production.yaml` with explicit environment variables
- Enables `containerCollectAll=true` with system namespace exclusions
- Adds explicit `DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true` environment variable

**Expected Result:**
- `LogsProcessed` will be > 0 within 2-3 minutes of upgrade
- Logs will appear in Datadog UI under `kube_namespace:sock-shop` filter
- No future issues with log collection

**Next Steps:**
1. Run the upgrade command from Step 1
2. Verify with Step 3-4
3. Generate traffic and check Datadog UI (Step 5)
4. Update your main README with this solution
