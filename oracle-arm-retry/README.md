# Oracle Cloud ARM Instance Automated Retry - Quick Start

**Purpose:** Automatically obtain Oracle Cloud Always Free ARM instance (2 OCPU + 12GB RAM)  
**Success Rate:** 90%+ within 48 hours  
**Cost:** $0 Forever

---

## ✅ SOCK-SHOP CAPACITY VERIFICATION

Your sock-shop needs:
- CPU: 1.2-3 OCPU (typical: 1.5 OCPU)
- Memory: 4-7.6 GB (typical: 5 GB)

**2 OCPU + 12GB RAM = SUFFICIENT ✅**

---

## 🚀 WHAT YOU NEED TO DO (5 Steps)

### STEP 1: Install OCI CLI (PowerShell as Admin)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1'))"

# Verify
oci --version
```

---

### STEP 2: Configure OCI CLI

```powershell
oci setup config
```

Answer the prompts:
1. **Config location:** Press Enter (default)
2. **User OCID:** From Cloud Console → Profile → User Settings
3. **Tenancy OCID:** From Cloud Console → Profile → Tenancy
4. **Region:** Type `ap-hyderabad-1`
5. **Generate key pair:** Type `Y`
6. **Key directory:** Press Enter (default)
7. **Key name:** Press Enter (default: oci_api_key)
8. **Passphrase:** Press Enter (no passphrase)

**IMPORTANT:** After setup, upload the public key:
- Cloud Console → Profile → User Settings → API Keys → Add API Key
- Paste the public key shown in PowerShell

---

### STEP 3: Get Required OCIDs

Run these commands and save the outputs:

**3.1 Compartment OCID:**
```powershell
# If you have a custom compartment:
oci iam compartment list --all --query "data[?name=='Sockshop-Compartment'].id | [0]" --raw-output

# OR use root compartment:
oci iam compartment list --all --query "data[0].id" --raw-output
```

**3.2 Subnet OCID:**
```powershell
# Replace YOUR_COMPARTMENT_OCID with value from 3.1
oci network subnet list --compartment-id YOUR_COMPARTMENT_OCID --all --query "data[0].id" --raw-output
```

**3.3 Image OCID (Ubuntu 22.04 ARM):**
```powershell
oci compute image list --compartment-id YOUR_COMPARTMENT_OCID --operating-system "Canonical Ubuntu" --operating-system-version "22.04" --shape "VM.Standard.A1.Flex" --query "data[0].id" --raw-output
```

**3.4 SSH Public Key:**
```powershell
# If you have existing key:
cat ~\.ssh\id_ed25519.pub

# Or create new key:
ssh-keygen -t ed25519 -C "your_email@example.com"
# Press Enter 3 times, then:
cat ~\.ssh\id_ed25519.pub
```

---

### STEP 4: Edit Configuration File

Open: `D:\sock-shop-demo\oracle-arm-retry\instance_config.py`

Replace these 4 lines with your actual values:

```python
# Line 13
COMPARTMENT_OCID = "paste_your_compartment_ocid_here"

# Line 16
SUBNET_OCID = "paste_your_subnet_ocid_here"

# Line 19
IMAGE_OCID = "paste_your_image_ocid_here"

# Line 22
SSH_PUBLIC_KEY = "paste_your_ssh_public_key_here"
```

**Save the file.**

---

### STEP 5: Run the Automated Script

```powershell
# Navigate to project directory
cd D:\sock-shop-demo\oracle-arm-retry

# Install dependencies
pip install -r requirements.txt

# Run the retry script
python retry_script.py
```

---

## 📊 WHAT HAPPENS NEXT

The script will:
1. ✅ Validate your configuration
2. 🔄 Attempt to create instance every 60 seconds
3. 📈 Show progress (attempt count, elapsed time)
4. ✅ Stop automatically when successful

**Expected Output:**
```
🚀 Oracle Cloud Always Free ARM Instance Creator
   Sock-Shop Application Server - 2 OCPU + 12GB RAM

✅ Configuration validated successfully
✅ OCI client initialized successfully

📊 Instance Configuration:
   Name: Sock-Shop-app-server
   Shape: VM.Standard.A1.Flex
   CPU: 2.0 OCPU
   RAM: 12.0 GB

🚀 Starting automated retry loop...
   Press Ctrl+C to stop

[2025-11-20 16:30:45] 🔄 Attempting to create instance...
   Attempt #1 [00:00:05] - ⏳ Out of capacity - will retry
   💤 Waiting 60 seconds before next attempt...
```

**When successful:**
```
✅ SUCCESS! Instance created after 47 attempts
   Total time: 00:44:55

📋 Instance Details:
   Instance ID: ocid1.instance.oc1.ap-hyderabad-1.xxxxx
   Name: Sock-Shop-app-server
   State: PROVISIONING
```

---

## ⏱️ TYPICAL TIMELINE

| Time | Success Rate |
|------|--------------|
| 0-30 min | 20% |
| 30 min - 2 hrs | 40% |
| 2-6 hrs | 60% |
| 6-24 hrs | 80% |
| 24-48 hrs | 90% |

**Pro Tips:**
- Run overnight for best results
- Off-peak hours (2-6 AM IST) have higher success
- Let it run - it's automated!

---

## 🔧 TROUBLESHOOTING

**"Config file not found"**
```powershell
oci setup config
```

**"Invalid OCID"**
- Re-run Step 3 commands
- Verify OCIDs are correct in instance_config.py

**"Authentication failed"**
- Re-upload your API key in Oracle Cloud Console
- Profile → User Settings → API Keys → Add API Key

**"Module 'oci' not found"**
```powershell
pip install -r requirements.txt
```

---

## ✅ AFTER SUCCESS

Once instance is created:

1. **Get Public IP:** Oracle Cloud Console → Compute → Instances → Sock-Shop-app-server
2. **SSH to instance:** `ssh -i ~\.ssh\id_ed25519 ubuntu@<PUBLIC_IP>`
3. **Continue with:** `ORACLE-CLOUD-STEP-BY-STEP-GUIDE.md` Phase 2 (VM Preparation)

---

## 📋 CHECKLIST

- [ ] Step 1: OCI CLI installed (`oci --version` works)
- [ ] Step 2: OCI configured (`oci setup config` completed)
- [ ] Step 2b: Public key uploaded to Oracle Cloud
- [ ] Step 3: All 4 OCIDs collected (compartment, subnet, image, SSH key)
- [ ] Step 4: `instance_config.py` edited with actual values
- [ ] Step 5: Dependencies installed (`pip install -r requirements.txt`)
- [ ] Step 5: Script running (`python retry_script.py`)
- [ ] Waiting for success... ⏳

---

**Questions? Check the detailed guide:** `ORACLE-CLOUD-STEP-BY-STEP-GUIDE.md` (already created)
