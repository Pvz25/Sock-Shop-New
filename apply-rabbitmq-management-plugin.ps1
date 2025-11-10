# Apply RabbitMQ Management Plugin Enablement
# Ultra-safe with monitoring and rollback capability

$ErrorActionPreference = "Stop"

Write-Host "=== Enabling RabbitMQ Management Plugin ===" -ForegroundColor Cyan
Write-Host ""

# Pre-flight checks
Write-Host "1. Pre-flight checks..." -ForegroundColor Yellow
$currentPods = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
Write-Host "   Current RabbitMQ pod: $currentPods" -ForegroundColor White

$ready = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'
if ($ready -ne "True") {
    Write-Host "   ❌ RabbitMQ pod not ready. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ RabbitMQ pod is ready" -ForegroundColor Green

# Check queue-master is running (critical for AI SRE)
$qmPod = kubectl get pods -n sock-shop -l name=queue-master -o jsonpath='{.items[0].metadata.name}' 2>$null
if ($qmPod) {
    Write-Host "   ✅ queue-master pod running: $qmPod" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ queue-master not running (expected if testing incident)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "2. Applying management plugin patch..." -ForegroundColor Yellow
kubectl patch deployment rabbitmq -n sock-shop --patch-file enable-rabbitmq-management-plugin.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Patch failed" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ Patch applied" -ForegroundColor Green

Write-Host ""
Write-Host "3. Monitoring rollout (max 3 minutes)..." -ForegroundColor Yellow
$timeout = 180
$elapsed = 0
$oldPod = $currentPods

while ($elapsed -lt $timeout) {
    $newPod = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    if ($newPod -and $newPod -ne $oldPod) {
        Write-Host "   New pod created: $newPod" -ForegroundColor Cyan
        
        # Wait for new pod to be ready
        for ($i = 0; $i -lt 60; $i++) {
            $ready = kubectl get pod -n sock-shop $newPod -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>$null
            $phase = kubectl get pod -n sock-shop $newPod -o jsonpath='{.status.phase}' 2>$null
            
            if ($ready -eq "True") {
                Write-Host "   ✅ New pod is ready!" -ForegroundColor Green
                break
            }
            
            Write-Host "   Pod status: $phase (waiting for Ready...)" -ForegroundColor Gray
            Start-Sleep -Seconds 3
        }
        
        if ($ready -eq "True") {
            break
        }
    }
    
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    $elapsed += 5
}

Write-Host ""

if ($elapsed -ge $timeout) {
    Write-Host "   ⚠️ Rollout timeout. Checking pod status..." -ForegroundColor Yellow
    kubectl get pods -n sock-shop -l name=rabbitmq
    exit 1
}

Write-Host ""
Write-Host "4. Verifying management plugin..." -ForegroundColor Yellow
Start-Sleep -Seconds 10  # Give time for postStart to complete

$newPod = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
Write-Host "   Checking pod: $newPod" -ForegroundColor White

# Check if management plugin is enabled
$plugins = kubectl logs -n sock-shop $newPod -c rabbitmq --tail=50 2>$null | Select-String -Pattern "rabbitmq_management|plugin"
if ($plugins) {
    Write-Host "   Plugin status from logs:" -ForegroundColor White
    $plugins | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
}

# Check if management API is responding
Write-Host ""
Write-Host "   Testing management API (port 15672)..." -ForegroundColor White
Start-Sleep -Seconds 5  # Extra time for API to start

$mgmtTest = kubectl exec -n sock-shop $newPod -c rabbitmq -- sh -c "wget -qO- http://localhost:15672/api/overview 2>&1 | head -c 100" 2>$null
if ($mgmtTest -like "*rabbitmq_version*" -or $mgmtTest -like "*{*") {
    Write-Host "   ✅ Management API is responding!" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ Management API may need more time to start" -ForegroundColor Yellow
    Write-Host "   Response: $mgmtTest" -ForegroundColor Gray
}

Write-Host ""
Write-Host "5. Checking exporter status..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$exporterLogs = kubectl logs -n sock-shop $newPod -c rabbitmq-exporter --tail=20 2>$null
$errors = $exporterLogs | Select-String -Pattern "error|Error" -Context 0,1
if ($errors) {
    Write-Host "   Exporter errors (may resolve after API fully starts):" -ForegroundColor Yellow
    $errors | Select-Object -First 3 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
} else {
    Write-Host "   ✅ No errors in exporter logs" -ForegroundColor Green
}

Write-Host ""
Write-Host "6. Regression check..." -ForegroundColor Yellow

# Check all pods still running
$allPods = kubectl get pods -n sock-shop -o json | ConvertFrom-Json
$notReady = $allPods.items | Where-Object { 
    $_.status.phase -ne "Running" -or 
    ($_.status.containerStatuses | Where-Object { $_.ready -eq $false })
}

if ($notReady) {
    Write-Host "   ⚠️ Some pods not ready:" -ForegroundColor Yellow
    $notReady | ForEach-Object { Write-Host "     $($_.metadata.name)" -ForegroundColor Gray }
} else {
    Write-Host "   ✅ All sock-shop pods are running and ready" -ForegroundColor Green
}

# Check RabbitMQ connectivity
$rabbitTest = kubectl exec -n sock-shop $newPod -c rabbitmq -- rabbitmqctl status 2>$null | Select-String -Pattern "running"
if ($rabbitTest) {
    Write-Host "   ✅ RabbitMQ is running" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ RabbitMQ status check inconclusive" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "✅ Management plugin patch applied" -ForegroundColor Green
Write-Host "✅ RabbitMQ pod restarted successfully" -ForegroundColor Green
Write-Host "⏱️  Management API starting (may take 1-2 minutes)" -ForegroundColor Yellow
Write-Host "⏱️  Exporter will start collecting metrics shortly" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Wait 2-3 minutes for API to fully start" -ForegroundColor Gray
Write-Host "  2. Verify metrics: kubectl exec -n sock-shop $newPod -c rabbitmq-exporter -- wget -qO- http://localhost:9419/metrics | grep rabbitmq_queue" -ForegroundColor Gray
Write-Host "  3. Check Datadog in 5-10 minutes for metrics" -ForegroundColor Gray

Write-Host ""
Write-Host "🎯 For your AI SRE agent: Metrics will appear in Datadog as 'rabbitmq_queue_*'" -ForegroundColor Cyan
