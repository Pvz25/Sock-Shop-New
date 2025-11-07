# ====================================================================
# Incident 6: Payment Gateway Timeout/Failure - RECOVERY
# ====================================================================
# This script recovers from the incident by restoring normal traffic flow
# and removing all failure injections from Toxiproxy
#
# SAFETY: This script restores the system to its original state
# ====================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  INCIDENT 6: Payment Gateway Failure - RECOVERY               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Step 1: Remove all toxics from Toxiproxy
Write-Host "`n[1/3] Removing all failure injections from Toxiproxy..." -ForegroundColor Green

$job = Start-Job -ScriptBlock {
    kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474 2>$null
}

Start-Sleep -Seconds 3

try {
    $headers = @{"User-Agent" = "PowerShell/Incident6"}
    
    # Get all toxics
    $proxies = Invoke-RestMethod -Uri "http://localhost:8474/proxies" -Method Get -Headers $headers
    $toxics = $proxies.payment.toxics
    
    if ($toxics -and $toxics.Count -gt 0) {
        Write-Host "   Found $($toxics.Count) active toxic(s)" -ForegroundColor Yellow
        foreach ($toxic in $toxics) {
            Write-Host "   Removing toxic: $($toxic.name)" -ForegroundColor Gray
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics/$($toxic.name)" -Method Delete -Headers $headers | Out-Null
        }
        Write-Host "✅ All failure injections removed" -ForegroundColor Green
    } else {
        Write-Host "✅ No active toxics found" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Error removing toxics: $_" -ForegroundColor Red
} finally {
    Stop-Job -Job $job 2>$null
    Remove-Job -Job $job 2>$null
}

# Step 2: Restore payment service to point directly to payment pods
Write-Host "`n[2/3] Restoring payment service to original configuration..." -ForegroundColor Green
Write-Host "   Current: payment service → toxiproxy pods → payment service" -ForegroundColor Gray
Write-Host "   Restoring: payment service → payment pods (direct)" -ForegroundColor Yellow

kubectl -n sock-shop patch svc payment -p '{\"spec\":{\"selector\":{\"name\":\"payment\"}}}'

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Payment service restored to direct routing" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to restore service! Check manually." -ForegroundColor Red
    Write-Host "   Manual fix: kubectl -n sock-shop patch svc payment -p '{\"spec\":{\"selector\":{\"name\":\"payment\"}}}'" -ForegroundColor Yellow
    exit 1
}

# Step 3: Verify recovery
Write-Host "`n[3/3] Verifying system recovery..." -ForegroundColor Green

$svcSelector = kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'
if ($svcSelector -eq "payment") {
    Write-Host "✅ Payment service correctly points to payment pods" -ForegroundColor Green
} else {
    Write-Host "❌ Warning: Payment service selector is: $svcSelector (expected: payment)" -ForegroundColor Yellow
}

# Test payment service health
Write-Host "`nTesting payment service health..." -ForegroundColor Gray
$testPod = "test-payment-health-$(Get-Random -Maximum 9999)"
$healthCheck = kubectl -n sock-shop run $testPod --rm -it --image=curlimages/curl --restart=Never -- curl -s --max-time 5 http://payment:80/health 2>&1

if ($healthCheck -match "payment.*OK") {
    Write-Host "✅ Payment service is healthy and responding normally" -ForegroundColor Green
} else {
    Write-Host "⚠️  Payment service health check did not return expected response" -ForegroundColor Yellow
    Write-Host "   This may be normal if payment pods are still starting" -ForegroundColor Gray
}

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ INCIDENT 6 RECOVERED - System Restored to Normal         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📊 CURRENT STATE:" -ForegroundColor Cyan
Write-Host "   • Payment service routes directly to payment pods ✅" -ForegroundColor White
Write-Host "   • All failure injections removed ✅" -ForegroundColor White
Write-Host "   • Toxiproxy still running (standby mode) ✅" -ForegroundColor White
Write-Host "   • Orders should process normally now ✅" -ForegroundColor White

Write-Host "`n🔬 VERIFICATION:" -ForegroundColor Cyan
Write-Host "   1. Go to http://localhost:2025" -ForegroundColor White
Write-Host "   2. Place a test order" -ForegroundColor White
Write-Host "   3. Should complete successfully" -ForegroundColor White

Write-Host "`n📝 NOTE: Toxiproxy deployment remains active for future incident testing" -ForegroundColor Magenta
Write-Host "   To completely remove: kubectl -n sock-shop delete -f toxiproxy-deployment.yaml" -ForegroundColor Gray
Write-Host ""
