# INCIDENT-6 Testing Timer
# Provides 180-second (3-minute) window for order placement

$duration = 180
$startTime = Get-Date

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ⏱️  INCIDENT-6 TESTING WINDOW: 180 SECONDS          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n🎯 PLACE YOUR ORDERS NOW!" -ForegroundColor Yellow
Write-Host "   URL: http://localhost:2025" -ForegroundColor White
Write-Host "   Login: user / password" -ForegroundColor White
Write-Host "`n   You have 3 MINUTES to place orders..." -ForegroundColor Yellow

# Countdown timer
for ($i = $duration; $i -gt 0; $i--) {
    $elapsed = $duration - $i
    $remaining = $i
    
    # Progress bar
    $percent = [math]::Round(($elapsed / $duration) * 100)
    $bar = "█" * [math]::Floor($percent / 2)
    $space = " " * (50 - [math]::Floor($percent / 2))
    
    # Time display
    $minutes = [math]::Floor($remaining / 60)
    $seconds = $remaining % 60
    
    # Color coding
    if ($remaining -gt 120) {
        $color = "Green"
        $status = "🟢 PLENTY OF TIME"
    } elseif ($remaining -gt 60) {
        $color = "Yellow"
        $status = "🟡 HALFWAY THROUGH"
    } elseif ($remaining -gt 30) {
        $color = "Magenta"
        $status = "🟠 HURRY UP!"
    } else {
        $color = "Red"
        $status = "🔴 LAST CHANCE!"
    }
    
    Write-Host "`r[$bar$space] $percent% | ${minutes}m ${seconds}s remaining | $status" -NoNewline -ForegroundColor $color
    Start-Sleep -Seconds 1
}

Write-Host "`n`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║              ⏰ TIME'S UP! WINDOW CLOSED!                 ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red

Write-Host "`n📊 Testing window complete!" -ForegroundColor Yellow
Write-Host "   Duration: 180 seconds (3 minutes)" -ForegroundColor White
Write-Host "   End time: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White

Write-Host "`n💊 READY TO RECOVER?" -ForegroundColor Cyan
Write-Host "   Run: .\incident-6-recover.ps1" -ForegroundColor White

Write-Host "`n🔍 CHECK RESULTS:" -ForegroundColor Cyan
Write-Host "   • Payment logs: kubectl logs -n sock-shop deployment/payment --tail=20" -ForegroundColor White
Write-Host "   • Failed orders: kubectl exec -n sock-shop deployment/orders-db -- mongo data --quiet --eval 'db.customerOrder.find({status:`"PAYMENT_FAILED`"}).count()'" -ForegroundColor White

Write-Host "`n"
