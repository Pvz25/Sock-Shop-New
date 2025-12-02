# ============================================================================
# INCIDENT-5C SCHEDULED EXECUTION WITH PRE-FLIGHT HEALTH CHECKS
# ============================================================================
# This script waits 30 minutes, performs comprehensive health checks,
# and then executes INCIDENT-5C
# ============================================================================

param(
    [DateTime]$ScheduledTime = [DateTime]::Parse('2025-11-29 23:32:35')
)

# Calculate wait time
$NOW = Get-Date
$WAIT_SECONDS = [Math]::Max(0, ($ScheduledTime - $NOW).TotalSeconds)

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║       INCIDENT-5C SCHEDULED EXECUTION TIMER                ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

Write-Host "`n📅 SCHEDULE:" -ForegroundColor Cyan
Write-Host "   Current Time (IST):   $($NOW.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Scheduled Time (IST): $($ScheduledTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "   Scheduled Time (UTC): $($ScheduledTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "   Wait Duration:        $([Math]::Round($WAIT_SECONDS/60, 2)) minutes`n" -ForegroundColor Cyan

if ($WAIT_SECONDS -gt 0) {
    Write-Host "⏳ Waiting for scheduled time..." -ForegroundColor Yellow
    Write-Host "   (You can cancel with Ctrl+C)`n" -ForegroundColor Gray
    
    # Countdown with progress updates every minute
    $REMAINING = $WAIT_SECONDS
    while ($REMAINING -gt 0) {
        $MINUTES_LEFT = [Math]::Ceiling($REMAINING / 60)
        Write-Host "   ⏰ Time remaining: $MINUTES_LEFT minutes..." -ForegroundColor Gray
        
        $SLEEP_TIME = [Math]::Min(60, $REMAINING)
        Start-Sleep -Seconds $SLEEP_TIME
        $REMAINING -= $SLEEP_TIME
    }
    
    Write-Host "`n✅ Scheduled time reached!`n" -ForegroundColor Green
}

# ============================================================================
# PRE-FLIGHT HEALTH CHECKS
# ============================================================================

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           PRE-FLIGHT HEALTH CHECKS                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$HEALTH_PASS = $true

# Check 1: All pods running
Write-Host "`n[1/6] Checking all Sock Shop pods..." -ForegroundColor Cyan
$PODS = kubectl -n sock-shop get pods --no-headers 2>&1
$POD_COUNT = ($PODS | Measure-Object).Count
$RUNNING_COUNT = ($PODS | Select-String "Running" | Measure-Object).Count

if ($RUNNING_COUNT -eq $POD_COUNT -and $POD_COUNT -ge 15) {
    Write-Host "   ✅ All $POD_COUNT pods are Running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Pod health issue: $RUNNING_COUNT/$POD_COUNT Running" -ForegroundColor Red
    $HEALTH_PASS = $false
}

# Check 2: Datadog agent running
Write-Host "`n[2/6] Checking Datadog agent..." -ForegroundColor Cyan
$DD_PODS = kubectl -n datadog get pods --no-headers 2>&1
$DD_COUNT = ($DD_PODS | Select-String "Running" | Measure-Object).Count

if ($DD_COUNT -ge 3) {
    Write-Host "   ✅ Datadog agent running ($DD_COUNT pods)" -ForegroundColor Green
} else {
    Write-Host "   ❌ Datadog agent issue: $DD_COUNT pods running" -ForegroundColor Red
    $HEALTH_PASS = $false
}

# Check 3: Datadog logs being processed
Write-Host "`n[3/6] Checking Datadog log processing..." -ForegroundColor Cyan
$DD_STATUS = kubectl -n datadog exec datadog-agent-ktm56 -c agent -- agent status 2>&1 | Select-String -Pattern "LogsProcessed"
$LOGS_PROCESSED = ($DD_STATUS -split ':')[1].Trim()

if ([int]$LOGS_PROCESSED -gt 0) {
    Write-Host "   ✅ Datadog logs being processed: $LOGS_PROCESSED" -ForegroundColor Green
} else {
    Write-Host "   ❌ Datadog not processing logs" -ForegroundColor Red
    $HEALTH_PASS = $false
}

# Check 4: Datadog logs being sent
Write-Host "`n[4/6] Checking Datadog log transmission..." -ForegroundColor Cyan
$DD_SENT = kubectl -n datadog exec datadog-agent-ktm56 -c agent -- agent status 2>&1 | Select-String -Pattern "LogsSent"
$LOGS_SENT = ($DD_SENT -split ':')[1].Trim()

if ([int]$LOGS_SENT -gt 0) {
    Write-Host "   ✅ Datadog logs being sent: $LOGS_SENT" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Datadog logs sent: $LOGS_SENT (may be normal if recent restart)" -ForegroundColor Yellow
}

# Check 5: Queue-master running (required for INCIDENT-5C)
Write-Host "`n[5/6] Checking queue-master status..." -ForegroundColor Cyan
$QM_STATUS = kubectl -n sock-shop get pods -l name=queue-master --no-headers 2>&1
$QM_RUNNING = $QM_STATUS -match "1/1.*Running"

if ($QM_RUNNING) {
    Write-Host "   ✅ Queue-master is running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Queue-master not running: $QM_STATUS" -ForegroundColor Red
    $HEALTH_PASS = $false
}

# Check 6: RabbitMQ running (required for INCIDENT-5C)
Write-Host "`n[6/6] Checking RabbitMQ status..." -ForegroundColor Cyan
$RMQ_STATUS = kubectl -n sock-shop get pods -l name=rabbitmq --no-headers 2>&1
$RMQ_RUNNING = $RMQ_STATUS -match "2/2.*Running"

if ($RMQ_RUNNING) {
    Write-Host "   ✅ RabbitMQ is running (2/2 containers)" -ForegroundColor Green
} else {
    Write-Host "   ❌ RabbitMQ not running: $RMQ_STATUS" -ForegroundColor Red
    $HEALTH_PASS = $false
}

# Health check summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
if ($HEALTH_PASS) {
    Write-Host "║         ✅ ALL HEALTH CHECKS PASSED                        ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "`n🚀 Proceeding with INCIDENT-5C execution...`n" -ForegroundColor Green
} else {
    Write-Host "║         ❌ HEALTH CHECKS FAILED                            ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "`n⚠️  System is not healthy. Aborting INCIDENT-5C execution.`n" -ForegroundColor Red
    exit 1
}

# ============================================================================
# EXECUTE INCIDENT-5C
# ============================================================================

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║         EXECUTING INCIDENT-5C: QUEUE BLOCKAGE              ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# Record start time
$INCIDENT5C_START = Get-Date
Write-Host "`n📅 INCIDENT-5C START TIME:" -ForegroundColor Yellow
Write-Host "   IST: $($INCIDENT5C_START.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   UTC: $($INCIDENT5C_START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))`n" -ForegroundColor White

# Execute INCIDENT-5C with 5-minute duration (300 seconds)
.\incident-5c-execute-fixed.ps1 -DurationSeconds 300

# Record end time
$INCIDENT5C_END = Get-Date
$INCIDENT5C_DURATION = (New-TimeSpan -Start $INCIDENT5C_START -End $INCIDENT5C_END).TotalMinutes

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ✅ INCIDENT-5C EXECUTION COMPLETE                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📊 INCIDENT-5C TIMELINE:" -ForegroundColor Cyan
Write-Host "   Start (IST):    $($INCIDENT5C_START.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Start (UTC):    $($INCIDENT5C_START.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   End (IST):      $($INCIDENT5C_END.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   End (UTC):      $($INCIDENT5C_END.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "   Duration:       $([Math]::Round($INCIDENT5C_DURATION, 2)) minutes`n" -ForegroundColor Yellow

Write-Host "✅ All incidents completed successfully!`n" -ForegroundColor Green
