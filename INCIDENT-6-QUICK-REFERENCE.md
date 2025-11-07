# Incident 6: Quick Reference Guide

## ⚡ Quick Start

### Activate Incident (Default: 30s timeout)
```powershell
.\incident-6-activate.ps1
```

### Activate with Specific Failure Mode
```powershell
.\incident-6-activate.ps1 -FailureMode timeout      # 30-second timeout
.\incident-6-activate.ps1 -FailureMode 503          # Service unavailable (80% failure)
.\incident-6-activate.ps1 -FailureMode 429          # Rate limiting (50% failure)
.\incident-6-activate.ps1 -FailureMode slowness     # 5-15 second delays
.\incident-6-activate.ps1 -FailureMode intermittent # Mixed failures (30% timeout, 30% fail)
```

### Recover from Incident
```powershell
.\incident-6-recover.ps1
```

---

## 🎯 What This Tests

**Client Requirement:** Payment gateway timeout or failure, caused by third-party API issues

**Real-World Scenarios:**
- ✅ Stripe API timeout during Black Friday
- ✅ PayPal returning 503 Service Unavailable
- ✅ Payment processor rate limiting (429)
- ✅ Gateway experiencing high latency
- ✅ Intermittent connectivity issues

---

## 🔍 Verification Commands

### Check Incident is Active
```powershell
# Service should point to toxiproxy-payment
kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'
```

### Check Failed Orders
```powershell
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders | ConvertFrom-Json | Select-Object -ExpandProperty _embedded | Select-Object -ExpandProperty customerOrders | Where-Object { $_.status -eq "PAYMENT_FAILED" }
```

### View Toxiproxy Configuration
```powershell
kubectl -n sock-shop port-forward svc/toxiproxy-payment 8474:8474 &
Invoke-RestMethod -Uri "http://localhost:8474/proxies/payment" -Headers @{"User-Agent"="PS"} | ConvertTo-Json
```

---

## 📊 Expected Datadog Evidence

**Logs:**
```
[ERROR] service:orders "Payment failed for order" "timeout after 30000ms"
[ERROR] service:orders "ResourceAccessException" "Read timed out"
[WARN] service:orders "Order status updated to PAYMENT_FAILED"
```

**Metrics:**
```
http.server.requests.duration{service:payment} > 25000ms
http.server.requests.count{service:orders,status:500} increased
```

---

## 🚨 Incident 3 vs Incident 6 - Key Differences

| Aspect | Incident 3 | Incident 6 |
|--------|-----------|-----------|
| **Cause** | Payment pods scaled to 0 | External gateway API failure |
| **Pods** | 0 payment pods | 1 payment pod running ✅ |
| **Error** | Connection refused | Timeout / 503 / 429 |
| **Speed** | Immediate (<1s) | Delayed (5-30s) |
| **Health** | `/health` fails | `/health` succeeds ✅ |

---

## 🔧 Troubleshooting

**Incident won't activate:**
```powershell
# Re-run configuration
.\configure-toxiproxy-local.ps1
.\incident-6-activate.ps1
```

**Orders still succeeding:**
```powershell
# Verify selector
kubectl -n sock-shop get svc payment -o jsonpath='{.spec.selector.name}'
# Should be: toxiproxy-payment
```

**Recovery fails:**
```powershell
# Manual restore
kubectl -n sock-shop patch svc payment -p '{"spec":{"selector":{"name":"payment"}}}'
```

---

## ✅ Success Criteria

- [x] Toxiproxy deployed and healthy
- [x] Payment proxy configured (0.0.0.0:8080 → payment:80)
- [x] Activation script routes traffic through proxy
- [x] Failure modes inject timeouts/errors
- [x] Orders marked PAYMENT_FAILED in database
- [x] Recovery script restores direct routing
- [x] Zero impact on Incident 3 functionality
- [x] Incident 3 still works (scale payment to 0)

---

## 📝 Client Demo Script

1. **Show Normal Operation:**
   ```powershell
   # Place successful order at http://localhost:2025
   # Show order status: PAID
   ```

2. **Activate Incident:**
   ```powershell
   .\incident-6-activate.ps1 -FailureMode timeout
   ```

3. **Demonstrate Failure:**
   ```powershell
   # Try to place order
   # Show 30-second wait, then error
   # Check database: status = PAYMENT_FAILED
   ```

4. **Show Datadog Evidence:**
   ```
   service:orders "Payment failed" "timeout"
   ```

5. **Recover:**
   ```powershell
   .\incident-6-recover.ps1
   ```

6. **Verify Recovery:**
   ```powershell
   # Place order again - should succeed
   ```

---

**Time Required:** 
- Setup: 2 minutes (already done)
- Demo: 5 minutes per failure mode
- Recovery: 30 seconds

**Impact:** Zero regression - all existing functionality preserved ✅
