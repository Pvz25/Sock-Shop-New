# Datadog Setup - Command Sequence
**Your API Key:** Already set in `$DD_API_KEY` variable ✅

Run these commands in order. Copy each command block and paste into PowerShell.

---

## 🔍 STEP 1: Check if Datadog Already Exists

```powershell
kubectl get namespace datadog
```

**If you see:** `namespace/datadog found` → Skip to STEP 2A  
**If you see:** `Error from server (NotFound)` → Skip to STEP 2B

---

## 🗑️ STEP 2A: Clean Up Existing Datadog (If Exists)

```powershell
# Uninstall existing Helm release
helm uninstall datadog-agent -n datadog

# Delete old secret with expired API key
kubectl -n datadog delete secret datadog-secret --ignore-not-found=true

# Wait for cleanup
Start-Sleep -Seconds 10

# Verify cleanup
kubectl -n datadog get pods
```

**Expected:** `No resources found in datadog namespace.`

**Then continue to STEP 3.**

---

## 📦 STEP 2B: Create Datadog Namespace (If Doesn't Exist)

```powershell
kubectl create namespace datadog
```

**Expected:** `namespace/datadog created`

**Then continue to STEP 3.**

---

## 🔐 STEP 3: Create New Datadog Secret

```powershell
kubectl -n datadog create secret generic datadog-secret --from-literal=api-key=$DD_API_KEY
```

**Expected:** `secret/datadog-secret created`

---

## ✅ STEP 4: Verify Secret

```powershell
kubectl -n datadog get secret datadog-secret
```

**Expected:**
```
NAME             TYPE     DATA   AGE
datadog-secret   Opaque   1      5s
```

---

## 📦 STEP 5: Add/Update Helm Repositories

