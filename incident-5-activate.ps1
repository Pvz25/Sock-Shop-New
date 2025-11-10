# INCIDENT-5: Async Processing Failure (Queue Consumer Unavailable)
# Root Cause: queue-master deployment scaled to 0 replicas
# Impact: Orders complete successfully but shipments never processed (silent failure)

param(
    [int]$DurationMinutes = 3  # Default: 3 minutes
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  INCIDENT-5: ASYNC PROCESSING FAILURE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Record start time
$START = Get-Date
$START_IST = $START.ToString("yyyy-MM-dd HH:mm:ss")
$START_UTC = $START.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "`nStart Time (IST): $START_IST" -ForegroundColor Yellow
Write-Host "Start Time (UTC): $START_UTC" -ForegroundColor Yellow

# Pre-incident check
Write-Host "`n[Pre-Check] Verifying system health..." -ForegroundColor Cyan

$queueMasterBefore = kubectl -n sock-shop get deployment queue-master --no-headers
if ($queueMasterBefore -match "1/1") {
    Write-Host "✅ queue-master running: 1/1 replicas ready" -ForegroundColor Green
} else {
    Write-Host "❌ queue-master not healthy: $queueMasterBefore" -ForegroundColor Red
    Write-Host "Cannot proceed with incident. Fix the deployment first." -ForegroundColor Red
    exit 1
}

# Check RabbitMQ
$rabbitmqStatus = kubectl -n sock-shop get pods -l name=rabbitmq --no-headers
if ($rabbitmqStatus -match "Running") {
    Write-Host "✅ RabbitMQ running" -ForegroundColor Green
} else {
    Write-Host "❌ RabbitMQ not running!" -ForegroundColor Red
    exit 1
}

# Trigger Incident
Write-Host "`n========================================" -ForegroundColor Red
Write-Host "  [INCIDENT START] SCALING DOWN CONSUMER" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

Write-Host "`nAction: Scaling queue-master to 0 replicas..." -ForegroundColor Red
kubectl -n sock-shop scale deployment/queue-master --replicas=0 | Out-Null

Start-Sleep -Seconds 10

# Verify incident
$queueMasterAfter = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
if ($queueMasterAfter -match "No resources found") {
    Write-Host "✅ Incident triggered successfully" -ForegroundColor Green
    Write-Host "✅ queue-master scaled to 0 (consumer DOWN)" -ForegroundColor Green
} else {
    Write-Host "⚠️ Warning: Pods may still be terminating..." -ForegroundColor Yellow
    Write-Host "   Status: $queueMasterAfter" -ForegroundColor Gray
}

# Record trigger time
$TRIGGER = Get-Date
$TRIGGER_IST = $TRIGGER.ToString("yyyy-MM-dd HH:mm:ss")
$TRIGGER_UTC = $TRIGGER.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  INCIDENT ACTIVE - SILENT FAILURE MODE" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "`nINCIDENT-5 Characteristics:" -ForegroundColor Cyan
Write-Host "  • Type: Silent Failure (Asynchronous Processing)" -ForegroundColor White
Write-Host "  • Root Cause: Queue consumer (queue-master) scaled to 0" -ForegroundColor White
Write-Host "  • User Impact: Orders appear successful but shipments never processed" -ForegroundColor White
Write-Host "  • Detection: No user-facing errors (HTTP 200 OK)" -ForegroundColor White

Write-Host "`nWhat's Happening:" -ForegroundColor Yellow
Write-Host "  ✅ Orders service: RUNNING (users can place orders)" -ForegroundColor Green
Write-Host "  ✅ Payment service: RUNNING (payments processed)" -ForegroundColor Green
Write-Host "  ✅ Shipping service: RUNNING (publishes to queue)" -ForegroundColor Green
Write-Host "  ❌ Queue-master: DOWN (messages accumulate, never processed)" -ForegroundColor Red
Write-Host "  ⚠️  RabbitMQ queue: FILLING UP (messages piling up)" -ForegroundColor Yellow

Write-Host "`nExpected Behavior:" -ForegroundColor Cyan
Write-Host "  1. User places order → SUCCESS ✅" -ForegroundColor White
Write-Host "  2. Payment processed → SUCCESS ✅" -ForegroundColor White
Write-Host "  3. Order marked PAID → SUCCESS ✅" -ForegroundColor White
Write-Host "  4. Shipping message published → SUCCESS ✅" -ForegroundColor White
Write-Host "  5. Message sits in queue → NEVER PROCESSED ❌" -ForegroundColor White
Write-Host "  6. Shipment never created → SILENT FAILURE ❌" -ForegroundColor White

Write-Host "`nTesting Instructions:" -ForegroundColor Yellow
Write-Host "1. Open: http://localhost:2025" -ForegroundColor White
Write-Host "2. Login: user / password" -ForegroundColor White
Write-Host "3. Add items to cart" -ForegroundColor White
Write-Host "4. Complete checkout and place order" -ForegroundColor White
Write-Host "5. Observe: Order shows 'SUCCESS' but shipment never processed" -ForegroundColor White
Write-Host "6. Place 3-5 orders to build up queue backlog" -ForegroundColor White

Write-Host "`nDatadog Observability Checks:" -ForegroundColor Yellow
Write-Host "  • Check 1: Queue-master logs disappear after $TRIGGER_IST" -ForegroundColor White
Write-Host "  • Check 2: RabbitMQ queue depth increasing" -ForegroundColor White
Write-Host "  • Check 3: RabbitMQ consumer count = 0" -ForegroundColor White
Write-Host "  • Check 4: kubernetes_state.deployment.replicas_available (queue-master) = 0" -ForegroundColor White
Write-Host "  • Check 5: Orders service logs show success, but no shipment processing" -ForegroundColor White

Write-Host "`nDuration: $DurationMinutes minutes" -ForegroundColor Green
Write-Host "Countdown:" -ForegroundColor Gray

# Countdown timer
$remainingSeconds = $DurationMinutes * 60
while ($remainingSeconds -gt 0) {
    $minutes = [Math]::Floor($remainingSeconds / 60)
    $seconds = $remainingSeconds % 60
    Write-Host "`r  Time remaining: $minutes min $seconds sec   " -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    $remainingSeconds--
}
Write-Host ""

# Recovery
$INCIDENT_END = Get-Date
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  [RECOVERY] RESTORING CONSUMER" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nAction: Scaling queue-master back to 1 replica..." -ForegroundColor White
kubectl -n sock-shop scale deployment/queue-master --replicas=1 | Out-Null

Write-Host "Waiting for queue-master pod to start..." -ForegroundColor Gray
$waitResult = kubectl -n sock-shop wait --for=condition=ready pod -l name=queue-master --timeout=60s 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ queue-master recovered successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️ Recovery taking longer than expected" -ForegroundColor Yellow
}

