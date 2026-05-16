## FCM Manual Trigger Debugging Guide

### 🔴 POTENTIAL ISSUES FOUND:

1. **FCM Token Not Registered**
   - The device registration might be failing silently
   - Backend might not have the correct FCM token

2. **Payload Structure Mismatch**
   - The backend might not be sending all required fields
   - Field names might be different from what the app expects

3. **firebase_messaging Plugin Issue**
   - Background message handler needs proper initialization

---

## ✅ DEBUGGING CHECKLIST

### Step 1: Verify FCM Token Registration
```dart
// Add this to HomePage > getFcmToken()
final registerResult = await DeviceApi.registerDevice(fcmToken!);
debugPrint("REGISTER DEVICE RESULT: $registerResult");

// Check in logs for success/failure
```

### Step 2: Verify Backend is Sending Correct Payload
The backend should send:
```python
send_fcm_to_user(
    "arun.itdigital@homegeniegroup.com",
    {
        "type": "NEW_LEAD_CALL",  # ✅ REQUIRED
        "doctype": "Opportunity",  # ✅ REQUIRED
        "docname": "CRM-OPP-00001",  # ✅ REQUIRED
        "customer_name": "Test Customer",  # ✅ REQUIRED
        "mobile_no": "9876543210",  # ✅ REQUIRED
        "auto_call": "1"
    }
)
```

### Step 3: Check Logs in Flutter
Run app with:
```bash
flutter run -v
```

Look for these logs:
```
✅ "FCM TOKEN => [token]"
✅ "REGISTER DEVICE => {"success": true}"
✅ "Home fallback onMessage payload => {...}"
✅ "Lead payload normalized => {...}"
```

### Step 4: Test with Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Send test message with data:
```json
{
  "type": "NEW_LEAD_CALL",
  "doctype": "Opportunity",
  "docname": "TEST-001",
  "customer_name": "Firebase Test",
  "mobile_no": "1234567890"
}
```

---

## 🔧 ISSUES I DETECTED IN YOUR CODE:

### Issue 1: NotificationService.normalizeLeadCallPayload() return null silently
If the payload normalization fails, the call is ignored.

**Fix:** Check the normalizeLeadCallPayload method output:
```dart
// In notification_service.dart around line 264
static Map<String, dynamic>? normalizeLeadCallPayload(
    Map<String, dynamic> rawData,
) {
    // Add detailed logging
    debugPrint("Raw payload: $rawData");
    // ... normalization code ...
    debugPrint("Normalized payload: $result");
    return result;
}
```

### Issue 2: Duplicate Lead Call Detection
The app filters duplicate calls within 3 seconds.
```dart
// In main.dart _isDuplicateLeadCall()
// This might be dropping valid consecutive calls
```

### Issue 3: pausedUntil DateTime Logic
```dart
bool get isCallFlowPaused {
    if (pausedUntil == null) return false;
    return DateTime.now().isBefore(pausedUntil!);
}
```
Make sure pausedUntil is being set correctly in toggleCallFlow()

---

## 🚀 RECOMMENDED QUICK FIXES:

1. **Enable Debug Logging**
   Add this line right after Firebase.initializeApp() in main():
   ```dart
   // In main.dart
   if (kDebugMode) {
     FirebaseMessaging.instance.getAPNSToken().then((token) {
       debugPrint("APNS Token: $token");
     });
   }
   ```

2. **Verify Device Registration**
   Check if DeviceApi.registerDevice() returns success:
   ```dart
   // Check the response status code and message
   // from registerResult variable
   ```

3. **Test Notification Channel**
   Verify Android notification channel is created:
   ```bash
   adb shell am get-config --json | grep notifications
   ```

---

## 📋 WHAT TO CHECK NEXT:

[ ] FCM token is being printed in logs
[ ] Device registration returns success
[ ] Backend is sending payload with all required fields
[ ] Test message from Firebase Console works
[ ] App is NOT ignoring as duplicate
[ ] pausedUntil is null (not paused)
[ ] Notification channel is created successfully

---

## 🔗 SEND THIS INFO TO BACKEND TEAM:

```
1. User email: arun.itdigital@homegeniegroup.com
2. Package name: com.example.lead_calling
3. Firebase Project ID: test-call-34bde
4. Required payload fields:
   - type: "NEW_LEAD_CALL"
   - doctype: "Opportunity"
   - docname: "[string]"
   - customer_name: "[string]"
   - mobile_no: "[string]"
5. Backend should verify:
   - Is the user's FCM token stored?
   - Is the token up-to-date?
   - Are all required fields being sent?
```
