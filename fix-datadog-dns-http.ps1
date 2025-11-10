# Fix Datadog DNS Issue by Forcing HTTP Transport
# This ensures logs are sent via HTTPS instead of TCP which fails DNS resolution

Write-Host "=== Fixing Datadog DNS Issue ===" -ForegroundColor Cyan

# Upgrade Datadog with explicit HTTP configuration
Write-Host "`nUpgrading Datadog agent with HTTP logs transport..." -ForegroundColor Yellow

helm upgrade datadog-agent datadog/datadog `
  --namespace datadog `
  --reuse-values `
  --set datadog.logs.useHTTP=true `
  --set datadog.logs.config.force_use_http=true

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Helm upgrade successful" -ForegroundColor Green
    
    Write-Host "`nWaiting for pods to roll out..." -ForegroundColor Yellow
    kubectl rollout status daemonset/datadog-agent -n datadog --timeout=180s
    
    Write-Host "`nChecking new pod configuration..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    $agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
    Write-Host "Agent pod: $agentPod" -ForegroundColor Cyan
    
    Write-Host "`nVerifying HTTP configuration:" -ForegroundColor Yellow
    kubectl exec -n datadog $agentPod -c agent -- env 2>$null | Select-String -Pattern "DD_LOGS"
    
    Write-Host "`n=== Verification ===" -ForegroundColor Cyan
    Write-Host "Wait 2-3 minutes, then check:" -ForegroundColor White
    Write-Host "  kubectl exec -n datadog $agentPod -c agent -- agent status | Select-String -Pattern 'Logs Agent' -Context 10" -ForegroundColor Gray
    
} else {
    Write-Host "❌ Helm upgrade failed" -ForegroundColor Red
}
