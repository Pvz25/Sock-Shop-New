# Orders Service Source Code Analysis Script
# This script clones the source repository and analyzes the current implementation

Write-Host "==========================================="
Write-Host "ORDERS SERVICE SOURCE CODE ANALYSIS"
Write-Host "==========================================="
Write-Host ""

# Configuration
$repoUrl = "https://github.com/ocp-power-demos/sock-shop-orders.git"
$targetDir = "d:\sock-shop-orders"
$analysisOutput = "d:\sock-shop-demo\orders-source-analysis.txt"

# Step 1: Clone repository
Write-Host "Step 1: Cloning orders service repository..." -ForegroundColor Cyan

if (Test-Path $targetDir) {
    Write-Host "⚠️  Directory already exists: $targetDir" -ForegroundColor Yellow
    $response = Read-Host "Delete and re-clone? (y/n)"
    if ($response -eq 'y') {
        Remove-Item -Recurse -Force $targetDir
        Write-Host "✅ Deleted existing directory" -ForegroundColor Green
    } else {
        Write-Host "Using existing directory" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $targetDir)) {
    Write-Host "Cloning from: $repoUrl" -ForegroundColor White
    git clone $repoUrl $targetDir
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ ERROR: Failed to clone repository" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Repository cloned successfully" -ForegroundColor Green
}

Write-Host ""

# Step 2: Analyze directory structure
Write-Host "Step 2: Analyzing directory structure..." -ForegroundColor Cyan
Write-Host ""

Set-Location $targetDir

Write-Host "Repository structure:" -ForegroundColor Yellow
tree /F /A | Select-Object -First 50

Write-Host ""

# Step 3: Find key Java files
Write-Host "Step 3: Locating key source files..." -ForegroundColor Cyan
Write-Host ""

$analysisResults = @()
$analysisResults += "==========================================="
$analysisResults += "ORDERS SERVICE SOURCE CODE ANALYSIS"
$analysisResults += "Date: $(Get-Date)"
$analysisResults += "==========================================="
$analysisResults += ""

# Find CustomerOrder.java
Write-Host "Looking for CustomerOrder.java..." -ForegroundColor White
$customerOrderFile = Get-ChildItem -Recurse -Filter "CustomerOrder.java" -ErrorAction SilentlyContinue

if ($customerOrderFile) {
    Write-Host "✅ Found: $($customerOrderFile.FullName)" -ForegroundColor Green
    $analysisResults += "CustomerOrder.java:"
    $analysisResults += "  Location: $($customerOrderFile.FullName)"
    $analysisResults += "  Size: $($customerOrderFile.Length) bytes"
    $analysisResults += ""
} else {
    Write-Host "❌ NOT FOUND: CustomerOrder.java" -ForegroundColor Red
    $analysisResults += "CustomerOrder.java: NOT FOUND"
    $analysisResults += ""
}

# Find OrdersController.java
Write-Host "Looking for OrdersController.java..." -ForegroundColor White
$ordersControllerFile = Get-ChildItem -Recurse -Filter "OrdersController.java" -ErrorAction SilentlyContinue

if ($ordersControllerFile) {
    Write-Host "✅ Found: $($ordersControllerFile.FullName)" -ForegroundColor Green
    $analysisResults += "OrdersController.java:"
    $analysisResults += "  Location: $($ordersControllerFile.FullName)"
    $analysisResults += "  Size: $($ordersControllerFile.Length) bytes"
    $analysisResults += ""
} else {
    Write-Host "❌ NOT FOUND: OrdersController.java" -ForegroundColor Red
    $analysisResults += "OrdersController.java: NOT FOUND"
    $analysisResults += ""
}

# Find any Status-related files
Write-Host "Looking for Status-related files..." -ForegroundColor White
$statusFiles = Get-ChildItem -Recurse -Filter "*Status*.java" -ErrorAction SilentlyContinue

if ($statusFiles) {
    Write-Host "✅ Found $($statusFiles.Count) Status-related files:" -ForegroundColor Green
    $analysisResults += "Status-related files:"
    foreach ($file in $statusFiles) {
        Write-Host "   - $($file.Name)" -ForegroundColor White
        $analysisResults += "  - $($file.FullName)"
    }
    $analysisResults += ""
} else {
    Write-Host "ℹ️  No existing Status enum files found" -ForegroundColor Yellow
    $analysisResults += "Status enum: NOT FOUND (will need to create)"
    $analysisResults += ""
}

