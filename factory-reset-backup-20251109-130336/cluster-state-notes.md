# KIND Cluster State Snapshot
Generated: 2025-11-09 13:03:40

## Cluster Information
Cluster Name: sockshop
Kubernetes Version: v1.32.0 (from previous diagnostics)

## Nodes
- sockshop-control-plane (control-plane)
- sockshop-worker (worker)

## Sock Shop Namespace Pods (Expected)
1. carts-*
2. carts-db-*
3. catalogue-*
4. catalogue-db-*
5. front-end-*
6. orders-*
7. orders-db-*
8. payment-*
9. queue-master-*
10. rabbitmq-*
11. session-db-*
12. shipping-*
13. stripe-mock-* (if INCIDENT-6 active)
14. user-*
15. user-db-*
16. toxiproxy-payment-* (if deployed)

## Port Forwards Needed
- Front-end UI: kubectl -n sock-shop port-forward svc/front-end 2025:80
- Access: http://localhost:2025

## Manifest Locations
All manifests are in: d:\sock-shop-demo\manifests\
(These are NOT affected by Docker reset)

## Incident Scripts
All incident scripts are in: d:\sock-shop-demo\
Files like: incident-*-activate.ps1, incident-*-recover.ps1
(These are NOT affected by Docker reset)
