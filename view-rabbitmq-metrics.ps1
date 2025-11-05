# RabbitMQ Metrics Viewer - Formatted and Filtered
# Makes raw metrics human-readable

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  RABBITMQ METRICS - READABLE FORMAT" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Fetch metrics
$metrics = Invoke-WebRequest -Uri "http://localhost:5025/metrics" -UseBasicParsing | Select-Object -ExpandProperty Content

# Parse and display key metrics
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  QUEUE METRICS (shipping-task)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green

# Queue depth
if ($metrics -match 'rabbitmq_queue_messages{[^}]*queue="shipping-task"[^}]*}\s+(\d+)') {
    Write-Host "  Current Queue Depth:        " -NoNewline
    Write-Host $matches[1] -ForegroundColor $(if ([int]$matches[1] -gt 10) { "Red" } else { "Green" })
}

# Messages ready
if ($metrics -match 'rabbitmq_queue_messages_ready{[^}]*queue="shipping-task"[^}]*}\s+(\d+)') {
    Write-Host "  Messages Ready:             " -NoNewline
    Write-Host $matches[1] -ForegroundColor $(if ([int]$matches[1] -gt 0) { "Yellow" } else { "Green" })
}

# Messages unacknowledged
if ($metrics -match 'rabbitmq_queue_messages_unacknowledged{[^}]*queue="shipping-task"[^}]*}\s+(\d+)') {
    Write-Host "  Messages Unacknowledged:    " -NoNewline
    Write-Host $matches[1] -ForegroundColor Yellow
}

# Total published
if ($metrics -match 'rabbitmq_queue_messages_published_total{[^}]*queue="shipping-task"[^}]*}\s+(\d+)') {
    Write-Host "  Total Published (lifetime): " -NoNewline
    Write-Host $matches[1] -ForegroundColor Cyan
}

# Total delivered
if ($metrics -match 'rabbitmq_queue_messages_delivered_total{[^}]*queue="shipping-task"[^}]*}\s+(\d+)') {
    Write-Host "  Total Delivered (lifetime): " -NoNewline
    Write-Host $matches[1] -ForegroundColor Cyan
}

# Consumer count
if ($metrics -match 'rabbitmq_queue_consumers{[^}]*queue="shipping-task"[^}]*}\s+(\d+)') {
    Write-Host "  Active Consumers:           " -NoNewline
    Write-Host $matches[1] -ForegroundColor $(if ([int]$matches[1] -eq 0) { "Red" } else { "Green" })
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  CLUSTER METRICS" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green

# Total connections
if ($metrics -match 'rabbitmq_connections{[^}]*}\s+(\d+)') {
    Write-Host "  Total Connections:          " -NoNewline
    Write-Host $matches[1] -ForegroundColor Cyan
}

# Total channels
if ($metrics -match 'rabbitmq_channels{[^}]*}\s+(\d+)') {
    Write-Host "  Total Channels:             " -NoNewline
    Write-Host $matches[1] -ForegroundColor Cyan
}

# Total exchanges
if ($metrics -match 'rabbitmq_exchanges{[^}]*}\s+(\d+)') {
    Write-Host "  Total Exchanges:            " -NoNewline
    Write-Host $matches[1] -ForegroundColor Cyan
}

# Total queues
if ($metrics -match 'rabbitmq_queues{[^}]*}\s+(\d+)') {
    Write-Host "  Total Queues:               " -NoNewline
    Write-Host $matches[1] -ForegroundColor Cyan
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  NODE HEALTH" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green

# Memory used
if ($metrics -match 'rabbitmq_node_mem_used{[^}]*}\s+([\d\.e\+]+)') {
    $memMB = [math]::Round([double]$matches[1] / 1MB, 2)
    Write-Host "  Memory Used:                " -NoNewline
    Write-Host "$memMB MB" -ForegroundColor Cyan
}

# Disk free
if ($metrics -match 'rabbitmq_node_disk_free{[^}]*}\s+([\d\.e\+]+)') {
    $diskGB = [math]::Round([double]$matches[1] / 1GB, 2)
    Write-Host "  Disk Free:                  " -NoNewline
    Write-Host "$diskGB GB" -ForegroundColor Green
}

# Uptime
if ($metrics -match 'rabbitmq_uptime{[^}]*}\s+([\d\.e\+]+)') {
    $uptimeHours = [math]::Round([double]$matches[1] / 1000 / 3600, 2)
    Write-Host "  Uptime:                     " -NoNewline
    Write-Host "$uptimeHours hours" -ForegroundColor Cyan
}

# File descriptors
if ($metrics -match 'rabbitmq_fd_used{[^}]*}\s+(\d+)') {
    $fdUsed = $matches[1]
    if ($metrics -match 'rabbitmq_fd_available{[^}]*}\s+([\d\.e\+]+)') {
        $fdTotal = [int][double]$matches[1]
        $fdPercent = [math]::Round(($fdUsed / $fdTotal) * 100, 2)
        Write-Host "  File Descriptors:           " -NoNewline
        Write-Host "$fdUsed / $fdTotal ($fdPercent%)" -ForegroundColor $(if ($fdPercent -gt 80) { "Red" } elseif ($fdPercent -gt 50) { "Yellow" } else { "Green" })
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Refresh with: .\view-rabbitmq-metrics.ps1" -ForegroundColor Gray
Write-Host "  Raw metrics: http://localhost:5025/metrics" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
