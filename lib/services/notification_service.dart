import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // StreamController for handling navigation
  static final StreamController<Map<String, dynamic>> notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  static int _buildNotificationId(Map<String, dynamic> data) {
    final seed =
        '${data['docname']}_${data['mobile_no']}_${data['queued_at'] ?? DateTime.now().toIso8601String()}';
    return seed.hashCode.abs() & 0x7fffffff;
  }

  static Map<String, dynamic>? normalizeLeadCallPayload(
    Map<String, dynamic> rawData,
  ) {
    debugPrint("[NOTIFY] normalizeLeadCallPayload input => $rawData");
    
    final merged = <String, dynamic>{};

    void merge(dynamic source) {
      if (source is Map) {
        source.forEach((key, value) {
          merged[key.toString()] = value;
        });
        return;
      }
      if (source is String) {
        try {
          final decoded = jsonDecode(source);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              merged[key.toString()] = value;
            });
          }
        } catch (_) {
          // Ignore non-JSON strings
        }
      }
    }

    merge(rawData);
    merge(rawData['data']);
    merge(rawData['payload']);
    merge(rawData['message']);

    debugPrint("[NOTIFY] merged data => $merged");

    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (merged.containsKey(key) && merged[key] != null) {
          return merged[key];
        }
      }
      return null;
    }

    final type =
        (pick(['type', 'event', 'event_type']) ?? '').toString().trim();
    debugPrint("[NOTIFY] extracted type => '$type'");
    
    // BUG FIX #1: Accept both 'NEW_LEAD_CALL' and 'LEAD_CALL'
    if (!['NEW_LEAD_CALL', 'LEAD_CALL'].contains(type.toUpperCase())) {
      debugPrint("[NOTIFY] ❌ type mismatch: '$type' not in acceptable types");
      return null;
    }

    final normalized = {
      'type': 'NEW_LEAD_CALL',
      'doctype': (pick(['doctype', 'doc_type', 'docType']) ?? '').toString(),
      'docname': (pick(['docname', 'doc_name', 'docName']) ?? '').toString(),
      'customer_name':
          (pick(['customer_name', 'customerName', 'customer', 'lead_name']) ??
                  'Customer')
              .toString(),
      'mobile_no':
          (pick(['mobile_no', 'mobileNo', 'mobile', 'phone', 'phone_number']) ??
                  '')
              .toString(),
      'auto_call': (pick(['auto_call', 'autoCall']) ?? '1').toString(),
      'queued_at': DateTime.now().toIso8601String(),
    };
    
    debugPrint("[NOTIFY] ✅ normalized => $normalized");
    return normalized;
  }

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('app_icon');

    const DarwinInitializationSettings iOSInitializationSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iOSInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    await _createAndroidNotificationChannel();

    // Request iOS permissions
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is terminated/closed
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        final leadData = normalizeLeadCallPayload(message.data);
        if (leadData != null) {
          notificationStream.add(leadData);
        }
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final leadData = normalizeLeadCallPayload(message.data);
      if (leadData != null) {
        notificationStream.add(leadData);
      }
    });
  }

  Future<void> _createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications like incoming calls.',
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint("Foreground Message: ${message.data}");

    final leadData = normalizeLeadCallPayload(message.data);
    if (leadData != null) {
      await _showCallNotification(leadData);
      notificationStream.add(leadData);
    }
  }

  Future<void> _showCallNotification(Map<String, dynamic> data) async {
    final customerName = data['customer_name'] ?? 'Incoming Call';
    final mobileNo = data['mobile_no'] ?? 'Unknown';
    final notificationId = _buildNotificationId(data);

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(
        'Incoming call from $customerName\n$mobileNo',
        htmlFormatBigText: true,
        contentTitle: 'Incoming Call',
        summaryText: 'Lead Call Alert',
      ),
    );

    const DarwinNotificationDetails iOSNotificationDetails =
        DarwinNotificationDetails(
      presentSound: true,
      presentBadge: true,
      presentAlert: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: 'Incoming Call',
      body: '$customerName - $mobileNo',
      notificationDetails: notificationDetails,
      payload: jsonEncode(data),
    );
  }

  Future<void> _onNotificationTapped(
    NotificationResponse notificationResponse,
  ) async {
    debugPrint('Notification tapped: ${notificationResponse.payload}');

    if (notificationResponse.payload != null && notificationResponse.payload!.isNotEmpty) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(notificationResponse.payload!) as Map<String, dynamic>;
        final leadData = normalizeLeadCallPayload(data);
        if (leadData != null) {
          notificationStream.add(leadData);
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void dispose() {
    notificationStream.close();
  }
}

// Top-level function to handle background messages
// BUG FIX #2 & #3: Moved from NotificationService.initialize() to main.dart
// This function will be registered before runApp() in main()
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // BUG FIX #3: Initialize FlutterLocalNotificationsPlugin in background isolate
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('app_icon');
  const DarwinInitializationSettings iOSInitializationSettings =
      DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: iOSInitializationSettings,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('Background notification tapped: ${response.payload}');
    },
  );
  
  // Create notification channel in background
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications like incoming calls.',
    importance: Importance.max,
    enableVibration: true,
    enableLights: true,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  debugPrint('========== BACKGROUND MESSAGE HANDLER ==========');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification}');

  // Show notification for background message
  final leadData = NotificationService.normalizeLeadCallPayload(message.data);
  if (leadData != null) {
    debugPrint("[BG] ✅ Showing notification for: ${leadData['customer_name']}");
    await _showCallNotificationInBackground(flutterLocalNotificationsPlugin, leadData);
  } else {
    debugPrint("[BG] ❌ Failed to normalize payload");
  }
  debugPrint('========== END BACKGROUND MESSAGE ==========');
}

// Helper function for background notifications
Future<void> _showCallNotificationInBackground(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  final customerName = data['customer_name'] ?? 'Incoming Call';
  final mobileNo = data['mobile_no'] ?? 'Unknown';
  
  // Use the same ID generation logic
  final seed =
      '${data['docname']}_${data['mobile_no']}_${data['queued_at'] ?? DateTime.now().toIso8601String()}';
  final notificationId = seed.hashCode.abs() & 0x7fffffff;

  final AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'This channel is used for important notifications.',
    importance: Importance.max,
    priority: Priority.high,
    enableVibration: true,
    enableLights: true,
    playSound: true,
    fullScreenIntent: true,
    styleInformation: BigTextStyleInformation(
      'Incoming call from $customerName\n$mobileNo',
      htmlFormatBigText: true,
      contentTitle: 'Incoming Call',
      summaryText: 'Lead Call Alert',
    ),
  );

  const DarwinNotificationDetails iOSNotificationDetails =
      DarwinNotificationDetails(
    presentSound: true,
    presentBadge: true,
    presentAlert: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iOSNotificationDetails,
  );

  await plugin.show(
    id: notificationId,
    title: 'Incoming Call',
    body: '$customerName - $mobileNo',
    notificationDetails: notificationDetails,
    payload: jsonEncode(data),
  );
}
