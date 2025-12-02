# Oracle Cloud OCID Gathering Script
# This script helps you collect all required OCIDs for instance creation

Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "=" * 69 -ForegroundColor Cyan
Write-Host "🔍 Oracle Cloud OCID Gathering Script" -ForegroundColor Cyan
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "=" * 69 -ForegroundColor Cyan
Write-Host ""

# Check if OCI CLI is installed
Write-Host "Checking OCI CLI installation..." -ForegroundColor Yellow
try {
    $ociVersion = oci --version 2>&1
    Write-Host "✅ OCI CLI installed: $ociVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ OCI CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   Run: powershell -NoProfile -ExecutionPolicy Bypass -Command `"iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1'))`"" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "=" * 69 -ForegroundColor Cyan
Write-Host ""

# Initialize results object
$ocids = @{
    compartment = ""
    subnet = ""
    image = ""
    ssh_key = ""
}

# Step 1: Get Compartment OCID
Write-Host "📋 Step 1: Getting Compartment OCID..." -ForegroundColor Cyan
Write-Host ""

Write-Host "   Searching for compartments..." -ForegroundColor Yellow

try {
    # Try to find custom compartment first
    $compartmentOcid = oci iam compartment list --all --query "data[?name=='Sockshop-Compartment'].id | [0]" --raw-output 2>$null
    
    if ([string]::IsNullOrWhiteSpace($compartmentOcid) -or $compartmentOcid -eq "null") {
        Write-Host "   ℹ️  Custom compartment 'Sockshop-Compartment' not found" -ForegroundColor Yellow
        Write-Host "   Using root compartment..." -ForegroundColor Yellow
        
        # Use root compartment (first in list)
        $compartmentOcid = oci iam compartment list --all --query "data[0].id" --raw-output
    } else {
        Write-Host "   ✅ Found custom compartment 'Sockshop-Compartment'" -ForegroundColor Green
    }
    
    if ([string]::IsNullOrWhiteSpace($compartmentOcid)) {
        throw "Failed to get compartment OCID"
    }
    
    $ocids.compartment = $compartmentOcid
    Write-Host "   Compartment OCID: " -NoNewline -ForegroundColor Green
    Write-Host $compartmentOcid -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "   ❌ Error: $_" -ForegroundColor Red
    Write-Host "   Please run 'oci setup config' first" -ForegroundColor Yellow
    exit 1
}

# Step 2: Get Subnet OCID
Write-Host "📋 Step 2: Getting Subnet OCID..." -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "   Searching for subnets in compartment..." -ForegroundColor Yellow
    
    $subnetOcid = oci network subnet list --compartment-id $compartmentOcid --all --query "data[0].id" --raw-output 2>&1
    
    if ([string]::IsNullOrWhiteSpace($subnetOcid) -or $subnetOcid -eq "null") {
        Write-Host "   ⚠️  No subnets found. You need to create a VCN first." -ForegroundColor Yellow
        Write-Host "   Go to: Oracle Cloud Console → Networking → Virtual Cloud Networks" -ForegroundColor Yellow
        $ocids.subnet = "SUBNET_NOT_FOUND_CREATE_VCN_FIRST"
    } else {
        $ocids.subnet = $subnetOcid
        Write-Host "   ✅ Found subnet" -ForegroundColor Green
        Write-Host "   Subnet OCID: " -NoNewline -ForegroundColor Green
        Write-Host $subnetOcid -ForegroundColor White
    }
    Write-Host ""
} catch {
    Write-Host "   ❌ Error getting subnet: $_" -ForegroundColor Red
    $ocids.subnet = "ERROR_GETTING_SUBNET"
    Write-Host ""
}

# Step 3: Get Ubuntu 22.04 ARM Image OCID
Write-Host "📋 Step 3: Getting Ubuntu 22.04 ARM Image OCID..." -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "   Searching for Ubuntu 22.04 ARM images (this may take 30 seconds)..." -ForegroundColor Yellow
    
    $imageOcid = oci compute image list `
        --compartment-id $compartmentOcid `
        --operating-system "Canonical Ubuntu" `
        --operating-system-version "22.04" `
        --shape "VM.Standard.A1.Flex" `
        --query "data[0].id" `
        --raw-output 2>&1
    
    if ([string]::IsNullOrWhiteSpace($imageOcid) -or $imageOcid -eq "null") {
        Write-Host "   ⚠️  No Ubuntu 22.04 ARM image found. Using generic query..." -ForegroundColor Yellow
        
        # Fallback: try without shape filter
        $imageOcid = oci compute image list `
            --compartment-id $compartmentOcid `
            --operating-system "Canonical Ubuntu" `
            --query "data[0].id" `
            --raw-output 2>&1
    }
    
    if ([string]::IsNullOrWhiteSpace($imageOcid) -or $imageOcid -eq "null") {
        $ocids.image = "IMAGE_NOT_FOUND_CHECK_REGION"
        Write-Host "   ⚠️  No image found. Verify you're in ap-hyderabad-1 region" -ForegroundColor Yellow
    } else {
        $ocids.image = $imageOcid
        Write-Host "   ✅ Found Ubuntu 22.04 ARM image" -ForegroundColor Green
        Write-Host "   Image OCID: " -NoNewline -ForegroundColor Green
        Write-Host $imageOcid -ForegroundColor White
    }
    Write-Host ""
} catch {
    Write-Host "   ❌ Error getting image: $_" -ForegroundColor Red
    $ocids.image = "ERROR_GETTING_IMAGE"
    Write-Host ""
}

# Step 4: Get SSH Public Key
Write-Host "📋 Step 4: Getting SSH Public Key..." -ForegroundColor Cyan
Write-Host ""

$sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"

