# Comprehensive Health Check Procedure
**For Incident Testing Preparation**

---

## Purpose

This document defines the **mandatory health check procedure** that must be completed before executing any incident scenarios. The goal is to ensure the application is in a fully functional baseline state so that incident-induced failures are clearly distinguishable from pre-existing issues.

---

## Why This Matters

### Lesson from November 9, 2025
**What Happened:**
- Incident execution began without thorough functional testing
- User discovered catalogue was completely broken (empty product pages)
- Root cause: Database authentication failure (password mismatch)
- **Impact:** Had to stop incident execution, diagnose, and fix before continuing

**The Problem:**
- Health checks focused on **infrastructure** (pods running, DNS working)
- Did NOT verify **application functionality** (can users browse products?)
- This created a false sense of readiness

**Key Insight:**
> **"Pods Running" ≠ "Application Working"**  
> A pod can be Running (1/1 Ready) but still unable to serve traffic due to:
> - Database connection failures
> - Authentication issues
> - Missing configuration
> - Network problems

---

## Three-Tier Health Check Model

### Tier 1: Infrastructure Health (What We Did ✅)
**Purpose:** Verify Kubernetes cluster and pods are operational

**Checks:**
- Node status (Ready/Not Ready)
- Pod status (Running/Failed/CrashLoopBackOff)
- Service endpoints (ClusterIP assigned)
- DNS resolution (CoreDNS functional)
- Datadog agent status (Running, logs flowing)

**Status Check:** PASSED ✅

**Limitation:** This tier does NOT verify if the application can serve user requests.

---

### Tier 2: Service Health (What We Missed ❌)
**Purpose:** Verify each microservice can communicate with its dependencies

**Critical Checks We Should Have Done:**

#### 1. Database Connection Tests
```bash
# Test Catalogue → Catalogue-DB
kubectl -n sock-shop logs deployment/catalogue --tail=50 | grep -i "error\|failed\|denied"
# Expected: No errors

# Test User → User-DB (MongoDB)
kubectl -n sock-shop logs deployment/user --tail=50 | grep -i "error\|mongo"
# Expected: No connection errors

# Test Orders → Orders-DB (MongoDB)
kubectl -n sock-shop logs deployment/orders --tail=50 | grep -i "error\|mongo"
# Expected: No connection errors

# Test Carts → Carts-DB (MongoDB)
kubectl -n sock-shop logs deployment/carts --tail=50 | grep -i "error\|mongo"
# Expected: No connection errors
```

**What This Would Have Caught:**
```
catalogue logs: err="database connection error"
catalogue-db logs: Access denied for user 'root'@'10.244.1.15'
```
→ **IMMEDIATE RED FLAG:** Authentication failure detected **BEFORE** starting incidents.

#### 2. Service Endpoint Tests
```bash
# Test each API endpoint returns expected data
kubectl -n sock-shop exec -it deployment/front-end -- wget -O- http://catalogue/catalogue
# Expected: JSON array with products

kubectl -n sock-shop exec -it deployment/front-end -- wget -O- http://user/customers
# Expected: JSON array or empty array (not error)

kubectl -n sock-shop exec -it deployment/front-end -- wget -O- http://carts/carts
# Expected: JSON response
```

#### 3. Health Endpoint Verification
```bash
# Verify all services report healthy
kubectl -n sock-shop exec -it deployment/front-end -- wget -O- http://catalogue/health
kubectl -n sock-shop exec -it deployment/front-end -- wget -O- http://user/health
kubectl -n sock-shop exec -it deployment/front-end -- wget -O- http://orders/health
```

---

### Tier 3: User Journey Testing (What We Should Have Done ❌)
**Purpose:** Verify end-to-end user workflows are functional

**Critical User Journeys:**

#### Journey 1: Browse Products
```
Steps:
1. Open front-end UI
2. Navigate to catalogue page
3. Verify products are displayed
4. Verify images load

Test Command:
curl http://localhost:2025/catalogue | jq 'length'
# Expected: 10 (or whatever the product count is)

curl -I http://localhost:2025/catalogue/images/holy_1.jpeg
# Expected: HTTP 200
```

**What This Would Have Caught:**
- Empty catalogue page
- Missing product images
- HTTP 500 errors from catalogue service

#### Journey 2: User Authentication
```
Steps:
1. Open login page
2. Login with test user (user / password)
3. Verify session created
4. Verify user profile accessible

Test Command:
curl -X POST http://localhost:2025/login \
  -d "username=user&password=password" \
  -c cookies.txt
# Expected: HTTP 200, session cookie set
```

