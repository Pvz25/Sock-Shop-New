# INCIDENT-8: Database Performance Degradation (SLOWNESS VERSION)
# Simulates catalogue database slowness causing product browsing delays
# This creates LATENCY, not a crash

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT-8: Database Performance SLOWNESS" -ForegroundColor Cyan
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

# Step 2: Apply MODERATE resource constraints (not too severe)
Write-Host "Step 2: Applying MODERATE resource constraints to catalogue-db..." -ForegroundColor Green
Write-Host "  - CPU Limit: 200m (0.2 cores) - MODERATE constraint" -ForegroundColor Yellow
Write-Host "  - Memory Limit: 256Mi" -ForegroundColor Yellow
Write-Host "  - CPU Request: 100m" -ForegroundColor Yellow
Write-Host "  - Memory Request: 128Mi" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  This will cause SLOWNESS, not a crash" -ForegroundColor Yellow
Write-Host ""

kubectl set resources deployment/catalogue-db -n sock-shop `
  --limits=cpu=200m,memory=256Mi `
  --requests=cpu=100m,memory=128Mi

Write-Host ""
Write-Host "✅ Resource constraints applied!" -ForegroundColor Green
Write-Host ""

# Step 3: Wait for rollout
Write-Host "Step 3: Waiting for pod restart..." -ForegroundColor Green
kubectl rollout status deployment/catalogue-db -n sock-shop --timeout=60s
Write-Host ""

# Step 4: Wait for database to warm up
Write-Host "Step 4: Waiting 10 seconds for database to warm up..." -ForegroundColor Green
Start-Sleep -Seconds 10
Write-Host ""

# Step 5: Verify new pod
Write-Host "Step 5: Verifying new pod with constraints..." -ForegroundColor Green
kubectl get pods -n sock-shop -l name=catalogue-db
Write-Host ""

Write-Host "New resource limits:" -ForegroundColor White
kubectl get deployment -n sock-shop catalogue-db -o jsonpath='{.spec.template.spec.containers[0].resources}' | ConvertFrom-Json | ConvertTo-Json
Write-Host ""
Write-Host ""

# Step 6: Generate some load to trigger slowness
Write-Host "Step 6: Generating initial load to trigger CPU usage..." -ForegroundColor Green
Write-Host "  Making 5 rapid requests to catalogue..." -ForegroundColor White

for ($i = 1; $i -le 5; $i++) {
    Write-Host "  Request $i..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:2025/catalogue" -TimeoutSec 15 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host " OK (took $($response.ResponseTime)ms)" -ForegroundColor Green
        }
    } catch {
        Write-Host " Slow/Timeout" -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 500
}
Write-Host ""

# Instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INCIDENT ACTIVATED!" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 USER IMPACT:" -ForegroundColor Yellow
Write-Host "  - Product browsing is now SLOWER (2-5 seconds)" -ForegroundColor Yellow
Write-Host "  - Database CPU constrained to 200m (20% of 1 core)" -ForegroundColor Yellow
Write-Host "  - Queries take longer but still complete" -ForegroundColor Yellow
Write-Host "  - You should see LATENCY, not blank pages" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 TEST IN UI NOW:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://localhost:2025" -ForegroundColor White
Write-Host "  2. Click 'Catalogue' - notice SLOWER load (2-5 seconds)" -ForegroundColor White
Write-Host "  3. Products WILL appear, just slower" -ForegroundColor Green
Write-Host "  4. Refresh multiple times - consistent slowness" -ForegroundColor White
Write-Host "  5. Click on products - details load slowly" -ForegroundColor White
Write-Host ""
Write-Host "📊 WHAT YOU'LL SEE:" -ForegroundColor Yellow
Write-Host "  ✅ Products DO load (not blank)" -ForegroundColor Green
Write-Host "  ⏳ But they take 2-5 seconds (was <1 second)" -ForegroundColor Yellow
Write-Host "  🐌 Noticeable delay, frustrating experience" -ForegroundColor Yellow
Write-Host ""
Write-Host "📊 DATADOG SIGNALS TO WATCH:" -ForegroundColor Yellow
Write-Host "  - kubernetes.cpu.usage.total (catalogue-db) → 80-100% of 200m limit" -ForegroundColor White
Write-Host "  - kubernetes.cpu.limits (catalogue-db) → 200m" -ForegroundColor White
Write-Host "  - catalogue service response time → 2000-5000ms" -ForegroundColor White
Write-Host "  - Queries still succeed, just slower" -ForegroundColor White
Write-Host ""
Write-Host "🔧 TO RECOVER:" -ForegroundColor Yellow
Write-Host "  Run: .\incident-8-recover.ps1" -ForegroundColor White
Write-Host ""
Write-Host "⏱️  Incident Duration: Ongoing until recovery" -ForegroundColor Yellow
Write-Host "📅 Started: $INCIDENT_START" -ForegroundColor Yellow
Write-Host ""
Write-Host "💡 TIP: Keep refreshing the catalogue page to feel the slowness!" -ForegroundColor Cyan
Write-Host ""