if (Test-Path $sshKeyPath) {
    try {
        $sshKey = Get-Content $sshKeyPath -Raw
        $sshKey = $sshKey.Trim()
        $ocids.ssh_key = $sshKey
        Write-Host "   ✅ Found SSH public key at: $sshKeyPath" -ForegroundColor Green
        Write-Host "   SSH Key: " -NoNewline -ForegroundColor Green
        Write-Host $sshKey.Substring(0, [Math]::Min(60, $sshKey.Length)) -NoNewline -ForegroundColor White
        Write-Host "..." -ForegroundColor White
        Write-Host ""
    } catch {
        Write-Host "   ❌ Error reading SSH key: $_" -ForegroundColor Red
        $ocids.ssh_key = "ERROR_READING_SSH_KEY"
        Write-Host ""
    }
} else {
    Write-Host "   ⚠️  SSH key not found at: $sshKeyPath" -ForegroundColor Yellow
    Write-Host "   Creating new SSH key..." -ForegroundColor Yellow
    
    try {
        # Create .ssh directory if it doesn't exist
        $sshDir = "$env:USERPROFILE\.ssh"
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }
        
        # Generate SSH key
        ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""' -C "sock-shop-oracle-cloud" 2>&1 | Out-Null
        
        $sshKey = Get-Content $sshKeyPath -Raw
        $sshKey = $sshKey.Trim()
        $ocids.ssh_key = $sshKey
        
        Write-Host "   ✅ Created new SSH key" -ForegroundColor Green
        Write-Host "   SSH Key: " -NoNewline -ForegroundColor Green
        Write-Host $sshKey.Substring(0, [Math]::Min(60, $sshKey.Length)) -NoNewline -ForegroundColor White
        Write-Host "..." -ForegroundColor White
        Write-Host ""
    } catch {
        Write-Host "   ❌ Error creating SSH key: $_" -ForegroundColor Red
        $ocids.ssh_key = "SSH_KEY_CREATION_FAILED"
        Write-Host ""
    }
}

# Summary
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "=" * 69 -ForegroundColor Cyan
Write-Host "📊 Summary of Collected OCIDs" -ForegroundColor Cyan
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host "=" * 69 -ForegroundColor Cyan
Write-Host ""

Write-Host "COMPARTMENT_OCID = `"$($ocids.compartment)`"" -ForegroundColor Yellow
Write-Host "SUBNET_OCID = `"$($ocids.subnet)`"" -ForegroundColor Yellow
Write-Host "IMAGE_OCID = `"$($ocids.image)`"" -ForegroundColor Yellow
Write-Host "SSH_PUBLIC_KEY = `"$($ocids.ssh_key.Substring(0, [Math]::Min(60, $ocids.ssh_key.Length)))...`"" -ForegroundColor Yellow
Write-Host ""

# Check for errors
$hasErrors = $false
if ($ocids.subnet -like "*NOT_FOUND*" -or $ocids.subnet -like "*ERROR*") {
    Write-Host "⚠️  SUBNET issue detected. You may need to create a VCN first." -ForegroundColor Red
    $hasErrors = $true
}
if ($ocids.image -like "*NOT_FOUND*" -or $ocids.image -like "*ERROR*") {
    Write-Host "⚠️  IMAGE issue detected. Verify region is ap-hyderabad-1." -ForegroundColor Red
    $hasErrors = $true
}
if ($ocids.ssh_key -like "*ERROR*" -or $ocids.ssh_key -like "*FAILED*") {
    Write-Host "⚠️  SSH KEY issue detected. Create key manually." -ForegroundColor Red
    $hasErrors = $true
}

if (-not $hasErrors) {
    Write-Host "=" -NoNewline -ForegroundColor Green
    Write-Host "=" * 69 -ForegroundColor Green
    Write-Host "✅ All OCIDs collected successfully!" -ForegroundColor Green
    Write-Host "=" -NoNewline -ForegroundColor Green
    Write-Host "=" * 69 -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next Step:" -ForegroundColor Cyan
    Write-Host "   1. Open: D:\sock-shop-demo\oracle-arm-retry\instance_config.py" -ForegroundColor Yellow
    Write-Host "   2. Replace the 4 placeholder values with the OCIDs shown above" -ForegroundColor Yellow
    Write-Host "   3. Save the file" -ForegroundColor Yellow
    Write-Host "   4. Run: python retry_script.py" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "=" -NoNewline -ForegroundColor Red
    Write-Host "=" * 69 -ForegroundColor Red
    Write-Host "⚠️  Some OCIDs could not be retrieved" -ForegroundColor Red
    Write-Host "=" -NoNewline -ForegroundColor Red
    Write-Host "=" * 69 -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 Action Required:" -ForegroundColor Cyan
    Write-Host "   1. Fix the issues mentioned above" -ForegroundColor Yellow
    Write-Host "   2. Run this script again: .\get-ocids.ps1" -ForegroundColor Yellow
    Write-Host ""
}

# Save to file for easy reference
$outputFile = "D:\sock-shop-demo\oracle-arm-retry\collected-ocids.txt"
@"
# Collected OCIDs for Oracle Cloud Instance Creation
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

COMPARTMENT_OCID = "$($ocids.compartment)"

SUBNET_OCID = "$($ocids.subnet)"

IMAGE_OCID = "$($ocids.image)"

SSH_PUBLIC_KEY = "$($ocids.ssh_key)"

# Instructions:
# 1. Copy these values (without quotes around the actual OCIDs)
# 2. Open: D:\sock-shop-demo\oracle-arm-retry\instance_config.py
# 3. Replace the placeholder values on lines 12, 15, 18, and 21
# 4. Save the file
# 5. Run: python retry_script.py
"@ | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "💾 OCIDs saved to: $outputFile" -ForegroundColor Green
Write-Host ""
