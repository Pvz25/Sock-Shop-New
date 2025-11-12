# ============================================================================
# Repository Cleanup Script - November 12, 2025
# ============================================================================
# Description: Safely removes redundant and empty files from sock-shop-demo
# Based on: REPOSITORY-CLEANUP-ANALYSIS.md
# Safety: Creates backup before deletion
# ============================================================================

param(
    [switch]$DryRun,
    [switch]$CreateBackup
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Repository Cleanup Script - November 12, 2025        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`n🔍 DRY RUN MODE - No files will be deleted" -ForegroundColor Yellow
} else {
    Write-Host "`n⚠️  LIVE MODE - Files will be permanently deleted" -ForegroundColor Red
}

# Create backup if requested
if ($CreateBackup -and -not $DryRun) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = "cleanup-backup-$timestamp"
    Write-Host "`n📦 Creating backup in: $backupDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$deletedCount = 0
$totalSize = 0

# Category 1: Empty Files
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  Category 1: Empty Files (16 files)                      ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$emptyFiles = @(
    "INCIDENT-5C-DATADOG-VERIFICATION.md",
    "INCIDENT-5C-ORDER-PROCESSING-BLOCKED.md",
    "INCIDENT-8-ANALYSIS.md",
    "INCIDENT-8-QUICK-START.md",
    "INCIDENT-8-REAL-SOLUTION.md",
    "INCIDENT-8-vs-8A-COMPARISON.md",
    "INCIDENT-8A-DATABASE-SLOWNESS-CORRECT.md",
    "INCIDENT-8B-DATABASE-LOAD-TESTING.md",
    "SYSTEM-HEALTH-REPORT.md",
    "incident-8-activate-slowness.ps1",
    "incident-8-activate.ps1",
    "incident-8-recover.ps1",
    "incident-8a-activate.ps1",
    "incident-8a-recover.ps1",
    "incident-8b-activate.ps1",
    "incident-8b-recover.ps1"
)

foreach ($file in $emptyFiles) {
    $filePath = Join-Path -Path "." -ChildPath $file
    if (Test-Path $filePath) {
        $fileInfo = Get-Item $filePath
        $totalSize += $fileInfo.Length
        
        if ($DryRun) {
            Write-Host "   [DRY RUN] Would delete: $file" -ForegroundColor Gray
        } else {
            if ($CreateBackup) {
                Copy-Item $filePath -Destination $backupDir -ErrorAction SilentlyContinue
            }
            Remove-Item $filePath -Force
            Write-Host "   ✅ Deleted: $file" -ForegroundColor Green
        }
        $deletedCount++
    }
}

# Category 2: Redundant INCIDENT-5C Docs
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  Category 2: Redundant INCIDENT-5C Docs (21 files)       ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$incident5cRedundant = @(
    "INCIDENT-5C-COMPLETE-GUIDE.md",
    "INCIDENT-5C-DOCUMENTATION-INDEX.md",
    "INCIDENT-5C-FINAL-OVERVIEW.md",
    "INCIDENT-5C-FINAL-VERDICT.md",
    "INCIDENT-5C-IMPLEMENTATION-PLAN.md",
    "INCIDENT-5C-PRE-EXECUTION-HEALTH-CHECK.md",
    "INCIDENT-5C-QUICK-REFERENCE.md",
    "INCIDENT-5C-READY-FOR-RETEST-2025-11-12.md",
    "INCIDENT-5C-READY-TO-EXECUTE.md",
    "INCIDENT-5C-SUMMARY.md",
    "INCIDENT-5C-DATADOG-QUERIES.md",
    "INCIDENT-5C-DATADOG-WORKING-QUERIES.md",
    "INCIDENT-5C-EXECUTION-REPORT-2025-11-12.md",
    "INCIDENT-5C-FAILURE-ANALYSIS-2025-11-12.md",
    "INCIDENT-5C-FIX-SUMMARY-2025-11-12.md",
    "INCIDENT-5C-FRONTEND-FIX-COMPLETE.md",
    "incident-5c-execute.ps1",
    "incident-5c-execute-fixed-v2.ps1"
)

foreach ($file in $incident5cRedundant) {
    $filePath = Join-Path -Path "." -ChildPath $file
    if (Test-Path $filePath) {
        $fileInfo = Get-Item $filePath
        $totalSize += $fileInfo.Length
        
        if ($DryRun) {
            Write-Host "   [DRY RUN] Would delete: $file" -ForegroundColor Gray
        } else {
            if ($CreateBackup) {
                Copy-Item $filePath -Destination $backupDir -ErrorAction SilentlyContinue
            }
            Remove-Item $filePath -Force
            Write-Host "   ✅ Deleted: $file" -ForegroundColor Green
        }
        $deletedCount++
    }
}

# Category 3: Redundant INCIDENT-5 Docs
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  Category 3: Redundant INCIDENT-5 Docs (10 files)        ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$incident5Redundant = @(
    "INCIDENT-5-ANALYSIS.md",
    "INCIDENT-5-CORRECTED-QUERIES.md",
    "INCIDENT-5-DATADOG-QUICK-GUIDE.md",
    "INCIDENT-5-DATADOG-VERIFICATION.md",
    "INCIDENT-5-DATADOG-VERIFIED-GUIDE.md",
    "INCIDENT-5-EXPLANATION.md",
    "INCIDENT-5-FIXES-SUMMARY.md",
    "INCIDENT-5-TEST-EXECUTION-REPORT.md",
    "INCIDENT-5A-QUEUE-BLOCKAGE.md"
)