#### Journey 3: Add to Cart
```
Steps:
1. Login as user
2. Browse catalogue
3. Add item to cart
4. Verify cart count increases

Manual Test: Required (UI interaction)
```

#### Journey 4: Place Order
```
Steps:
1. Add items to cart
2. Proceed to checkout
3. Complete order
4. Verify order appears in orders list

Manual Test: Required (full checkout flow)
```

---

## The Complete Health Check Procedure

### Phase 1: Infrastructure Health (5 minutes)

#### Step 1.1: Verify Kubernetes Cluster
```bash
kubectl get nodes
# Expected: All nodes Ready

kubectl get pods -n sock-shop
# Expected: All pods Running, all Ready

kubectl get svc -n sock-shop
# Expected: All services have valid ClusterIPs
```

#### Step 1.2: Verify Datadog Agents
```bash
kubectl get pods -n datadog
# Expected: All Datadog pods Running

POD=$(kubectl -n datadog get pods -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}')
kubectl -n datadog exec $POD -c agent -- agent status | grep -i "logssent\|dnserror"
# Expected: LogsSent > 0, DNSErrors = 0
```

#### Step 1.3: Verify DNS Resolution
```bash
kubectl get configmap coredns -n kube-system -o yaml | grep -A5 "forward"
# Expected: forward . 8.8.8.8 8.8.4.4
```

✅ **Checkpoint:** If any checks fail, STOP and fix infrastructure issues.

---

### Phase 2: Service Health (10 minutes)

#### Step 2.1: Check All Service Logs for Errors
```bash
# Create a comprehensive error check script
kubectl -n sock-shop get deployments -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read deploy; do
  echo "=== Checking $deploy ==="
  kubectl -n sock-shop logs deployment/$deploy --tail=20 | grep -i "error\|fail\|exception\|panic\|fatal" || echo "No errors"
done
```

**Expected:** No critical errors in any service.

**Red Flags to Watch For:**
- "database connection error" → Database authentication/connectivity issue
- "connection refused" → Dependent service not reachable
- "timeout" → Service dependency too slow
- "panic" → Application crash
- "out of memory" → Resource exhaustion

#### Step 2.2: Test Service-to-Service Communication
```bash
# Test from front-end pod (acts as client)
kubectl -n sock-shop exec -it deployment/front-end -- sh

# Inside the pod, test each service:
wget -O- http://catalogue/health     # Expected: OK
wget -O- http://user/health          # Expected: OK
wget -O- http://carts/health         # Expected: OK
wget -O- http://orders/health        # Expected: OK
wget -O- http://payment/health       # Expected: OK
wget -O- http://shipping/health      # Expected: OK
```

#### Step 2.3: Test Database Connections
```bash
# Test catalogue can query database
kubectl -n sock-shop exec -it deployment/catalogue -- wget -O- http://localhost:8080/catalogue
# Expected: JSON array with products (not empty, not error)

# Test user service can query database
kubectl -n sock-shop exec -it deployment/user -- wget -O- http://localhost:8080/customers
# Expected: JSON array (may be empty, but not error)
```

✅ **Checkpoint:** If any service reports errors or cannot reach dependencies, STOP and investigate.

---

### Phase 3: User Journey Testing (10 minutes)

#### Step 3.1: Setup Port Forwarding
```bash
kubectl -n sock-shop port-forward svc/front-end 2025:80 &
```

#### Step 3.2: Test Front-End Access
```bash
curl -I http://localhost:2025/
# Expected: HTTP 200
```

#### Step 3.3: Test Catalogue API (CRITICAL)
```bash
# This is the test that would have caught the issue!
curl http://localhost:2025/catalogue
# Expected: JSON array with products

# Count products
curl -s http://localhost:2025/catalogue | jq 'length'
# Expected: 10 (or known product count)

# Verify product structure
curl -s http://localhost:2025/catalogue | jq '.[0] | keys'
# Expected: ["id", "name", "description", "imageUrl", "price", "count", "tag"]
```

**If this returns empty array or error:** 🚨 **STOP! Catalogue is broken!**

#### Step 3.4: Test Product Images
```bash
# Test first product image
curl -I http://localhost:2025/catalogue/images/holy_1.jpeg
# Expected: HTTP 200, Content-Type: image/jpeg

# Test multiple images
for img in holy_1.jpeg classic.jpg catsocks.jpg; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:2025/catalogue/images/$img)
  echo "$img: $STATUS"
done
# Expected: All return 200
```

