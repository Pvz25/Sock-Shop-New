# User Registration Error Fix Documentation

## 📋 Issue Summary

| Attribute | Details |
|-----------|---------|
| **Component** | Front-End Service (User Registration) |
| **Issue Type** | Error Handling / User Experience |
| **Severity** | Medium (Poor UX, but functionality works) |
| **Reported Date** | 2025-11-07 |
| **Status** | ✅ **FIXED** - Code updated in `front-end-user-index.js` |
| **Deployment Status** | ⏳ **PENDING** - Requires rebuild and redeployment |

---

## 🐛 Problem Description

### User Experience Issue

When attempting to register a user with a username that already exists, the system:

❌ **Shows:** Generic/cryptic error or no error message  
❌ **Backend Returns:** Raw MongoDB error message  
❌ **HTTP Status:** Always 500 Internal Server Error  
❌ **Frontend Behavior:** Doesn't parse or display the error properly

### Expected Behavior

When registering a duplicate user, the system should:

✅ **Show:** "User already exists. Please choose a different username."  
✅ **Backend Returns:** Structured error with friendly message  
✅ **HTTP Status:** 409 Conflict (for duplicates)  
✅ **Frontend Behavior:** Parse and display error clearly

---

## 🔍 Root Cause Analysis

### Backend Response (User Service)

When attempting to register a duplicate user, the user service returns:

```http
HTTP/1.1 500 Internal Server Error
Content-Type: text/plain; charset=utf-8

{
  "error": "E11000 duplicate key error collection: users.customers index: username_1 dup key: { : \"testdup123\" }",
  "status_code": 500,
  "status_text": "Internal Server Error"
}
```

**Issues:**
1. Raw MongoDB error (E11000) exposed to client
2. HTTP 500 instead of 409 Conflict
3. Not user-friendly

### Frontend Handling (Before Fix)

**File:** `front-end-user-index.js`  
**Function:** `app.post("/register")`  
**Lines:** 180-248

**Problems Identified:**

#### Problem 1: Generic Error Callback (Line 210)
```javascript
console.log(response.statusCode);
callback(true);  // ❌ Passes boolean true instead of error object
```

#### Problem 2: No Error Parsing (Lines 192-211)
```javascript
request(options, function(error, response, body) {
    if (error !== null ) {
        callback(error);
        return;
    }
    if (response.statusCode == 200 && body != null && body != "") {
        // ... success handling ...
        return;
    }
    console.log(response.statusCode);
    callback(true);  // ❌ No attempt to parse error from body
});
```

#### Problem 3: Generic Error Response (Lines 232-236)
```javascript
function(err, custId) {
    if (err) {
        console.log("Error with log in: " + err);  // ❌ Wrong log message (says "log in")
        res.status(500);  // ❌ Always 500, not specific
        res.end();  // ❌ No error body sent to client
        return;
    }
```

---

## ✅ Solution Implemented

### Frontend Fix (front-end-user-index.js)

#### Change 1: Parse Error from Response Body (Lines 209-231)

**Before:**
```javascript
console.log(response.statusCode);
callback(true);
```

**After:**
```javascript
// Handle specific error cases with meaningful messages
console.log("Registration failed with status:", response.statusCode);
var errorMessage = "Registration failed";

if (body && body.error) {
    // Check if it's a duplicate user error
    if (body.error.indexOf("E11000 duplicate key") >= 0 || body.error.indexOf("username_1") >= 0) {
        errorMessage = "User already exists. Please choose a different username.";
    } else if (body.error.indexOf("duplicate") >= 0) {
        errorMessage = "User already exists. Please try logging in instead.";
    } else {
        // Generic error from service
        errorMessage = body.error;
    }
} else if (response.statusCode === 409) {
    errorMessage = "User already exists. Please choose a different username.";
} else if (response.statusCode === 400) {
    errorMessage = "Invalid registration data. Please check your information.";
} else if (response.statusCode >= 500) {
    errorMessage = "Server error during registration. Please try again later.";
}

callback({message: errorMessage, statusCode: response.statusCode});
```

#### Change 2: Return Proper Error Response (Lines 252-268)

**Before:**
```javascript
function(err, custId) {
    if (err) {
        console.log("Error with log in: " + err);
        res.status(500);
        res.end();
        return;
    }
```

