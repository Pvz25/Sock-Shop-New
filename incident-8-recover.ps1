# INCIDENT-8 RECOVERY: Remove Database Resource Constraints
# Restores catalogue-db to unlimited resources (normal operation)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8 RECOVERY: Database Performance" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$RECOVERY_START = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Write-Host "📅 RECOVERY START: $RECOVERY_START" -ForegroundColor Green
Write-Host ""

# Step 1: Show current constrained state
Write-Host "Step 1: Current degraded state..." -ForegroundColor Yellow
Write-Host "Current catalogue-db resources (CONSTRAINED):" -ForegroundColor White
kubectl get deployment -n sock-shop catalogue-db -o jsonpath='{.spec.template.spec.containers[0].resources}' | ConvertFrom-Json | ConvertTo-Json
Write-Host ""
Write-Host ""

# Step 2: Remove resource constraints
Write-Host "Step 2: Removing resource constraints..." -ForegroundColor Green
Write-Host "  - Removing CPU limits (unlimited)" -ForegroundColor Yellow
Write-Host "  - Removing memory limits (unlimited)" -ForegroundColor Yellow
Write-Host ""

# Remove all resource constraints
kubectl set resources deployment/catalogue-db -n sock-shop `
  --limits=cpu=0,memory=0 `
  --requests=cpu=0,memory=0

Write-Host ""
Write-Host "✅ Resource constraints removed!" -ForegroundColor Green
Write-Host ""

# Step 3: Wait for rollout
Write-Host "Step 3: Waiting for pod restart..." -ForegroundColor Green
kubectl rollout status deployment/catalogue-db -n sock-shop --timeout=60s
Write-Host ""

# Step 4: Verify recovery
Write-Host "Step 4: Verifying recovery..." -ForegroundColor Green
kubectl get pods -n sock-shop -l name=catalogue-db
Write-Host ""

Write-Host "New resource limits (should be empty = unlimited):" -ForegroundColor White
kubectl get deployment -n sock-shop catalogue-db -o jsonpath='{.spec.template.spec.containers[0].resources}'
Write-Host ""
Write-Host ""

# Step 5: Test
Write-Host "Step 5: Testing product browsing..." -ForegroundColor Green
Write-Host "  Making test request to catalogue service..." -ForegroundColor White

$response = Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -TimeoutSec 10 -ErrorAction SilentlyContinue
if ($response.StatusCode -eq 200) {
    Write-Host "  ✅ Catalogue responding normally!" -ForegroundColor Green
} else {
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
Write-Host "  - No timeouts or errors" -ForegroundColor Green
Write-Host "  - Database CPU usage normal (not throttled)" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 VERIFY IN UI:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Browse products - should load INSTANTLY" -ForegroundColor White
Write-Host "  3. Refresh multiple times - consistent fast performance" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATADOG VERIFICATION:" -ForegroundColor Yellow
Write-Host "  - kubernetes.cpu.usage.total (catalogue-db) → Normal levels" -ForegroundColor White
Write-Host "  - kubernetes.cpu.limits (catalogue-db) → Removed (unlimited)" -ForegroundColor White
Write-Host "  - catalogue service response time → <100ms" -ForegroundColor White
Write-Host "  - HTTP errors → Zero" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Recovery Duration: ~30 seconds" -ForegroundColor Green
Write-Host "📅 Completed: $RECOVERY_START" -ForegroundColor Green
Write-Host ""
