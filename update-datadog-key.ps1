# Update Datadog API Key
# Created: 2025-11-09
# Purpose: Update Datadog secret with real API key

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Datadog API Key Update Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Prompt for API key
Write-Host "Paste your Datadog API key (it will be hidden): " -ForegroundColor Yellow -NoNewline
$apiKey = Read-Host -AsSecureString
$apiKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey))

if ([string]::IsNullOrWhiteSpace($apiKeyPlain)) {
    Write-Host "`n❌ ERROR: No API key provided!`n" -ForegroundColor Red
    exit 1
}

# Validate length (Datadog keys are 32 characters)
if ($apiKeyPlain.Length -ne 32) {
    Write-Host "`n⚠️  WARNING: Datadog API keys are typically 32 characters." -ForegroundColor Yellow
    Write-Host "   Your key is $($apiKeyPlain.Length) characters." -ForegroundColor Yellow
    Write-Host "   Continuing anyway...`n" -ForegroundColor Yellow
}

Write-Host "`n[1/4] Deleting old secret..." -ForegroundColor Cyan
kubectl delete secret datadog-secret -n datadog 2>&1 | Out-Null

Write-Host "[2/4] Creating new secret with your API key..." -ForegroundColor Cyan
kubectl create secret generic datadog-secret `
    --from-literal=api-key=$apiKeyPlain `
    -n datadog

if ($LASTEXITCODE -eq 0) {
    Write-Host "      ✅ Secret created successfully`n" -ForegroundColor Green
} else {
    Write-Host "      ❌ Failed to create secret`n" -ForegroundColor Red
    exit 1
}

Write-Host "[3/4] Restarting Datadog agents..." -ForegroundColor Cyan
kubectl rollout restart daemonset/datadog-agent -n datadog
kubectl rollout restart deployment/datadog-agent-cluster-agent -n datadog
Write-Host "      ✅ Agents restarting`n" -ForegroundColor Green

Write-Host "[4/4] Waiting 30 seconds for agents to restart..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Checking agent status..." -ForegroundColor Yellow
kubectl get pods -n datadog

Write-Host "`nChecking for successful log transmission..." -ForegroundColor Yellow
$logs = kubectl logs -n datadog -l app=datadog-agent --tail=100 2>&1 | Select-String -Pattern "Successfully posted payload|Sent|successfully|OK" | Select-Object -First 5

if ($logs) {
    Write-Host "`n✅ SUCCESS! Datadog is sending data:`n" -ForegroundColor Green
    $logs | ForEach-Object { Write-Host "   $_" -ForegroundColor White }
} else {
    Write-Host "`n⚠️  No success messages found yet. Checking for errors..." -ForegroundColor Yellow
    kubectl logs -n datadog -l app=datadog-agent --tail=20 | Select-String -Pattern "error|ERROR|invalid|403"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Go to https://app.datadoghq.com/logs" -ForegroundColor White
Write-Host "2. Filter by: kube_namespace:sock-shop" -ForegroundColor White
Write-Host "3. You should see logs appearing within 1-2 minutes" -ForegroundColor White
Write-Host "`n" -ForegroundColor White