Start-Sleep -Seconds 5

# Verify backlog processing
Write-Host "`nVerifying backlog processing..." -ForegroundColor Cyan
$queueMasterLogs = kubectl -n sock-shop logs deployment/queue-master --tail=20 | Select-String "Received shipment"

if ($queueMasterLogs) {
    Write-Host "✅ Queue-master processing backlog:" -ForegroundColor Green
    $queueMasterLogs | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "⚠️ No processing activity yet (queue may be empty)" -ForegroundColor Yellow
}

$RECOVERY = Get-Date
$RECOVERY_IST = $RECOVERY.ToString("yyyy-MM-dd HH:mm:ss")
$RECOVERY_UTC = $RECOVERY.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
$DURATION = (New-TimeSpan -Start $START -End $RECOVERY).TotalMinutes

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  ✅ INCIDENT-5 RECOVERED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nRecovery Time (IST): $RECOVERY_IST" -ForegroundColor Yellow
Write-Host "Recovery Time (UTC): $RECOVERY_UTC" -ForegroundColor Yellow
Write-Host "Total Duration: $([Math]::Round($DURATION, 2)) minutes" -ForegroundColor White

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  INCIDENT-5 SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nIncident Timeline:" -ForegroundColor Yellow
Write-Host "  Start:    $START_IST IST ($START_UTC UTC)" -ForegroundColor White
Write-Host "  Trigger:  $TRIGGER_IST IST ($TRIGGER_UTC UTC)" -ForegroundColor White
Write-Host "  End:      $($INCIDENT_END.ToString('yyyy-MM-dd HH:mm:ss')) IST" -ForegroundColor White
Write-Host "  Recovery: $RECOVERY_IST IST ($RECOVERY_UTC UTC)" -ForegroundColor White
Write-Host "  Duration: $([Math]::Round($DURATION, 2)) minutes" -ForegroundColor White

Write-Host "`nDatadog Analysis Time Range:" -ForegroundColor Yellow
Write-Host "  From: $TRIGGER_UTC UTC" -ForegroundColor Green
Write-Host "  To:   $RECOVERY_UTC UTC" -ForegroundColor Green

Write-Host "`nKey Datadog Queries:" -ForegroundColor Yellow
Write-Host "  Logs:" -ForegroundColor Cyan
Write-Host "    • kube_namespace:sock-shop service:queue-master" -ForegroundColor White
Write-Host "    • kube_namespace:sock-shop service:shipping" -ForegroundColor White
Write-Host "    • kube_namespace:sock-shop service:orders" -ForegroundColor White
Write-Host "  Metrics:" -ForegroundColor Cyan
Write-Host "    • kubernetes_state.deployment.replicas_available{kube_deployment:queue-master}" -ForegroundColor White
Write-Host "    • rabbitmq.queue.messages{queue:shipping-task}" -ForegroundColor White
Write-Host "    • rabbitmq.queue.consumers{queue:shipping-task}" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Open Datadog UI: https://app.datadoghq.com/logs" -ForegroundColor White
Write-Host "2. Set time range: $TRIGGER_UTC to $RECOVERY_UTC UTC" -ForegroundColor White
Write-Host "3. Review DATADOG-VERIFICATION-INCIDENT-5.md for detailed analysis" -ForegroundColor White
Write-Host "4. Verify queue backlog was processed after recovery" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  EXECUTION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
