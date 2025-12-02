# ============================================================================
# INCIDENT-5C: Queue Blockage - MANUAL ACTIVATION (NO AUTO-RECOVERY)
# ============================================================================
# This script activates INCIDENT-5C and WAITS for manual recovery command
# Use incident-5c-recover-manual.ps1 to recover when ready
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  🚨 ACTIVATING INCIDENT-5C: QUEUE BLOCKAGE                 ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red

Write-Host "`n📋 Incident Details:" -ForegroundColor Cyan
Write-Host "   Type: Middleware queue blockage" -ForegroundColor White
Write-Host "   Cause: RabbitMQ queue at capacity (max 3 messages)" -ForegroundColor White
Write-Host "   Impact: Orders 1-3 succeed, orders 4+ fail" -ForegroundColor White
Write-Host "   Detection: Queue stuck at 3/3, visible errors" -ForegroundColor White

# Record start time
$START = Get-Date
$START_IST = $START.ToString("yyyy-MM-dd HH:mm:ss")
$START_UTC = $START.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "`n📅 INCIDENT START TIME:" -ForegroundColor Yellow
Write-Host "   IST: $START_IST" -ForegroundColor White
Write-Host "   UTC: $START_UTC" -ForegroundColor White

# Pre-incident health check
Write-Host "`n⏳ Step 1/4: Verifying system health..." -ForegroundColor Cyan

$shippingStatus = kubectl -n sock-shop get pods -l name=shipping --no-headers 2>&1
$queueMasterStatus = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
$rabbitmqStatus = kubectl -n sock-shop get pods -l name=rabbitmq --no-headers 2>&1

if ($shippingStatus -match "1/1.*Running") {
    Write-Host "   ✅ Shipping service: Running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Shipping service not healthy!" -ForegroundColor Red
    exit 1
}

if ($queueMasterStatus -match "1/1.*Running") {
    Write-Host "   ✅ Queue-master: Running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Queue-master not healthy!" -ForegroundColor Red
    exit 1
}

if ($rabbitmqStatus -match "2/2.*Running") {
    Write-Host "   ✅ RabbitMQ: Running (2/2 containers)" -ForegroundColor Green
} else {
    Write-Host "   ❌ RabbitMQ not healthy!" -ForegroundColor Red
    exit 1
}

# Step 2: Set queue policy via Management API
Write-Host "`n🚨 Step 2/4: Setting RabbitMQ queue capacity limit..." -ForegroundColor Red
Write-Host "   Action: max-length=3, overflow=reject-publish" -ForegroundColor White

$RABBITMQ_POD = kubectl -n sock-shop get pods -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}' 2>&1

$POLICY_RESULT = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest -X PUT `
    -H "Content-Type: application/json" `
    -d '{"pattern":"^shipping-task$","definition":{"max-length":3,"overflow":"reject-publish"},"apply-to":"queues"}' `
    http://localhost:15672/api/policies/%2F/shipping-limit 2>&1

if ($POLICY_RESULT -match "shipping-limit") {
    Write-Host "   ✅ Queue policy set successfully" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Policy result: $POLICY_RESULT" -ForegroundColor Yellow
}

# Verify policy
Start-Sleep -Seconds 2
$VERIFY_POLICY = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/policies 2>&1

if ($VERIFY_POLICY -match "shipping-limit") {
    Write-Host "   ✅ Policy verified active" -ForegroundColor Green
} else {
    Write-Host "   ❌ Policy verification failed!" -ForegroundColor Red
    exit 1
}

# Step 3: Scale down queue-master (consumer)
Write-Host "`n🚨 Step 3/4: Stopping queue consumer..." -ForegroundColor Red
kubectl -n sock-shop scale deployment queue-master --replicas=0 2>&1 | Out-Null

Start-Sleep -Seconds 3

$QM_PODS = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
if ($QM_PODS -match "No resources found") {
    Write-Host "   ✅ Queue-master scaled to 0" -ForegroundColor Green
    Write-Host "   ✅ Consumer is DOWN - queue will fill up" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Queue-master status: $QM_PODS" -ForegroundColor Yellow
}

