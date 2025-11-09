# Place Test Orders for Incident Testing
param(
    [int]$OrderCount = 5,
    [string]$FrontEndUrl = "http://localhost:30001"
)

Write-Host "=== Placing $OrderCount Test Orders ===" -ForegroundColor Cyan
Write-Host "Front-end URL: $FrontEndUrl" -ForegroundColor Yellow
Write-Host ""

# Test connectivity first
try {
    $testResponse = Invoke-WebRequest -Uri "$FrontEndUrl/" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ Front-end is accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot reach front-end at $FrontEndUrl" -ForegroundColor Red
    Write-Host "   Make sure the service is exposed via NodePort 30001" -ForegroundColor Yellow
    exit 1
}

# Order payload
$ordersPlaced = 0

for ($i = 1; $i -le $OrderCount; $i++) {
    Write-Host "Placing order $i of $OrderCount..." -ForegroundColor White
    
    try {
        # Create a simple order via the orders API
        $orderPayload = @{
            customerId = "57a98d98e4b00679b4a830af"  # Default test user
            items = @(
                @{ itemId = "03fef6ac-1896-4ce8-bd69-b798f85c6e0b"; quantity = 1 }  # Holy socks
            )
        } | ConvertTo-Json
        
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        # Send order to orders service via kubectl port-forward
        $response = Invoke-RestMethod -Uri "http://localhost:8080/orders" `
            -Method POST `
            -Body $orderPayload `
            -Headers $headers `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        if ($response) {
            Write-Host "  ✅ Order placed successfully" -ForegroundColor Green
            $ordersPlaced++
        }
        
    } catch {
        Write-Host "  ⚠️ Order placement failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "=== Orders Placement Complete ===" -ForegroundColor Cyan
Write-Host "Orders placed: $ordersPlaced / $OrderCount" -ForegroundColor Yellow
Write-Host ""
