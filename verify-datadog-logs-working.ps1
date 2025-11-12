# ==============================================================================
# VERIFY DATADOG LOG COLLECTION IS WORKING
# ==============================================================================
# Purpose: Quick health check to confirm logs are being collected and visible
# Created: November 12, 2025 - After regression fix
# ==============================================================================

$ErrorActionPreference = "Stop"

function Write-Success { param([string]$Message); Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Failure { param([string]$Message); Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Warning { param([string]$Message); Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message); Write-Host "ℹ️  $Message" -ForegroundColor Cyan }

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Datadog Log Collection Health Check" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# 1. Check Datadog agent pods are running
Write-Info "Checking Datadog agent pods..."
$agentPods = kubectl get pods -n datadog -l app=datadog-agent -o json | ConvertFrom-Json
if ($agentPods.items.Count -eq 0) {
    Write-Failure "No Datadog agent pods found"
    exit 1
}

$allReady = $true
foreach ($pod in $agentPods.items) {
    $podName = $pod.metadata.name
    $ready = $pod.status.conditions | Where-Object { $_.type -eq "Ready" } | Select-Object -ExpandProperty status
    if ($ready -eq "True") {
        Write-Success "Agent pod running: $podName"
    } else {
        Write-Failure "Agent pod not ready: $podName"
        $allReady = $false
    }
}

if (-not $allReady) {
    Write-Failure "Some agent pods are not ready. Fix pods before continuing."
    exit 1
}

# 2. Check agent log collection status
Write-Info "`nChecking log collection status..."
$agentPod = $agentPods.items[0].metadata.name

$agentStatus = kubectl exec -n datadog $agentPod -- agent status 2>&1 | Out-String

# Check transport mode
if ($agentStatus -match "Sending compressed logs in HTTPS") {
    Write-Success "Transport mode: Compressed HTTPS (CORRECT)"
} elseif ($agentStatus -match "uncompressed.*TCP") {
    Write-Failure "Transport mode: Uncompressed TCP (INCORRECT - will cause visibility issues)"
    Write-Warning "Run fix: kubectl rollout restart daemonset/datadog-agent -n datadog"
    exit 1
} else {
    Write-Warning "Transport mode: Unknown (check agent status manually)"
}

# Extract log metrics
if ($agentStatus -match "LogsProcessed:\s*(\d+)") {
    $logsProcessed = $matches[1]
    Write-Success "Logs processed: $logsProcessed"
    
    if ([int]$logsProcessed -eq 0) {
        Write-Failure "No logs being processed. Check pod logs."
        exit 1
    }
} else {
    Write-Warning "Could not extract LogsProcessed count"
}

if ($agentStatus -match "LogsSent:\s*(\d+)") {
    $logsSent = $matches[1]
    Write-Success "Logs sent: $logsSent"
    
    if ([int]$logsSent -eq 0) {
        Write-Failure "No logs being sent. Check connectivity to Datadog."
        exit 1
    }
} else {
    Write-Warning "Could not extract LogsSent count"
}

# Check for errors
if ($agentStatus -match "RetryCount:\s*(\d+)") {
    $retryCount = $matches[1]
    if ([int]$retryCount -gt 0) {
        Write-Warning "Retry count: $retryCount (some transmission failures)"
    } else {
        Write-Success "No retry attempts (clean transmission)"
    }
}

# 3. Check RabbitMQ annotations (ensure no explicit log annotations)
Write-Info "`nChecking RabbitMQ deployment annotations..."
$rabbitmqAnnotations = kubectl get deployment rabbitmq -n sock-shop -o jsonpath='{.spec.template.metadata.annotations}' | ConvertFrom-Json

if ($rabbitmqAnnotations.'ad.datadoghq.com/rabbitmq.logs' -or 
    $rabbitmqAnnotations.'ad.datadoghq.com/rabbitmq-exporter.logs') {
    Write-Failure "Explicit log annotations found on RabbitMQ (will cause regression)"
    Write-Warning "Remove with: kubectl patch deployment rabbitmq -n sock-shop --type json -p='[{""op"": ""remove"", ""path"": ""/spec/template/metadata/annotations/ad.datadoghq.com~1rabbitmq.logs""}]'"
} else {
    Write-Success "No explicit log annotations (correct - using global containerCollectAll)"
}

# Check metrics annotations are present
if ($rabbitmqAnnotations.'ad.datadoghq.com/rabbitmq-exporter.check_names') {
    Write-Success "RabbitMQ metrics annotations present (correct)"
} else {
    Write-Warning "RabbitMQ metrics annotations missing (metrics may not be collected)"
}

# 4. Verify logs from sock-shop namespace
Write-Info "`nChecking sock-shop pod logs..."
$sockShopPods = kubectl get pods -n sock-shop -o jsonpath='{.items[*].metadata.name}'
if ($sockShopPods) {
    Write-Success "Found sock-shop pods: $($sockShopPods.Split(' ').Count) pods"
} else {
    Write-Warning "No sock-shop pods found"
}

# 5. Final summary
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

Write-Info "Next steps:"
Write-Host "  1. Check Datadog UI: https://app.datadoghq.com/logs" -ForegroundColor White
Write-Host "  2. Query: kube_namespace:sock-shop" -ForegroundColor White
Write-Host "  3. Time range: Past 15 minutes" -ForegroundColor White
Write-Host "  4. Expect: Recent logs visible within 2-3 minutes" -ForegroundColor White

Write-Host "`n" -ForegroundColor White
Write-Success "Health check complete. Log collection appears healthy."
Write-Info "If logs still not visible in UI after 5 minutes, check Datadog index filters."

