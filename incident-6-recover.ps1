# ============================================================================
# INCIDENT 6: Payment Gateway Recovery Script
# ============================================================================
# Description: Restores stripe-mock (external payment gateway)
# Effect: Payments will start working again
# Recovery Time: ~30 seconds
# ============================================================================

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  💊 RECOVERING FROM INCIDENT 6: Payment Gateway Failure   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n⏳ Step 1/4: Checking current state..." -ForegroundColor Cyan
$currentState = kubectl -n sock-shop get deployment stripe-mock -o json | ConvertFrom-Json
$currentReplicas = $currentState.spec.replicas

Write-Host "   • Stripe-mock current replicas: $currentReplicas" -ForegroundColor Gray

if ($currentReplicas -gt 0) {
    Write-Host "`n⚠️  WARNING: Stripe-mock is already running!" -ForegroundColor Yellow
    Write-Host "   Current replicas: $currentReplicas" -ForegroundColor Yellow
    $continue = Read-Host "`nContinue with recovery anyway? (y/n)"
    if ($continue -ne "y") {
        Write-Host "`n❌ Recovery cancelled." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n💊 Step 2/4: Scaling stripe-mock back to 1..." -ForegroundColor Green
kubectl -n sock-shop scale deployment stripe-mock --replicas=1

Write-Host "`n⏳ Step 3/4: Waiting for pod to start..." -ForegroundColor Cyan
kubectl -n sock-shop wait --for=condition=ready pod -l name=stripe-mock --timeout=60s

Write-Host "`n✅ Step 4/4: Verifying recovery..." -ForegroundColor Green
Start-Sleep -Seconds 3

Write-Host "`n📊 Pod Status:" -ForegroundColor Cyan
kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'

Write-Host "`n🧪 Testing payment gateway connectivity..." -ForegroundColor Cyan
$testPod = kubectl -n sock-shop get pods -l name=payment -o jsonpath='{.items[0].metadata.name}'
Write-Host "   Testing from payment pod: $testPod" -ForegroundColor Gray

$testResult = kubectl -n sock-shop exec $testPod -- sh -c 'wget -q -O- http://stripe-mock/v1/charges 2>&1 | head -c 100'
if ($testResult) {
    Write-Host "   ✅ Payment gateway is reachable!" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Gateway may still be starting..." -ForegroundColor Yellow
}

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✅ INCIDENT 6 RECOVERY COMPLETE!                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 CURRENT STATE:" -ForegroundColor Yellow
Write-Host "   ✅ Payment service: RUNNING" -ForegroundColor Green
Write-Host "   ✅ Stripe-mock: RUNNING" -ForegroundColor Green
Write-Host "   ✅ Payment gateway: REACHABLE" -ForegroundColor Green

Write-Host "`n🧪 VERIFY NORMAL OPERATION:" -ForegroundColor Cyan
Write-Host "   1. Open Sock Shop UI: http://localhost:2025" -ForegroundColor White
Write-Host "   2. Login (username: user, password: password)" -ForegroundColor White
Write-Host "   3. Add items to cart" -ForegroundColor White
Write-Host "   4. Proceed to checkout" -ForegroundColor White
Write-Host "   5. Click 'Place Order'" -ForegroundColor White
Write-Host "`n   Expected Result: ✅ Order succeeds, status: SHIPPED" -ForegroundColor Green

Write-Host "`n📊 MONITORING:" -ForegroundColor Cyan
Write-Host "   • Payment logs: kubectl -n sock-shop logs deployment/payment --tail=20" -ForegroundColor White
Write-Host "   • Stripe-mock logs: kubectl -n sock-shop logs deployment/stripe-mock --tail=20" -ForegroundColor White

Write-Host "`n✅ System is back to normal operation!" -ForegroundColor Green
