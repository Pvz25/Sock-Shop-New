# INCIDENT-8: The Real Solution for Database Slowness

## ❌ Why Resource Constraints Don't Work

### What We Tried:
1. **50m CPU** → Database crashed (OOMKilled)
2. **200m CPU + 256Mi memory** → Database crashed (OOMKilled)  
3. **Any constraint** → Either crashes or no noticeable slowness

### Why This Fails:
- MariaDB needs ~300-400Mi memory minimum to function
- CPU constraints either crash it or have no visible effect
- **You cannot simulate slowness by starving resources**

---

## ✅ THE CORRECT APPROACH: Load-Based Slowness

**Client Requirement:** "Product search slowness due to database latency or connection pool exhaustion"

**Correct Simulation Method:** Generate **HEAVY LOAD** to saturate the database

### How It Works:

```
Normal State:
- 1 user browsing → Database handles easily → Fast (<100ms)

Heavy Load State:
- 50+ concurrent users → Database saturated → Slow (2-5 seconds)
- Connection pool exhausted
- Query queue builds up
- Real slowness, not crash
```

---

## 🚀 Implementation: Use Locust Load Testing

### Step 1: Create Load Test Script

```python
# load/incident8_heavy_load.py
from locust import HttpUser, task, between
import random

class HeavyDatabaseUser(HttpUser):
    wait_time = between(0.1, 0.3)  # Very aggressive
    
    @task(10)
    def browse_catalogue_heavy(self):
        """Hit catalogue repeatedly - saturates database"""
        self.client.get("/catalogue")
    
    @task(5)
    def view_product_details(self):
        """View product details - more DB queries"""
        product_ids = [
            "03fef6ac-1896-4ce8-bd69-b798f85c6e0b",
            "510a0d7e-8e83-4193-b483-e27e09ddc34d",
            "808a2de1-1aaa-4c25-a9b9-6612e8f29a38"
        ]
        product_id = random.choice(product_ids)
        self.client.get(f"/catalogue/{product_id}")
    
    @task(3)
    def search_products(self):
        """Search - triggers complex DB queries"""
        tags = ["blue", "green", "formal", "action"]
        tag = random.choice(tags)
        self.client.get(f"/catalogue?tags={tag}")
```

### Step 2: Run Heavy Load

```powershell
# Generate 50 concurrent users hitting database
locust -f load/incident8_heavy_load.py `
  --host http://localhost:2025 `
  --users 50 `
  --spawn-rate 10 `
  --run-time 5m `
  --headless
```

### Step 3: Experience Slowness in UI

**While Locust is running:**
- Open http://localhost:2025
- Browse products - **NOW you'll see 2-5 second delays**
- Database is saturated with 50 concurrent users
- Connection pool exhausted
- **Real slowness, not crash**

---

## 📊 What This Demonstrates

### Real-World Scenario:
- Flash sale announced
- 50+ users hit site simultaneously
- Database can't keep up
- Every user experiences slowness
- **This is REAL database performance degradation**

### AI SRE Detection:
- High query latency (P95 > 2000ms)
- Connection pool near limit
- Slow response times
- No crashes, no errors - just slowness

---

## Alternative: Inject Artificial Latency

### If Locust Not Available:

**Use MySQL SLEEP() function to simulate slow queries:**

```sql
-- Connect to catalogue-db
kubectl exec -it -n sock-shop deployment/catalogue-db -- mysql -u root -padmin socksdb

-- Add artificial delay to queries (2 seconds)
DELIMITER $$
CREATE TRIGGER slow_query_trigger BEFORE SELECT ON sock
FOR EACH ROW
BEGIN
  DO SLEEP(2);
END$$
DELIMITER ;
```

**Problem:** This requires modifying the database, not ideal for demo.

---

## 🎯 RECOMMENDED SOLUTION FOR CLIENT DEMO

### Option 1: Use Locust (Best)

**Pros:**
- ✅ Real slowness from actual load
- ✅ No code/config changes
- ✅ Demonstrates real-world scenario
- ✅ Shows connection pool exhaustion

**Cons:**
- Requires Locust installed
- Need to run load test

### Option 2: Manual Heavy Browsing

**Pros:**
- ✅ No tools needed
- ✅ Simple to execute

**Cons:**
- Hard to generate enough load manually
- Inconsistent results

### Option 3: Use Different Incident

**INCIDENT-4: Pure Latency**
- Already exists in your repo
- Simulates CPU throttling on **application** (not database)
- Causes slowness without crashes
- **This might be better suited**

---

## 💡 Recommendation

**For "Product search slowness due to database latency":**

### Best Approach:
1. **Use INCIDENT-4** (CPU throttling on catalogue service)
   - Already working
   - Causes visible slowness
   - No database crashes

2. **OR Use Locust** to generate heavy database load
   - More realistic
   - Shows connection pool exhaustion
   - Requires load testing tool

### Don't Use:
- ❌ Database resource constraints (causes crashes, not slowness)
- ❌ Current INCIDENT-8 approach (doesn't work)

---

## 🔧 Quick Fix: Repurpose INCIDENT-4

**INCIDENT-4 already does what you need:**
- Throttles **catalogue service** CPU
- Causes slow product browsing
- Visible 2-5 second delays
- No crashes

**Just rename it:**
- INCIDENT-4 → "Service CPU Throttling"
- INCIDENT-8 → "Database Slowness via Load Testing"

---

## Final Verdict

**Database slowness cannot be reliably simulated with resource constraints.**

**Use one of these instead:**
1. ✅ INCIDENT-4 (catalogue service throttling)
2. ✅ Locust load testing (heavy database load)
3. ✅ Manual concurrent browsing (if no tools)

**Current INCIDENT-8 approach:** ❌ Doesn't work (causes crashes)

---

**Would you like me to:**
1. Set up Locust load testing for real database slowness?
2. Use INCIDENT-4 instead (already working)?
3. Try a different approach?