Write-Host ""

# Step 4: Search for "status" mentions
Write-Host "Step 4: Searching for 'status' references in code..." -ForegroundColor Cyan
Write-Host ""

$analysisResults += "==========================================="
$analysisResults += "STATUS FIELD ANALYSIS"
$analysisResults += "==========================================="
$analysisResults += ""

$statusMentions = Get-ChildItem -Recurse -Include "*.java" | Select-String -Pattern "\bstatus\b" -CaseSensitive:$false

$analysisResults += "Total mentions of 'status' in Java files: $($statusMentions.Count)"
$analysisResults += ""

# Group by file
$groupedMentions = $statusMentions | Group-Object Path | Sort-Object Count -Descending | Select-Object -First 10

$analysisResults += "Top 10 files with 'status' mentions:"
foreach ($group in $groupedMentions) {
    $fileName = Split-Path $group.Name -Leaf
    $analysisResults += "  $fileName : $($group.Count) mentions"
}
$analysisResults += ""

Write-Host "Found $($statusMentions.Count) mentions of 'status' in Java files" -ForegroundColor White
Write-Host ""

# Step 5: Analyze CustomerOrder.java specifically
if ($customerOrderFile) {
    Write-Host "Step 5: Analyzing CustomerOrder.java in detail..." -ForegroundColor Cyan
    Write-Host ""
    
    $customerOrderContent = Get-Content $customerOrderFile.FullName -Raw
    
    # Check if status field exists
    if ($customerOrderContent -match 'private\s+(\w+)\s+status') {
        $statusType = $Matches[1]
        Write-Host "✅ Status field found: type = $statusType" -ForegroundColor Green
        $analysisResults += "CustomerOrder.java - Status field:"
        $analysisResults += "  Type: $statusType"
        
        # Check for default value
        if ($customerOrderContent -match 'private\s+\w+\s+status\s*=\s*([^;]+);') {
            $defaultValue = $Matches[1].Trim()
            Write-Host "✅ Default value: $defaultValue" -ForegroundColor Green
            $analysisResults += "  Default value: $defaultValue"
        } else {
            Write-Host "❌ No default value set!" -ForegroundColor Red
            $analysisResults += "  Default value: NONE (BUG!)"
        }
        
    } else {
        Write-Host "❌ Status field NOT found in CustomerOrder.java!" -ForegroundColor Red
        $analysisResults += "CustomerOrder.java - Status field: NOT FOUND"
    }
    
    $analysisResults += ""
    
    # Show first 50 lines of CustomerOrder.java
    $analysisResults += "CustomerOrder.java - First 50 lines:"
    $analysisResults += "-----------------------------------"
    $firstLines = Get-Content $customerOrderFile.FullName | Select-Object -First 50
    $analysisResults += $firstLines
    $analysisResults += ""
}

Write-Host ""

# Step 6: Analyze OrdersController.java specifically
if ($ordersControllerFile) {
    Write-Host "Step 6: Analyzing OrdersController.java in detail..." -ForegroundColor Cyan
    Write-Host ""
    
    $controllerContent = Get-Content $ordersControllerFile.FullName -Raw
    
    # Find the newOrder method
    if ($controllerContent -match 'public\s+CustomerOrder\s+newOrder') {
        Write-Host "✅ newOrder() method found" -ForegroundColor Green
        $analysisResults += "OrdersController.java - newOrder() method:"
        $analysisResults += "  Status: FOUND"
        
        # Check for status setting
        $statusSetCount = ([regex]::Matches($controllerContent, '\.setStatus\(')).Count
        Write-Host "   Status setting calls: $statusSetCount" -ForegroundColor White
        $analysisResults += "  setStatus() calls: $statusSetCount"
        
        # Check for try-catch around payment
        if ($controllerContent -match 'try\s*\{[^}]*payment[^}]*\}\s*catch') {
            Write-Host "✅ Try-catch around payment: YES" -ForegroundColor Green
            $analysisResults += "  Try-catch for payment: YES"
        } else {
            Write-Host "❌ Try-catch around payment: NO (BUG!)" -ForegroundColor Red
            $analysisResults += "  Try-catch for payment: NO (BUG!)"
        }
        
    } else {
        Write-Host "❌ newOrder() method NOT found!" -ForegroundColor Red
        $analysisResults += "OrdersController.java - newOrder() method: NOT FOUND"
    }
    
    $analysisResults += ""
    
    # Show the newOrder method
    $analysisResults += "OrdersController.java - newOrder() method excerpt:"
    $analysisResults += "---------------------------------------------------"
    
    # Extract newOrder method (rough extraction)
    if ($controllerContent -match '(?s)(public\s+CustomerOrder\s+newOrder.*?\n\s*\})') {
        $newOrderMethod = $Matches[1]
        $analysisResults += $newOrderMethod
    } else {
        $analysisResults += "Could not extract newOrder() method"
    }
    
    $analysisResults += ""
}

