# ====================================================================
# Incident 6: Payment Gateway Timeout/Failure - ACTIVATION
# ====================================================================
# This script activates the incident by routing traffic through Toxiproxy
# which will inject realistic third-party API failures
#
# SAFETY: This script can be safely reverted using incident-6-recover.ps1
# ====================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("timeout", "503", "429", "500", "slowness", "intermittent")]
    [string]$FailureMode = "timeout"
)

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  INCIDENT 6: Payment Gateway Failure - ACTIVATION             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nFailure Mode: $FailureMode" -ForegroundColor Yellow

# Step 1: Save current payment service configuration (for rollback)
Write-Host "`n[1/4] Backing up current payment service configuration..." -ForegroundColor Green
kubectl -n sock-shop get svc payment -o yaml > payment-service-backup.yaml
Write-Host "✅ Backup saved to payment-service-backup.yaml" -ForegroundColor Green

# Step 2: Redirect payment service to toxiproxy
Write-Host "`n[2/4] Redirecting payment service to Toxiproxy..." -ForegroundColor Green
Write-Host "   Current: payment service → payment pods" -ForegroundColor Gray
Write-Host "   New:     payment service → toxiproxy pods → payment service (via ClusterIP)" -ForegroundColor Yellow

kubectl -n sock-shop patch svc payment -p '{\"spec\":{\"selector\":{\"name\":\"toxiproxy-payment\"}}}'

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Traffic now flows through Toxiproxy" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to patch service!" -ForegroundColor Red
    exit 1
}

# Step 3: Configure failure mode via Toxiproxy API
Write-Host "`n[3/4] Configuring $FailureMode failure mode..." -ForegroundColor Green

# Start port-forward in background
$job = Start-Job -ScriptBlock {
    kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474 2>$null
}

Start-Sleep -Seconds 3

try {
    $headers = @{"User-Agent" = "PowerShell/Incident6"}
    
    switch ($FailureMode) {
        "timeout" {
            Write-Host "   Injecting 30-second timeout (100% of requests)..." -ForegroundColor Yellow
            $toxic = @{
                type = "latency"
                name = "gateway_timeout"
                toxicity = 1.0
                attributes = @{
                    latency = 30000
                }
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic -ContentType "application/json" -Headers $headers | Out-Null
            Write-Host "✅ Configured: All payment requests will timeout after 30s" -ForegroundColor Green
        }
        
        "503" {
            Write-Host "   Injecting HTTP 503 Service Unavailable (80% of requests)..." -ForegroundColor Yellow
            $toxic = @{
                type = "limit_data"
                name = "service_unavailable"
                toxicity = 0.8
                attributes = @{
                    bytes = 0
                }
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic -ContentType "application/json" -Headers $headers | Out-Null
            Write-Host "✅ Configured: 80% of requests will fail (connection closed)" -ForegroundColor Green
        }
        
        "429" {
            Write-Host "   Injecting rate limiting (50% of requests fail)..." -ForegroundColor Yellow
            $toxic = @{
                type = "limit_data"
                name = "rate_limit"
                toxicity = 0.5
                attributes = @{
                    bytes = 0
                }
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic -ContentType "application/json" -Headers $headers | Out-Null
            Write-Host "✅ Configured: 50% of requests will be rate limited" -ForegroundColor Green
        }
        
        "500" {
            Write-Host "   Injecting connection failures (70% of requests)..." -ForegroundColor Yellow
            $toxic = @{
                type = "limit_data"
                name = "internal_error"
                toxicity = 0.7
                attributes = @{
                    bytes = 0
                }
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic -ContentType "application/json" -Headers $headers | Out-Null
            Write-Host "✅ Configured: 70% of requests will fail immediately" -ForegroundColor Green
        }
        
        "slowness" {
            Write-Host "   Injecting 5-15 second delays (100% of requests)..." -ForegroundColor Yellow
            $toxic = @{
                type = "latency"
                name = "slow_gateway"
                toxicity = 1.0
                attributes = @{
                    latency = 10000
                    jitter = 5000
                }
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic -ContentType "application/json" -Headers $headers | Out-Null
            Write-Host "✅ Configured: All requests delayed by 5-15 seconds" -ForegroundColor Green
        }
        
        "intermittent" {
            Write-Host "   Injecting intermittent failures (30% timeout, 30% fail)..." -ForegroundColor Yellow
            
            $toxic1 = @{
                type = "latency"
                name = "intermittent_timeout"
                toxicity = 0.3
                attributes = @{
                    latency = 30000
                }
            } | ConvertTo-Json
            
            $toxic2 = @{
                type = "limit_data"
                name = "intermittent_fail"
                toxicity = 0.3
                attributes = @{
                    bytes = 0
                }
            } | ConvertTo-Json
            
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic1 -ContentType "application/json" -Headers $headers | Out-Null
            Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment/toxics" -Method Post -Body $toxic2 -ContentType "application/json" -Headers $headers | Out-Null
            Write-Host "✅ Configured: 30% timeout, 30% fail, 40% succeed" -ForegroundColor Green
        }
    }
    
} catch {
    Write-Host "❌ Error configuring toxic: $_" -ForegroundColor Red
} finally {
    Stop-Job -Job $job 2>$null
    Remove-Job -Job $job 2>$null
}

# Step 4: Verify configuration
Write-Host "`n[4/4] Verifying incident is active..." -ForegroundColor Green

$svcSelector = kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'
if ($svcSelector -eq "toxiproxy-payment") {
    Write-Host "✅ Payment service correctly points to Toxiproxy" -ForegroundColor Green
} else {
    Write-Host "❌ Warning: Payment service selector is: $svcSelector" -ForegroundColor Yellow
}

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ INCIDENT 6 ACTIVATED - Payment Gateway Failures Active    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📊 WHAT'S HAPPENING:" -ForegroundColor Cyan
Write-Host "   • Orders service → Payment service → Toxiproxy → Real payment service" -ForegroundColor White
Write-Host "   • Toxiproxy is injecting: $FailureMode failures" -ForegroundColor White
Write-Host "   • Users will see: Payment errors during checkout" -ForegroundColor White
Write-Host "   • Orders will be marked: PAYMENT_FAILED in database" -ForegroundColor White

Write-Host "`n🔬 TESTING:" -ForegroundColor Cyan
Write-Host "   1. Go to http://localhost:2025" -ForegroundColor White
Write-Host "   2. Add items to cart, login (user/password)" -ForegroundColor White
Write-Host "   3. Try to checkout - should see payment errors" -ForegroundColor White

Write-Host "`n🔧 RECOVERY:" -ForegroundColor Cyan
Write-Host "   Run: .\incident-6-recover.ps1" -ForegroundColor Yellow

Write-Host "`n⚠️  REMINDER: This simulates realistic third-party payment gateway issues" -ForegroundColor Magenta
Write-Host "   In production, this could be Stripe, PayPal, or any payment processor being down/slow" -ForegroundColor Gray
Write-Host ""
