# INCIDENT-8: Database Performance Degradation
# Simulates catalogue database resource exhaustion causing slow product browsing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8: Database Performance Degradation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Record incident start time
$INCIDENT_START = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Write-Host "📅 INCIDENT START: $INCIDENT_START" -ForegroundColor Yellow
Write-Host ""

# Step 1: Verify current state
Write-Host "Step 1: Verifying baseline state..." -ForegroundColor Green
Write-Host ""

Write-Host "Current catalogue-db resources:" -ForegroundColor White
kubectl get deployment -n sock-shop catalogue-db -o jsonpath='{.spec.template.spec.containers[0].resources}' | Write-Host
Write-Host ""
Write-Host ""

# Step 2: Apply severe resource constraints
Write-Host "Step 2: Applying severe resource constraints to catalogue-db..." -ForegroundColor Green
Write-Host "  - CPU Limit: 50m (0.05 cores) - EXTREMELY LIMITED" -ForegroundColor Yellow
Write-Host "  - Memory Limit: 128Mi" -ForegroundColor Yellow
Write-Host "  - CPU Request: 25m" -ForegroundColor Yellow
Write-Host "  - Memory Request: 64Mi" -ForegroundColor Yellow
Write-Host ""

kubectl set resources deployment/catalogue-db -n sock-shop `
  --limits=cpu=50m,memory=128Mi `
  --requests=cpu=25m,memory=64Mi

Write-Host ""
Write-Host "✅ Resource constraints applied!" -ForegroundColor Green
Write-Host ""

# Step 3: Wait for rollout
Write-Host "Step 3: Waiting for pod restart..." -ForegroundColor Green
kubectl rollout status deployment/catalogue-db -n sock-shop --timeout=60s
Write-Host ""

# Step 4: Verify new pod
Write-Host "Step 4: Verifying new pod with constraints..." -ForegroundColor Green
kubectl get pods -n sock-shop -l name=catalogue-db
Write-Host ""

Write-Host "New resource limits:" -ForegroundColor White
kubectl get deployment -n sock-shop catalogue-db -o jsonpath='{.spec.template.spec.containers[0].resources}' | ConvertFrom-Json | ConvertTo-Json
Write-Host ""
Write-Host ""

# Step 5: Instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT ACTIVATED!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 USER IMPACT:" -ForegroundColor Yellow
Write-Host "  - Product browsing is now EXTREMELY SLOW (5-10 seconds)" -ForegroundColor Red
Write-Host "  - Frequent timeouts and errors" -ForegroundColor Red
Write-Host "  - Database CPU throttled to 50m (5% of 1 core)" -ForegroundColor Red
Write-Host ""
Write-Host "🌐 TEST IN UI:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Click 'Catalogue' or browse products" -ForegroundColor White
Write-Host "  3. Notice SLOW page loads (5-10 seconds)" -ForegroundColor White
Write-Host "  4. Refresh multiple times - may see errors" -ForegroundColor White
Write-Host ""
Write-Host "📊 DATADOG SIGNALS TO WATCH:" -ForegroundColor Yellow
Write-Host "  - kubernetes.cpu.usage.total (catalogue-db) → 100%" -ForegroundColor White
Write-Host "  - kubernetes.cpu.limits (catalogue-db) → 50m" -ForegroundColor White
Write-Host "  - catalogue service response time → 5000ms+" -ForegroundColor White
Write-Host "  - HTTP 500/504 errors increasing" -ForegroundColor White
Write-Host ""
Write-Host "🔧 TO RECOVER:" -ForegroundColor Yellow
Write-Host "  Run: .\incident-8-recover.ps1" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Incident Duration: Ongoing until recovery" -ForegroundColor Yellow
Write-Host "📅 Started: $INCIDENT_START" -ForegroundColor Yellow
Write-Host ""