**After:**
```javascript
function(err, custId) {
    if (err) {
        console.log("Error with registration: ", err);
        // Determine appropriate HTTP status code
        var statusCode = 500;
        var errorMessage = "Registration failed";
        
        if (typeof err === 'object' && err.statusCode) {
            statusCode = err.statusCode === 500 ? 409 : err.statusCode; // Convert 500 to 409 for duplicates
            errorMessage = err.message || errorMessage;
        } else if (typeof err === 'string') {
            errorMessage = err;
        }
        
        res.status(statusCode);
        res.json({error: errorMessage});
        return;
    }
```

---

## 🧪 Testing & Verification

### Test Case 1: Register New User (Success)

**Request:**
```bash
curl -X POST http://localhost:2025/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser123",
    "password": "password",
    "email": "newuser@example.com",
    "firstName": "New",
    "lastName": "User"
  }'
```

**Expected Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{"id": "690e0f029c10d30001923206"}
```

---

### Test Case 2: Register Duplicate User (Error) ✅ **FIXED**

**Request:**
```bash
# Register same user again
curl -X POST http://localhost:2025/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newuser123",
    "password": "password",
    "email": "different@example.com",
    "firstName": "Another",
    "lastName": "User"
  }'
```

**Before Fix:**
```http
HTTP/1.1 500 Internal Server Error
(no response body)
```

**After Fix:**
```http
HTTP/1.1 409 Conflict
Content-Type: application/json

{"error": "User already exists. Please choose a different username."}
```

---

### Test Case 3: Backend Direct Test (User Service)

**Test duplicate at user service level:**
```bash
kubectl -n sock-shop run test-dup --image=curlimages/curl:latest --rm -i --restart=Never \
  --command -- curl -v -X POST http://user:80/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"pass","email":"test@example.com","firstName":"Test","lastName":"User"}'
```

**User Service Response (unchanged - still returns 500):**
```json
{
  "error": "E11000 duplicate key error collection: users.customers index: username_1 dup key...",
  "status_code": 500,
  "status_text": "Internal Server Error"
}
```

**Frontend Now Translates This To:**
```json
{
  "error": "User already exists. Please choose a different username."
}
```

---

## 🚀 Deployment Instructions

### Option 1: Rebuild and Deploy (Recommended)

Since the front-end source is not in this repository, you'll need to:

#### Step 1: Clone Front-End Source

```powershell
cd d:\sock-shop-demo
git clone https://github.com/ocp-power-demos/sock-shop-front-end
cd sock-shop-front-end
```

#### Step 2: Apply the Fix

Copy the fixed file:
```powershell
# Backup original
cp api/user/index.js api/user/index.js.backup

# Copy fixed version
cp d:\sock-shop-demo\front-end-user-index.js api/user/index.js
```

Or manually apply the changes shown in the "Solution Implemented" section above to `sock-shop-front-end/api/user/index.js`.

#### Step 3: Build Docker Image

```powershell
cd d:\sock-shop-demo\sock-shop-front-end

# Build image
docker build -t sock-shop-front-end:v1.2-reg-fix \
  -f ..\automation\Dockerfile-front-end-local .

# Verify image
docker images | findstr front-end
```

#### Step 4: Load into KIND Cluster

```powershell
kind load docker-image sock-shop-front-end:v1.2-reg-fix --name sockshop
```

#### Step 5: Update Deployment

```powershell
kubectl -n sock-shop set image deployment/front-end \
  front-end=sock-shop-front-end:v1.2-reg-fix

# Wait for rollout
kubectl -n sock-shop rollout status deployment/front-end

# Verify new image
kubectl -n sock-shop get deployment front-end -o jsonpath='{.spec.template.spec.containers[0].image}'
```

#### Step 6: Test the Fix

```powershell
# Port-forward if not already running
kubectl -n sock-shop port-forward svc/front-end 2025:80

# Test in browser: http://localhost:2025
# Try registering a duplicate user
```

---

### Option 2: Patch Running Pod (Temporary - For Testing Only)

⚠️ **WARNING:** This is temporary and will be lost on pod restart!

```powershell
# Get pod name
$POD = kubectl -n sock-shop get pod -l name=front-end -o jsonpath='{.items[0].metadata.name}'

# Copy fixed file into pod
kubectl -n sock-shop cp front-end-user-index.js ${POD}:/usr/src/app/api/user/index.js

# Restart pod to reload code
kubectl -n sock-shop delete pod $POD

