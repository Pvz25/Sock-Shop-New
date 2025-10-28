# Datadog Log Collection Troubleshooting Guide

**Created:** October 27, 2025  
**Issue Resolved:** Datadog agent collecting logs but not sending to Datadog UI  
**Environment:** KIND cluster with WSL2, Datadog Helm Chart

---

## 🔍 Problem Summary

### Symptoms Observed

```powershell
# Checking agent status showed:
kubectl -n datadog exec <agent-pod> -c agent -- agent status

Logs Agent
==========
  BytesSent: 0                    ← NO logs sent to Datadog!
  LogsProcessed: 381              ← Logs ARE being collected locally
  LogsSent: 0                     ← Nothing reaching Datadog UI
```

**Key Indicators:**
- ✅ Agent running (pods 2/2 Ready)
- ✅ Logs collected (`LogsProcessed > 0`)
- ❌ Logs not sent (`BytesSent: 0`)
- ❌ Nothing in Datadog UI

### Error Messages in Agent Logs

```powershell
kubectl -n datadog logs <agent-pod> -c agent --tail=100 | Select-String "error|ERROR|warn|WARN"
```

**Output:**
```
2025-10-27 13:56:50 UTC | CORE | WARN | dial tcp: lookup agent-intake.logs.us5.datadoghq.com.: no such host
2025-10-27 13:56:54 UTC | CORE | WARN | dial tcp: lookup agent-intake.logs.us5.datadoghq.com.: no such host
2025-10-27 13:57:16 UTC | CORE | WARN | dial tcp: lookup agent-intake.logs.us5.datadoghq.com.: no such host
```

**Critical Error:** `dial tcp: lookup agent-intake.logs.us5.datadoghq.com.: no such host`

---

## 🎯 Root Cause Analysis

### Issue #1: DNS Resolution Failure

**Root Cause:** WSL2 + KIND networking limitation

**Explanation:**
- KIND clusters run in isolated Docker networks
- WSL2 DNS resolution may not properly resolve external domains
- Datadog agent pods cannot resolve `agent-intake.logs.us5.datadoghq.com`
- TCP transport requires DNS resolution to work

**Why This Happens:**
1. KIND uses Docker networking
2. WSL2 has its own DNS resolver
3. Container-to-external DNS lookups may fail
4. This is a known issue with nested virtualization (WSL2 → Docker → KIND → Pods)

### Issue #2: Sock-Shop Logs Not in Integration List

**Secondary Issue:** Even with DNS working, sock-shop logs weren't being collected

**Agent Status Showed:**
```
============
Integrations
============

kube-system/coredns-xxxxx/coredns         ✓ Collecting logs
kube-system/kube-proxy-xxxxx/kube-proxy   ✓ Collecting logs
datadog/datadog-agent-xxxxx/agent         ✓ Collecting logs
monitoring/node-exporter-xxxxx            ✓ Collecting logs

sock-shop/front-end-xxxxx/front-end       ✗ NOT LISTED!
sock-shop/catalogue-xxxxx/catalogue       ✗ NOT LISTED!
```

**Root Cause:**
- Namespace exclusion configuration was too aggressive
- OR volume mount permissions prevented file access
- Logs from sock-shop namespace weren't being tailed

---

## ✅ Solution Implemented

### Step 1: Switch from TCP to HTTP Transport

**Why This Works:**
- HTTP transport uses different endpoint: `agent-http-intake.logs.us5.datadoghq.com`
- HTTP/HTTPS has better compatibility with DNS resolution
- Uses port 443 (HTTPS) which is more reliable than custom ports

**Configuration Changes Made:**

**File:** `d:\sock-shop-demo\datadog-values-metrics-logs.yaml`

```yaml
datadog:
  logs:
    enabled: true
    containerCollectAll: true
    containerCollectUsingFiles: true
    # NEW: Force HTTP transport
    config:
      force_use_http: true
      use_compression: true
      compression_level: 6
```

### Step 2: Add Explicit Environment Variables

**Why This Works:**
- Ensures HTTP transport is configured at agent runtime level
- Overrides any Helm chart defaults
- Provides redundancy in configuration

```yaml
agents:
  containers:
    agent:
      env:
        # Logs collection
        - name: DD_LOGS_ENABLED
          value: "true"
        - name: DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL
          value: "true"
        - name: DD_LOGS_CONFIG_K8S_CONTAINER_USE_FILE
          value: "true"
        
        # HTTP transport (bypasses DNS issues)
        - name: DD_LOGS_CONFIG_USE_HTTP
          value: "true"
        - name: DD_LOGS_CONFIG_USE_COMPRESSION
          value: "true"
        - name: DD_LOGS_CONFIG_COMPRESSION_LEVEL
          value: "6"
```

### Step 3: Remove Namespace Exclusions (Temporarily)

**Why This Works:**
- Ensures all namespaces are collected during troubleshooting
- Verifies sock-shop logs can be collected
- Can be re-added after confirming logs work

