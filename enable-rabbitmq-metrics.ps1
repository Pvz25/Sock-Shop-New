# Enable RabbitMQ Datadog Metrics for Incident-5
# This adds Datadog annotations to RabbitMQ deployment for metric collection

Write-Host "=== Enabling RabbitMQ Datadog Integration ===" -ForegroundColor Cyan

# Apply the patch
Write-Host "`nApplying Datadog annotations to RabbitMQ deployment..." -ForegroundColor Yellow
kubectl patch deployment rabbitmq -n sock-shop --patch-file rabbitmq-datadog-annotations-patch.yaml

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Annotations applied successfully!" -ForegroundColor Green
    
    Write-Host "`nWaiting for RabbitMQ pod to restart..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    Write-Host "`nChecking RabbitMQ pod status:" -ForegroundColor Yellow
    kubectl get pods -n sock-shop -l app=sock-shop,name=rabbitmq
    
    Write-Host "`n=== Metrics Available in 2-3 Minutes ===" -ForegroundColor Cyan
    Write-Host "After Datadog agent discovers the annotations, these metrics will appear:" -ForegroundColor Green
    Write-Host "  - rabbitmq.queue.consumers"
    Write-Host "  - rabbitmq.queue.messages"
    Write-Host "  - rabbitmq.queue.messages.publish.count"
    
    Write-Host "`n⚠️ Note: Metrics may take 2-3 minutes to appear in Datadog UI" -ForegroundColor Yellow
    
} else {
    Write-Host "❌ Failed to apply annotations" -ForegroundColor Red
    Write-Host "Check that rabbitmq-datadog-annotations-patch.yaml exists" -ForegroundColor Yellow
}
