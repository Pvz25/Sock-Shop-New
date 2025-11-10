# INCIDENT-5C: Order Processing Stuck in Middleware Queue
# Queue Blockage with Visible Errors (Publisher Confirms Enabled)

param(
    [int]$DurationSeconds = 150  # 2.5 minutes (2 minutes 30 seconds)
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  INCIDENT-5C: MIDDLEWARE QUEUE BLOCKED" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Record start time
$START = Get-Date
$START_IST = $START.ToString("yyyy-MM-dd HH:mm:ss")
$START_UTC = $START.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "`nStart Time (IST): $START_IST" -ForegroundColor Yellow
Write-Host "Start Time (UTC): $START_UTC" -ForegroundColor Yellow

# Pre-incident check
Write-Host "`n[Pre-Check] Verifying system health..." -ForegroundColor Cyan
$shippingBefore = kubectl -n sock-shop get pods -l name=shipping --no-headers
$queueMasterBefore = kubectl -n sock-shop get pods -l name=queue-master --no-headers
$rabbitmqBefore = kubectl -n sock-shop get pods -l name=rabbitmq --no-headers

if ($shippingBefore -match "Running") {
    Write-Host "✅ Shipping service running: $($shippingBefore.Split()[0])" -ForegroundColor Green
} else {
    Write-Host "❌ Shipping service not running!" -ForegroundColor Red
    exit 1
}

if ($queueMasterBefore -match "Running") {
    Write-Host "✅ Queue-master running: $($queueMasterBefore.Split()[0])" -ForegroundColor Green
} else {
    Write-Host "❌ Queue-master not running!" -ForegroundColor Red
    exit 1
}

if ($rabbitmqBefore -match "Running") {
    Write-Host "✅ RabbitMQ running: $($rabbitmqBefore.Split()[0])" -ForegroundColor Green
} else {
    Write-Host "❌ RabbitMQ not running!" -ForegroundColor Red
    exit 1
}

# Step 1: Set Queue Policy (max-length = 3, reject overflow)
Write-Host "`n[Step 1] Configuring RabbitMQ queue policy..." -ForegroundColor Red
Write-Host "Action: Setting max-length=3 with overflow=reject-publish" -ForegroundColor White

kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl set_policy shipping-limit "^shipping-task$" '{"max-length":3,"overflow":"reject-publish"}' --apply-to queues 2>&1 | Out-Null

Start-Sleep -Seconds 2

# Verify policy was set
$policyCheck = kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl list_policies 2>&1 | Select-String "shipping-limit"

if ($policyCheck) {
    Write-Host "✅ Queue policy set successfully" -ForegroundColor Green
    Write-Host "   Policy: max-length=3, overflow=reject-publish" -ForegroundColor Gray
} else {
    Write-Host "⚠️ Warning: Could not verify policy" -ForegroundColor Yellow
}

# Step 2: Scale Down Consumer
Write-Host "`n[Step 2] Stopping queue consumer..." -ForegroundColor Red
Write-Host "Action: Scaling queue-master to 0 replicas" -ForegroundColor White

kubectl -n sock-shop scale deployment/queue-master --replicas=0 | Out-Null

Start-Sleep -Seconds 10

# Verify consumer is down
$queueMasterAfter = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
if ($queueMasterAfter -match "No resources found") {
    Write-Host "✅ Queue-master successfully scaled to 0" -ForegroundColor Green
    Write-Host "✅ Consumer is DOWN - queue will fill up" -ForegroundColor Green
} else {
    Write-Host "⚠️ Warning: Queue-master pods may still be terminating" -ForegroundColor Yellow
}

# Step 3: User Action Window
Write-Host "`n========================================" -ForegroundColor Red
Write-Host "  [Step 3] INCIDENT ACTIVE" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red

Write-Host "`n⚠️ QUEUE LIMITED TO 3 MESSAGES" -ForegroundColor Yellow
Write-Host "⚠️ ORDERS 4+ WILL FAIL WITH VISIBLE ERRORS" -ForegroundColor Yellow

Write-Host "`nInstructions:" -ForegroundColor Cyan
Write-Host "1. Open: http://localhost:2025" -ForegroundColor White
Write-Host "2. Login: user / password" -ForegroundColor White
Write-Host "3. Add items to cart" -ForegroundColor White
Write-Host "4. Proceed to checkout" -ForegroundColor White
Write-Host "5. Click 'Place Order'" -ForegroundColor White
Write-Host "6. Repeat until you see errors (place 5-7 orders)" -ForegroundColor White

Write-Host "`nExpected Behavior:" -ForegroundColor Yellow
Write-Host "  • Orders 1-3: SUCCESS ✅ (queue has space)" -ForegroundColor Green
Write-Host "  • Orders 4+: FAILURE ❌ (queue FULL, RabbitMQ rejects)" -ForegroundColor Red
Write-Host "  • You will see: 'Service unavailable' or 'Queue unavailable'" -ForegroundColor Red

Write-Host "`nDuration: $DurationSeconds seconds ($([Math]::Floor($DurationSeconds/60))m $($DurationSeconds%60)s)" -ForegroundColor Green
Write-Host "`nCountdown:" -ForegroundColor Gray

# Countdown timer
$remaining = $DurationSeconds
while ($remaining -gt 0) {
    $minutes = [Math]::Floor($remaining / 60)
    $seconds = $remaining % 60
    Write-Host "`r  Time remaining: $minutes min $seconds sec   " -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    $remaining--
}
Write-Host ""

# Step 4: Verify Queue and Errors
Write-Host "`n[Step 4] Analyzing incident results..." -ForegroundColor Cyan

Write-Host "`nChecking RabbitMQ queue depth..." -ForegroundColor Yellow
$queueDepth = kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl list_queues name messages 2>&1 | Select-String "shipping-task"

if ($queueDepth) {
    Write-Host "✅ Queue status:" -ForegroundColor Green
    Write-Host "   $queueDepth" -ForegroundColor Gray
} else {
    Write-Host "⚠️ Could not retrieve queue depth" -ForegroundColor Yellow
}

Write-Host "`nChecking shipping service logs for rejections..." -ForegroundColor Yellow
$shippingLogs = kubectl -n sock-shop logs deployment/shipping --tail=50 | Select-String "rejected|Queue unavailable|confirmed" -CaseInsensitive

if ($shippingLogs) {
    Write-Host "✅ Found shipping service activity:" -ForegroundColor Green
    $shippingLogs | Select-Object -Last 10 | ForEach-Object { 
        if ($_ -match "confirmed") {
            Write-Host "  [✅ ACK] $_" -ForegroundColor Green
        } else {
            Write-Host "  [❌ NACK] $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "⚠️ No shipping activity found (check if orders were placed)" -ForegroundColor Yellow
}

Write-Host "`nChecking orders service for errors..." -ForegroundColor Yellow
$ordersErrors = kubectl -n sock-shop logs deployment/orders --tail=50 | Select-String "503|Service unavailable|shipping" -CaseInsensitive | Select-Object -Last 10

if ($ordersErrors) {
    Write-Host "✅ Found orders service errors:" -ForegroundColor Green
    $ordersErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "⚠️ No errors in orders service" -ForegroundColor Yellow
}

# Step 5: Recovery
$INCIDENT_END = Get-Date
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  [Step 5] RECOVERING SYSTEM" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nStep 5a: Removing queue limit policy..." -ForegroundColor White
kubectl -n sock-shop exec deployment/rabbitmq -c rabbitmq -- rabbitmqctl clear_policy shipping-limit 2>&1 | Out-Null

Start-Sleep -Seconds 2

Write-Host "✅ Queue policy removed" -ForegroundColor Green

Write-Host "`nStep 5b: Restoring queue consumer..." -ForegroundColor White
kubectl -n sock-shop scale deployment/queue-master --replicas=1 | Out-Null

Write-Host "Waiting for queue-master pod to start..." -ForegroundColor Gray
$waitResult = kubectl -n sock-shop wait --for=condition=ready pod -l name=queue-master --timeout=60s 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Queue-master recovered successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️ Queue-master recovery taking longer than expected" -ForegroundColor Yellow
}

Start-Sleep -Seconds 5

# Check if backlog is being processed
Write-Host "`nVerifying backlog processing..." -ForegroundColor Cyan
$queueMasterLogs = kubectl -n sock-shop logs deployment/queue-master --tail=20 | Select-String "Received shipment"

if ($queueMasterLogs) {
    Write-Host "✅ Queue-master processing backlog:" -ForegroundColor Green
    $queueMasterLogs | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "⚠️ No processing activity yet (queue may have been empty)" -ForegroundColor Yellow
}

$RECOVERY = Get-Date
$RECOVERY_IST = $RECOVERY.ToString("yyyy-MM-dd HH:mm:ss")
$RECOVERY_UTC = $RECOVERY.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
$DURATION = (New-TimeSpan -Start $START -End $RECOVERY).TotalMinutes

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  ✅ INCIDENT-5C RECOVERED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nRecovery Time (IST): $RECOVERY_IST" -ForegroundColor Yellow
Write-Host "Recovery Time (UTC): $RECOVERY_UTC" -ForegroundColor Yellow
Write-Host "Total Duration: $([Math]::Round($DURATION, 2)) minutes" -ForegroundColor White

# Step 6: Post-Incident Health Check
Write-Host "`n[Step 6] Post-incident health check..." -ForegroundColor Cyan
$allPods = kubectl -n sock-shop get pods --no-headers
$runningCount = ($allPods | Where-Object { $_ -match "Running" }).Count
$totalCount = $allPods.Count

Write-Host "Running pods: $runningCount / $totalCount" -ForegroundColor White

if ($runningCount -eq $totalCount) {
    Write-Host "✅ All pods healthy" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some pods not running" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  INCIDENT-5C SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nIncident Timeline:" -ForegroundColor Yellow
Write-Host "  Start:    $START_IST IST ($START_UTC UTC)" -ForegroundColor White
Write-Host "  End:      $($INCIDENT_END.ToString('yyyy-MM-dd HH:mm:ss')) IST" -ForegroundColor White
Write-Host "  Recovery: $RECOVERY_IST IST ($RECOVERY_UTC UTC)" -ForegroundColor White
Write-Host "  Duration: $([Math]::Round($DURATION, 2)) minutes" -ForegroundColor White

Write-Host "`nIncident Configuration:" -ForegroundColor Yellow
Write-Host "  Queue Limit: 3 messages (max-length)" -ForegroundColor White
Write-Host "  Overflow Policy: reject-publish" -ForegroundColor White
Write-Host "  Consumer: Scaled to 0 (blocked)" -ForegroundColor White

Write-Host "`nExpected Results:" -ForegroundColor Yellow
Write-Host "  First 3 orders: Queued successfully ✅" -ForegroundColor Green
Write-Host "  Orders 4+: Rejected by queue ❌" -ForegroundColor Red
Write-Host "  User sees: 'Queue unavailable' errors ❌" -ForegroundColor Red

Write-Host "`nDatadog Analysis Time Range:" -ForegroundColor Yellow
Write-Host "  From: $START_UTC UTC" -ForegroundColor Green
Write-Host "  To:   $RECOVERY_UTC UTC" -ForegroundColor Green

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Open Datadog UI" -ForegroundColor White
Write-Host "2. Set time range: $START_UTC to $RECOVERY_UTC UTC" -ForegroundColor White
Write-Host "3. Run queries from INCIDENT-5C-DATADOG-VERIFICATION.md" -ForegroundColor White
Write-Host "4. Verify error logs and metrics" -ForegroundColor White

Write-Host "`nKey Datadog Queries:" -ForegroundColor Yellow
Write-Host "  • kube_namespace:sock-shop service:shipping 'rejected'" -ForegroundColor White
Write-Host "  • kube_namespace:sock-shop service:orders 503" -ForegroundColor White
Write-Host "  • rabbitmq.queue.messages{queue:shipping-task}" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  EXECUTION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
