import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:async';

class AutoDialer {
  /// Auto-dial a phone number directly (no user confirmation needed)
  static Future<bool> autoCall(String phoneNumber) async {
    try {
      debugPrint("[DIALER] 📞 Auto-dialing: $phoneNumber");
      
      // Remove any non-digit characters except + for international format
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      debugPrint("[DIALER] 📞 Cleaned number: $cleanedNumber");
      
      try {
        // Use Android Intent to directly call
        final intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$cleanedNumber',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint("[DIALER] ✅ Auto-dial initiated successfully");
        return true;
      } catch (e) {
        debugPrint("[DIALER] ❌ Auto-dial failed with intent: $e");
        return await _fallbackCall(cleanedNumber);
      }
    } catch (e) {
      debugPrint("[DIALER] ❌ Auto-dial error: $e");
      return false;
    }
  }

  /// Fallback to tel: URI if Android Intent fails
  static Future<bool> _fallbackCall(String cleanedNumber) async {
    try {
      debugPrint("[DIALER] Using fallback tel: URI");
      
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.CALL',
          data: 'tel:$cleanedNumber',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint("[DIALER] ✅ Fallback call initiated");
        return true;
      } catch (e) {
        debugPrint("[DIALER] ❌ Fallback intent also failed: $e");
        return false;
      }
    } catch (e) {
      debugPrint("[DIALER] ❌ Fallback call error: $e");
      return false;
    }
  }

  /// Open dialer with number pre-filled (user presses call button)
  static Future<bool> openDialer(String phoneNumber) async {
    try {
      debugPrint("[DIALER] 📞 Opening dialer for: $phoneNumber");
      
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.DIAL',
          data: 'tel:$cleanedNumber',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint("[DIALER] ✅ Dialer opened");
        return true;
      } catch (e) {
        debugPrint("[DIALER] ❌ Failed to open dialer: $e");
        return false;
      }
    } catch (e) {
      debugPrint("[DIALER] ❌ Dialer error: $e");
      return false;
    }
  }
}
