# Configure Toxiproxy to proxy payment service traffic
# This creates a proxy that forwards to the actual payment service

$POD = kubectl -n sock-shop get pods -l name=toxiproxy-payment -o jsonpath='{.items[0].metadata.name}'

Write-Host "Configuring Toxiproxy pod: $POD" -ForegroundColor Cyan

# Create the payment proxy that forwards to actual payment service
Write-Host "`nCreating payment proxy (forwards to payment:80)..." -ForegroundColor Yellow

$proxyConfig = @"
{
  "name": "payment",
  "listen": "0.0.0.0:8080",
  "upstream": "payment.sock-shop.svc.cluster.local:80",
  "enabled": true
}
"@

kubectl -n sock-shop exec $POD -- sh -c "curl -X POST -H 'Content-Type: application/json' -d '$proxyConfig' http://localhost:8474/proxies"

Write-Host "`nVerifying proxy configuration..." -ForegroundColor Yellow
kubectl -n sock-shop exec $POD -- curl -s http://localhost:8474/proxies

Write-Host "`n✅ Toxiproxy configured successfully!" -ForegroundColor Green
Write-Host "Proxy: 0.0.0.0:8080 → payment.sock-shop.svc.cluster.local:80" -ForegroundColor Cyan
