# Oracle Cloud Migration: Complete Step-by-Step Guide

**Prerequisites:** Read `ORACLE-CLOUD-FEASIBILITY-REPORT.md` first  
**Time Required:** 4-5 hours  
**Skill Level:** Intermediate (following exact steps)  
**Cost:** $0 (100% FREE)

---

## 🗺️ Migration Roadmap

```
Phase 1: Oracle Cloud Setup (30 min)
├── Create VM instance (A1.Flex, 4 OCPU, 24 GB)
├── Configure networking & firewall
└── SSH access setup

Phase 2: VM Preparation (60 min)
├── System update & tools install
├── Install Docker & K3s
├── Configure storage (data volume)
└── Setup kubectl access

Phase 3: Deploy Sock Shop (45 min)
├── Clone manifests
├── Modify for ARM64 compatibility
├── Deploy microservices & databases
└── Verify all pods running

Phase 4: Deploy Monitoring (45 min)
├── Install Prometheus + Grafana (Helm)
├── Deploy Datadog Agent (ARM64)
└── Verify metrics & logs

Phase 5: Migrate Incidents (30 min)
├── Adapt PowerShell scripts for remote execution
├── Test all 9 incident scenarios
└── Verify Datadog observability

Phase 6: Testing & Validation (60 min)
├── End-to-end user journey
├── Run load tests
└── Validate Healr AI SRE integration
```

---

## Phase 1: Oracle Cloud Setup (30 minutes)

### Step 1.1: Log In & Verify Home Region

1. **Open Browser:**
   ```
   URL: https://cloud.oracle.com/?region=ap-hyderabad-1
   ```

2. **Sign In:**
   - Use your existing Oracle Cloud credentials
   - Click "Sign In"

3. **Verify Home Region:**
   ```
   Top-right corner → Shows current region
   Verify: "India Central (Hyderabad)" or "ap-hyderabad-1"
   ```

   ⚠️ **CRITICAL:** If different region shown, SWITCH to ap-hyderabad-1 now!

### Step 1.2: Create VM Instance

1. **Navigate to Compute Instances:**
   ```
   Click: ☰ (hamburger menu, top-left)
   → Compute
   → Instances
   ```

2. **Click "Create Instance":**

3. **Configure Instance - Part 1 (Name & Placement):**
   ```
   Name: sockshop-prod
   
   Compartment: (root) [leave default]
   
   Placement:
   ├── Availability Domain: AD-1
   │   (If "Out of capacity" error, try AD-2 or AD-3)
   └── Fault Domain: [Leave default - Oracle chooses]
   ```

4. **Configure Instance - Part 2 (Image):**
   ```
   Image:
   ├── Click: "Change Image"
   ├── Select: Oracle Linux
   ├── Version: 8 (not 7 or 9)
   ├── Architecture: ARM64 (Ampere)
   └── Verify: "Always Free Eligible" badge appears ✅
   
   Click: "Select Image"
   ```

5. **Configure Instance - Part 3 (Shape):**
   ```
   Shape:
   ├── Click: "Change Shape"
   ├── Instance Type: Virtual Machine
   ├── Shape Series: Ampere
   ├── Select: VM.Standard.A1.Flex
   └── Verify: "Always Free Eligible" badge appears ✅
   
   Configure resources:
   ├── Number of OCPUs: 4 (slider to maximum)
   ├── Amount of memory (GB): 24 (auto-adjusts to 6 GB per OCPU)
   └── Network bandwidth (Gbps): 4 (auto-set)
   
   Click: "Select Shape"
   ```

   ⚠️ **CRITICAL CHECK:**
   ```
   You MUST see "Always Free Eligible" badge for BOTH image and shape!
   If not visible, you're selecting paid resources - STOP and reselect.
   ```

6. **Configure Instance - Part 4 (Networking):**
   ```
   Primary VNIC Information:
   ├── ✅ Create new virtual cloud network (if first time)
   │   ├── Name: sockshop-vcn
   │   └── Compartment: (root)
   │
   ├── ✅ Create new public subnet
   │   ├── Name: sockshop-public-subnet
   │   └── Compartment: (root)
   │
   ├── ✅ Assign a public IPv4 address (MUST be checked!)
   │
   └── ❌ Use network security groups (leave unchecked)
   ```

