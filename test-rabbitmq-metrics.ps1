# Test RabbitMQ Metrics Endpoint
$ErrorActionPreference = "Stop"

Write-Host "Fetching RabbitMQ metrics..." -ForegroundColor Cyan

$rabbitmqPod = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}'
Write-Host "RabbitMQ Pod: $rabbitmqPod"

# Start port-forward
$job = Start-Job -ScriptBlock {
    kubectl port-forward -n sock-shop $args[0] 9091:9090
} -ArgumentList $rabbitmqPod

Start-Sleep -Seconds 3

try {
    $metrics = Invoke-WebRequest -Uri "http://localhost:9091/metrics" -UseBasicParsing -TimeoutSec 5
    
    Write-Host "`n=== Queue Metrics ===" -ForegroundColor Green
    $metrics.Content -split "`n" | Where-Object { $_ -match "rabbitmq_queue" } | Select-Object -First 30
    
    Write-Host "`n=== Consumer Metrics ===" -ForegroundColor Green
    $metrics.Content -split "`n" | Where-Object { $_ -match "consumer" }
    
    Write-Host "`n=== Message Stats ===" -ForegroundColor Green
    $metrics.Content -split "`n" | Where-Object { $_ -match "message_stats" } | Select-Object -First 10
    
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    $allMetrics = $metrics.Content -split "`n" | Where-Object { $_ -match "^rabbitmq_" -and $_ -notmatch "^#" }
    Write-Host "Total RabbitMQ metrics available: $($allMetrics.Count)"
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
} finally {
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -ErrorAction SilentlyContinue
}