#### Step 3.5: Test User Authentication
```bash
# Test login endpoint
curl -X POST http://localhost:2025/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=user&password=password" \
  -c cookies.txt -v
# Expected: HTTP 200, Set-Cookie header present
```

#### Step 3.6: Manual UI Test (REQUIRED)
```
Browser: Open http://localhost:2025

Visual Checks:
1. ✅ Homepage loads with banner
2. ✅ "Catalogue" link works
3. ✅ Product grid displays 10 products
4. ✅ Product images are visible (not broken image icons)
5. ✅ Product names and prices visible
6. ✅ Click on a product → Details page loads
7. ✅ Login works (user / password)
8. ✅ After login, cart icon appears
9. ✅ Can add items to cart
10. ✅ Cart count updates
```

**If ANY of these fail:** 🚨 **STOP! Application is not functional!**

✅ **Checkpoint:** ALL user journeys must work before proceeding to incidents.

---

## Automated Health Check Script

```powershell
# comprehensive-health-check.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Comprehensive Health Check" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Phase 1: Infrastructure
Write-Host "[Phase 1] Infrastructure Health" -ForegroundColor Yellow
Write-Host ""

# Check nodes
$nodes = kubectl get nodes --no-headers 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Kubernetes nodes: OK" -ForegroundColor Green
} else {
    Write-Host "  ❌ Kubernetes nodes: FAILED" -ForegroundColor Red
    $allPassed = $false
}

# Check pods
$failedPods = kubectl -n sock-shop get pods --no-headers 2>&1 | Where-Object { $_ -notmatch "Running" -and $_ -notmatch "Completed" }
if ($failedPods) {
    Write-Host "  ❌ Some pods not Running:" -ForegroundColor Red
    $failedPods | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
    $allPassed = $false
} else {
    Write-Host "  ✅ All pods Running: OK" -ForegroundColor Green
}

# Check Datadog
$ddLogs = kubectl -n datadog exec $(kubectl -n datadog get pods -l app=datadog-agent -o jsonpath='{.items[0].metadata.name}') -c agent -- agent status 2>&1 | Select-String "LogsSent"
if ($ddLogs -match "LogsSent: [1-9]") {
    Write-Host "  ✅ Datadog logs flowing: OK" -ForegroundColor Green
} else {
    Write-Host "  ❌ Datadog logs NOT flowing" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""

# Phase 2: Service Health
Write-Host "[Phase 2] Service Health" -ForegroundColor Yellow
Write-Host ""

# Check for errors in logs
$services = @("front-end", "catalogue", "user", "carts", "orders", "payment", "shipping")
foreach ($svc in $services) {
    $errors = kubectl -n sock-shop logs deployment/$svc --tail=20 2>&1 | Select-String -Pattern "error|fail|exception" -CaseSensitive:$false
    if ($errors) {
        Write-Host "  ⚠️  $svc has errors in logs" -ForegroundColor Yellow
        $errors | Select-Object -First 2 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ✅ $svc: No errors in logs" -ForegroundColor Green
    }
}

Write-Host ""

# Phase 3: User Journey Testing
Write-Host "[Phase 3] User Journey Tests" -ForegroundColor Yellow
Write-Host ""

# Test catalogue API
try {
    $catalogue = Invoke-RestMethod -Uri "http://localhost:2025/catalogue" -TimeoutSec 5 -ErrorAction Stop
    if ($catalogue.Count -gt 0) {
        Write-Host "  ✅ Catalogue API: $($catalogue.Count) products" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Catalogue API: EMPTY (0 products)" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "  ❌ Catalogue API: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    $allPassed = $false
}

# Test product images
try {
    $img = Invoke-WebRequest -Uri "http://localhost:2025/catalogue/images/holy_1.jpeg" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Host "  ✅ Product images: Loading (HTTP $($img.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Product images: NOT loading" -ForegroundColor Red
    $allPassed = $false
}

# Test front-end
try {
    $fe = Invoke-WebRequest -Uri "http://localhost:2025/" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Host "  ✅ Front-end: Accessible (HTTP $($fe.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Front-end: NOT accessible" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan

if ($allPassed) {
    Write-Host "  ✅ ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host "  System ready for incident testing" -ForegroundColor Green
} else {
    Write-Host "  ❌ SOME CHECKS FAILED" -ForegroundColor Red
    Write-Host "  Fix issues before proceeding" -ForegroundColor Red
    exit 1
}

Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
```

**Usage:**
```powershell
.\comprehensive-health-check.ps1
```

---

## Health Check Decision Tree

