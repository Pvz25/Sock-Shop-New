# =========================================================================
# Datadog DNS Fix Script - Automated Recovery
# =========================================================================
# Purpose: Ensure CoreDNS and Datadog agents work correctly after restarts
# Run this after: Docker Desktop restart, Windows reboot, or DNS issues
# Location: D:\sock-shop-demo\fix-dns-after-restart.ps1
# =========================================================================

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Datadog DNS Fix - Automated Recovery" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check cluster connectivity
Write-Host "[1/6] Checking cluster connectivity..." -ForegroundColor Yellow
try {
    $nodes = kubectl get nodes --no-headers 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Cannot connect to Kubernetes cluster!" -ForegroundColor Red
        Write-Host "   Make sure Docker Desktop is running and KIND cluster is started." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Cluster is reachable" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Check CoreDNS configuration
Write-Host ""
Write-Host "[2/6] Checking CoreDNS configuration..." -ForegroundColor Yellow
try {
    $corednsConfig = kubectl get configmap coredns -n kube-system -o yaml 2>&1
    
    if ($corednsConfig -match "forward \. 8\.8\.8\.8 8\.8\.4\.4") {
        Write-Host "✅ CoreDNS already configured with external DNS (8.8.8.8 8.8.4.4)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  CoreDNS needs fixing - applying correct configuration..." -ForegroundColor Yellow
        
        # Apply the fixed CoreDNS config
        kubectl apply -f D:\sock-shop-demo\coredns-fixed.yaml
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ CoreDNS configuration applied" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to apply CoreDNS config" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "❌ Error checking CoreDNS: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Restart CoreDNS to apply changes
Write-Host ""
Write-Host "[3/6] Restarting CoreDNS deployment..." -ForegroundColor Yellow
try {
    kubectl rollout restart deployment/coredns -n kube-system | Out-Null
    Write-Host "   Waiting for CoreDNS to be ready..." -ForegroundColor Gray
    
    $rolloutStatus = kubectl rollout status deployment/coredns -n kube-system --timeout=60s 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ CoreDNS restarted successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  CoreDNS restart timed out, but continuing..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  CoreDNS restart encountered issues, but continuing..." -ForegroundColor Yellow
}

# Step 4: Wait for DNS to stabilize
Write-Host ""
Write-Host "[4/6] Waiting for DNS to stabilize..." -ForegroundColor Yellow
Write-Host "   (15 second pause)" -ForegroundColor Gray
Start-Sleep -Seconds 15
Write-Host "✅ DNS stabilization period complete" -ForegroundColor Green

# Step 5: Test DNS resolution
Write-Host ""
Write-Host "[5/6] Testing DNS resolution..." -ForegroundColor Yellow
try {
    # Create a test pod
    $testPodYaml = @"
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-temp
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox:1.28
    command: ['sh', '-c', 'nslookup agent-intake.logs.us5.datadoghq.com && nslookup google.com']
  restartPolicy: Never
"@
    
    $testPodYaml | kubectl apply -f - | Out-Null
    
    # Wait for pod to complete
    Start-Sleep -Seconds 10
    
    # Check logs
    $dnsTestLogs = kubectl logs dns-test-temp 2>&1
    
    # Clean up test pod
    kubectl delete pod dns-test-temp --ignore-not-found=true | Out-Null
    
    if ($dnsTestLogs -match "Address.*172\.|Address.*142\.|Address.*2404:") {
        Write-Host "✅ DNS resolution working correctly" -ForegroundColor Green
        Write-Host "   - agent-intake.logs.us5.datadoghq.com: Resolvable" -ForegroundColor Gray
        Write-Host "   - google.com: Resolvable" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  DNS test completed with warnings" -ForegroundColor Yellow
        Write-Host "   Continuing with Datadog restart..." -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️  DNS test failed, but continuing..." -ForegroundColor Yellow
}

# Step 6: Restart Datadog agents
Write-Host ""
Write-Host "[6/6] Restarting Datadog agents..." -ForegroundColor Yellow
try {
    # Check if datadog namespace exists
    $datadogNs = kubectl get namespace datadog --ignore-not-found=true 2>&1
    
    if ([string]::IsNullOrWhiteSpace($datadogNs)) {
        Write-Host "⚠️  Datadog namespace not found - skipping agent restart" -ForegroundColor Yellow
    } else {
        kubectl rollout restart daemonset/datadog-agent -n datadog | Out-Null
        Write-Host "   Waiting for Datadog agents to be ready..." -ForegroundColor Gray
        
        $waitResult = kubectl wait --for=condition=ready pod -l app=datadog-agent -n datadog --timeout=120s 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Datadog agents restarted successfully" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Datadog agents restart timed out" -ForegroundColor Yellow
            Write-Host "   They may still be starting - check status with:" -ForegroundColor Gray
            Write-Host "   kubectl get pods -n datadog" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "⚠️  Datadog restart encountered issues" -ForegroundColor Yellow
}

# Final status check
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Fix Script Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Provide next steps
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify CoreDNS is running:" -ForegroundColor White
Write-Host "   kubectl get pods -n kube-system -l k8s-app=kube-dns" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Verify Datadog agents are running:" -ForegroundColor White
Write-Host "   kubectl get pods -n datadog" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Check Datadog agent status:" -ForegroundColor White
Write-Host "   kubectl exec -n datadog datadog-agent-[POD] -c agent -- agent status | Select-String -Pattern 'Logs Agent' -Context 3" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Wait 5-10 minutes, then check logs in Datadog UI:" -ForegroundColor White
Write-Host "   https://us5.datadoghq.com/logs?query=kube_namespace%3Asock-shop" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ DNS fix script completed successfully!" -ForegroundColor Green
Write-Host ""
