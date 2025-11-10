# ==============================================================================
# APPLY PERMANENT RABBITMQ DATADOG FIX
# ==============================================================================
# Purpose: Fix Datadog RabbitMQ integration port mismatch
# Root Cause: Auto-discovery tries port 15692, but exporter is on port 9090
# Solution: Add annotations to use OpenMetrics check on correct port
# Risk Level: ZERO - Only metadata changes, fully reversible
# ==============================================================================

param(
    [switch]$Verify,
    [switch]$Rollback
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

# ==============================================================================
# ROLLBACK MODE
# ==============================================================================
if ($Rollback) {
    Write-Header "ROLLBACK: Remove Datadog Annotations"
    
    Write-Info "Removing Datadog autodiscovery annotations..."
    
    $annotations = @(
        "ad.datadoghq.com~1rabbitmq-exporter.check_names",
        "ad.datadoghq.com~1rabbitmq-exporter.init_configs",
        "ad.datadoghq.com~1rabbitmq-exporter.instances",
        "ad.datadoghq.com~1rabbitmq.logs",
        "ad.datadoghq.com~1rabbitmq-exporter.logs"
    )
    
    foreach ($annotation in $annotations) {
        $patch = "[{`"op`": `"remove`", `"path`": `"/spec/template/metadata/annotations/$annotation`"}]"
        kubectl patch deployment rabbitmq -n sock-shop --type json -p=$patch 2>$null
    }
    
    Write-Success "Annotations removed"
    Write-Info "RabbitMQ will return to default state (no metrics)"
    exit 0
}

# ==============================================================================
# VERIFICATION MODE
# ==============================================================================
if ($Verify) {
    Write-Header "VERIFICATION: Check Current State"
    
    # Check if annotations exist
    Write-Info "Checking deployment annotations..."
    $annotations = kubectl get deployment rabbitmq -n sock-shop -o jsonpath='{.spec.template.metadata.annotations}' | ConvertFrom-Json
    
    if ($annotations.'ad.datadoghq.com/rabbitmq-exporter.check_names') {
        Write-Success "Datadog annotations are configured"
    } else {
        Write-Warning "Datadog annotations are NOT configured"
    }
    
    # Check pod status
    Write-Info "`nChecking RabbitMQ pod..."
    $pod = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].metadata.name}' 2>$null
    if ($pod) {
        $status = kubectl get pod $pod -n sock-shop -o jsonpath='{.status.phase}'
        if ($status -eq "Running") {
            Write-Success "RabbitMQ pod is running: $pod"
        } else {
            Write-Warning "RabbitMQ pod status: $status"
        }
    }
    
    # Check Datadog agent status
    Write-Info "`nChecking Datadog agent..."
    $agentPod = kubectl get pods -n datadog -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}' 2>$null
    if ($agentPod) {
        Write-Success "Datadog agent pod: $agentPod"
        Write-Info "Checking for RabbitMQ checks..."
        
        $checkStatus = kubectl exec -n datadog $agentPod -- agent status 2>$null | Select-String -Pattern "openmetrics.*rabbitmq|rabbitmq.*openmetrics" -Context 5
        if ($checkStatus) {
            Write-Success "OpenMetrics check found"
        } else {
            Write-Warning "OpenMetrics check not found (may take 2-3 minutes after applying)"
        }
    }
    
    Write-Info "`nTo check metrics in Datadog UI:"
    Write-Info "  1. Go to Metrics Explorer"
    Write-Info "  2. Search: rabbitmq_queue_consumers"
    Write-Info "  3. Filter: kube_namespace:sock-shop"
    exit 0
}

# ==============================================================================
# APPLY MODE (DEFAULT)
# ==============================================================================
Write-Header "PERMANENT FIX: RabbitMQ Datadog Integration"

# Pre-flight checks
Write-Info "Running pre-flight checks..."

