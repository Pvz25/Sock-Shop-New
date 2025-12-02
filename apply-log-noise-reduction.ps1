# apply-log-noise-reduction.ps1
# Purpose: Apply Datadog log filtering to reduce health check noise
# Created: November 30, 2025
#
# This script applies log processing rules to exclude:
# - Health check logs (method=Health)
# - RabbitMQ exporter routine updates
# - MongoDB WiredTiger routine messages
#
# Expected Result: ~90% log volume reduction

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " DATADOG LOG NOISE REDUCTION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Processing rules in JSON format for DD_LOGS_CONFIG_PROCESSING_RULES
$processingRules = @"
[
  {
    "type": "exclude_at_match",
    "name": "exclude_go_health_checks",
    "pattern": "method=Health"
  },
  {
    "type": "exclude_at_match",
    "name": "exclude_rabbitmq_metrics_updates",
    "pattern": "Metrics updated"
  },
  {
    "type": "exclude_at_match",
    "name": "exclude_mongodb_wiredtiger",
    "pattern": "WiredTiger message"
  },
  {
    "type": "exclude_at_match",
    "name": "exclude_health_endpoint",
    "pattern": "GET /health"
  }
]
"@

# Minify JSON for environment variable
$processingRulesMinified = ($processingRules | ConvertFrom-Json | ConvertTo-Json -Compress)

Write-Host "Step 1: Applying log processing rules to Datadog agent..." -ForegroundColor Yellow

# Apply the environment variable to the Datadog agent DaemonSet
kubectl -n datadog set env daemonset/datadog-agent "DD_LOGS_CONFIG_PROCESSING_RULES=$processingRulesMinified"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Processing rules applied successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to apply processing rules" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Waiting for Datadog agent rollout..." -ForegroundColor Yellow
kubectl -n datadog rollout status daemonset/datadog-agent --timeout=120s

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Datadog agent rollout complete" -ForegroundColor Green
} else {
    Write-Host "❌ Rollout timeout - checking pods..." -ForegroundColor Yellow
    kubectl get pods -n datadog -l app=datadog-agent
}

Write-Host ""
Write-Host "Step 3: Verifying configuration..." -ForegroundColor Yellow
$agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}'
Write-Host "Agent pod: $agentPod"

# Check environment variable is set
$envCheck = kubectl -n datadog exec $agentPod -c agent -- env | Select-String "DD_LOGS_CONFIG_PROCESSING_RULES"
if ($envCheck) {
    Write-Host "✅ Processing rules environment variable is set" -ForegroundColor Green
} else {
    Write-Host "⚠️ Could not verify environment variable" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " LOG NOISE REDUCTION APPLIED" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The following log patterns will now be EXCLUDED:" -ForegroundColor White
Write-Host "  - method=Health        (Go health checks)" -ForegroundColor Gray
Write-Host "  - Metrics updated      (RabbitMQ exporter)" -ForegroundColor Gray
Write-Host "  - WiredTiger message   (MongoDB routine)" -ForegroundColor Gray
Write-Host "  - GET /health          (HTTP health endpoints)" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected log volume reduction: ~90%" -ForegroundColor Green
Write-Host "Before: ~78 logs/minute (~4,680/hour)" -ForegroundColor Red
Write-Host "After:  ~8 logs/minute (~480/hour)" -ForegroundColor Green
Write-Host ""
Write-Host "Wait 2-3 minutes for changes to take effect," -ForegroundColor Yellow
Write-Host "then check Datadog UI to verify reduced log volume." -ForegroundColor Yellow
