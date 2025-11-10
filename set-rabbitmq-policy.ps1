# Set RabbitMQ Policy via Management API

Write-Host "Setting up port-forward to RabbitMQ Management..." -ForegroundColor Cyan

# Kill any existing port-forwards
Get-Job | Where-Object { $_.Command -like "*port-forward*rabbitmq*" } | Stop-Job | Remove-Job

# Start port-forward
$portForwardJob = Start-Job -ScriptBlock {
    kubectl -n sock-shop port-forward deployment/rabbitmq 15672:15672 2>&1 | Out-Null
}

Start-Sleep -Seconds 5

try {
    Write-Host "Setting queue policy: max-length=3, overflow=reject-publish" -ForegroundColor Yellow
    
    $policy = @{
        pattern = "^shipping-task$"
        definition = @{
            "max-length" = 3
            overflow = "reject-publish"
        }
        "apply-to" = "queues"
        priority = 0
    }
    
    $json = $policy | ConvertTo-Json -Compress
    $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("guest:guest"))
    
    $response = Invoke-RestMethod `
        -Uri "http://localhost:15672/api/policies/%2F/shipping-limit" `
        -Method Put `
        -Headers @{
            Authorization = "Basic $base64Auth"
            "Content-Type" = "application/json"
        } `
        -Body $json `
        -ErrorAction Stop
    
    Write-Host "✅ Policy set successfully!" -ForegroundColor Green
    
    # Verify
    Start-Sleep -Seconds 2
    $policies = Invoke-RestMethod `
        -Uri "http://localhost:15672/api/policies/%2F" `
        -Headers @{ Authorization = "Basic $base64Auth" } `
        -ErrorAction Stop
    
    $shippingPolicy = $policies | Where-Object { $_.name -eq "shipping-limit" }
    
    if ($shippingPolicy) {
        Write-Host "✅ Policy verified:" -ForegroundColor Green
        Write-Host "   Name: $($shippingPolicy.name)"
        Write-Host "   Pattern: $($shippingPolicy.pattern)"
        Write-Host "   Max-length: $($shippingPolicy.definition.'max-length')"
        Write-Host "   Overflow: $($shippingPolicy.definition.overflow)"
    } else {
        Write-Host "⚠️ Policy not found in verification" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
} finally {
    # Cleanup port-forward
    Write-Host "Cleaning up port-forward..." -ForegroundColor Gray
    $portForwardJob | Stop-Job | Remove-Job -Force
}
