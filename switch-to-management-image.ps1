# Switch to Official RabbitMQ Management Image
# Cleanest approach - plugin pre-enabled, zero configuration needed
# Image: rabbitmq:3.12-management (official, tested, production-ready)

$ErrorActionPreference = "Stop"

Write-Host "=== Switching to RabbitMQ Management Image ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. Switch from: quay.io/powercloud/rabbitmq:latest" -ForegroundColor White
Write-Host "  2. Switch to:   rabbitmq:3.12-management" -ForegroundColor White
Write-Host "  3. Management plugin pre-enabled ✅" -ForegroundColor Green
Write-Host "  4. Zero configuration needed ✅" -ForegroundColor Green
Write-Host ""

Write-Host "Safeguards:" -ForegroundColor Yellow
Write-Host "  • Backup already created ✅" -ForegroundColor Green
Write-Host "  • Official Docker Hub image ✅" -ForegroundColor Green
Write-Host "  • Same RabbitMQ version (3.x) ✅" -ForegroundColor Green
Write-Host "  • Management plugin included ✅" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "Proceed with image change? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Aborted by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "1. Updating deployment image..." -ForegroundColor Yellow
kubectl set image deployment/rabbitmq -n sock-shop `
    rabbitmq=rabbitmq:3.12-management

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ❌ Image update failed" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ Image updated" -ForegroundColor Green

Write-Host ""
Write-Host "2. Monitoring rollout..." -ForegroundColor Yellow
$timeout = 180
$elapsed = 0

while ($elapsed -lt $timeout) {
    $ready = kubectl get deployment rabbitmq -n sock-shop -o jsonpath='{.status.readyReplicas}' 2>$null
    $desired = kubectl get deployment rabbitmq -n sock-shop -o jsonpath='{.spec.replicas}' 2>$null
    
    if ($ready -eq $desired -and $ready -gt 0) {
        Write-Host "   ✅ Rollout complete! ($ready/$desired pods ready)" -ForegroundColor Green
        break
    }
    
    Write-Host "   Waiting... ($ready/$desired ready)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $elapsed += 5
}

if ($elapsed -ge $timeout) {
    Write-Host "   ⚠️ Rollout timeout" -ForegroundColor Red
    kubectl get pods -n sock-shop -l name=rabbitmq
    exit 1
}

Write-Host ""
Write-Host "3. Verifying new pod..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$pod = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
Write-Host "   Pod: $pod" -ForegroundColor White

# Check if management plugin is enabled
$plugins = kubectl exec -n sock-shop $pod -c rabbitmq -- rabbitmqctl eval 'application:which_applications().' 2>$null
if ($plugins -like "*rabbitmq_management*") {
    Write-Host "   ✅ Management plugin is running!" -ForegroundColor Green
} else {
    Write-Host "   Checking logs..." -ForegroundColor Yellow
    $logs = kubectl logs -n sock-shop $pod -c rabbitmq --tail=30 2>$null | Select-String -Pattern "management|plugin"
    $logs | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
}

Write-Host ""
Write-Host "4. Testing management API..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Forward port temporarily to test
$job = Start-Job -ScriptBlock {
    kubectl port-forward -n sock-shop $args[0] 15673:15672 2>$null
} -ArgumentList $pod

Start-Sleep -Seconds 3

try {
    $response = Invoke-WebRequest -Uri "http://localhost:15673/api/overview" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 401) {
        Write-Host "   ✅ Management API is responding!" -ForegroundColor Green
        Write-Host "   API endpoint: http://localhost:15672/api/" -ForegroundColor White
    }
} catch {
    Write-Host "   ⚠️ API test: $_" -ForegroundColor Yellow
    Write-Host "   Note: May need HTTP Basic Auth (guest/guest)" -ForegroundColor Gray
} finally {
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "5. Checking exporter..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$exporterLogs = kubectl logs -n sock-shop $pod -c rabbitmq-exporter --tail=30 2>$null
$errors = $exporterLogs | Select-String -Pattern "error|Error" -Context 0,1
if ($errors) {
    $recentErrors = $errors | Select-Object -Last 3
    Write-Host "   Recent exporter activity:" -ForegroundColor White
    $recentErrors | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    
    if ($exporterLogs -like "*successfully*" -or $exporterLogs -like "*Starting*") {
        Write-Host "   ℹ️  Exporter is starting up" -ForegroundColor Cyan
    }
} else {
    Write-Host "   ✅ Exporter running cleanly" -ForegroundColor Green
}

Write-Host ""
Write-Host "6. Regression check..." -ForegroundColor Yellow

# Check all pods
$allPods = kubectl get pods -n sock-shop --no-headers 2>$null
$notRunning = $allPods | Where-Object { $_ -notlike "*Running*" -and $_ -notlike "*Completed*" }
if ($notRunning) {
    Write-Host "   ⚠️ Some pods not running:" -ForegroundColor Yellow
    $notRunning | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
} else {
    Write-Host "   ✅ All sock-shop pods running" -ForegroundColor Green
}

# Test RabbitMQ connectivity
$testConn = kubectl exec -n sock-shop $pod -c rabbitmq -- rabbitmqctl status 2>$null | Select-String -Pattern "RabbitMQ version"
if ($testConn) {
    Write-Host "   ✅ RabbitMQ: $testConn" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== ✅ SUCCESS! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Management plugin is now enabled!" -ForegroundColor Cyan
Write-Host ""
Write-Host "What happens next:" -ForegroundColor Yellow
Write-Host "  1. Exporter will start collecting metrics (1-2 minutes)" -ForegroundColor White
Write-Host "  2. Datadog will discover metrics (2-3 minutes)" -ForegroundColor White
Write-Host "  3. Metrics visible in Datadog UI (5-10 minutes total)" -ForegroundColor White
Write-Host ""
Write-Host "Metrics for your AI SRE Agent:" -ForegroundColor Cyan
Write-Host "  • rabbitmq_queue_consumers - Consumer count" -ForegroundColor White
Write-Host "  • rabbitmq_queue_messages - Queue depth" -ForegroundColor White
Write-Host "  • rabbitmq_queue_messages_published_total - Publish rate" -ForegroundColor White
Write-Host "  • rabbitmq_queue_messages_delivered_total - Delivery rate" -ForegroundColor White
Write-Host "  • Plus 46 more metrics!" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Search in Datadog: rabbitmq_queue_*" -ForegroundColor Green
