# ============================================================================
# INCIDENT 6: Payment Gateway Timeout/Failure Activation Script
# ============================================================================
# Description: Simulates external payment gateway (Stripe) becoming unavailable
# Impact: Orders will fail with "Payment gateway error: connection refused"
# Root Cause: Third-party API issues (gateway down)
# ============================================================================

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  🚨 ACTIVATING INCIDENT 6: Payment Gateway Failure        ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red

Write-Host "`n📋 Incident Details:" -ForegroundColor Yellow
Write-Host "   Type: External payment gateway unavailable" -ForegroundColor White
Write-Host "   Cause: Third-party API (Stripe) is down" -ForegroundColor White
Write-Host "   Impact: Payments will fail, orders cannot be completed" -ForegroundColor White
Write-Host "   Detection: Payment pods healthy, but gateway unreachable" -ForegroundColor White

Write-Host "`n⏳ Step 1/3: Verifying current state..." -ForegroundColor Cyan
$currentState = kubectl -n sock-shop get deployment payment,stripe-mock -o json | ConvertFrom-Json

$paymentReplicas = $currentState.items | Where-Object { $_.metadata.name -eq "payment" } | Select-Object -ExpandProperty spec | Select-Object -ExpandProperty replicas
$stripeMockReplicas = $currentState.items | Where-Object { $_.metadata.name -eq "stripe-mock" } | Select-Object -ExpandProperty spec | Select-Object -ExpandProperty replicas

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
kubectl -n sock-shop scale deployment stripe-mock --replicas=0

Write-Host "`n⏳ Step 3/3: Waiting for pods to terminate..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host "`n📊 Verifying incident state..." -ForegroundColor Cyan
kubectl -n sock-shop get pods -l name=stripe-mock
kubectl -n sock-shop get pods -l name=payment

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║         ✅ INCIDENT 6 ACTIVATED SUCCESSFULLY!             ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red

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

Write-Host "`n🔍 MONITORING COMMANDS:" -ForegroundColor Cyan
Write-Host "   • Watch payment logs: kubectl -n sock-shop logs deployment/payment -f" -ForegroundColor White
Write-Host "   • Check pod status: kubectl -n sock-shop get pods -l 'name in (payment,stripe-mock)'" -ForegroundColor White

Write-Host "`n💊 TO RECOVER:" -ForegroundColor Yellow
Write-Host "   Run: .\incident-6-recover.ps1" -ForegroundColor White

Write-Host "`n⚠️  REMINDER: This simulates a REAL production incident!" -ForegroundColor Yellow
Write-Host "   In production, this would mean revenue loss and customer impact." -ForegroundColor Yellow
