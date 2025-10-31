# Check what kubernetes_state metrics are available in Datadog
# This script lists the actual metric names Datadog is collecting

Write-Host "=== Checking Datadog Agent kubernetes_state_core Status ===" -ForegroundColor Cyan

# Get cluster agent status for kubernetes_state_core check
Write-Host "`nKubernetes State Core Check Configuration:" -ForegroundColor Yellow
kubectl -n datadog exec deployment/datadog-agent-cluster-agent -- agent status | Select-String -Pattern "kubernetes_state" -Context 10

Write-Host "`n=== Expected Metric Names ===" -ForegroundColor Cyan
Write-Host "For Deployment replicas (use these in Datadog):" -ForegroundColor Green
Write-Host "  - kubernetes_state.deployment.replicas_available"
Write-Host "  - kubernetes_state.deployment.replicas_desired"
Write-Host "  - kubernetes_state.deployment.replicas_ready"
Write-Host "  - kubernetes_state.deployment.replicas_updated"

Write-Host "`nFor Pod counts:" -ForegroundColor Green
Write-Host "  - kubernetes_state.pod.ready"
Write-Host "  - kubernetes_state.pod.status_phase"

Write-Host "`nFor ReplicaSet:" -ForegroundColor Green
Write-Host "  - kubernetes_state.replicaset.replicas"
Write-Host "  - kubernetes_state.replicaset.replicas_ready"

Write-Host "`n=== Correct Query for Metrics Explorer ===" -ForegroundColor Cyan
Write-Host "avg:kubernetes_state.deployment.replicas_available{kube_namespace:sock-shop,kube_deployment:payment}" -ForegroundColor Yellow

Write-Host "`nThis should show the drop from 1 to 0 during your incident!" -ForegroundColor Green
