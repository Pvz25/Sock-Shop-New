# Orders Service - Quick Reference Card

**Last Updated:** October 28, 2025  
**Status:** Production Deployed  
**Version:** v1.0-status-fix

---

## ⚡ **CRITICAL FACTS**

```
Database Name:     data          ← NOT "orders"!
Collection Name:   customerOrder
MongoDB Version:   4.4.16        ← Use 'mongo' not 'mongosh'
Container Port:    80
Service Port:      80 → 80       ← targetPort MUST be 80
Deployment:        KIND cluster  ← No registry credentials needed
```

---

## 🚀 **BUILD & DEPLOY (KIND)**

```powershell
# 1. Build JAR
cd D:\sock-shop-orders
mvn clean package -DskipTests

# 2. Build Docker Image
docker build -f docker/orders/Dockerfile -t quay.io/powercloud/sock-shop-orders:v1.0-status-fix .

# 3. Load into KIND (NO PUSH TO REGISTRY!)
kind load docker-image quay.io/powercloud/sock-shop-orders:v1.0-status-fix --name sockshop

# 4. Deploy to Kubernetes
kubectl -n sock-shop set image deployment/orders orders=quay.io/powercloud/sock-shop-orders:v1.0-status-fix

# 5. Verify
kubectl -n sock-shop rollout status deployment/orders
kubectl -n sock-shop get pods -l name=orders
```

---

## 🔍 **VERIFICATION COMMANDS**

### Pod Status
```powershell
kubectl -n sock-shop get pods -l name=orders
kubectl -n sock-shop logs -l name=orders --tail=50
```

### Health Check
```powershell
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/health
```

### Service Configuration
```powershell
kubectl -n sock-shop get svc orders -o yaml | grep targetPort
# Should show: targetPort: 80
```

---

## 🗄️ **MONGODB QUERIES**

### Connect to MongoDB
```powershell
# Get pod name
kubectl -n sock-shop get pods -l name=orders-db

# List databases (find the correct one!)
kubectl exec -n sock-shop <orders-db-pod> -- mongo --eval "db.adminCommand('listDatabases')"
```

### Query Orders
```powershell
# CRITICAL: Database is 'data' NOT 'orders'!

# Show all orders
kubectl exec -n sock-shop <orders-db-pod> -- mongo data --eval "db.customerOrder.find().pretty()"

# Count total orders
kubectl exec -n sock-shop <orders-db-pod> -- mongo data --quiet --eval "db.customerOrder.count()"

# Count orders WITH status field
kubectl exec -n sock-shop <orders-db-pod> -- mongo data --quiet --eval "db.customerOrder.find({status: {\$exists: true}}).count()"

# Show orders with status
kubectl exec -n sock-shop <orders-db-pod> -- mongo data --quiet --eval "db.customerOrder.find({status: {\$exists: true}}, {_id:1, status:1, total:1, date:1}).pretty()"

# Find by customer ID
kubectl exec -n sock-shop <orders-db-pod> -- mongo data --quiet --eval "db.customerOrder.find({customerId: '69004a839c10d3000194fa98'}).pretty()"
```

---

## 🔧 **TROUBLESHOOTING**

### Fix Service Port Mismatch
```powershell
kubectl -n sock-shop patch svc orders --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":80}]'
```

### Restart Front-End (Clear Cache)
```powershell
kubectl -n sock-shop rollout restart deployment/front-end
kubectl -n sock-shop rollout status deployment/front-end
```

### Check Pod Events
```powershell
kubectl -n sock-shop get events --field-selector involvedObject.name=<pod-name> --sort-by='.lastTimestamp'
```

### View Full Logs
```powershell
kubectl -n sock-shop logs <pod-name> --all-containers --tail=200
```

---

## 📡 **API ENDPOINTS**

```
Health Check:      GET  http://orders:80/health
Create Order:      POST http://orders:80/orders
Get All Orders:    GET  http://orders:80/orders
Search by Customer: GET  http://orders:80/orders/search/customerId?custId=<id>
```

### Test from Front-End Pod
```powershell
# Health
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/health

# All orders
kubectl -n sock-shop exec -it deployment/front-end -- curl -s http://orders:80/orders

# By customer
kubectl -n sock-shop exec -it deployment/front-end -- curl -s "http://orders:80/orders/search/customerId?custId=69004a839c10d3000194fa98"
```

---

## 📊 **ORDER STATUS LIFECYCLE**

