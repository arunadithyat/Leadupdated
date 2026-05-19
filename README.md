# lead_calling

A Flutter call automation app with real-time call status tracking.

## 🎯 Features

- ✅ **Real-Time Call Status Tracking** - Monitor call status (Ringing → Connected → Disconnected)
- ✅ **Accurate Call Duration** - Real-time duration calculation updated every second
- ✅ **Multi-Platform** - Works on Android, iOS, Windows, macOS, Linux, and Web
- ✅ **Firebase Integration** - Push notifications and cloud messaging
- ✅ **Direct Phone Calling** - Automated call initiation via system dialer
- ✅ **Permission Handling** - Secure permission management
- ✅ **Local Notifications** - In-app notification system

## 🚀 Quick Start

### 1. Prerequisites
- Flutter SDK
- Android SDK (API 21+)
- Xcode (for iOS)

### 2. Installation
```bash
git clone https://github.com/arunadithyat/leadcalling.git
cd leadcalling
flutter pub get
```

### 3. Setup Call Status Tracking
See [QUICK_SETUP.md](QUICK_SETUP.md) for step-by-step instructions (takes 5 minutes).

### 4. Run
```bash
flutter run
```

## 📚 Documentation

- **[QUICK_SETUP.md](QUICK_SETUP.md)** - 5-minute setup guide
- **[CALL_STATUS_TRACKING_GUIDE.md](CALL_STATUS_TRACKING_GUIDE.md)** - Complete integration guide
- **[CHANGELOG_CALL_STATUS.md](CHANGELOG_CALL_STATUS.md)** - Feature details
- **[lib/CALL_STATUS_EXAMPLE.dart](lib/CALL_STATUS_EXAMPLE.dart)** - Working example code

## 🏗️ Project Structure

```
leadcalling/
├── lib/
│   ├── services/
│   │   └── call_status_service.dart      # Call monitoring service
│   ├── widgets/
│   │   └── call_status_widgets.dart      # UI widgets for call display
│   └── CALL_STATUS_EXAMPLE.dart          # Example implementation
├── android/
│   └── app/src/main/
│       ├── kotlin/com/example/lead_calling/
│       │   ├── MainActivity.kt           # Updated with call monitoring
│       │   ├── CallStatusManager.kt      # Call timing & state
│       │   └── CallStatusReceiver.kt     # Phone state receiver
│       └── AndroidManifest.xml           # Updated permissions
├── ios/                                   # iOS implementation
├── QUICK_SETUP.md                        # Quick setup guide
├── CALL_STATUS_TRACKING_GUIDE.md         # Full integration guide
└── CHANGELOG_CALL_STATUS.md              # Feature changelog
```

## 🔧 Dependencies

Key dependencies from pubspec.yaml:
```yaml
flutter:
  sdk: flutter
firebase_core: ^4.8.0
firebase_messaging: ^16.2.1
flutter_phone_direct_caller: ^2.2.1
permission_handler: ^12.0.1
url_launcher: ^6.3.2
shared_preferences: ^2.5.5
```

## 📱 Features Details

### Call Status Tracking
Real-time monitoring of phone calls with:
- Call status updates: IDLE → RINGING → CONNECTED → DISCONNECTED
- Accurate call duration calculation
- Phone number tracking
- Call start/end time recording
- Visual status indicators

### Error Handling
Production-ready with:
- Comprehensive try-catch blocks
- Null safety throughout
- Thread-safe implementation
- Automatic resource cleanup
- Fallback values for edge cases

## 🧪 Testing

### Manual Testing
```bash
# Build and run
flutter run -v

# Watch logs for call status
adb logcat | grep CallStatus
```

### Make a Test Call
1. Install app on device/emulator
2. Use device dialer to call another number
3. Watch screen for status updates
4. Verify duration updates every second
5. End call and verify final duration

### Example Log Output
```
CallStatusManager: ☎️ Call ringing: +919876543210
CallStatusManager: ✅ Call connected: +919876543210
CallStatusManager: 📴 Call disconnected: +919876543210
```

## 🔐 Permissions Required

- `android.permission.READ_PHONE_STATE` - Monitor call states
- `android.permission.CALL_PHONE` - Make phone calls
- `android.permission.INTERNET` - Network communication
- `android.permission.ACCESS_FINE_LOCATION` - Location services (optional)

## 📊 Data Flow

```
Android System
    ↓ (broadcasts PHONE_STATE)
CallStatusReceiver
    ↓ (calls sendCallStatus)
CallStatusManager
    ↓ (invokes method)
MethodChannel
    ↓ (sends to Flutter)
CallStatusService
    ↓ (notifies listeners)
UI Widgets
    ↓ (updates display)
```

## 🎯 Usage Example

```dart
import 'services/call_status_service.dart';
import 'widgets/call_status_widgets.dart';

// Initialize service
final callStatusService = CallStatusService();
await callStatusService.initialize();
await callStatusService.startMonitoring();

// Listen to call status
callStatusService.addStatusListener((callInfo) {
  print('Status: ${callInfo.status}');
  print('Duration: ${callInfo.getFormattedDuration()}');
});

// Listen to call end
callStatusService.addCallEndListener((callInfo) {
  print('Call ended: ${callInfo.durationSeconds} seconds');
  // Save to database
});

// Display in UI
CallStatusDisplay(callInfo: currentCall)
```

## 🐛 Troubleshooting

See [CALL_STATUS_TRACKING_GUIDE.md](CALL_STATUS_TRACKING_GUIDE.md) for:
- Common errors and fixes
- Debugging tips
- Testing procedures
- Production checklist

## 📈 Future Enhancements

Planned features:
- [ ] Call recording
- [ ] Call transcript generation
- [ ] Call queue management
- [ ] Missed call tracking
- [ ] Call analytics dashboard
- [ ] WhatsApp integration
- [ ] SMS fallback

## 👨‍💻 Development

### Code Style
- Follow Flutter conventions
- Use null safety throughout
- Comprehensive error handling
- Document complex logic

### Git Workflow
```bash
git checkout -b feature/your-feature
git commit -m "feat: description"
git push origin feature/your-feature
```

## 📄 License

This project is part of LeadCalling automation system.

## 📞 Support

For issues or questions:
1. Check the troubleshooting section in CALL_STATUS_TRACKING_GUIDE.md
2. Review logs: `adb logcat | grep CallStatus`
3. See example code: lib/CALL_STATUS_EXAMPLE.dart

## 🙏 Credits

Built with Flutter and production-grade error handling practices.

---

**Last Updated:** May 19, 2026  
**Version:** 1.0.0 + Call Status Tracking