# Step 4: Verify incident is active
Write-Host "`n📊 Step 4/4: Verifying incident state..." -ForegroundColor Cyan

$QUEUE_INFO = kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task 2>&1

if ($QUEUE_INFO -match '"consumers":0') {
    Write-Host "   ✅ Queue consumers: 0 (consumer down)" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Queue info: $QUEUE_INFO" -ForegroundColor Yellow
}

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ✅ INCIDENT-5C ACTIVATED SUCCESSFULLY!             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 CURRENT STATE:" -ForegroundColor Yellow
Write-Host "   ✅ Shipping service: RUNNING (publisher active)" -ForegroundColor Green
Write-Host "   ❌ Queue-master: SCALED TO 0 (consumer down)" -ForegroundColor Red
Write-Host "   ⚠️  Queue capacity: LIMITED TO 3 MESSAGES" -ForegroundColor Yellow
Write-Host "   ⚠️  Overflow policy: REJECT NEW MESSAGES" -ForegroundColor Yellow

Write-Host "`n🧪 TESTING THE INCIDENT:" -ForegroundColor Cyan
Write-Host "   1. Open Sock Shop UI: http://localhost:2025" -ForegroundColor White
Write-Host "   2. Login (username: user, password: password)" -ForegroundColor White
Write-Host "   3. Add items to cart" -ForegroundColor White
Write-Host "   4. Proceed to checkout" -ForegroundColor White
Write-Host "   5. Click 'Place Order' - REPEAT 7 TIMES" -ForegroundColor White

Write-Host "`n   Expected Results:" -ForegroundColor Cyan
Write-Host "   ✅ Orders 1-3: SUCCESS (queue fills to 3/3)" -ForegroundColor Green
Write-Host "   ❌ Orders 4-7: FAILURE (queue rejects, visible errors)" -ForegroundColor Red

Write-Host "`n📊 DATADOG OBSERVATIONS:" -ForegroundColor Cyan
Write-Host "   • Queue depth: 0 → 1 → 2 → 3 (stuck at 3)" -ForegroundColor White
Write-Host "   • Queue consumers: 0 (consumer down)" -ForegroundColor White
Write-Host "   • Shipping logs: 'Message rejected' for orders 4+" -ForegroundColor White
Write-Host "   • Orders logs: '503 Service Unavailable' errors" -ForegroundColor White

Write-Host "`n🔍 MONITORING COMMANDS:" -ForegroundColor Cyan
Write-Host "   • Watch queue depth:" -ForegroundColor White
Write-Host "     kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/queues/%2F/shipping-task | jq '.messages'" -ForegroundColor Gray
Write-Host "`n   • Watch shipping logs:" -ForegroundColor White
Write-Host "     kubectl -n sock-shop logs deployment/shipping -f" -ForegroundColor Gray
Write-Host "`n   • Check queue policy:" -ForegroundColor White
Write-Host "     kubectl -n sock-shop exec $RABBITMQ_POD -c rabbitmq -- curl -s -u guest:guest http://localhost:15672/api/policies" -ForegroundColor Gray

Write-Host "`n💊 TO RECOVER:" -ForegroundColor Yellow
Write-Host "   Run: .\incident-5c-recover-manual.ps1" -ForegroundColor White

Write-Host "`n⚠️  IMPORTANT: This incident will remain active until you run recovery!" -ForegroundColor Red
Write-Host "   Take your time to place orders and gather logs in Datadog." -ForegroundColor Yellow

Write-Host "`n✅ Incident is now ACTIVE and waiting for your recovery command!`n" -ForegroundColor Green

# Save start time for recovery script
$START_IST | Out-File -FilePath ".\incident-5c-start-time.txt" -Encoding UTF8
$START_UTC | Out-File -FilePath ".\incident-5c-start-time-utc.txt" -Encoding UTF8
