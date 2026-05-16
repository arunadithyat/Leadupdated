# 🔴 FCM MANUAL TRIGGER - ISSUE REPORT & FIXES

## ISSUES FOUND

### 1. ✅ ENHANCED DEBUG LOGGING ADDED
I've added comprehensive logging throughout the app to help identify where FCM breaks:

- **Device Registration**: Now logs success/failure with detailed messages
- **Payload Normalization**: Shows raw data → normalized conversion with detailed errors
- **Message Handling**: Logs all 4 Firebase message sources (onMessage, onMessageOpenedApp, initialMessage, notification_stream)
- **Background Handler**: Full logging with message ID and notification details

---

## MOST LIKELY ISSUES

### 🔴 Issue #1: Backend Not Sending Correct Payload Format
**Expected payload:**
```json
{
  "type": "NEW_LEAD_CALL",
  "doctype": "Opportunity",
  "docname": "CRM-OPP-00001",
  "customer_name": "Test Customer",
  "mobile_no": "9876543210"
}
```

**Common mistakes:**
- ❌ Missing `type: "NEW_LEAD_CALL"`
- ❌ `type` in different case (e.g., "new_lead_call")
- ❌ Sending data inside nested `data` or `payload` object
- ❌ Empty or null fields

### 🔴 Issue #2: FCM Token Not Registered
The device token might not be stored on the backend.

**Check in logs:**
```
REGISTER DEVICE RESULT => {"success": true}
```

If it shows `false`, backend registration is failing.

### 🔴 Issue #3: Call Marked as Duplicate
If you send 2 calls within 3 seconds, the 2nd is ignored:
```dart
// In _isDuplicateLeadCall()
if (now.difference(_lastLeadCallAt!).inSeconds <= 3) {
  return true; // Ignored!
}
```

### 🔴 Issue #4: Call Flow is Paused
If `pausedUntil` is set to a future time, incoming calls are queued instead of processed.

---

## 🧪 TESTING STEPS

### Step 1: Get Full Debug Output
```bash
flutter clean
flutter pub get
flutter run -v 2>&1 | tee debug_output.log
```

Then send test FCM from backend.

### Step 2: Look for These Logs

✅ **Expected successful flow:**
```
=============== FCM TOKEN ===============
FCM TOKEN => eKDm...xyz123
Token length: 152
📱 Registering device with token...
REGISTER DEVICE RESULT => {"success": true}
✅ Device registered successfully
========================================

[INIT] Starting notification initialization...
[INIT] NotificationService initialized
[INIT] ✅ Notification initialization complete

========== BACKGROUND MESSAGE HANDLER ==========
Message ID: 0:1234567...
Message data: {type: NEW_LEAD_CALL, ...}
[NOTIFY] normalizeLeadCallPayload input => {...}
[NOTIFY] merged data => {...}
[NOTIFY] extracted type => 'NEW_LEAD_CALL'
[NOTIFY] ✅ normalized => {...}
[BG] ✅ Showing notification for: Test Customer
========== END BACKGROUND MESSAGE ==========

========== HANDLE INCOMING LEAD CALL ==========
Source: notification_stream
Raw data: {type: NEW_LEAD_CALL, ...}
Is paused: false
Queue length: 0
Normalized: {type: NEW_LEAD_CALL, ...}
✅ Navigating to LeadCallScreen
========== END INCOMING LEAD CALL ==========
```

### Step 3: If Something Fails

❌ **Issue: "Token is empty"**
→ Firebase not initialized or permissions not granted

❌ **Issue: "Device registration failed"**
→ Backend API endpoint issue or auth error

❌ **Issue: "type mismatch"**
→ Backend sending wrong `type` value

❌ **Issue: "ignored_invalid_payload"**
→ Payload missing required fields

❌ **Issue: "ignored_duplicate"**
→ Send the same call >3 seconds apart

❌ **Issue: "queued_paused_flow"**
→ Call flow is paused, check `pausedUntil` value

---

## 🔧 BACKEND REQUIREMENTS

Send FCM exactly like this:

```python
from itgenie.lead_calling.fcm_utils import send_fcm_to_user

send_fcm_to_user(
    "arun.itdigital@homegeniegroup.com",  # ✅ Must match user email
    {
        "type": "NEW_LEAD_CALL",  # ✅ EXACTLY this string, case-sensitive
        "doctype": "Opportunity",
        "docname": "CRM-OPP-00001",
        "customer_name": "Test Customer",
        "mobile_no": "9876543210",
        "auto_call": "1"  # Optional
    }
)
```

---

## 📋 QUICK DIAGNOSIS

### Test Checklist:

```
[ ] 1. Run app with -v flag and capture logs
[ ] 2. Send FCM from backend
[ ] 3. Check for "FCM TOKEN => " in logs
    - If NOT present: Firebase not working
    - If present: Note the token
[ ] 4. Check for "REGISTER DEVICE RESULT => " in logs
    - If "success": true → Device registered ✅
    - If "success": false → Registration failed ❌
[ ] 5. Check for "BACKGROUND MESSAGE HANDLER" logs
    - If present → FCM received ✅
    - If NOT present → Backend didn't send or wrong user
[ ] 6. Check for normalized payload logs
    - If ❌ "type mismatch" → Backend sending wrong type
    - If ✅ "normalized" → Payload correct
[ ] 7. Check for "HANDLE INCOMING LEAD CALL" logs
    - If "queued_paused_flow" → Resume call flow
    - If "ignored_duplicate" → Send calls >3s apart
    - If "ignored_invalid_payload" → Missing fields
    - If "navigated_to_lead_call_screen" → ✅ SUCCESS!
```

---

## 🚀 NEXT STEPS

1. **Run app with full logging** (see Step 1 above)
2. **Send test FCM** from backend
3. **Check logs** for where it fails
4. **Share logs** showing the error
5. **I'll pinpoint the exact issue**

---

## 📍 FILE LOCATIONS OF DEBUG LOGGING

- `lib/main.dart` → Lines with `[INIT]`, `[STREAM]`, `[FOREGROUND]`, `[OPENED_APP]`, `[INITIAL]`
- `lib/services/notification_service.dart` → Lines with `[NOTIFY]`, `[BG]`
- `lib/api/device_api.dart` → Device registration errors

---

**Ready to test? Run:**
```bash
flutter run -v
```
**Then send FCM from backend and share the console output! 🚀**