```
CREATED          ← Initial state when order object created
   ↓
PENDING          ← Payment being processed
   ├─ Success → PAID          ← Payment authorized
   │              ↓
   │           SHIPPED        ← Items dispatched
   │              ↓
   │           DELIVERED      ← Order complete
   │
   └─ Failure → PAYMENT_FAILED ← Payment declined/error
```

**Enum Location:** `works.weave.socks.orders.entities.OrderStatus`

---

## 🔑 **KEY FILES MODIFIED**

```
D:\sock-shop-orders\
├── src/main/java/works/weave/socks/orders/entities/
│   ├── OrderStatus.java              ← NEW: Status enum
│   └── CustomerOrder.java            ← MODIFIED: Added status field
├── src/main/java/works/weave/socks/orders/controllers/
│   └── OrdersController.java         ← MODIFIED: Status transitions
└── docker/orders/
    └── Dockerfile                     ← MODIFIED: Port 80, JVM tuning
```

---

## 🎯 **EXPECTED LOG OUTPUT**

When creating an order, you should see:

```
INFO ... Starting calls addressFuture
INFO ... Starting calls customerFuture
INFO ... Starting calls cardFuture
INFO ... Starting calls itemsFuture
INFO ... End of calls.
INFO ... Order created with ID: 69007aa4c1f4320001b506ff and status: Created
INFO ... Order 69007aa4c1f4320001b506ff status updated to PENDING
INFO ... Sending payment request for order 69007aa4c1f4320001b506ff: PaymentRequest{...}
INFO ... Received payment response for order 69007aa4c1f4320001b506ff: PaymentResponse{authorised=true, ...}
INFO ... Order 69007aa4c1f4320001b506ff payment successful, status updated to PAID
INFO ... Order 69007aa4c1f4320001b506ff shipped successfully
```

---

## 🔬 **DEBUGGING TIPS**

### Check if Image Loaded in KIND
```powershell
docker exec -it sockshop-control-plane crictl images | grep sock-shop-orders
```

### Describe Deployment
```powershell
kubectl -n sock-shop describe deployment orders
```

### Check Environment Variables
```powershell
kubectl -n sock-shop exec -it <pod-name> -- env | grep -i java
```

### Test Database Connection
```powershell
kubectl -n sock-shop exec -it deployment/orders -- curl -s orders-db:27017
```

---

## 📋 **COMMON ERRORS & FIXES**

| Error | Cause | Fix |
|-------|-------|-----|
| `CrashLoopBackOff` | OOM or wrong entrypoint | Check JVM settings in Dockerfile |
| `Connection refused` | Port mismatch | Patch service targetPort to 80 |
| `mongosh: not found` | Wrong mongo client | Use `mongo` not `mongosh` |
| `orders: database not found` | Wrong database name | Use `data` not `orders` |
| UI shows empty orders | Front-end cache | Restart front-end, hard refresh browser |

---

## 🎓 **EXAMPLE QUERIES**

### Create Test Order (curl)
```bash
curl -X POST http://localhost:80/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer": "http://user/customers/69004a839c10d3000194fa98",
    "address": "http://user/addresses/69004a839c10d3000194fa98",
    "card": "http://user/cards/69004a839c10d3000194fa98",
    "items": "http://carts/carts/69004a839c10d3000194fa98/items"
  }'
```

### MongoDB Aggregation
```javascript
// Count orders by status
db.customerOrder.aggregate([
  { $match: { status: { $exists: true } } },
  { $group: { _id: "$status", count: { $sum: 1 } } }
])

// Average order total by status
db.customerOrder.aggregate([
  { $match: { status: { $exists: true } } },
  { $group: { _id: "$status", avgTotal: { $avg: "$total" } } }
])
```

---

## 📚 **DOCUMENTATION**

- **Full Implementation:** [ORDERS-STATUS-IMPLEMENTATION-COMPLETE.md](./ORDERS-STATUS-IMPLEMENTATION-COMPLETE.md)
- **Original Plan:** [ORDERS-STATUS-ANALYSIS-PLAN.md](./ORDERS-STATUS-ANALYSIS-PLAN.md)
- **Service README:** [sock-shop-orders/README.md](../sock-shop-orders/README.md)

---

## ⚠️ **REMEMBER**

1. ✅ **Database is `data` NOT `orders`**
2. ✅ **Use `mongo` client, NOT `mongosh`**
3. ✅ **KIND loads images directly - NO registry push needed**
4. ✅ **Service targetPort MUST be 80**
5. ✅ **Hard refresh browser after front-end restart**

---

**Need Help?** Check the full implementation guide or review pod logs for detailed error messages.
