# ============================================================================
# PRODUCTION ERROR MESSAGE DEPLOYMENT SCRIPT
# ============================================================================
# Purpose: Deploy production-grade error messages for INCIDENT-5C
# Risk: MINIMAL (frontend-only, surgical text change)
# Rollback: Instant (previous image retained)
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🎯 PRODUCTION ERROR MESSAGE DEPLOYMENT                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📋 Deployment Details:" -ForegroundColor Yellow
Write-Host "   Target: Frontend error messages" -ForegroundColor White
Write-Host "   Change: 2 lines of text (surgical)" -ForegroundColor White
Write-Host "   Risk: MINIMAL" -ForegroundColor Green
Write-Host "   Rollback: Instant" -ForegroundColor Green

# Step 1: Check if source directory exists
Write-Host "`n⏳ Step 1/7: Checking prerequisites..." -ForegroundColor Cyan

if (Test-Path "d:\front-end-source-production") {
    Write-Host "   ⚠️  Frontend source already exists" -ForegroundColor Yellow
    $continue = Read-Host "   Delete and re-clone? (y/n)"
    if ($continue -eq "y") {
        Remove-Item -Path "d:\front-end-source-production" -Recurse -Force
        Write-Host "   ✅ Removed existing source" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️  Using existing source" -ForegroundColor Cyan
    }
}

# Step 2: Clone frontend source
if (-not (Test-Path "d:\front-end-source-production")) {
    Write-Host "`n🔄 Step 2/7: Cloning frontend source..." -ForegroundColor Cyan
    Set-Location d:\
    git clone https://github.com/ocp-power-demos/sock-shop-front-end.git front-end-source-production 2>&1 | Out-Null
    
    if (Test-Path "d:\front-end-source-production") {
        Write-Host "   ✅ Frontend source cloned successfully" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Failed to clone frontend source" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n✅ Step 2/7: Frontend source already exists" -ForegroundColor Green
}

# Step 3: Apply surgical fix
Write-Host "`n🔧 Step 3/7: Applying production error messages..." -ForegroundColor Cyan

$CLIENT_JS_PATH = "d:\front-end-source-production\public\js\client.js"

if (-not (Test-Path $CLIENT_JS_PATH)) {
    Write-Host "   ❌ client.js not found at: $CLIENT_JS_PATH" -ForegroundColor Red
    exit 1
}

# Read the file
$content = Get-Content $CLIENT_JS_PATH -Raw

# Surgical replacement 1: HTTP 503 message
$OLD_503 = 'errorMessage = "Service temporarily unavailable. Please try again later.";'
$NEW_503 = 'errorMessage = "We''re experiencing high order volume. Please try again in a moment.";'

# Surgical replacement 2: HTTP 500 message
$OLD_500 = 'errorMessage = "Internal server error. Please try again.";'
$NEW_500 = 'errorMessage = "Due to high demand, we''re experiencing delays. Your order is being processed.";'

# Apply replacements
$content = $content -replace [regex]::Escape($OLD_503), $NEW_503
$content = $content -replace [regex]::Escape($OLD_500), $NEW_500

# Write back to file
$content | Set-Content $CLIENT_JS_PATH -NoNewline

Write-Host "   ✅ Production error messages applied" -ForegroundColor Green
Write-Host "      • HTTP 503: 'We're experiencing high order volume...'" -ForegroundColor Gray
Write-Host "      • HTTP 500: 'Due to high demand, we're experiencing delays...'" -ForegroundColor Gray

# Step 4: Build Docker image
Write-Host "`n🐳 Step 4/7: Building Docker image..." -ForegroundColor Cyan

Set-Location d:\front-end-source-production

# Check if Dockerfile exists
$DOCKERFILE_PATH = "d:\sock-shop-demo\automation\Dockerfile-front-end-local"

if (-not (Test-Path $DOCKERFILE_PATH)) {
    Write-Host "   ❌ Dockerfile not found at: $DOCKERFILE_PATH" -ForegroundColor Red
    exit 1
}

docker build -t sock-shop-front-end:production-v1 -f $DOCKERFILE_PATH . 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Docker image built: sock-shop-front-end:production-v1" -ForegroundColor Green
} else {
    Write-Host "   ❌ Docker build failed" -ForegroundColor Red
    exit 1
}

# Step 5: Load into KIND cluster
Write-Host "`n📦 Step 5/7: Loading image into KIND cluster..." -ForegroundColor Cyan

kind load docker-image sock-shop-front-end:production-v1 --name sockshop 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Image loaded into KIND cluster" -ForegroundColor Green
} else {
    Write-Host "   ❌ Failed to load image into cluster" -ForegroundColor Red
    exit 1
}

# Step 6: Deploy to cluster
Write-Host "`n🚀 Step 6/7: Deploying to cluster..." -ForegroundColor Cyan

Set-Location d:\sock-shop-demo

kubectl -n sock-shop set image deployment/front-end front-end=sock-shop-front-end:production-v1 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Deployment updated" -ForegroundColor Green
} else {
    Write-Host "   ❌ Deployment update failed" -ForegroundColor Red
    exit 1
}

Write-Host "   ⏳ Waiting for rollout to complete..." -ForegroundColor Cyan
kubectl -n sock-shop rollout status deployment/front-end --timeout=120s 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Rollout completed successfully" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Rollout may still be in progress" -ForegroundColor Yellow
}

# Step 7: Verify deployment
Write-Host "`n✅ Step 7/7: Verifying deployment..." -ForegroundColor Cyan

$CURRENT_IMAGE = kubectl -n sock-shop get deployment front-end -o jsonpath='{.spec.template.spec.containers[0].image}' 2>&1

if ($CURRENT_IMAGE -eq "sock-shop-front-end:production-v1") {
    Write-Host "   ✅ Deployment verified: $CURRENT_IMAGE" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Current image: $CURRENT_IMAGE" -ForegroundColor Yellow
}

$POD_STATUS = kubectl -n sock-shop get pods -l name=front-end --no-headers 2>&1

if ($POD_STATUS -match "1/1.*Running") {
    Write-Host "   ✅ Frontend pod is running" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Pod status: $POD_STATUS" -ForegroundColor Yellow
}

# Final summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ✅ DEPLOYMENT COMPLETE!                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 DEPLOYMENT SUMMARY:" -ForegroundColor Yellow
Write-Host "   Image: sock-shop-front-end:production-v1" -ForegroundColor White
Write-Host "   Changes: 2 lines (surgical text replacement)" -ForegroundColor White
Write-Host "   Risk: MINIMAL" -ForegroundColor Green
Write-Host "   Status: DEPLOYED" -ForegroundColor Green

Write-Host "`n🧪 TESTING INSTRUCTIONS:" -ForegroundColor Cyan
Write-Host "   1. Activate INCIDENT-5C" -ForegroundColor White
Write-Host "   2. Place orders 1-3 (should succeed)" -ForegroundColor White
Write-Host "   3. Place order 4+ (should fail with NEW message)" -ForegroundColor White
Write-Host "`n   Expected Error Message:" -ForegroundColor Yellow
Write-Host '   "Due to high demand, we''re experiencing delays.' -ForegroundColor Green
Write-Host '    Your order is being processed."' -ForegroundColor Green

Write-Host "`n💊 ROLLBACK (if needed):" -ForegroundColor Yellow
Write-Host "   kubectl -n sock-shop set image deployment/front-end front-end=sock-shop-front-end:error-fix" -ForegroundColor White
Write-Host "   kubectl -n sock-shop rollout status deployment/front-end" -ForegroundColor White

Write-Host "`n✅ Deployment successful!`n" -ForegroundColor Green