```yaml
# BEFORE (blocking sock-shop collection):
logs:
  containerExclude:
    - "kube_namespace:kube-system"
    - "kube_namespace:kube-public"
    - "kube_namespace:kube-node-lease"
    - "kube_namespace:local-path-storage"

# AFTER (collect from all namespaces):
logs:
  # Temporarily removed exclusions
  # containerExclude: []
```

---

## 📋 Complete Fix Procedure

### Commands to Apply the Fix

```powershell
# Step 1: Navigate to repository
cd d:\sock-shop-demo

# Step 2: Verify updated configuration
Get-Content datadog-values-metrics-logs.yaml | Select-String -Pattern "force_use_http" -Context 2

# Expected output:
#   containerCollectAll: true
# > force_use_http: true
#   use_compression: true

# Step 3: Upgrade Datadog Helm release
helm upgrade datadog-agent datadog/datadog `
  --namespace datadog `
  --values datadog-values-metrics-logs.yaml `
  --wait `
  --timeout 5m

# Expected output:
# Release "datadog-agent" has been upgraded. Happy Helming!

# Step 4: Wait for rollout to complete
kubectl -n datadog rollout status daemonset datadog-agent
kubectl -n datadog rollout status deployment datadog-agent-cluster-agent

# Expected output:
# daemon set "datadog-agent" successfully rolled out
# deployment "datadog-agent-cluster-agent" successfully rolled out

# Step 5: Wait 3 minutes for log collection to stabilize
Start-Sleep -Seconds 180

# Step 6: Verify pods are running
kubectl -n datadog get pods

# Expected output:
# NAME                                           READY   STATUS    RESTARTS   AGE
# datadog-agent-cluster-agent-xxxxx              1/1     Running   0          3m
# datadog-agent-xxxxx                            2/2     Running   0          2m
# datadog-agent-yyyyy                            2/2     Running   0          2m
```

---

## ✅ Verification Steps

### Step 1: Check for DNS Errors (Should Be Gone)

```powershell
$agentPod = kubectl -n datadog get pods -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
kubectl -n datadog logs $agentPod -c agent --tail=50 | Select-String -Pattern "no such host"
```

**✅ Success:** No output (empty = no DNS errors)  
**❌ Failure:** Still seeing DNS error messages

### Step 2: Verify HTTP Transport is Active

```powershell
kubectl -n datadog exec $agentPod -c agent -- agent status | Select-String -Pattern "HTTP|BytesSent|LogsProcessed" -Context 3
```

**✅ Success Indicators:**
```
Logs Agent
==========
  Reliable: Sending compressed logs in HTTPS to agent-http-intake.logs.us5.datadoghq.com. on port 443
  
  BytesSent: 3660829        ← MUST BE > 0!
  LogsProcessed: 3655       ← Should be increasing
  LogsSent: 3651            ← Should be > 0
```

**Key Changes:**
- Protocol: `HTTPS` (not TCP)
- Endpoint: `agent-http-intake.logs.us5.datadoghq.com` (not `agent-intake.logs`)
- `BytesSent` is **greater than 0**

### Step 3: Verify Sock-Shop Logs Are Collected

```powershell
kubectl -n datadog exec $agentPod -c agent -- agent status | Select-String -Pattern "sock-shop" -Context 5
```

**✅ Success - Should see:**
```
============
Integrations
============

sock-shop/front-end-5db94cdb6b-xkxpf/front-end
----------------------------------------------
  - Type: file
    Path: /var/log/pods/sock-shop_front-end-5db94cdb6b-xkxpf_xxxxx/front-end/*.log
    Status: OK
      1 files tailed out of 2 files matching
    Bytes Read: 53248
    
sock-shop/catalogue-xxxxx/catalogue
----------------------------------
  - Type: file
    Status: OK
    Bytes Read: 12345
```

**❌ If NOT listed:** Logs still not being collected from sock-shop

### Step 4: Verify in Datadog UI

```powershell
Start-Process "https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop"
```

**In Datadog UI:**
1. Set time range: "Past 15 Minutes"
2. Click "Live Tail" button
3. Look for logs streaming

**✅ Success:** Logs from front-end, catalogue, orders, etc. streaming in real-time

**❌ Failure:** No logs appear (wait 2-3 more minutes and refresh)

---

## 📊 Before & After Comparison

### Before Fix

| Metric | Value | Status |
|--------|-------|--------|
| **Agent Status** | Running | ✓ |
| **LogsProcessed** | 381 | ✓ |
| **BytesSent** | 0 | ✗ |
| **LogsSent** | 0 | ✗ |
| **Transport** | TCP | ✗ |
| **DNS Resolution** | Failing | ✗ |
| **Sock-Shop Logs** | Not collected | ✗ |
| **Datadog UI** | Empty | ✗ |

### After Fix

