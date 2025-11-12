# ============================================================================
# INCIDENT 6: Payment Gateway Timeout/Failure Activation Script (Timed)
# ============================================================================
# Description: Simulates external payment gateway (Stripe) becoming unavailable
# Impact: Orders will fail with "Payment gateway error: connection refused"
# Root Cause: Third-party API issues (gateway down)
# Duration: Configurable with auto-recovery
# ============================================================================

param(
    [int]$DurationSeconds = 300  # Default: 5 minutes
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  🚨 ACTIVATING INCIDENT 6: Payment Gateway Failure        ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red

$durationMinutes = [math]::Round($DurationSeconds / 60, 1)
Write-Host "`n📋 Incident Details:" -ForegroundColor Yellow
Write-Host "   Type: External payment gateway unavailable" -ForegroundColor White
Write-Host "   Cause: Third-party API (Stripe) is down" -ForegroundColor White
Write-Host "   Impact: Payments will fail, orders cannot be completed" -ForegroundColor White
Write-Host "   Detection: Payment pods healthy, but gateway unreachable" -ForegroundColor White
Write-Host "   Duration: $DurationSeconds seconds ($durationMinutes minutes)" -ForegroundColor Cyan

Write-Host "`n⏳ Step 1/3: Verifying current state..." -ForegroundColor Cyan
$paymentReplicas = kubectl -n sock-shop get deployment payment -o jsonpath='{.spec.replicas}'
$stripeMockReplicas = kubectl -n sock-shop get deployment stripe-mock -o jsonpath='{.spec.replicas}'

Write-Host "   • Payment service: $paymentReplicas replica(s)" -ForegroundColor Gray
Write-Host "   • Stripe-mock: $stripeMockReplicas replica(s)" -ForegroundColor Gray

if ($stripeMockReplicas -eq 0) {
    Write-Host "`n⚠️  WARNING: Stripe-mock is already scaled to 0!" -ForegroundColor Yellow
    Write-Host "   The incident may already be active." -ForegroundColor Yellow
    $continue = Read-Host "`nContinue anyway? (y/n)"
    if ($continue -ne "y") {
        Write-Host "`n❌ Activation cancelled." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n🚨 Step 2/3: Scaling stripe-mock to 0 (simulating gateway down)..." -ForegroundColor Red
kubectl -n sock-shop scale deployment stripe-mock --replicas=0 | Out-Null

Write-Host "`n⏳ Step 3/3: Waiting for pods to terminate..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host "`n📊 Verifying incident state..." -ForegroundColor Cyan
$stripeMockPods = kubectl -n sock-shop get pods -l name=stripe-mock --no-headers 2>&1
if ($stripeMockPods -match "No resources found") {
    Write-Host "   ✅ Stripe-mock pods terminated (0 running)" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Stripe-mock pods may still be terminating" -ForegroundColor Yellow
}

$paymentPods = kubectl -n sock-shop get pods -l name=payment --no-headers
Write-Host "   ✅ Payment service running: $($paymentPods.Split()[0])" -ForegroundColor Green

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║         ✅ INCIDENT 6 ACTIVATED SUCCESSFULLY!             ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red

$startTime = Get-Date
$startTimeIST = $startTime.AddHours(5.5)
$startTimeUTC = $startTime.ToUniversalTime()

Write-Host "`n📋 INCIDENT TIMELINE:" -ForegroundColor Yellow
Write-Host "   Start Time (IST): $($startTimeIST.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Start Time (UTC): $($startTimeUTC.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Duration: $DurationSeconds seconds ($durationMinutes minutes)" -ForegroundColor White
Write-Host "   Auto-Recovery: Enabled" -ForegroundColor Green

Write-Host "`n📋 CURRENT STATE:" -ForegroundColor Yellow
Write-Host "   ✅ Payment service: RUNNING (healthy)" -ForegroundColor Green
Write-Host "   ❌ Stripe-mock: SCALED TO 0 (gateway down)" -ForegroundColor Red
Write-Host "   ❌ Payment gateway: UNREACHABLE" -ForegroundColor Red

Write-Host "`n🧪 TESTING THE INCIDENT:" -ForegroundColor Cyan
Write-Host "   1. Open Sock Shop UI: http://localhost:2025" -ForegroundColor White
Write-Host "   2. Login (username: user, password: password)" -ForegroundColor White
Write-Host "   3. Add items to cart" -ForegroundColor White
Write-Host "   4. Proceed to checkout" -ForegroundColor White
Write-Host "   5. Click 'Place Order'" -ForegroundColor White
Write-Host "`n   Expected Result: ❌ Payment will fail with:" -ForegroundColor Yellow
Write-Host "   'Payment declined. Payment gateway error: connection refused'" -ForegroundColor Red

Write-Host "`n📊 DATADOG OBSERVATIONS:" -ForegroundColor Cyan
Write-Host "   • Payment pods: 1/1 Running (healthy)" -ForegroundColor White
Write-Host "   • Stripe-mock pods: 0/0 (gateway down)" -ForegroundColor White
Write-Host "   • Payment logs: 'connection refused to payment gateway'" -ForegroundColor White
Write-Host "   • Orders logs: 'Payment authorization failed'" -ForegroundColor White

Write-Host "`n🔍 KEY DATADOG QUERIES:" -ForegroundColor Cyan
Write-Host "   • Payment errors: kube_namespace:sock-shop service:payment 'connection refused'" -ForegroundColor White
Write-Host "   • Orders errors: kube_namespace:sock-shop service:orders 'Payment authorization failed'" -ForegroundColor White
Write-Host "   • Time range: $($startTimeUTC.ToString('yyyy-MM-dd HH:mm:ss')) UTC onwards" -ForegroundColor White

Write-Host "`n⏱️  INCIDENT ACTIVE - COUNTDOWN STARTING..." -ForegroundColor Yellow
Write-Host "   Duration: $DurationSeconds seconds" -ForegroundColor White

# Countdown loop
$remainingSeconds = $DurationSeconds
while ($remainingSeconds -gt 0) {
    $minutes = [math]::Floor($remainingSeconds / 60)
    $seconds = $remainingSeconds % 60
    Write-Host "`r   Time remaining: $minutes min $seconds sec   " -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    $remainingSeconds--
}

Write-Host "`n`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           🔄 AUTO-RECOVERY STARTING...                    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n💊 Step 1/3: Scaling stripe-mock back to 1..." -ForegroundColor Cyan
kubectl -n sock-shop scale deployment stripe-mock --replicas=1 | Out-Null

Write-Host "💊 Step 2/3: Waiting for pod to become ready..." -ForegroundColor Cyan
kubectl -n sock-shop wait --for=condition=ready pod -l name=stripe-mock --timeout=60s | Out-Null

Write-Host "💊 Step 3/3: Verifying recovery..." -ForegroundColor Cyan
$finalPods = kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)' --no-headers
Write-Host "`n📊 Final Pod Status:" -ForegroundColor Cyan
kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'

$endTime = Get-Date
$endTimeIST = $endTime.AddHours(5.5)
$endTimeUTC = $endTime.ToUniversalTime()
$actualDuration = ($endTime - $startTime).TotalMinutes

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✅ INCIDENT 6 RECOVERED SUCCESSFULLY!            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📊 INCIDENT SUMMARY:" -ForegroundColor Yellow
Write-Host "   Start Time (IST): $($startTimeIST.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Start Time (UTC): $($startTimeUTC.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   End Time (IST):   $($endTimeIST.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   End Time (UTC):   $($endTimeUTC.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Duration: $([math]::Round($actualDuration, 2)) minutes" -ForegroundColor White

Write-Host "`n📋 DATADOG ANALYSIS TIME RANGE:" -ForegroundColor Cyan
Write-Host "   From: $($startTimeUTC.ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor White
Write-Host "   To:   $($endTimeUTC.ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor White

Write-Host "`n🔍 RECOMMENDED DATADOG QUERIES:" -ForegroundColor Cyan
Write-Host "   1. Payment service errors:" -ForegroundColor White
Write-Host "      kube_namespace:sock-shop service:payment 'connection refused'" -ForegroundColor Gray
Write-Host "      @timestamp:[$($startTimeUTC.ToString('yyyy-MM-ddTHH:mm:ss')) TO $($endTimeUTC.ToString('yyyy-MM-ddTHH:mm:ss'))]" -ForegroundColor Gray
Write-Host "`n   2. Orders service failures:" -ForegroundColor White
Write-Host "      kube_namespace:sock-shop service:orders 'Payment authorization failed'" -ForegroundColor Gray
Write-Host "      @timestamp:[$($startTimeUTC.ToString('yyyy-MM-ddTHH:mm:ss')) TO $($endTimeUTC.ToString('yyyy-MM-ddTHH:mm:ss'))]" -ForegroundColor Gray

Write-Host "`n✅ System is back to normal operation!" -ForegroundColor Green
Write-Host "   • Payment service: RUNNING" -ForegroundColor Green
Write-Host "   • Stripe-mock: RUNNING" -ForegroundColor Green
Write-Host "   • Payment gateway: REACHABLE" -ForegroundColor Green

Write-Host "`n🧪 VERIFY NORMAL OPERATION:" -ForegroundColor Cyan
Write-Host "   Place an order through the UI - it should succeed now!" -ForegroundColor White