```powershell
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

**Expected:**
```
"datadog" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "datadog" chart repository
Update Complete. ⎈Happy Helming!⎈
```

---

## 🚀 STEP 6: Install Datadog Agent (Metrics + Logs)

```powershell
cd D:\sock-shop-demo
helm install datadog-agent datadog/datadog --namespace datadog --values datadog-values-metrics-logs.yaml --wait
```

**Expected:**
```
NAME: datadog-agent
LAST DEPLOYED: [timestamp]
NAMESPACE: datadog
STATUS: deployed
REVISION: 1
```

**⏱️ This will take 2-3 minutes.** The `--wait` flag ensures all pods are ready before completing.

---

## 🔍 STEP 7: Verify Pods are Running

```powershell
kubectl -n datadog get pods -o wide
```

**Expected:**
```
NAME                                    READY   STATUS    RESTARTS   AGE   NODE
datadog-agent-xxxxx                     2/2     Running   0          2m    sockshop-control-plane
datadog-agent-yyyyy                     2/2     Running   0          2m    sockshop-worker
datadog-agent-cluster-agent-zzzzz-xxx  1/1     Running   0          2m    sockshop-worker
```

**Success Indicators:**
- 3 pods total (2 node agents + 1 cluster agent)
- Node agents: `2/2` containers ready (agent + trace-agent sidecar)
- Cluster agent: `1/1` ready
- All showing `Running`

**Note:** Process Agent runs INSIDE the main agent container (`DD_PROCESS_CONFIG_RUN_IN_CORE_AGENT_ENABLED=true`), not as a separate container. This is the modern, recommended architecture.

**If `ContainerCreating`:** Wait 30 seconds and check again.

---

## STEP 8: Get Worker Agent Pod Name

```powershell
$POD = (kubectl -n datadog get pods -l app.kubernetes.io/component=agent -o json | ConvertFrom-Json).items | Where-Object { $_.spec.nodeName -eq "sockshop-worker" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name
echo "Worker Agent Pod: $POD"
```

**Expected:**
```
Worker Agent Pod: datadog-agent-xxxxx
```

---

## 🔍 STEP 9: Verify Configuration

```powershell
kubectl -n datadog exec $POD -c agent -- env | Select-String -Pattern "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL"
```

**Expected:**
```
DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
```

**✅ Critical:** Must show `true`

---

## ⏱️ STEP 10: Wait for Log Processing

```powershell
Write-Host "Waiting 3 minutes for agent to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 180
Write-Host "Done!" -ForegroundColor Green
```

**Just wait 3 minutes.** The agent needs time to:
- Discover all pods
- Start tailing log files
- Begin processing and sending data

---

## ✅ STEP 11: Check Logs Processing Status

```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,15 -Pattern "Logs Agent"
```

**Expected:**
```
> Logs Agent
  ==========
  
      Reliable: Sending compressed logs in HTTPS to agent-http-intake.logs.us5.datadoghq.com
      BytesSent: 2847392
      EncodedBytesSent: 654821
      LogsProcessed: 847       ← MUST BE > 0 ✅
      LogsSent: 127
      LogsTruncated: 0
      RetryCount: 0
```

**✅ SUCCESS:** `LogsProcessed: > 0`  
**❌ PROBLEM:** `LogsProcessed: 0` (tell me if this happens)

---

## 📊 STEP 12: Check Metrics Collection

```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Context 0,20 -Pattern "Process Component"
```

**Expected:**
```
> Process Component
  =================
  
  Enabled Checks: [process rtprocess]
  System Probe Process Module Status: Not running
  Process Language Detection Enabled: False
  
  =================
  Process Endpoints
  =================
    https://process.us5.datadoghq.com. - API Key ending with:
        - 88eb8
```

**✅ SUCCESS:** Shows "Enabled Checks" with process and rtprocess

**📝 Important Note:** The Process Agent runs INSIDE the core agent (in-core mode). If you query it as a separate process (`-c process-agent`), it will show "Not running" - this is normal and expected! The metrics are still being collected by the core agent.

---

## 🎯 STEP 13: Check API Key Status

```powershell
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "API Key"
```

**Expected:**
```
      API key ending with 8eb8: API Key valid
```

**✅ SUCCESS:** "API Key valid"  
**❌ PROBLEM:** "API Key invalid" (double-check your API key)

---

## 🌐 STEP 14: Open Datadog UI - Infrastructure

```powershell
Start-Process "https://us5.datadoghq.com/infrastructure"
```

**What to look for:**
1. 2 hosts visible: `sockshop-control-plane` and `sockshop-worker`
2. Click on a host → should see CPU, Memory, Network metrics
3. Look for tag: `kube_cluster_name:sockshop-kind`

---

## 🐳 STEP 15: Open Datadog UI - Containers

```powershell
Start-Process "https://us5.datadoghq.com/containers"
```

**What to do:**
1. Filter by: `kube_namespace:sock-shop`
2. Should see all sock-shop containers
3. Click on a container → should show metrics

---

## ☸️ STEP 16: Open Datadog UI - Kubernetes

```powershell
Start-Process "https://us5.datadoghq.com/orchestration/explorer"
```

**What to check:**
1. Cluster: `sockshop-kind` visible
2. Namespaces: sock-shop, monitoring, datadog
3. Pods, Deployments, Services all listed

---

## 📝 STEP 17: Open Datadog UI - Logs

```powershell
Start-Process "https://us5.datadoghq.com/logs"
```

**What to do:**
1. Time range: "Past 15 minutes"
2. Filter: `kube_namespace:sock-shop`
3. Should see logs from front-end, catalogue, user, carts, etc.

---

## 📈 STEP 18: Open Datadog UI - Metrics

```powershell
Start-Process "https://us5.datadoghq.com/metric/explorer"
```

**What to try:**
1. Search metric: `kubernetes.cpu.usage`
2. Filter: `kube_cluster_name:sockshop-kind`
3. Should see CPU usage graphs for all pods

---

## 🧪 STEP 19: Generate Traffic

```powershell
# Start port forward
Start-Process powershell -ArgumentList 'kubectl -n sock-shop port-forward svc/front-end 2025:80'

# Wait for it to start
Start-Sleep -Seconds 5

# Open sock shop
Start-Process "http://localhost:2025"
```

**Manual actions:**
1. Browse catalogue (click on 5+ socks)
2. Login: username=`user`, password=`password`
3. Add 3-4 items to cart
4. Checkout and complete an order
5. Repeat 2-3 times

---

## 🔍 STEP 20: Verify Increased Activity

```powershell
Start-Sleep -Seconds 60
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"
```

**Expected:**
```
      LogsProcessed: 1542    ← Should be HIGHER than Step 11
```

---

## ✅ STEP 21: Final Health Check

```powershell
Write-Host "`n=== DATADOG HEALTH CHECK ===" -ForegroundColor Cyan

Write-Host "`n1. Pods:" -ForegroundColor Yellow
kubectl -n datadog get pods | Select-Object -First 5

Write-Host "`n2. Logs:" -ForegroundColor Yellow
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "LogsProcessed"

Write-Host "`n3. API Key:" -ForegroundColor Yellow
kubectl -n datadog exec $POD -c agent -- agent status | Select-String -Pattern "API Key"

Write-Host "`n4. Metrics:" -ForegroundColor Yellow
kubectl -n datadog exec $POD -c process-agent -- agent status | Select-String -Pattern "Status:"

Write-Host "`n=== END ===" -ForegroundColor Cyan
```

**Expected:**
```
=== DATADOG HEALTH CHECK ===

1. Pods:
NAME                                    READY   STATUS
datadog-agent-xxxxx                     3/3     Running
datadog-agent-yyyyy                     3/3     Running
datadog-agent-cluster-agent-zzzzz       1/1     Running

2. Logs:
      LogsProcessed: 1847

3. API Key:
      API key ending with 8eb8: API Key valid

4. Metrics:
  Status: Running

=== END ===
```

---

## 🎉 Success Criteria

You're **FULLY SET UP** if you see:

- [x] All pods Running (3/3 and 1/1)
- [x] LogsProcessed > 0
- [x] API Key valid
- [x] Process Agent running
- [x] 2 hosts in Infrastructure view
- [x] Containers visible with metrics
- [x] Logs visible in Logs Explorer
- [x] Metrics searchable in Metrics Explorer

---

## 🆘 If Something Goes Wrong

**Problem: LogsProcessed = 0**
```powershell
kubectl -n datadog logs $POD -c agent --tail=100 | Select-String "error"
```

**Problem: API Key Invalid**
```powershell
# Check secret
kubectl -n datadog get secret datadog-secret -o jsonpath='{.data.api-key}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Should show your API key
# If wrong, delete and recreate:
kubectl -n datadog delete secret datadog-secret
kubectl -n datadog create secret generic datadog-secret --from-literal=api-key=$DD_API_KEY
kubectl -n datadog rollout restart daemonset datadog-agent
```

**Problem: Pods Not Starting**
```powershell
kubectl -n datadog describe pod $POD
```

---

## 📚 Reference

- **Setup Guide:** `DATADOG-METRICS-LOGS-SETUP.md`
- **Config File:** `datadog-values-metrics-logs.yaml`
- **Main Guide:** `COMPLETE-SETUP-GUIDE.md`

---

**START WITH STEP 1** and work through each step. Paste outputs if you encounter any issues!
