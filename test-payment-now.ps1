# Quick test to verify payment gateway is working
Write-Host "🧪 Testing Payment Gateway Recovery..." -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Current Pod Status:" -ForegroundColor Yellow
kubectl get pods -n sock-shop -l 'name in (payment,stripe-mock)'
Write-Host ""
Write-Host "🔍 Watching payment logs (last 5 lines):" -ForegroundColor Yellow
kubectl logs -n sock-shop deployment/payment --tail=5
Write-Host ""
Write-Host "✅ Please try placing an order NOW in the UI" -ForegroundColor Green
Write-Host "   URL: http://localhost:2025" -ForegroundColor White
Write-Host ""
Write-Host "⏳ Waiting for new payment attempt (30 seconds)..." -ForegroundColor Cyan
Write-Host "   (Press Ctrl+C to stop)" -ForegroundColor Gray
Write-Host ""

# Follow logs for 30 seconds
kubectl logs -n sock-shop deployment/payment -f --tail=0 &
$job = Start-Job -ScriptBlock { Start-Sleep -Seconds 30 }
Wait-Job $job | Out-Null
Remove-Job $job
Stop-Job * 2>$null
Remove-Job * 2>$null

Write-Host ""
Write-Host "📊 Final Status:" -ForegroundColor Yellow
kubectl logs -n sock-shop deployment/payment --tail=10