7. **Configure Instance - Part 5 (SSH Keys):**
   ```
   Add SSH keys:
   ├── Select: "Generate a key pair for me" (EASIEST)
   ├── Click: "Save Private Key" 
   │   └── Save as: sockshop-ssh-key.key (to Downloads folder)
   ├── Click: "Save Public Key"
   │   └── Save as: sockshop-ssh-key.pub (to Downloads folder)
   └── ⚠️ CRITICAL: Without these keys, you CANNOT access VM!
   ```

8. **Configure Instance - Part 6 (Boot Volume):**
   ```
   Boot Volume:
   ├── ✅ Specify a custom boot volume size
   ├── Boot volume size (GB): 100
   │   (Leaves 100 GB for data volume later)
   └── Backup policy: Bronze (free)
   ```

9. **Create Instance:**
   ```
   Review all settings:
   ├── Name: sockshop-prod
   ├── Shape: VM.Standard.A1.Flex (4 OCPU, 24 GB) ✅ Always Free
   ├── Image: Oracle Linux 8 (ARM64) ✅ Always Free
   ├── Boot volume: 100 GB
   ├── Public IP: Will be assigned
   └── SSH keys: Downloaded
   
   Click: "Create" button (bottom)
   ```

10. **Wait for Provisioning:**
    ```
    Status: Provisioning... (orange icon)
    ↓ (wait 2-5 minutes)
    Status: Running (green icon) ✅
    ```

### Step 1.3: Note Instance Details

**Once status = Running, copy these details:**

```
Instance Details Page:

Public IP address: ________________ (e.g., 158.101.123.45)
Private IP address: _______________ (e.g., 10.0.0.5)
Shape: VM.Standard.A1.Flex
OCPU count: 4
Memory (GB): 24
Boot volume size (GB): 100
Always Free eligible: ✅ Yes

Save these! You'll need the Public IP constantly.
```

### Step 1.4: Configure Security List (Firewall Rules)

**Why:** Oracle Cloud has TWO firewalls:
1. Security List (cloud-level) ← We configure this now
2. firewalld (OS-level) ← We configure later

**Steps:**

1. **Navigate to Security List:**
   ```
   On Instance Details page:
   → Scroll to "Primary VNIC" section
   → Click: "Subnet" link (e.g., sockshop-public-subnet)
   → Left side menu: "Security Lists"
   → Click: "Default Security List for sockshop-vcn"
   ```

2. **Add Ingress Rules (one by one):**

   Click "Add Ingress Rules" button, then add each rule below:

   **Rule 1: SSH (Already exists, verify)**
   ```
   Source Type: CIDR
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Source Port Range: (empty)
   Destination Port Range: 22
   Description: SSH access
   ```

   **Rule 2: Kubernetes API**
   ```
   Source Type: CIDR
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Destination Port Range: 6443
   Description: K3s API Server
   Click: "Add Ingress Rules"
   ```

   **Rule 3: Sock Shop Front-End**
   ```
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Destination Port Range: 2025
   Description: Sock Shop UI
   Click: "Add Ingress Rules"
   ```

   **Rule 4: Grafana**
   ```
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Destination Port Range: 3025
   Description: Grafana Dashboard
   Click: "Add Ingress Rules"
   ```

   **Rule 5: Prometheus**
   ```
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Destination Port Range: 4025
   Description: Prometheus Metrics
   Click: "Add Ingress Rules"
   ```

   **Rule 6: RabbitMQ Management**
   ```
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Destination Port Range: 15672
   Description: RabbitMQ Management UI
   Click: "Add Ingress Rules"
   ```

   **Rule 7: NodePort Range (Optional)**
   ```
   Source CIDR: 0.0.0.0/0
   IP Protocol: TCP
   Destination Port Range: 30000-32767
   Description: Kubernetes NodePort Services
   Click: "Add Ingress Rules"
   ```

3. **Verify Ingress Rules:**
   ```
   Security List should now show 7-8 ingress rules total
   (SSH + 6 new rules)
   ```

✅ **Phase 1 Complete!** You now have:
- Running VM (4 OCPU, 24 GB, 100 GB boot)
- Public IP address
- SSH keys downloaded
- Firewall configured
- 100% FREE (verified "Always Free" badges)

---

## Phase 2: VM Preparation (60 minutes)

### Step 2.1: Connect via SSH

**From Windows PowerShell:**

