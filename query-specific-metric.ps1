# Query specific Prometheus metrics programmatically
param(
    [string]$metric = "rabbitmq_queue_messages_published_total"
)

Write-Host "Querying Prometheus for: $metric" -ForegroundColor Cyan

# Query Prometheus API
$query = [System.Web.HttpUtility]::UrlEncode($metric)
$url = "http://localhost:4025/api/v1/query?query=$query"

$response = Invoke-RestMethod -Uri $url -Method Get

if ($response.status -eq "success") {
    Write-Host "`nResults:" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    foreach ($result in $response.data.result) {
        # Extract metric name and labels
        $metricName = $result.metric.__name__
        $labels = $result.metric.PSObject.Properties | Where-Object { $_.Name -ne "__name__" }
        
        # Extract value and timestamp
        $value = $result.value[1]
        $timestamp = [DateTimeOffset]::FromUnixTimeSeconds($result.value[0]).LocalDateTime
        
        # Display
        Write-Host "`nMetric: " -NoNewline -ForegroundColor Yellow
        Write-Host $metricName -ForegroundColor White
        
        if ($labels) {
            Write-Host "Labels: " -NoNewline -ForegroundColor Yellow
            $labelStr = ($labels | ForEach-Object { "$($_.Name)=`"$($_.Value)`"" }) -join ", "
            Write-Host $labelStr -ForegroundColor Cyan
        }
        
        Write-Host "Value:  " -NoNewline -ForegroundColor Yellow
        Write-Host $value -ForegroundColor Green
        
        Write-Host "Time:   " -NoNewline -ForegroundColor Yellow
        Write-Host $timestamp -ForegroundColor Gray
    }
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Total results: $($response.data.result.Count)" -ForegroundColor Cyan
} else {
    Write-Host "Error: $($response.error)" -ForegroundColor Red
}

Write-Host "`nExamples:" -ForegroundColor Yellow
Write-Host "  .\query-specific-metric.ps1 'rabbitmq_connections'" -ForegroundColor Gray
Write-Host "  .\query-specific-metric.ps1 'rabbitmq_queue_messages'" -ForegroundColor Gray
Write-Host "  .\query-specific-metric.ps1 'rate(rabbitmq_queue_messages_published_total[1m])'" -ForegroundColor Gray