# Check if file exists
if (!(Test-Path "rabbitmq-datadog-fix-permanent.yaml")) {
    Write-Error "Fix file not found: rabbitmq-datadog-fix-permanent.yaml"
    Write-Info "Make sure you're in the correct directory"
    exit 1
}

# Check kubectl connectivity
try {
    kubectl get namespace sock-shop | Out-Null
    Write-Success "Kubernetes cluster accessible"
} catch {
    Write-Error "Cannot connect to Kubernetes cluster"
    Write-Info "Make sure kubectl is configured and cluster is running"
    exit 1
}

# Check if RabbitMQ deployment exists
$deployment = kubectl get deployment rabbitmq -n sock-shop -o name 2>$null
if (!$deployment) {
    Write-Error "RabbitMQ deployment not found in sock-shop namespace"
    exit 1
}
Write-Success "RabbitMQ deployment found"

# Backup current configuration
Write-Info "`nCreating backup of current deployment..."
kubectl get deployment rabbitmq -n sock-shop -o yaml > "rabbitmq-deployment-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"
Write-Success "Backup created"

# Show current state
Write-Info "`nCurrent annotations:"
kubectl get deployment rabbitmq -n sock-shop -o jsonpath='{.spec.template.metadata.annotations}' | ConvertFrom-Json | Format-List

# Apply the fix
Write-Header "Applying Fix"
Write-Info "Patching RabbitMQ deployment with Datadog annotations..."

kubectl patch deployment rabbitmq -n sock-shop --patch-file rabbitmq-datadog-fix-permanent.yaml

if ($LASTEXITCODE -eq 0) {
    Write-Success "Fix applied successfully!"
} else {
    Write-Error "Failed to apply fix"
    exit 1
}

# Wait for rollout
Write-Info "`nWaiting for pod rollout..."
Start-Sleep -Seconds 5

$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $pod = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].status.phase}' 2>$null
    if ($pod -eq "Running") {
        $ready = kubectl get pods -n sock-shop -l name=rabbitmq -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>$null
        if ($ready -match "true.*true") {
            Write-Success "RabbitMQ pod is running and ready"
            break
        }
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    $elapsed += 5
}

if ($elapsed -ge $timeout) {
    Write-Warning "Pod did not become ready within $timeout seconds"
    Write-Info "Check pod status: kubectl get pods -n sock-shop -l name=rabbitmq"
}

# Show new annotations
Write-Info "`nNew annotations:"
kubectl get deployment rabbitmq -n sock-shop -o jsonpath='{.spec.template.metadata.annotations}' | ConvertFrom-Json | Format-List

# Verification instructions
Write-Header "Verification"

Write-Info "Wait 2-3 minutes for Datadog agent to discover the new configuration"
Write-Info ""
Write-Info "Then verify with:"
Write-Info "  .\apply-rabbitmq-fix.ps1 -Verify"
Write-Info ""
Write-Info "Or check Datadog agent directly:"
Write-Info "  kubectl exec -n datadog <agent-pod> -- agent status | Select-String -Pattern 'openmetrics' -Context 10"
Write-Info ""
Write-Info "In Datadog UI (Metrics Explorer):"
Write-Info "  1. Search: rabbitmq_queue_consumers"
Write-Info "  2. Filter: kube_namespace:sock-shop"
Write-Info "  3. Should see data appearing in 2-3 minutes"

Write-Header "Available Metrics After Fix"
Write-Info "Once working, you'll have access to:"
Write-Host "  • rabbitmq_queue_messages         - Total messages in queue" -ForegroundColor White
Write-Host "  • rabbitmq_queue_messages_ready   - Ready messages" -ForegroundColor White
Write-Host "  • rabbitmq_queue_consumers        - Consumer count (CRITICAL)" -ForegroundColor Yellow
Write-Host "  • rabbitmq_queue_message_stats_*  - Publish/deliver rates" -ForegroundColor White
Write-Host "  • rabbitmq_node_*                 - Node health metrics" -ForegroundColor White

Write-Success "`nFix applied successfully! Wait 2-3 minutes for metrics to appear."