| Metric | Value | Status |
|--------|-------|--------|
| **Agent Status** | Running | ✓ |
| **LogsProcessed** | 3,655 | ✓ |
| **BytesSent** | 3,660,829 | ✓ |
| **LogsSent** | 3,651 | ✓ |
| **Transport** | HTTPS | ✓ |
| **DNS Resolution** | Working | ✓ |
| **Sock-Shop Logs** | Collected | ✓ |
| **Datadog UI** | Logs flowing | ✓ |

---

## 🔧 Alternative Solutions (If HTTP Doesn't Work)

### Option 1: Add Explicit DNS Resolution

If HTTP transport still has issues, add DNS override:

```yaml
agents:
  hostAliases:
    - ip: "52.206.24.91"  # Get from: nslookup agent-http-intake.logs.us5.datadoghq.com
      hostnames:
        - "agent-http-intake.logs.us5.datadoghq.com"
```

### Option 2: Use Host Network Mode

```yaml
agents:
  useHostNetwork: true  # Should already be true for KIND
```

This makes pods use the host's network stack instead of Docker's.

### Option 3: Verify API Key Permissions

```powershell
# Check API key has logs_write permission
kubectl -n datadog get secret datadog-secret -o jsonpath='{.data.api-key}' | base64 -d
```

Verify in Datadog UI:
- Organization Settings → API Keys
- Find your key
- Ensure "Logs" permission is enabled

---

## 🚨 Common Pitfalls to Avoid

### Pitfall 1: Searching Logs for OOMKilled

**Wrong:** Searching in Logs Explorer for "OOMKilled"
```
Query: kube_namespace:sock-shop OOMKilled
Result: No logs found ❌
```

**Right:** OOMKilled is a Kubernetes EVENT, not a log

**Where to find:**
1. **Kubernetes Events:**
   ```powershell
   kubectl -n sock-shop get events --sort-by='.lastTimestamp' | Select-String "OOM"
   ```

2. **Datadog Event Explorer (NOT Logs!):**
   ```
   URL: https://us5.datadoghq.com/event/explorer
   Query: kube_namespace:sock-shop
   ```

3. **Pod Description:**
   ```powershell
   kubectl -n sock-shop describe pod <pod-name> | Select-String "OOMKilled"
   ```

### Pitfall 2: Wrong Deployment Name

**Wrong:**
```powershell
kubectl -n datadog rollout status deployment datadog-cluster-agent
# Error: deployments.apps "datadog-cluster-agent" not found
```

**Right:**
```powershell
kubectl -n datadog rollout status deployment datadog-agent-cluster-agent
#                                              ^^^^^^^^^^^^^^ Correct name
```

### Pitfall 3: Not Waiting Long Enough

After Helm upgrade, wait at least **3 minutes** before checking logs:
- Pods need to restart
- Agent needs to discover pods
- Logs need to buffer and send
- Datadog needs to index logs

### Pitfall 4: Checking Wrong Time Range

If you ran an incident earlier but are checking "Past 15 Minutes" in Datadog, you won't see old logs.

**Always:**
- Note the exact time you ran the test
- Set Datadog time range to include that time
- Use "Past 1 Hour" or "Past 4 Hours" for safety

---

## 📝 Summary

### Problem
- Datadog agent collecting logs locally but not sending to Datadog UI
- DNS resolution failure preventing TCP transport from working
- Sock-shop namespace logs not being collected

### Solution
1. Switch from TCP to HTTP transport (`force_use_http: true`)
2. Add explicit environment variables for HTTP transport
3. Remove namespace exclusions temporarily
4. Upgrade Helm release with new configuration
5. Wait 3 minutes for stabilization

### Result
- **BytesSent:** 0 → 3,660,829 ✓
- **LogsProcessed:** 381 → 3,655 ✓
- **LogsSent:** 0 → 3,651 ✓
- **Datadog UI:** Empty → Logs flowing ✓

### Key Learnings
1. KIND + WSL2 environments may need HTTP transport for Datadog logs
2. TCP transport relies on DNS which can fail in nested virtualization
3. OOMKilled is a Kubernetes EVENT, not an application log
4. Always verify logs are being sent (`BytesSent > 0`), not just collected
5. Wait 3+ minutes after configuration changes for logs to appear

---

## 🔗 Related Documentation

- [INCIDENT-1-APP-CRASH.md](./INCIDENT-1-APP-CRASH.md) - Full incident simulation guide
- [DATADOG-METRICS-LOGS-SETUP.md](./DATADOG-METRICS-LOGS-SETUP.md) - Complete Datadog setup
- [datadog-values-metrics-logs.yaml](./datadog-values-metrics-logs.yaml) - Working configuration file

---

**Document Version:** 1.0  
**Last Updated:** October 27, 2025  
**Issue Status:** ✅ RESOLVED  
**Configuration File:** `datadog-values-metrics-logs.yaml`
