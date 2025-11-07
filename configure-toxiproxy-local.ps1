# Configure Toxiproxy via port-forward and local API calls

Write-Host "Starting port-forward to Toxiproxy API..." -ForegroundColor Cyan

# Start port-forward in background
$job = Start-Job -ScriptBlock {
    kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474
}

Start-Sleep -Seconds 3

try {
    Write-Host "`nCreating payment proxy configuration..." -ForegroundColor Yellow
    
    $proxyConfig = @{
        name = "payment"
        listen = "0.0.0.0:8080"
        upstream = "payment.sock-shop.svc.cluster.local:80"
        enabled = $true
    } | ConvertTo-Json

    $headers = @{"User-Agent" = "PowerShell/Toxiproxy-Config"}
    $response = Invoke-RestMethod -Uri "http://localhost:8474/proxies" -Method Post -Body $proxyConfig -ContentType "application/json" -Headers $headers
    
    Write-Host "`n✅ Proxy created successfully!" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3)

    Write-Host "`nVerifying all proxies..." -ForegroundColor Yellow
    $proxies = Invoke-RestMethod -Uri "http://localhost:8474/proxies" -Method Get -Headers $headers
    Write-Host ($proxies | ConvertTo-Json -Depth 3)

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
} finally {
    Write-Host "`nStopping port-forward..." -ForegroundColor Cyan
    Stop-Job -Job $job
    Remove-Job -Job $job
}

Write-Host "`n✅ Toxiproxy configured: 0.0.0.0:8080 → payment:80" -ForegroundColor Green
