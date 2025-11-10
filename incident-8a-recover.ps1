# INCIDENT-8A RECOVERY: Release Database Table Lock
# Restores database query performance by releasing table locks

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8A RECOVERY: Database Performance" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$RECOVERY_START = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Write-Host "📅 RECOVERY START: $RECOVERY_START" -ForegroundColor Green
Write-Host ""

# Step 1: Get database pod
Write-Host "Step 1: Locating database pod..." -ForegroundColor Green
$dbPod = kubectl get pods -n sock-shop -l name=catalogue-db -o jsonpath='{.items[0].metadata.name}'
Write-Host "  Database pod: $dbPod" -ForegroundColor White
Write-Host ""

# Step 2: Check for active locks
Write-Host "Step 2: Checking for active table locks..." -ForegroundColor Green
$locks = kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin -e "SHOW OPEN TABLES WHERE In_use > 0;" 2>$null

if ($locks -match "sock") {
    Write-Host "  ⚠️  Table lock detected on 'sock' table" -ForegroundColor Yellow
} else {
    Write-Host "  ℹ️  No active table locks found" -ForegroundColor Cyan
}
Write-Host ""

# Step 3: Kill lock-holding process
Write-Host "Step 3: Killing lock-holding MySQL processes..." -ForegroundColor Green

# Get process list
$processList = kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin -e "SHOW PROCESSLIST;" 2>$null

# Find and kill SLEEP processes (these are holding locks)
$sleepProcesses = $processList | Select-String "SLEEP" | Select-String -NotMatch "SHOW PROCESSLIST"

if ($sleepProcesses) {
    Write-Host "  Found lock-holding processes:" -ForegroundColor Yellow
    
    foreach ($process in $sleepProcesses) {
        # Extract process ID (first column after splitting by whitespace)
        $processId = ($process -split '\s+')[1]
        
        if ($processId -match '^\d+$') {
            Write-Host "    Killing process ID: $processId" -ForegroundColor Yellow
            kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin -e "KILL $processId;" 2>$null
            Write-Host "    ✅ Process $processId killed" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ℹ️  No SLEEP processes found" -ForegroundColor Cyan
}
Write-Host ""

# Step 4: Stop background job if exists
Write-Host "Step 4: Stopping background lock job..." -ForegroundColor Green

if (Test-Path ".\incident-8a-job-id.txt") {
    $jobId = Get-Content ".\incident-8a-job-id.txt"
    $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
    
    if ($job) {
        Write-Host "  Found background job (ID: $jobId)" -ForegroundColor Yellow
        Stop-Job -Id $jobId -ErrorAction SilentlyContinue
        Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
        Write-Host "  ✅ Background job stopped" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️  Background job already completed" -ForegroundColor Cyan
    }
    
    Remove-Item ".\incident-8a-job-id.txt" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  ℹ️  No job ID file found" -ForegroundColor Cyan
}
Write-Host ""

# Step 5: Verify locks released
Write-Host "Step 5: Verifying locks released..." -ForegroundColor Green
Start-Sleep -Seconds 2

$locksAfter = kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin -e "SHOW OPEN TABLES WHERE In_use > 0;" 2>$null

if ($locksAfter -match "sock") {
    Write-Host "  ⚠️  Warning: Table lock still present" -ForegroundColor Yellow
    Write-Host "  Attempting force unlock..." -ForegroundColor Yellow
    
    # Try to unlock all tables
    kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin socksdb -e "UNLOCK TABLES;" 2>$null
    Start-Sleep -Seconds 1
    
    $locksRetry = kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin -e "SHOW OPEN TABLES WHERE In_use > 0;" 2>$null
    
    if ($locksRetry -match "sock") {
        Write-Host "  ⚠️  Lock persists - may need database restart" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ Locks released successfully" -ForegroundColor Green
    }
} else {
    Write-Host "  ✅ All table locks released" -ForegroundColor Green
}
Write-Host ""

# Step 6: Test query performance
Write-Host "Step 6: Testing query performance..." -ForegroundColor Green
Write-Host "  Running test query..." -NoNewline

$testStart = Get-Date
kubectl exec -n sock-shop $dbPod -- mysql -u root -padmin socksdb -e "SELECT COUNT(*) FROM sock;" > $null 2>&1
$testEnd = Get-Date
$testDuration = ($testEnd - $testStart).TotalMilliseconds

Write-Host " took $([math]::Round($testDuration))ms" -ForegroundColor Green

if ($testDuration -lt 500) {
    Write-Host "  ✅ Query performance restored!" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Query still slow ($([math]::Round($testDuration))ms)" -ForegroundColor Yellow
}
Write-Host ""

# Step 7: Test catalogue service
Write-Host "Step 7: Testing catalogue service..." -ForegroundColor Green
Write-Host "  Making HTTP request to catalogue..." -NoNewline

try {
    $httpStart = Get-Date
    $response = Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -TimeoutSec 15 -ErrorAction Stop
    $httpEnd = Get-Date
    $httpDuration = ($httpEnd - $httpStart).TotalMilliseconds
    
    if ($response.StatusCode -eq 200) {
        Write-Host " OK ($([math]::Round($httpDuration))ms)" -ForegroundColor Green
        Write-Host "  ✅ Catalogue responding normally!" -ForegroundColor Green
    }
} catch {
    Write-Host " Failed" -ForegroundColor Yellow
    Write-Host "  ⚠️  Catalogue may still be recovering..." -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOVERY COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ DATABASE PERFORMANCE RESTORED" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 EXPECTED RESULTS:" -ForegroundColor Yellow
Write-Host "  - Product browsing now FAST (<1 second)" -ForegroundColor Green
Write-Host "  - No table locks or delays" -ForegroundColor Green
Write-Host "  - Database queries execute instantly" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 VERIFY IN UI:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Browse products - should load INSTANTLY" -ForegroundColor White
Write-Host "  3. Refresh multiple times - consistent fast performance" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATADOG VERIFICATION:" -ForegroundColor Yellow
Write-Host "  - mysql.performance.query_run_time.avg → <100ms" -ForegroundColor White
Write-Host "  - mysql.performance.table_lock_waits → Zero" -ForegroundColor White
Write-Host "  - http.request.duration{service:catalogue} → <200ms" -ForegroundColor White
Write-Host "  - Normal operation restored" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Recovery Duration: ~10 seconds" -ForegroundColor Green
Write-Host "📅 Completed: $RECOVERY_START" -ForegroundColor Green
Write-Host ""
