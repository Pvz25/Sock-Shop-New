# ✅ Sock Shop Demo Checklist

**Print this page and check off items as you complete them**

---

## 📅 Before Demo Day

- [ ] Review complete demo guide (`SOCK-SHOP-COMPLETE-DEMO-GUIDE.md`)
- [ ] Print quick reference card (`DEMO-QUICK-REFERENCE-CARD.md`)
- [ ] Test run the full demo once
- [ ] Prepare backup demo environment (if possible)
- [ ] Charge laptop (ensure 100% battery)
- [ ] Test screen sharing/projection
- [ ] Close unnecessary applications

---

## ⏰ 15 Minutes Before Demo

### Environment Check
- [ ] Cluster running: `kubectl cluster-info`
- [ ] All pods Running in sock-shop namespace (14 pods)
- [ ] All pods Running in monitoring namespace (5 pods)
- [ ] All pods Running in datadog namespace (3 pods)

### Port Forwards
- [ ] Kill existing port forwards
- [ ] Start front-end forward (2025)
- [ ] Start Grafana forward (3025)
- [ ] Start Prometheus forward (4025)
- [ ] Start RabbitMQ forward (5025)
- [ ] Test all 4 URLs accessible

### Browser Setup
- [ ] Pre-open Sock Shop: http://localhost:2025
- [ ] Pre-open Grafana: http://localhost:3025
- [ ] Pre-open Prometheus: http://localhost:4025
- [ ] Pre-open Datadog Infrastructure
- [ ] Pre-open Datadog Logs
- [ ] Close other browser tabs

### Datadog Verification
- [ ] Check LogsProcessed > 5000
- [ ] Check API Key valid
- [ ] Test log search: `kube_namespace:sock-shop`

---

## 🎬 During Demo - Part 1: Introduction (5 min)

- [ ] Opening statement delivered
- [ ] Architecture diagram shown
- [ ] Technology stack explained
- [ ] Show `kubectl get pods -n sock-shop`
- [ ] Mention multi-architecture support

---

## 🎬 During Demo - Part 2: Application (10 min)

- [ ] Open Sock Shop UI (http://localhost:2025)
- [ ] Browse catalogue (click 2-3 socks)
- [ ] Register user (demo-user) OR Login (user/password)
- [ ] Add 3 items to cart (Weave, Holy, Crossed)
- [ ] View cart
- [ ] Fill checkout address
- [ ] Place order
- [ ] **COPY ORDER ID!** Write here: ___________________________
- [ ] Explain microservices interaction

---

## 🎬 During Demo - Part 3: Prometheus/Grafana (10 min)

### Prometheus
- [ ] Open Prometheus (http://localhost:4025)
- [ ] Show Status → Targets
- [ ] Query 1: Container CPU usage
- [ ] Query 2: Memory usage
- [ ] Query 3: RabbitMQ queue depth

### Grafana
- [ ] Open Grafana (http://localhost:3025)
- [ ] Login (admin/prom-operator)
- [ ] Navigate to Kubernetes dashboard
- [ ] Select sock-shop namespace
- [ ] Show CPU/Memory/Network graphs
- [ ] Explain alerting potential

---

## 🎬 During Demo - Part 4: Datadog (10 min)

- [ ] Open Infrastructure view
- [ ] Show 2 hosts (control-plane, worker)
- [ ] Click on sockshop-worker host
- [ ] Open Containers view
- [ ] Filter: `kube_namespace:sock-shop`
- [ ] Show all 8 microservices
- [ ] Open Kubernetes Explorer
- [ ] Show cluster hierarchy
- [ ] Open Logs Explorer
- [ ] Search: `kube_namespace:sock-shop`
- [ ] Search: `service:orders`
- [ ] **Search for your order ID**
- [ ] Show complete audit trail
- [ ] Click service facet (show all 8 services)
- [ ] Open Metrics Explorer
- [ ] Search: `kubernetes.cpu.usage`
- [ ] Filter: `kube_cluster_name:sockshop-kind`

---

## 🎬 During Demo - Part 5: Troubleshooting (5-10 min)

- [ ] Introduce troubleshooting scenario
- [ ] Show `kubectl get pods -n sock-shop`
- [ ] Show `kubectl logs deployment/front-end`
- [ ] Cross-reference with Datadog logs
- [ ] Show `kubectl top pods -n sock-shop`
- [ ] Explain 4-level troubleshooting workflow
- [ ] Summarize DevOps benefits

---

## 🎬 Closing (2 min)

- [ ] Deliver closing statement
- [ ] Summarize key points:
  - [ ] Application architecture (8 services)
  - [ ] Monitoring (Prometheus/Grafana)
  - [ ] Observability (Datadog 5,500+ logs)
  - [ ] DevOps benefits (fast troubleshooting)
- [ ] Open for Q&A

---

## ❓ Q&A Preparation

- [ ] Have answers ready for:
  - [ ] Cost questions
  - [ ] Scaling questions
  - [ ] Security questions
  - [ ] Deployment questions
  - [ ] Prometheus vs Datadog
  - [ ] Setup time
  - [ ] APM capabilities

---

## 🔧 Emergency Procedures

### If Port Forwards Fail
- [ ] Run kill command for ports
- [ ] Restart all 4 port forwards
- [ ] Wait 5 seconds
- [ ] Test all URLs

### If Pods Not Running
- [ ] Check pod status
- [ ] Check pod logs
- [ ] Describe pod for events
- [ ] Restart deployment if needed

### If Datadog Not Working
- [ ] Check agent pod status
- [ ] Check agent logs
- [ ] Verify API key
- [ ] Check LogsProcessed

---

## 📊 Success Metrics

By end of demo, audience should understand:
- [ ] Microservices architecture principles
- [ ] Kubernetes observability patterns
- [ ] Metrics vs Logs vs Traces
- [ ] Production troubleshooting workflow
- [ ] DevOps/SRE best practices

---

## 📝 Post-Demo

- [ ] Answer all questions
- [ ] Share demo repository link
- [ ] Share documentation files
- [ ] Collect feedback
- [ ] Note improvements for next time

---

## 🎯 Demo Went Well If:

✅ All services accessible throughout demo  
✅ Successfully placed order and tracked it  
✅ Showed logs, metrics, and infrastructure  
✅ Demonstrated troubleshooting workflow  
✅ Audience asked engaged questions  
✅ Completed within 45 minutes  

---

**Keep this checklist visible during your demo!**

**Good luck! 🎉**
