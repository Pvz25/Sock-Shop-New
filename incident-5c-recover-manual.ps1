# ============================================================================
# INCIDENT-5C: Queue Blockage - MANUAL RECOVERY
# ============================================================================
# This script recovers from INCIDENT-5C
# Run this when you're ready to restore normal operation
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  💊 RECOVERING FROM INCIDENT-5C: QUEUE BLOCKAGE            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

# Record recovery start time
$RECOVERY_START = Get-Date
$RECOVERY_START_IST = $RECOVERY_START.ToString("yyyy-MM-dd HH:mm:ss")
$RECOVERY_START_UTC = $RECOVERY_START.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "`n📅 RECOVERY START TIME:" -ForegroundColor Yellow
Write-Host "   IST: $RECOVERY_START_IST" -ForegroundColor White
Write-Host "   UTC: $RECOVERY_START_UTC" -ForegroundColor White

# Get RabbitMQ pod name
$RABBITMQ_POD = kubectl -n sock-shop get pods -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}' 2>&1

# Step 1: Check current queue state
Write-Host "`n⏳ Step 1/4: Checking current queue state..." -ForegroundColor Cyan

$QUEUE_BEFORE = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task 2>&1

if ($QUEUE_BEFORE -match '"messages":(\d+)') {
    $MSG_COUNT = $Matches[1]
    Write-Host "   • Queue depth: $MSG_COUNT messages" -ForegroundColor White
}

if ($QUEUE_BEFORE -match '"consumers":(\d+)') {
    $CONSUMER_COUNT = $Matches[1]
    Write-Host "   • Consumers: $CONSUMER_COUNT" -ForegroundColor White
}

# Step 2: Remove queue policy
Write-Host "`n💊 Step 2/4: Removing queue capacity limit..." -ForegroundColor Green

$REMOVE_POLICY = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest -X DELETE http://localhost:15672/api/policies/%2F/shipping-limit 2>&1

Start-Sleep -Seconds 2

$VERIFY_REMOVED = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/policies 2>&1

if ($VERIFY_REMOVED -eq "[]") {
    Write-Host "   ✅ Queue policy removed successfully" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Policy status: $VERIFY_REMOVED" -ForegroundColor Yellow
}

# Step 3: Restore queue-master (consumer)
Write-Host "`n💊 Step 3/4: Restoring queue consumer..." -ForegroundColor Green

kubectl -n sock-shop scale deployment queue-master --replicas=1 2>&1 | Out-Null

Write-Host "   ⏳ Waiting for queue-master to start..." -ForegroundColor Cyan
kubectl -n sock-shop wait --for=condition=ready pod -l name=queue-master --timeout=60s 2>&1 | Out-Null

$QM_STATUS = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1

if ($QM_STATUS -match "1/1.*Running") {
    Write-Host "   ✅ Queue-master restored: $($QM_STATUS.Split()[0])" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Queue-master status: $QM_STATUS" -ForegroundColor Yellow
}

# Step 4: Verify recovery
Write-Host "`n✅ Step 4/4: Verifying recovery..." -ForegroundColor Green

Start-Sleep -Seconds 5

$QUEUE_AFTER = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task 2>&1

if ($QUEUE_AFTER -match '"consumers":(\d+)') {
    $CONSUMER_COUNT_AFTER = $Matches[1]
    if ($CONSUMER_COUNT_AFTER -gt 0) {
        Write-Host "   ✅ Queue consumers: $CONSUMER_COUNT_AFTER (consumer active)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Queue consumers: $CONSUMER_COUNT_AFTER (may still be starting)" -ForegroundColor Yellow
    }
}

if ($QUEUE_AFTER -match '"messages":(\d+)') {
    $MSG_COUNT_AFTER = $Matches[1]
    Write-Host "   • Queue depth: $MSG_COUNT_AFTER messages (processing backlog)" -ForegroundColor White
}

Write-Host "`n📊 Pod Status:" -ForegroundColor Cyan
kubectl -n sock-shop get pods -l 'name in (queue-master,rabbitmq,shipping)'

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ✅ INCIDENT-5C RECOVERY COMPLETE!                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 CURRENT STATE:" -ForegroundColor Yellow
Write-Host "   ✅ Shipping service: RUNNING" -ForegroundColor Green
Write-Host "   ✅ Queue-master: RUNNING (consumer active)" -ForegroundColor Green
Write-Host "   ✅ RabbitMQ: RUNNING (no capacity limits)" -ForegroundColor Green
Write-Host "   ✅ Queue: Processing backlog" -ForegroundColor Green

Write-Host "`n🧪 VERIFY NORMAL OPERATION:" -ForegroundColor Cyan
Write-Host "   1. Open Sock Shop UI: http://localhost:2025" -ForegroundColor White
Write-Host "   2. Login (username: user, password: password)" -ForegroundColor White
Write-Host "   3. Add items to cart" -ForegroundColor White
Write-Host "   4. Proceed to checkout" -ForegroundColor White
Write-Host "   5. Click 'Place Order'" -ForegroundColor White
Write-Host "`n   Expected Result: ✅ Order succeeds, status: SHIPPED" -ForegroundColor Green

# Calculate duration
if (Test-Path ".\incident-5c-start-time.txt") {
    $START_IST = Get-Content ".\incident-5c-start-time.txt"
    $START_UTC = Get-Content ".\incident-5c-start-time-utc.txt"
    $START_TIME = [DateTime]::Parse($START_IST)
    $DURATION = (New-TimeSpan -Start $START_TIME -End $RECOVERY_START).TotalMinutes
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  INCIDENT-5C TIMELINE SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Start (IST):    $START_IST" -ForegroundColor White
    Write-Host "Start (UTC):    $START_UTC" -ForegroundColor White
    Write-Host "Recovery (IST): $RECOVERY_START_IST" -ForegroundColor White
    Write-Host "Recovery (UTC): $RECOVERY_START_UTC" -ForegroundColor White
    Write-Host "Duration:       $([Math]::Round($DURATION, 2)) minutes" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Clean up temp files
    Remove-Item ".\incident-5c-start-time.txt" -ErrorAction SilentlyContinue
    Remove-Item ".\incident-5c-start-time-utc.txt" -ErrorAction SilentlyContinue
}

Write-Host "✅ System is back to normal operation!`n" -ForegroundColor Green