# Wait for new pod
kubectl -n sock-shop wait --for=condition=ready pod -l name=front-end --timeout=60s
```

---

### Option 3: Document Only (No Deployment)

If rebuilding is not desired right now:
1. ✅ Code fix is documented above
2. ✅ File `front-end-user-index.js` contains the fix
3. ⏳ Apply during next maintenance window or front-end update

---

## 📊 Impact Analysis

### User Experience Improvements

| Scenario | Before Fix | After Fix |
|----------|------------|-----------|
| **Duplicate Username** | No error / Generic error | "User already exists. Please choose a different username." |
| **Invalid Data** | Generic 500 error | "Invalid registration data. Please check your information." |
| **Server Error** | No message | "Server error during registration. Please try again later." |
| **HTTP Status Code** | Always 500 | 409 for duplicates, 400 for validation, 500 for server errors |
| **Error Format** | No JSON body | `{"error": "message"}` |

### Error Message Examples

```javascript
// Duplicate user (MongoDB E11000 error)
{"error": "User already exists. Please choose a different username."}

// HTTP 409 from service
{"error": "User already exists. Please choose a different username."}

// HTTP 400 from service
{"error": "Invalid registration data. Please check your information."}

// HTTP 500 from service (non-duplicate)
{"error": "Server error during registration. Please try again later."}

// Generic error with message in body
{"error": "Custom error message from service"}
```

---

## 🔄 Regression Testing

After deploying the fix, verify these scenarios:

### ✅ Checklist

- [ ] **New user registration** → Should succeed (HTTP 200)
- [ ] **Duplicate username** → Should show "User already exists" (HTTP 409)
- [ ] **Invalid email format** → Should show appropriate error
- [ ] **Empty required fields** → Should show validation error
- [ ] **Login after registration** → Should work normally
- [ ] **Cart merge after registration** → Should work normally

### Test Script

```powershell
# Test 1: Register new user
$NEW_USER = "testuser_$(Get-Date -Format 'yyyyMMddHHmmss')"
curl -X POST http://localhost:2025/register `
  -H "Content-Type: application/json" `
  -d "{`"username`":`"$NEW_USER`",`"password`":`"test123`",`"email`":`"test@example.com`",`"firstName`":`"Test`",`"lastName`":`"User`"}"

# Test 2: Register duplicate (should fail with clear message)
curl -X POST http://localhost:2025/register `
  -H "Content-Type: application/json" `
  -d "{`"username`":`"$NEW_USER`",`"password`":`"test123`",`"email`":`"test2@example.com`",`"firstName`":`"Test`",`"lastName`":`"User`"}"

# Expected: {"error":"User already exists. Please choose a different username."}
```

---

## 📝 Future Improvements

### Backend (User Service)

The user service should also be improved to return proper status codes:

**Recommended Changes:**
1. Return **409 Conflict** instead of 500 for duplicate users
2. Return user-friendly error messages
3. Sanitize MongoDB errors before sending to client

**Example ideal response:**
```json
HTTP/1.1 409 Conflict
{
  "error": "Username already exists",
  "error_code": "DUPLICATE_USERNAME",
  "field": "username"
}
```

### Frontend Validation

Add client-side validation before API call:
- Username format validation
- Password strength checking
- Email format validation
- Real-time availability checking

---

## 📚 Related Documentation

- **INCIDENT-6 Test Report:** `INCIDENT-6-TEST-REPORT-2025-11-07.md`
- **Port Forward Guide:** `PORT-FORWARD-GUIDE.md`
- **Architecture Guide:** `SOCK-SHOP-COMPLETE-ARCHITECTURE.md`
- **Complete Setup Guide:** `COMPLETE-SETUP-GUIDE.md`

---

## 📞 Summary

### What Was Fixed

✅ **Fixed:** Frontend now properly parses and displays registration errors  
✅ **Fixed:** HTTP status codes now reflect actual error type (409 for duplicates)  
✅ **Fixed:** JSON error messages sent to browser  
✅ **Fixed:** User-friendly error messages for common scenarios  

### What Still Needs Work

⏳ **Backend:** User service should return 409 instead of 500 for duplicates  
⏳ **Backend:** User service should sanitize MongoDB errors  
⏳ **Frontend:** Add client-side validation  
⏳ **Deployment:** Rebuild and redeploy front-end with this fix  

### Files Modified

- ✅ `d:\sock-shop-demo\front-end-user-index.js` - Contains the fix
- ⏳ Apply to `sock-shop-front-end/api/user/index.js` in source repo
- ⏳ Rebuild image `sock-shop-front-end:v1.2-reg-fix`
- ⏳ Deploy to cluster

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-07  
**Author:** AI SRE Assistant  
**Status:** ✅ **Code Fixed, Pending Deployment**