```
Start Health Check
     |
     v
[Phase 1] Infrastructure
     |
     ├─ Nodes Ready? ──NO──> Fix Kubernetes cluster ──> Retry
     |       |
     |      YES
     |       |
     ├─ Pods Running? ──NO──> kubectl describe pod, check logs ──> Fix ──> Retry
     |       |
     |      YES
     |       |
     └─ Datadog logging? ──NO──> Fix DNS/Datadog ──> Retry
             |
            YES
             |
             v
[Phase 2] Service Health
     |
     ├─ Service logs clean? ──NO──> Investigate errors ──> Fix ──> Retry
     |       |
     |      YES
     |       |
     └─ DB connections OK? ──NO──> Check passwords, network ──> Fix ──> Retry
             |
            YES
             |
             v
[Phase 3] User Journeys
     |
     ├─ Catalogue API works? ──NO──> Check catalogue service & DB ──> Fix ──> Retry
     |       |
     |      YES
     |       |
     ├─ Images loading? ──NO──> Check image paths, volumes ──> Fix ──> Retry
     |       |
     |      YES
     |       |
     └─ UI functional? ──NO──> Manual investigation ──> Fix ──> Retry
             |
            YES
             |
             v
    ✅ READY FOR INCIDENTS
```

---

## What We Learned

### Before This Incident
**Our Approach:**
- Run `kubectl get pods` → All Running → "System healthy" ✅
- Start incident execution

**Problem:** Missed critical application-level failures.

### After This Incident
**Improved Approach:**
1. Check infrastructure (pods, nodes, DNS) ✅
2. **Check service logs for errors** ✅ ← NEW
3. **Test service APIs return data** ✅ ← NEW
4. **Verify database connections** ✅ ← NEW
5. **Test user journeys in UI** ✅ ← NEW
6. Only then start incidents

**Result:** Catch issues BEFORE they interfere with incident testing.

---

## Estimated Time Breakdown

| Phase | Activities | Time |
|-------|-----------|------|
| Phase 1: Infrastructure | Nodes, pods, DNS, Datadog | 5 min |
| Phase 2: Service Health | Logs, connections, APIs | 10 min |
| Phase 3: User Journeys | Catalogue, images, UI tests | 10 min |
| **Total** | **Complete health check** | **25 min** |

**Is 25 minutes worth it?**

**YES!** Because:
- Catching a broken catalogue took 10+ minutes to diagnose and fix
- We had to STOP incident execution mid-stream
- Lost all progress on INCIDENT-5
- Had to re-baseline the system

**25 minutes upfront** > **60+ minutes fixing issues during incidents**

---

## Mandatory Checklist (Print & Check Off)

```
□ Phase 1: Infrastructure Health
  □ Kubernetes nodes Ready
  □ All pods Running
  □ All pods Ready (1/1 or 2/2)
  □ Services have valid ClusterIPs
  □ Datadog agents Running
  □ Datadog logs flowing (LogsSent > 0)
  □ DNS resolution working
  □ No DNS errors in Datadog

□ Phase 2: Service Health
  □ front-end logs: No errors
  □ catalogue logs: No errors ← CRITICAL!
  □ user logs: No errors
  □ carts logs: No errors
  □ orders logs: No errors
  □ payment logs: No errors
  □ shipping logs: No errors
  □ queue-master logs: No errors
  □ Database connections verified

□ Phase 3: User Journey Testing
  □ Front-end accessible (HTTP 200)
  □ Catalogue API returns products (count > 0) ← CRITICAL!
  □ Product images loading (HTTP 200)
  □ User login works
  □ Cart functionality works
  □ Order placement works
  □ Manual UI test passed

□ Final Approval
  □ All checks above passed
  □ Health check report generated
  □ Baseline metrics captured
  □ Ready to start incidents

Approved by: _______________  Date: _______________
```

---

## Summary

**Key Takeaway:**  
> "Pods Running" is a necessary but **not sufficient** condition for incident testing.

**Complete Health Check = Infrastructure + Services + User Journeys**

**When to Run:**
- ✅ Before starting incident testing
- ✅ After any system restart (DNS fix, cluster reboot, etc.)
- ✅ After deploying application changes
- ✅ When resuming incident testing after a break

**Time Investment:** 25 minutes  
**Value:** Prevents hours of debugging during incidents  
**Outcome:** Clean baseline for accurate incident analysis

---

**Document Version:** 1.0  
**Created:** November 9, 2025  
**Last Updated:** November 9, 2025  
**Owner:** SRE Team  
**Status:** MANDATORY for all incident testing
