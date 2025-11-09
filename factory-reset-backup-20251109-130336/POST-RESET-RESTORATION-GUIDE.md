# Post-Factory Reset Restoration Checklist

## ✅ Step-by-Step Recovery

### 1. Verify Docker Desktop (5 minutes)
After factory reset completes:
- [ ] Docker Desktop shows "Running" in system tray
- [ ] Run: docker version
- [ ] Run: docker ps (should show no containers - that's normal)

### 2. Verify WSL2 Integration (2 minutes)
- [ ] Docker Desktop → Settings → Resources → WSL Integration
- [ ] Ensure "docker-desktop" is enabled
- [ ] Apply & Restart if needed

### 3. Recreate KIND Cluster (3 minutes)
`powershell
cd d:\sock-shop-demo

# If you have a custom KIND config:
kind create cluster --name sockshop --config kind-config.yaml

# If using default (no custom config):
kind create cluster --name sockshop
`

Wait for: "✓ Ensuring node image" → "✓ Preparing nodes" → "✓ Cluster created"

### 4. Verify Cluster (1 minute)
`powershell
kubectl cluster-info
kubectl get nodes
# Should show 2 nodes Ready (or 1 if default config)
`

### 5. Deploy Sock Shop Application (5 minutes)
`powershell
# Apply all manifests
kubectl apply -f d:\sock-shop-demo\manifests\

# OR if you have a specific deployment script:
.\deploy-sock-shop.ps1
`

### 6. Wait for Pods to Start (3-5 minutes)
`powershell
kubectl get pods -n sock-shop --watch
# Press Ctrl+C when all pods show Running
`

Expected pods: 15 total (14 app + 1 stripe-mock if deployed)

### 7. Test Port Forwarding (1 minute)
`powershell
kubectl -n sock-shop port-forward svc/front-end 2025:80
`

Keep terminal open, then browse to: http://localhost:2025

### 8. Verify UI Loads (1 minute)
- [ ] Homepage loads
- [ ] Product catalogue visible
- [ ] Can click on products

### 9. Test Basic User Journey (Optional - 2 minutes)
- [ ] Register new user
- [ ] Add item to cart
- [ ] Place order

### 10. Re-apply Datadog Agent (if used)
`powershell
kubectl apply -f d:\sock-shop-demo\datadog-agent.yaml
`

## 📊 Estimated Total Time: 20-25 minutes

## 🆘 If Issues Occur

### Issue: "kind create cluster" fails
Solution:
`powershell
# Delete any remnants
kind delete cluster --name sockshop

# Restart Docker Desktop
# Wait 2 minutes

# Try again
kind create cluster --name sockshop
`

### Issue: Pods stuck in "Pending" or "ImagePullBackOff"
Solution:
`powershell
# Check pod details
kubectl describe pod <pod-name> -n sock-shop

# Common causes:
# 1. Images still downloading (wait 5 more minutes)
# 2. Resource limits (check Docker Desktop settings → Resources)
# 3. Node not ready (kubectl get nodes)
`

### Issue: Port forward still fails
Solution:
`powershell
# Check if proxy is running now
Get-Process com.docker.proxy

# If not, run diagnostic again
.\diagnose-docker-issue.ps1
`

## 📝 Important Notes

1. **Your repository data is SAFE**: All files in d:\sock-shop-demo are untouched
2. **Manifests preserved**: All YAML files still exist
3. **Incident scripts preserved**: All PowerShell scripts intact
4. **Documentation preserved**: All .md files intact
5. **Only Docker layer reset**: Containers, images, volumes deleted

## 🎯 Success Criteria

✅ kubectl cluster-info works
✅ kubectl get nodes shows Ready
✅ kubectl get pods -n sock-shop shows all Running
✅ Port forward works: kubectl -n sock-shop port-forward svc/front-end 2025:80
✅ UI accessible at: http://localhost:2025
✅ Can browse products and add to cart

Once all checked, you're fully restored! 🎉