```powershell
# 1. Navigate to Downloads folder
cd ~\Downloads

# 2. Fix SSH key permissions (Windows-specific)
icacls .\sockshop-ssh-key.key /inheritance:r
icacls .\sockshop-ssh-key.key /grant:r "$($env:USERNAME):(R)"

# 3. Connect to VM (replace <PUBLIC_IP> with your actual IP)
ssh -i .\sockshop-ssh-key.key opc@<PUBLIC_IP>

# Example:
# ssh -i .\sockshop-ssh-key.key opc@158.101.123.45
```

**First connection prompt:**
```bash
The authenticity of host '158.101.123.45 (158.101.123.45)' can't be established.
ED25519 key fingerprint is SHA256:xxxxx.
Are you sure you want to continue connecting (yes/no/[fingerprint])? 

Type: yes [ENTER]
```

**Success looks like:**
```bash
Warning: Permanently added '158.101.123.45' (ED25519) to the list of known hosts.
[opc@sockshop-prod ~]$ 
```

✅ **You're connected!**

### Step 2.2: System Update & Essential Tools

```bash
# Switch to root user (easier for setup)
sudo su -

# You should now see:
[root@sockshop-prod ~]#

# Update all packages (takes 5-10 minutes)
dnf update -y

# Install essential tools
dnf install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  iotop \
  net-tools \
  bind-utils \
  jq \
  tar \
  unzip \
  bash-completion

# Verify installations
which curl git jq
# Should show paths for all three
```

### Step 2.3: Install Docker

```bash
# Add Docker repository
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker
dnf install -y docker-ce docker-ce-cli containerd.io

# Enable & start Docker
systemctl enable docker
systemctl start docker

# Verify Docker
docker --version
# Should show: Docker version 24.x.x or newer

# Test Docker
docker run --rm hello-world
# Should show: "Hello from Docker!"
```

### Step 2.4: Configure OS Firewall (firewalld)

```bash
# Check firewalld status
systemctl status firewalld
# Should show: active (running)

# Add Kubernetes ports
firewall-cmd --permanent --add-port=6443/tcp       # K3s API
firewall-cmd --permanent --add-port=10250/tcp      # Kubelet
firewall-cmd --permanent --add-port=8472/udp       # Flannel VXLAN

# Add application ports
firewall-cmd --permanent --add-port=2025/tcp       # Sock Shop UI
firewall-cmd --permanent --add-port=3025/tcp       # Grafana
firewall-cmd --permanent --add-port=4025/tcp       # Prometheus
firewall-cmd --permanent --add-port=5025/tcp       # RabbitMQ Metrics
firewall-cmd --permanent --add-port=15672/tcp      # RabbitMQ Management

# Add NodePort range
firewall-cmd --permanent --add-port=30000-32767/tcp

# Reload firewall
firewall-cmd --reload

# Verify all ports
firewall-cmd --list-ports
# Should show all ports we just added
```

### Step 2.5: Install K3s (Lightweight Kubernetes)

```bash
# Install K3s as single-node cluster
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb

# Wait for K3s to start (30-60 seconds)
# Check status
systemctl status k3s
# Should show: active (running)

# Verify kubectl works
kubectl get nodes
# Should show:
# NAME            STATUS   ROLES                  AGE   VERSION
# sockshop-prod   Ready    control-plane,master   30s   v1.28.x+k3s1

# Check system pods
kubectl get pods --all-namespaces
# Should show pods in kube-system namespace
```