foreach ($file in $incident5Redundant) {
    $filePath = Join-Path -Path "." -ChildPath $file
    if (Test-Path $filePath) {
        $fileInfo = Get-Item $filePath
        $totalSize += $fileInfo.Length
        
        if ($DryRun) {
            Write-Host "   [DRY RUN] Would delete: $file" -ForegroundColor Gray
        } else {
            if ($CreateBackup) {
                Copy-Item $filePath -Destination $backupDir -ErrorAction SilentlyContinue
            }
            Remove-Item $filePath -Force
            Write-Host "   ✅ Deleted: $file" -ForegroundColor Green
        }
        $deletedCount++
    }
}

# Category 4: Redundant INCIDENT-6 Docs
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  Category 4: Redundant INCIDENT-6 Docs (7 files)         ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$incident6Redundant = @(
    "INCIDENT-6-CORRECTED-QUERIES.md",
    "INCIDENT-6-DOCUMENTATION-COMPLETE.md",
    "INCIDENT-6-NOV10-LOGS-MISSING-ANALYSIS.md",
    "INCIDENT-6-QUERY-UPDATE-SUMMARY.md",
    "INCIDENT-6-READY-TO-TEST.md",
    "INCIDENT-6-TIMELINE-UPDATED.md",
    "incident-6-timer.ps1"
)

foreach ($file in $incident6Redundant) {
    $filePath = Join-Path -Path "." -ChildPath $file
    if (Test-Path $filePath) {
        $fileInfo = Get-Item $filePath
        $totalSize += $fileInfo.Length
        
        if ($DryRun) {
            Write-Host "   [DRY RUN] Would delete: $file" -ForegroundColor Gray
        } else {
            if ($CreateBackup) {
                Copy-Item $filePath -Destination $backupDir -ErrorAction SilentlyContinue
            }
            Remove-Item $filePath -Force
            Write-Host "   ✅ Deleted: $file" -ForegroundColor Green
        }
        $deletedCount++
    }
}

# Category 5: Redundant INCIDENT-7 Docs
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  Category 5: Redundant INCIDENT-7 Docs (2 files)         ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

$incident7Redundant = @(
    "INCIDENT-7-DATADOG-QUERIES-CORRECTED.md",
    "INCIDENT-7-DATADOG-QUERIES-LATEST.md"
)

foreach ($file in $incident7Redundant) {
    $filePath = Join-Path -Path "." -ChildPath $file
    if (Test-Path $filePath) {
        $fileInfo = Get-Item $filePath
        $totalSize += $fileInfo.Length
        
        if ($DryRun) {
            Write-Host "   [DRY RUN] Would delete: $file" -ForegroundColor Gray
        } else {
            if ($CreateBackup) {
                Copy-Item $filePath -Destination $backupDir -ErrorAction SilentlyContinue
            }
            Remove-Item $filePath -Force
            Write-Host "   ✅ Deleted: $file" -ForegroundColor Green
        }
        $deletedCount++
    }
}

# Summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    CLEANUP SUMMARY                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "`n🔍 DRY RUN COMPLETE" -ForegroundColor Yellow
    Write-Host "   Files that would be deleted: $deletedCount" -ForegroundColor White
    Write-Host "   Total size: $([math]::Round($totalSize / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "`n   Run without -DryRun to perform actual deletion" -ForegroundColor Yellow
} else {
    Write-Host "`n✅ CLEANUP COMPLETE" -ForegroundColor Green
    Write-Host "   Files deleted: $deletedCount" -ForegroundColor White
    Write-Host "   Total size freed: $([math]::Round($totalSize / 1KB, 2)) KB" -ForegroundColor White
    if ($CreateBackup) {
        Write-Host "   Backup created in: $backupDir" -ForegroundColor Cyan
    }
}

Write-Host "`n📋 REMAINING CORE FILES:" -ForegroundColor Cyan
Write-Host "   • INCIDENT-1 through INCIDENT-8 core definitions" -ForegroundColor White
Write-Host "   • INCIDENT-5C-DEFINITIVE-REQUIREMENT-ANALYSIS.md" -ForegroundColor White
Write-Host "   • INCIDENT-5C-TEST-EXECUTION-REPORT.md (Nov 11 timeline)" -ForegroundColor White
Write-Host "   • INCIDENT-5C-EXECUTION-ANALYSIS-2025-11-12-FINAL.md (Nov 12 timeline)" -ForegroundColor White
Write-Host "   • INCIDENT-6-DATADOG-OBSERVABILITY-GUIDE.md" -ForegroundColor White
Write-Host "   • INCIDENT-6-TEST-NOV11-SUMMARY.md (timeline)" -ForegroundColor White
Write-Host "   • INCIDENT-7-DATADOG-OBSERVABILITY-GUIDE.md" -ForegroundColor White
Write-Host "   • INCIDENT-7-TEST-EXECUTION-REPORT.md (timeline)" -ForegroundColor White
Write-Host "   • All active execution scripts" -ForegroundColor White
Write-Host "   • Core documentation (README, ARCHITECTURE, etc.)" -ForegroundColor White

Write-Host "`n✅ Repository cleanup analysis complete!" -ForegroundColor Green
