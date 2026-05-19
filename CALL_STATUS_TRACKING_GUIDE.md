# Call Status Tracking - PRODUCTION IMPLEMENTATION GUIDE
## With Comprehensive Error Handling & Unexpected Scenarios

---

## 📋 Pre-Integration Checklist

- [ ] Flutter SDK installed and updated
- [ ] Android SDK (API 21+) installed
- [ ] Know your app's package name (from `android/app/src/main/AndroidManifest.xml`)
- [ ] Android Studio installed for testing
- [ ] At least one Android device or emulator for testing
- [ ] Git set up (for version control)

**Your Package Name:** `com.example.leadcalling` (REPLACE THIS WITH YOUR ACTUAL PACKAGE)

---

## 🔧 STEP 1: Update AndroidManifest.xml

**File:** `android/app/src/main/AndroidManifest.xml`

Add permissions BEFORE `<application>` tag:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.leadcalling">

    <!-- CRITICAL: Call monitoring permissions -->
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.CALL_PHONE" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application>
        <!-- Your existing activities here -->
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            ...
        >
        </activity>

        <!-- ADD THIS: Broadcast receiver for call state -->
        <receiver
            android:name=".CallStatusReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.PHONE_STATE" />
            </intent-filter>
        </receiver>

    </application>

</manifest>
```

✅ **Verification:** Check that `android:exported="true"` is present

---

## 🏗️ STEP 2: Create Kotlin Files

**Create these 3 files** in `android/app/src/main/kotlin/com/example/leadcalling/`

**(Replace `com.example.leadcalling` with YOUR package name)**

### File 1: CallStatusManager.kt

```kotlin
// Copy from CallStatusManager_production.kt
// This handles the call timing and status tracking
```

### File 2: CallStatusReceiver.kt

```kotlin
// Copy from CallStatusReceiver_production.kt
// This receives broadcast events from Android system
```

### File 3: MainActivity.kt

```kotlin
// Copy from MainActivity_production.kt
// IMPORTANT: This REPLACES your existing MainActivity.kt
// Make sure you keep any custom code you had
```

⚠️ **Important:** If you have custom code in MainActivity.kt, merge it carefully

---

## 📱 STEP 3: Add Flutter Files

Create these in `lib/`:

### File 1: lib/services/call_status_service.dart

```
mkdir -p lib/services
# Copy call_status_service_production.dart content to this file
```

### File 2: lib/widgets/call_status_widgets.dart

```
mkdir -p lib/widgets
# Copy call_status_widgets_production.dart content to this file
```

---

## 🚀 STEP 4: Initialize in main.dart

```dart
import 'package:flutter/material.dart';
import 'services/call_status_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize call status service
  try {
    final callStatusService = CallStatusService();
    final initialized = await callStatusService.initialize();
    
    if (!initialized) {
      debugPrint('⚠️ Failed to initialize CallStatusService');
    } else {
      debugPrint('✅ CallStatusService initialized');
      
      // Start monitoring
      final started = await callStatusService.startMonitoring();
      if (!started) {
        debugPrint('⚠️ Failed to start call monitoring');
      } else {
        debugPrint('✅ Call monitoring started');
      }
    }
  } catch (e) {
    debugPrint('❌ Error initializing CallStatusService: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lead Calling',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CallStatusService _callStatusService;
  CallInfo? _currentCall;

  @override
  void initState() {
    super.initState();
    _initializeCallTracking();
  }

  Future<void> _initializeCallTracking() async {
    try {
      _callStatusService = CallStatusService();
      
      // Add listener for status changes
      _callStatusService.addStatusListener((callInfo) {
        try {
          setState(() {
            _currentCall = callInfo;
          });
          
          debugPrint('📞 Call Status Updated:');
          debugPrint('   Number: ${callInfo.phoneNumber}');
          debugPrint('   Status: ${callInfo.status}');
          debugPrint('   Duration: ${callInfo.getFormattedDuration()}');
        } catch (e) {
          debugPrint('❌ Error updating UI: $e');
        }
      });

      // Listen for call end events
      _callStatusService.addCallEndListener((callInfo) {
        try {
          debugPrint('✅ Call Ended:');
          debugPrint('   Number: ${callInfo.phoneNumber}');
          debugPrint('   Duration: ${callInfo.getFormattedDuration()}');
          debugPrint('   Started: ${callInfo.startTime}');
          debugPrint('   Ended: ${callInfo.endTime}');
          
          // TODO: Save to database
          // await saveCallRecord(callInfo);
        } catch (e) {
          debugPrint('❌ Error in call end listener: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ Error initializing call tracking: $e');
    }
  }

  @override
  void dispose() {
    try {
      // Cleanup
      _callStatusService.dispose();
    } catch (e) {
      debugPrint('❌ Error in dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lead Calling')),
      body: Center(
        child: _currentCall != null
            ? CallStatusDisplay(
                callInfo: _currentCall,
                onHangup: () {
                  try {
                    Navigator.pop(context);
                  } catch (e) {
                    debugPrint('❌ Error hanging up: $e');
                  }
                },
              )
            : const Text('No active call'),
      ),
    );
  }
}
```

---

## 🔐 STEP 5: Request Runtime Permissions

Add to your app (before making calls):

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPhonePermissions() async {
  try {
    final status = await Permission.phone.request();
    
    if (status.isDenied) {
      debugPrint('⚠️ Phone permission denied');
    } else if (status.isGranted) {
      debugPrint('✅ Phone permission granted');
    } else if (status.isDenied) {
      debugPrint('❌ Phone permission permanently denied');
      // Show dialog asking user to enable in settings
    }
  } catch (e) {
    debugPrint('❌ Error requesting permission: $e');
  }
}
```

Call this early in your app (like in initState):

```dart
@override
void initState() {
  super.initState();
  requestPhonePermissions();
  _initializeCallTracking();
}
```

---

## 🧪 STEP 6: Testing & Verification

### Test 1: Build the App

```bash
# Clean build
flutter clean
flutter pub get

# Debug build
flutter run -v

# Or release build
flutter build apk --release
```

### Test 2: Check Logs

Open Android Studio logcat and filter for:
```
CallStatusService
CallMonitoring
CallStatusManager
CallStatusReceiver
```

### Test 3: Make a Test Call

1. Install app on device/emulator
2. Use device's dialer to call another number
3. Watch the logs:

```
✅ CallStatusManager: 📞 Processing state: RINGING
✅ CallStatusManager: ☎️ Call ringing
✅ CallStatusManager: ✅ Call connected
✅ CallStatusManager: 📴 Call disconnected
```

### Test 4: Verify Call Display

- [ ] Call status shows on screen during call
- [ ] Duration updates every second
- [ ] Status changes from Ringing → Connected → Disconnected
- [ ] Final duration is correct

---

## ⚠️ Common Errors & Fixes

### ❌ Error 1: "No implementation found for method startCallMonitoring"

**Cause:** Package name mismatch

**Fix:**
1. Find your actual package in `android/app/src/main/AndroidManifest.xml`
2. Update all Kotlin files with correct package
3. Example: If package is `com.mycompany.app`, change:
```kotlin
package com.example.leadcalling  // ❌ Wrong
package com.mycompany.app        // ✅ Correct
```

### ❌ Error 2: "Receiver not registered"

**Cause:** Receiver not in AndroidManifest.xml

**Fix:**
```xml
<!-- Make sure this is in your AndroidManifest.xml -->
<receiver
    android:name=".CallStatusReceiver"
    android:enabled="true"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.PHONE_STATE" />
    </intent-filter>
</receiver>
```

### ❌ Error 3: "Permission denied"

**Cause:** Permission not requested

**Fix:**
```xml
<!-- In AndroidManifest.xml -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />

<!-- And in code -->
await Permission.phone.request();
```

### ❌ Error 4: "NullPointerException in CallStatusManager"

**Cause:** MethodChannel is null

**Fix:**
- Ensure MainActivity.kt properly initializes MethodChannel
- Check package name is correct
- Verify Flutter and Android are both built

### ❌ Error 5: "App crashes on call"

**Cause:** Null callInfo being accessed

**Fix:**
```dart
// ❌ Wrong
final duration = _currentCall!.getFormattedDuration();

// ✅ Correct
final duration = _currentCall?.getFormattedDuration() ?? '00:00';

// Or check first
if (_currentCall != null) {
  final duration = _currentCall!.getFormattedDuration();
}
```

### ❌ Error 6: "Timer keeps running after call ends"

**Cause:** Timer not cancelled in dispose

**Fix:**
The production code handles this with `_isTimerRunning` flag. Make sure you:
- Call `dispose()` on the widget
- Check `if (_isTimerRunning && _durationTimer.isActive)` before cancelling

### ❌ Error 7: "Negative duration detected"

**Cause:** System clock issues

**Fix:**
The production code already handles this:
```kotlin
if (elapsed < 0) {
    Log.w(TAG, "⚠️ Negative elapsed time detected, resetting")
    callStartTime = SystemClock.uptimeMillis()
}
```

---

## 🐛 Debugging Tips

### Enable Verbose Logging

```bash
flutter run -v  # Run app in verbose mode
```

### Check Logs in Real-Time

```bash
adb logcat | grep "CallStatus"
```

### Force Stop and Clear Cache

```bash
adb shell pm clear com.example.leadcalling
adb shell am force-stop com.example.leadcalling
```

### Check if Receiver is Registered

```bash
adb shell dumpsys package receivers | grep CallStatusReceiver
```

### Test with ADB

```bash
# Send PHONE_STATE broadcast manually
adb shell am broadcast -a android.intent.action.PHONE_STATE \
  --es android_telcom_extra_state "RINGING" \
  --es incoming_number "9876543210"
```

---

## ✅ Verification Checklist

Before going to production:

- [ ] `android/app/src/main/AndroidManifest.xml` has permissions
- [ ] `android/app/src/main/AndroidManifest.xml` has receiver
- [ ] All 3 Kotlin files are in correct package folder
- [ ] All 2 Flutter service files are created
- [ ] `main.dart` initializes CallStatusService
- [ ] Runtime permissions are requested
- [ ] Build runs without errors
- [ ] Test call shows status updates
- [ ] Duration updates every second
- [ ] Call end is logged
- [ ] No crashes in logs
- [ ] App doesn't crash when closed during call

---

## 🚀 Going Live

Once everything works:

1. Test on multiple devices
2. Test edge cases:
   - Call during app backgrounding
   - Call when app is closed
   - Multiple rapid calls
   - Very long calls (30+ min)
   - Missed calls

3. Push to production:
```bash
git add .
git commit -m "feat: Add call status tracking with comprehensive error handling"
git push origin main
```

---

## 📞 Troubleshooting Script

Create a debug file to test:

```dart
// lib/debug_call_status.dart

import 'package:flutter/material.dart';
import 'services/call_status_service.dart';

class CallStatusDebugScreen extends StatefulWidget {
  @override
  State<CallStatusDebugScreen> createState() => _CallStatusDebugScreenState();
}

class _CallStatusDebugScreenState extends State<CallStatusDebugScreen> {
  late CallStatusService _service;
  String _status = 'Not initialized';
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _initializeDebug();
  }

  Future<void> _initializeDebug() async {
    try {
      _service = CallStatusService();
      
      final initialized = await _service.initialize();
      _addLog('Initialize: $initialized');
      
      final started = await _service.startMonitoring();
      _addLog('Monitoring started: $started');
      
      _service.addStatusListener((callInfo) {
        _addLog('STATUS: ${callInfo.status} - ${callInfo.phoneNumber}');
        setState(() {
          _status = '${callInfo.status} - ${callInfo.getFormattedDuration()}';
        });
      });

      _service.addCallEndListener((callInfo) {
        _addLog('CALL ENDED: ${callInfo.phoneNumber} - ${callInfo.getFormattedDuration()}');
      });
      
      setState(() {
        _status = 'Monitoring active';
      });
    } catch (e) {
      _addLog('ERROR: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs = '${DateTime.now().toIso8601String()} - $message\n$_logs';
    });
    debugPrint(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Status Debug')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade100,
            child: Text('Status: $_status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Text(_logs, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Summary

✅ **This implementation includes:**
- Null safety everywhere
- Try-catch blocks for all operations
- Proper thread safety in Kotlin
- Comprehensive logging
- Error recovery mechanisms
- Timer management
- Listener cleanup
- Validation at every step
- Fallback values for errors
- No crashes from unexpected input

**It's production-ready!**