**Why K3s?**
- Lightweight (40 MB binary vs KIND's Docker-in-Docker)
- Production-ready (used by many cloud deployments)
- Perfect for single-node VM scenarios
- ARM64 native support
- All features needed for sock-shop

### Step 2.6: Install kubectl & Helm

```bash
# kubectl is already installed by K3s, verify:
kubectl version --client
# Should show client version

# Install Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm
helm version
# Should show: version.BuildInfo{Version:"v3.13.x" or newer}

# Add Helm repositories we'll need
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Verify repos
helm repo list
# Should show prometheus-community and datadog
```

### Step 2.7: Create Data Volume for Databases

**Why:** Databases need persistent storage that survives pod restarts.

1. **Create Block Volume (from OCI Console):**

   Open browser, go to OCI Console:
   ```
   ☰ Menu → Storage → Block Storage → Block Volumes
   → Click "Create Block Volume"
   
   Name: sockshop-data
   Compartment: (root)
   Availability Domain: (same as VM - usually AD-1)
   Size (GB): 100
   Volume Performance:
   ├── VPUs per GB: 10 (Balanced, default)
   └── Backup Policy: Bronze (free)
   
   Click: "Create Block Volume"
   
   Wait for: State = Available (green)
   ```

2. **Attach Volume to Instance:**
   ```
   On Block Volume details page:
   → Click "Attached Instances" (left menu)
   → Click "Attach to Instance"
   
   Attachment Type: Paravirtualized
   Access Type: Read/Write
   Select Instance: sockshop-prod
   Device Path: /dev/oracleoci/oraclevdb
   
   Click: "Attach"
   
   Wait for: State = Attached (green)
   ```

3. **Mount Volume (back in SSH terminal):**

   ```bash
   # Check if volume attached
   lsblk
   # Should show sdb (or similar) with 100G size
   
   # Format volume (ONLY FIRST TIME!)
   mkfs.ext4 /dev/sdb
   # Type 'y' if asked about proceeding
   
   # Create mount point
   mkdir -p /data
   
   # Mount volume
   mount /dev/sdb /data
   
   # Verify mount
   df -h /data
   # Should show 100G filesystem mounted at /data
   
   # Add to /etc/fstab for auto-mount on reboot
   echo '/dev/sdb /data ext4 defaults 0 0' >> /etc/fstab
   
   # Create database directories
   mkdir -p /data/databases/{mongodb,mariadb,redis}
   chmod -R 777 /data/databases
   
   # Verify
   ls -la /data/databases/
   # Should show mongodb, mariadb, redis directories
   ```

### Step 2.8: Setup kubectl from Local Machine (Optional)

This allows you to run `kubectl` commands from your Windows machine instead of SSH.

```powershell
# On your Windows machine (PowerShell)

# 1. Copy kubeconfig from VM
scp -i ~\Downloads\sockshop-ssh-key.key opc@<PUBLIC_IP>:/etc/rancher/k3s/k3s.yaml ~\.kube\config-oracle

# 2. Edit the downloaded file
# Open: C:\Users\<YourName>\.kube\config-oracle
# Change line:
#   server: https://127.0.0.1:6443
# To:
#   server: https://<PUBLIC_IP>:6443

# 3. Set KUBECONFIG environment variable
$env:KUBECONFIG = "$HOME\.kube\config-oracle"

# 4. Test
kubectl get nodes
# Should show your oracle VM node
```

✅ **Phase 2 Complete!** You now have:
- Fully updated Oracle Linux 8 VM
- Docker installed
- K3s (Kubernetes) running
- kubectl & Helm installed
- 100 GB data volume attached & mounted
- All firewalls configured
- Ready for sock-shop deployment!

---

## Phase 3: Deploy Sock Shop (45 minutes)

### Step 3.1: Clone Sock Shop Manifests

```bash
# Still logged in as root on VM

# Navigate to home directory
cd /root

# Clone your sock-shop repository
# Option 1: If repository is public
git clone https://github.com/Pvz25/Sock-Shop-New.git sock-shop-demo

# Option 2: If repository is private (need token)
# Create GitHub Personal Access Token first, then:
git clone https://<TOKEN>@github.com/Pvz25/Sock-Shop-New.git sock-shop-demo

# Navigate to repository
cd sock-shop-demo

# Verify files
ls -la
# Should show all your INCIDENT-*.md files, manifests/, etc.
```

### Step 3.2: Verify ARM64 Image Compatibility

Your images from quay.io/powercloud already support ARM64 (multi-arch). Verify:

```bash
# Check if Docker can inspect manifest
docker manifest inspect quay.io/powercloud/sock-shop-front-end:latest | grep -A5 "architecture"

# Should show entries for:
# "architecture": "amd64"
# "architecture": "arm64"  ← This one!
```

**If images are ARM64-compatible:** ✅ Proceed
**If not:** You'll need to rebuild images for ARM64 (complex, ask if needed)

### Step 3.3: Deploy Sock Shop Application

```bash
# Create sock-shop namespace
kubectl create namespace sock-shop

# Verify namespace
kubectl get ns sock-shop

# Deploy using Kustomize (adjust overlay if needed)
kubectl apply -k manifests/overlays/local-kind/

# Watch deployment
kubectl get pods -n sock-shop -w
# Press Ctrl+C to stop watching
```

**Expected output:**
```
NAME                            READY   STATUS              RESTARTS   AGE
carts-xxxxx                     0/1     ContainerCreating   0          10s
carts-db-xxxxx                  0/1     ContainerCreating   0          10s
catalogue-xxxxx                 0/1     ContainerCreating   0          10s
catalogue-db-xxxxx              0/1     ContainerCreating   0          10s
...

After 2-5 minutes, all should show:
NAME                            READY   STATUS    RESTARTS   AGE
carts-xxxxx                     1/1     Running   0          3m
carts-db-xxxxx                  1/1     Running   0          3m
...
(14 pods total)
```

**Troubleshooting if pods stuck:**
```bash
# Check specific pod
kubectl describe pod <POD_NAME> -n sock-shop

# Check logs
kubectl logs <POD_NAME> -n sock-shop

# Common issues:
# - Image pull errors: Check ARM64 compatibility
# - CrashLoopBackOff: Check logs for errors
# - Pending: Check storage/resources
```

### Step 3.4: Expose Services via NodePort

```bash
# Front-end service (main UI)
kubectl patch svc front-end -n sock-shop -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30025,"targetPort":8079}]}}'

# Verify
kubectl get svc front-end -n sock-shop
# Should show NodePort type with 30025
```

### Step 3.5: Test Sock Shop Access

```bash
# From your Windows browser:
http://<PUBLIC_IP>:30025

# You should see Sock Shop homepage!
```

**If not accessible:**
1. Check pod status: `kubectl get pods -n sock-shop`
2. Check service: `kubectl get svc front-end -n sock-shop`
3. Check firewall: `firewall-cmd --list-ports` (should include 30000-32767)
4. Check OCI Security List: Verify ingress rule for NodePort range

✅ **Phase 3 Complete!** Sock Shop is running on Oracle Cloud!

---

## Phase 4: Deploy Monitoring (45 minutes)

### Step 4.1: Install Prometheus + Grafana (Helm)

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack
helm upgrade --install kps \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f /root/sock-shop-demo/values-kps-kind-clean.yml \
  --set grafana.adminPassword='prom-operator' \
  --wait

# Wait for deployment (3-5 minutes)
kubectl get pods -n monitoring -w
# All pods should reach Running state
```

### Step 4.2: Expose Grafana & Prometheus via NodePort

```bash
# Grafana
kubectl patch svc kps-grafana -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30030,"targetPort":3000}]}}'