Write-Host ""

# Step 7: Check build configuration
Write-Host "Step 7: Analyzing build configuration..." -ForegroundColor Cyan
Write-Host ""

$pomFile = Join-Path $targetDir "pom.xml"
if (Test-Path $pomFile) {
    Write-Host "✅ Found pom.xml" -ForegroundColor Green
    $analysisResults += "Build Configuration:"
    $analysisResults += "  Build tool: Maven (pom.xml found)"
    
    $pomContent = Get-Content $pomFile -Raw
    
    # Extract version
    if ($pomContent -match '<version>([^<]+)</version>') {
        $version = $Matches[1]
        Write-Host "   Version: $version" -ForegroundColor White
        $analysisResults += "  Version: $version"
    }
    
    # Extract Spring Boot version
    if ($pomContent -match '<spring-boot\.version>([^<]+)</spring-boot\.version>') {
        $springVersion = $Matches[1]
        Write-Host "   Spring Boot: $springVersion" -ForegroundColor White
        $analysisResults += "  Spring Boot: $springVersion"
    }
    
} else {
    Write-Host "ℹ️  pom.xml not found, checking for Gradle..." -ForegroundColor Yellow
    $gradleFile = Join-Path $targetDir "build.gradle"
    if (Test-Path $gradleFile) {
        Write-Host "✅ Found build.gradle" -ForegroundColor Green
        $analysisResults += "Build Configuration:"
        $analysisResults += "  Build tool: Gradle (build.gradle found)"
    }
}

$analysisResults += ""
Write-Host ""

# Step 8: Check for Dockerfile
Write-Host "Step 8: Checking Dockerfile..." -ForegroundColor Cyan

$dockerfile = Join-Path $targetDir "Dockerfile"
if (Test-Path $dockerfile) {
    Write-Host "✅ Dockerfile found" -ForegroundColor Green
    $analysisResults += "Dockerfile:"
    $analysisResults += "  Status: FOUND"
    $analysisResults += "  Location: $dockerfile"
    
    $dockerfileContent = Get-Content $dockerfile
    $analysisResults += ""
    $analysisResults += "Dockerfile contents:"
    $analysisResults += "-------------------"
    $analysisResults += $dockerfileContent
} else {
    Write-Host "⚠️  Dockerfile not found" -ForegroundColor Yellow
    $analysisResults += "Dockerfile: NOT FOUND"
}

$analysisResults += ""
Write-Host ""

# Step 9: Save analysis results
Write-Host "Step 9: Saving analysis results..." -ForegroundColor Cyan

$analysisResults | Out-File -FilePath $analysisOutput -Encoding UTF8

Write-Host "✅ Analysis saved to: $analysisOutput" -ForegroundColor Green
Write-Host ""

# Step 10: Summary
Write-Host "==========================================="
Write-Host "ANALYSIS COMPLETE"
Write-Host "==========================================="
Write-Host ""

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Repository cloned: $targetDir" -ForegroundColor White
Write-Host "  Analysis saved: $analysisOutput" -ForegroundColor White
Write-Host ""

if ($customerOrderFile -and $ordersControllerFile) {
    Write-Host "✅ Key files located successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review analysis file: code $analysisOutput" -ForegroundColor White
    Write-Host "  2. Read CustomerOrder.java: code $($customerOrderFile.FullName)" -ForegroundColor White
    Write-Host "  3. Read OrdersController.java: code $($ordersControllerFile.FullName)" -ForegroundColor White
    Write-Host "  4. Confirm bug locations before making changes" -ForegroundColor White
} else {
    Write-Host "⚠️  Some key files were not found" -ForegroundColor Yellow
    Write-Host "   Review the analysis file for details" -ForegroundColor White
}

Write-Host ""
Write-Host "==========================================="
