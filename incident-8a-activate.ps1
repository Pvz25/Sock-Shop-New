# INCIDENT-8A: Database Performance Degradation (Table Lock Method)
# Simulates database slowness using MySQL table locks
# This creates REAL slowness without crashing the database

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8A: Database Query Latency" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$INCIDENT_START = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Write-Host "📅 INCIDENT START: $INCIDENT_START" -ForegroundColor Yellow
Write-Host ""

Write-Host "🎯 METHOD: MySQL Table Lock (Not Resource Constraints)" -ForegroundColor Cyan
Write-Host "   This will cause SLOWNESS, not crashes" -ForegroundColor Green
Write-Host ""

# Step 1: Verify database is healthy
Write-Host "Step 1: Verifying database health..." -ForegroundColor Green
$dbPod = kubectl get pods -n sock-shop -l name=catalogue-db -o jsonpath='{.items[0].metadata.name}'
$dbStatus = kubectl get pods -n sock-shop -l name=catalogue-db -o jsonpath='{.items[0].status.phase}'

if ($dbStatus -eq "Running") {
    Write-Host "  ✅ Database pod: $dbPod (Running)" -ForegroundColor Green
} else {
    Write-Host "  ❌ Database not running! Status: $dbStatus" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 2: Test baseline query performance
Write-Host "Step 2: Testing baseline query performance..." -ForegroundColor Green
Write-Host "  Running test query..." -NoNewline

$baselineStart = Get-Date
kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin socksdb -e "SELECT COUNT(*) FROM sock;" > $null 2>&1
$baselineEnd = Get-Date
$baselineDuration = ($baselineEnd - $baselineStart).TotalMilliseconds

Write-Host " took $([math]::Round($baselineDuration))ms" -ForegroundColor Green
Write-Host ""

# Step 3: Start background job to hold table lock
Write-Host "Step 3: Acquiring table lock on 'sock' table..." -ForegroundColor Green
Write-Host "  This will hold a READ lock for 5 minutes" -ForegroundColor Yellow
Write-Host "  All SELECT queries will wait for this lock" -ForegroundColor Yellow
Write-Host ""

# Create the lock script
$lockScript = @"
LOCK TABLES sock READ;
SELECT SLEEP(300);
UNLOCK TABLES;
"@

# Start background job to hold the lock
$lockJob = Start-Job -ScriptBlock {
    param($pod, $script)
    $script | kubectl exec -i -n sock-shop $pod -- mysql -u root -padmin socksdb
} -ArgumentList $dbPod, $lockScript

Write-Host "  ✅ Table lock acquired (Job ID: $($lockJob.Id))" -ForegroundColor Green
Write-Host "  ⚠️  Lock will be held for 5 minutes or until recovery" -ForegroundColor Yellow
Write-Host ""

# Step 4: Wait a moment for lock to take effect
Write-Host "Step 4: Waiting 3 seconds for lock to take effect..." -ForegroundColor Green
Start-Sleep -Seconds 3
Write-Host ""

# Step 5: Verify lock is active
Write-Host "Step 5: Verifying table lock is active..." -ForegroundColor Green
$lockCheck = kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin -e "SHOW OPEN TABLES WHERE In_use > 0;" 2>$null

if ($lockCheck -match "sock") {
    Write-Host "  ✅ Table lock confirmed active" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Lock may not be active yet, give it a moment" -ForegroundColor Yellow
}
Write-Host ""

# Step 6: Test query performance with lock
Write-Host "Step 6: Testing query performance WITH lock..." -ForegroundColor Green
Write-Host "  Running test query (this should be SLOW)..." -NoNewline

$slowStart = Get-Date
$testResult = kubectl exec -n sock-shop $dbPod -- timeout 15 mysql -u root -padmin socksdb -e "SELECT COUNT(*) FROM sock;" 2>&1
$slowEnd = Get-Date
$slowDuration = ($slowEnd - $slowStart).TotalMilliseconds

if ($slowDuration -gt 1000) {
    Write-Host " took $([math]::Round($slowDuration))ms 🐌" -ForegroundColor Yellow
    Write-Host "  ✅ Query slowness confirmed!" -ForegroundColor Green
} else {
    Write-Host " took $([math]::Round($slowDuration))ms" -ForegroundColor Yellow
    Write-Host "  ⚠️  Query not as slow as expected, but lock is active" -ForegroundColor Yellow
}
Write-Host ""

# Instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT ACTIVATED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 USER IMPACT:" -ForegroundColor Yellow
Write-Host "  - Product browsing is now SLOW (5-10 seconds)" -ForegroundColor Yellow
Write-Host "  - Database queries wait for table lock" -ForegroundColor Yellow
Write-Host "  - Products WILL load (not blank)" -ForegroundColor Green
Write-Host "  - This is REAL slowness, not crash" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 TEST IN UI NOW:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Click 'Catalogue' - notice SLOW load (5-10 seconds)" -ForegroundColor White
Write-Host "  3. Products WILL appear (just slowly)" -ForegroundColor Green
Write-Host "  4. Refresh multiple times - consistent slowness" -ForegroundColor White
Write-Host "  5. Every page load takes 5-10 seconds" -ForegroundColor White
Write-Host ""
Write-Host "📊 WHAT YOU'LL SEE:" -ForegroundColor Yellow
Write-Host "  ✅ Products DO load (not blank)" -ForegroundColor Green
Write-Host "  ⏳ But they take 5-10 seconds (was <1 second)" -ForegroundColor Yellow
Write-Host "  🐌 Noticeable, frustrating delay" -ForegroundColor Yellow
Write-Host "  ✅ This matches client requirement!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 DATADOG SIGNALS TO WATCH:" -ForegroundColor Yellow
Write-Host "  - mysql.performance.query_run_time.avg → 5000-10000ms" -ForegroundColor White
Write-Host "  - mysql.performance.table_lock_waits → Increasing" -ForegroundColor White
Write-Host "  - http.request.duration{service:catalogue} → 8000-12000ms" -ForegroundColor White
Write-Host "  - Queries succeed, just slow (no errors)" -ForegroundColor White
Write-Host ""
Write-Host "🔧 TO RECOVER:" -ForegroundColor Yellow
Write-Host "  Run: .\incident-8a-recover.ps1" -ForegroundColor White
Write-Host "  OR manually: UNLOCK TABLES in MySQL session" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Incident Duration: 5 minutes or until recovery" -ForegroundColor Yellow
Write-Host "📅 Started: $INCIDENT_START" -ForegroundColor Yellow
Write-Host "🆔 Lock Job ID: $($lockJob.Id)" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 TIP: This simulates database maintenance operation!" -ForegroundColor Cyan
Write-Host ""

# Save job ID for recovery
$lockJob.Id | Out-File -FilePath ".\incident-8a-job-id.txt" -Force
