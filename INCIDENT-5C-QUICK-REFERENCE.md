# INCIDENT-5C: Quick Reference Card

---

## 🎯 What It Is
**Queue blockage in RabbitMQ middleware** - Messages stuck due to capacity limit

---

## 🚀 Execute
```powershell
.\incident-5c-execute-fixed.ps1
```

---

## ⏱️ Timeline
- **Duration:** 3 minutes
- **Action:** Place 7 orders during window

---

## 📊 Expected
- **Orders 1-3:** ✅ Success (queued at 3/3)
- **Orders 4-7:** ❌ Error (queue rejects)

---

## 🔍 Verify

**Queue depth:**
```powershell
kubectl exec rabbitmq -c rabbitmq -- curl -s -u guest:guest \
  http://localhost:15672/api/queues/%2F/shipping-task
```
Expected: `"messages": 3, "consumers": 0`

**Shipping logs:**
```powershell
kubectl logs deployment/shipping --tail=20
```
Expected: ACKs (3) + NACKs (4+)

---

## 📈 Datadog

**Time:** Nov 11, 2025, 08:23-08:27 UTC

```
rabbitmq.queue.messages{queue:shipping-task}
kube_namespace:sock-shop service:shipping "rejected"
kube_namespace:sock-shop service:orders 503
```

---

## ✅ Success Criteria
- [ ] Queue at 3/3
- [ ] Consumer at 0
- [ ] First 3 orders succeed
- [ ] Orders 4+ fail
- [ ] Errors visible
- [ ] Auto-recovery works

---

## 💡 Key Point
**ONLY incident with queue itself blocked** (not just processing)

---

## 📞 Troubleshooting

**No errors?** Check shipping image has publisher-confirms  
**Policy not set?** Verify Management API accessible  
**All succeed?** Check consumer scaled to 0

---

## 📚 Full Docs
`INCIDENT-5C-COMPLETE-GUIDE.md`