# Prometheus
kubectl patch svc kps-kube-prometheus-stack-prometheus -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":9090,"nodePort":30040,"targetPort":9090}]}}'

# Verify
kubectl get svc -n monitoring | grep -E "grafana|prometheus"
```

### Step 4.3: Access Grafana

```bash
# From browser:
http://<PUBLIC_IP>:30030

Username: admin
Password: prom-operator
```

### Step 4.4: Deploy Datadog Agent (ARM64)

```bash
# Create datadog namespace
kubectl create namespace datadog

# Create Datadog API key secret
# Replace YOUR_DD_API_KEY with your actual key
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_DD_API_KEY \
  -n datadog

# Deploy Datadog Agent (using your existing values file)
helm upgrade --install datadog-agent \
  datadog/datadog \
  -n datadog \
  -f /root/sock-shop-demo/datadog-values-metrics-logs.yaml \
  --wait

# Verify
kubectl get pods -n datadog
# Should show 1 pod (single node cluster)
```

### Step 4.5: Verify Datadog Integration

```bash
# Check agent status
kubectl exec -it -n datadog $(kubectl get pod -n datadog -l app.kubernetes.io/name=datadog-agent -o name) -c agent -- agent status

# Look for:
# - "API Key status: API key valid"
# - "Logs Agent: Running"
# - "Kubernetes metrics: OK"
```

✅ **Phase 4 Complete!** Monitoring stack is running!

---

## Phase 5-6: See ORACLE-CLOUD-FINAL-STEPS.md

Due to length, remaining phases covered in separate file.

**What's Next:**
- Incident script migration
- Load testing
- Healr AI SRE integration
- Production checklist

---

**Questions? Issues?** Document them and I'll help troubleshoot!
