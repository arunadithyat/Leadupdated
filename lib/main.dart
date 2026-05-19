
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lead_calling/services/auto_dialer.dart';
import 'package:lead_calling/api/call_log_api.dart';
import 'package:lead_calling/screens/call_completion_dialog.dart';
import 'package:lead_calling/screens/call_queue_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/device_api.dart';
import 'api/login_api.dart';
import 'api/opportunities_api.dart';
import 'services/notification_service.dart';
import 'services/call_status_service.dart';
import 'models/call_queue.dart';

/// Launches the phone dialer to call the given phone number
Future<bool> launchPhoneCall(String phoneNumber) async {
  // Remove any non-digit characters except + for international format
  final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  
  final Uri launchUri = Uri(
    scheme: 'tel',
    path: cleanedNumber,
  );
  
  try {
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
      return true;
    } else {
      debugPrint('Could not launch phone call to: $launchUri');
      return false;
    }
  } catch (e) {
    debugPrint('Error launching phone call: $e');
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint("═════════════════════════════════════════");
  debugPrint("[FIREBASE] Initializing Firebase...");
  
  try {
    await Firebase.initializeApp();
    debugPrint("[FIREBASE] ✅ Firebase initialized successfully");
  } catch (e) {
    debugPrint("[FIREBASE] ❌ Firebase initialization failed: $e");
    rethrow;
  }
  
  debugPrint("[FIREBASE] Setting up background message handler...");
  // BUG FIX #2: Register background handler BEFORE runApp()
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  debugPrint("[FIREBASE] ✅ Background handler registered");
  
  debugPrint("[AUTH] Checking session...");
  // Check if user is already logged in
  final isLoggedIn = await LoginApi.checkSession();
  debugPrint("[AUTH] Session check result: isLoggedIn=$isLoggedIn");
  
  debugPrint("═════════════════════════════════════════");
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Homegenie Call App",
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userController = TextEditingController();
  final passController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    final result = await LoginApi.login(
      userController.text.trim(),
      passController.text.trim(),
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (result["success"] == true) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Login Failed")),
      );
    }
  }

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Homegenie Call App"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 50),
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : login,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("LOGIN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String token = "";
  List<Map<String, dynamic>> opportunities = [];
  bool isLoading = true;
  DateTime? pausedUntil;
  Timer? _pauseTimer;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  String? _lastLeadCallKey;
  DateTime? _lastLeadCallAt;
  DateTime? _lastPushReceivedAt;
  String _lastPushSource = "-";
  String _lastPushAction = "-";
  int _pushReceivedCount = 0;
  Map<String, dynamic>? _lastPushRaw;
  Map<String, dynamic>? _lastPushNormalized;
  final CallQueue callQueue = CallQueue();

  bool get isCallFlowPaused {
    if (pausedUntil == null) return false;
    return DateTime.now().isBefore(pausedUntil!);
  }

  @override
  void initState() {
    super.initState();
    getFcmToken();
    _initializeNotifications();
    _listenForTokenRefresh();
    fetchOpportunities();
  }

  Future<void> _initializeNotifications() async {
    debugPrint("[INIT] Starting notification initialization...");
    
    _notificationSub?.cancel();
    _notificationSub =
        NotificationService.notificationStream.stream.listen((data) {
          debugPrint("[STREAM] Notification stream received: $data");
          _handleIncomingLeadCall(data, source: "notification_stream");
        });

    // Initialize notification service
    await NotificationService().initialize();
    debugPrint("[INIT] NotificationService initialized");
    
    debugPrint("[INIT] ✅ Notification initialization complete");
  }

  Future<void> getFcmToken() async {
    final messaging = FirebaseMessaging.instance;

    debugPrint("═════════════════════════════════════════");
    debugPrint("[FCM] Starting FCM initialization...");
    
    // Request permissions
    debugPrint("[FCM] Requesting notification permissions...");
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint("[FCM] Permission status: ${settings.authorizationStatus}");
    debugPrint("[FCM] Authorization status details:");
    debugPrint("     - isEnabled: ${settings.authorizationStatus == AuthorizationStatus.authorized}");
    debugPrint("     - isSilent: ${settings.authorizationStatus == AuthorizationStatus.provisional}");
    debugPrint("     - isDenied: ${settings.authorizationStatus == AuthorizationStatus.denied}");

    // Get token
    debugPrint("[FCM] Getting FCM token...");
    final fcmToken = await messaging.getToken();

    debugPrint("═════════════════════════════════════════");
    debugPrint("FCM TOKEN => $fcmToken");
    debugPrint("Token length: ${(fcmToken ?? "").length}");

    if (!mounted) return;

    setState(() {
      token = fcmToken ?? "";
    });

    if ((fcmToken ?? "").isNotEmpty) {
      debugPrint("📱 Registering device with token...");
      final registerResult = await DeviceApi.registerDevice(fcmToken!);
      debugPrint("REGISTER DEVICE RESULT => $registerResult");
      
      if (registerResult["success"] != true) {
        debugPrint("❌ Device registration failed: ${registerResult['message']}");
      } else {
        debugPrint("✅ Device registered successfully");
      }
    } else {
      debugPrint("❌ FCM Token is empty!");
    }
    debugPrint("═════════════════════════════════════════");
  }

  void _listenForTokenRefresh() {
    debugPrint("[FCM] Setting up token refresh listener...");
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      refreshedToken,
    ) async {
      debugPrint("[FCM] 🔄 Token refreshed! New token: $refreshedToken");
      if (!mounted) return;
      setState(() {
        token = refreshedToken;
      });
      final registerResult = await DeviceApi.registerDevice(refreshedToken);
      debugPrint("REGISTER REFRESHED TOKEN => $registerResult");
    });
    debugPrint("[FCM] ✅ Token refresh listener set up");
  }

  Future<void> fetchOpportunities() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    final result = await OpportunitiesApi.getOpportunities();

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (result["success"] == true) {
        opportunities = List<Map<String, dynamic>>.from(
          result["opportunities"] ?? [],
        );
      } else {
        opportunities = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result["message"] ?? "Failed to fetch opportunities"),
          ),
        );
      }
    });
  }

  void _handleIncomingLeadCall(
    Map<String, dynamic> data, {
    String source = "unknown",
  }) {
    debugPrint("========== HANDLE INCOMING LEAD CALL ==========");
    debugPrint("Source: $source");
    debugPrint("Raw data: $data");
    debugPrint("Is paused: $isCallFlowPaused");
    debugPrint("Queue length: ${callQueue.length}");
    
    if (!mounted) {
      debugPrint("❌ Not mounted, ignoring");
      return;
    }

    final normalized = NotificationService.normalizeLeadCallPayload(data);
    debugPrint("Normalized: $normalized");
    
    setState(() {
      _pushReceivedCount++;
      _lastPushReceivedAt = DateTime.now();
      _lastPushSource = source;
      _lastPushRaw = Map<String, dynamic>.from(data);
      _lastPushNormalized = normalized != null
          ? Map<String, dynamic>.from(normalized)
          : null;
    });

    if (normalized == null) {
      debugPrint("❌ Lead payload ignored after normalize => $data");
      setState(() {
        _lastPushAction = "ignored_invalid_payload";
      });
      return;
    }
    
    if (_isDuplicateLeadCall(normalized)) {
      debugPrint("❌ Duplicate call detected");
      setState(() {
        _lastPushAction = "ignored_duplicate";
      });
      return;
    }

    if (isCallFlowPaused) {
      debugPrint("⏸️ Call flow is paused. Adding to queue...");
      setState(() {
        callQueue.addItem(CallQueueItem.fromMap(normalized));
        _lastPushAction = "queued_paused_flow";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Call from ${normalized["customer_name"] ?? "Unknown"} queued',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      debugPrint("========== END INCOMING LEAD CALL ==========");
      return;
    }

    debugPrint("✅ Navigating to LeadCallScreen");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadCallScreen(data: normalized),
      ),
    );
    setState(() {
      _lastPushAction = "navigated_to_lead_call_screen";
    });
    debugPrint("========== END INCOMING LEAD CALL ==========");
  }

  void _showCallQueueScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallQueueScreen(
          callQueue: callQueue,
          onCancel: (index) {
            setState(() {
              callQueue.remove(index);
            });
            debugPrint("[QUEUE] Canceled call at index $index");
          },
          onClearAll: () {
            setState(() {
              callQueue.clearAll();
            });
            debugPrint("[QUEUE] Cleared all calls");
          },
        ),
      ),
    ).then((selectedIndex) {
      if (selectedIndex != null && selectedIndex is int) {
        // User selected a call to make
        final callItem = callQueue.get(selectedIndex);
        if (callItem != null) {
          callQueue.remove(selectedIndex);
          setState(() {});
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeadCallScreen(data: callItem.toMap()),
            ),
          );
        }
      }
    });
  }

  bool _isDuplicateLeadCall(Map<String, dynamic> data) {
    final key =
        '${data["docname"]}_${data["mobile_no"]}_${data["customer_name"]}';
    final now = DateTime.now();
    if (_lastLeadCallKey == key &&
        _lastLeadCallAt != null &&
        now.difference(_lastLeadCallAt!).inSeconds <= 3) {
      return true;
    }
    _lastLeadCallKey = key;
    _lastLeadCallAt = now;
    return false;
  }

  Future<void> toggleCallFlow() async {
    if (isCallFlowPaused) {
      // Resume call flow
      _pauseTimer?.cancel();
      setState(() {
        pausedUntil = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Call flow resumed")),
      );
      
      // Optionally process queued calls
      if (callQueue.isNotEmpty) {
        _showQueueProcessingOption();
      }
    } else {
      // Pause call flow for a selected interval
      final minutes = await _selectPauseMinutes();
      if (minutes == null || minutes <= 0 || !mounted) return;

      final until = DateTime.now().add(Duration(minutes: minutes));
      _pauseTimer?.cancel();
      _pauseTimer = Timer(Duration(minutes: minutes), () {
        if (!mounted) return;
        setState(() {
          pausedUntil = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pause interval ended. Call flow resumed")),
        );
        if (callQueue.isNotEmpty) {
          _showQueueProcessingOption();
        }
      });

      setState(() {
        pausedUntil = until;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Call flow paused for $minutes minute(s)")),
      );
    }
  }

  Future<int?> _selectPauseMinutes() async {
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pause Call Flow"),
        content: const Text("Select pause interval"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 5),
            child: const Text("5 min"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 15),
            child: const Text("15 min"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 30),
            child: const Text("30 min"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showQueueProcessingOption() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Process Queued Calls?"),
        content: Text(
          "You have ${callQueue.length} call(s) in the queue.\nWould you like to process them?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processFirstQueuedCall();
            },
            child: const Text("Process"),
          ),
        ],
      ),
    );
  }

  void _processFirstQueuedCall() {
    final call = callQueue.removeFirst();
    if (call != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeadCallScreen(data: call.toMap()),
        ),
      );
    }
  }

  Future<void> logout() async {
    await LoginApi.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _tokenRefreshSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Opportunities"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: Column(
        children: [
          // Call Flow Status Bar
          Container(
            color: isCallFlowPaused ? Colors.red.shade100 : Colors.green.shade100,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCallFlowPaused
                      ? "📴 Call Flow Paused"
                      : "📱 Call Flow Active",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCallFlowPaused ? Colors.red : Colors.green,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: toggleCallFlow,
                  icon: Icon(
                    isCallFlowPaused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(isCallFlowPaused ? "Resume" : "Pause"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCallFlowPaused ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (isCallFlowPaused && pausedUntil != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Text(
                "Paused until: ${pausedUntil!.toLocal().toString().split('.')[0]}",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Push Debug",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _lastPushReceivedAt = null;
                              _lastPushSource = "-";
                              _lastPushAction = "-";
                              _lastPushRaw = null;
                              _lastPushNormalized = null;
                              _pushReceivedCount = 0;
                            });
                          },
                          child: const Text("Clear"),
                        ),
                      ],
                    ),
                    Text("Count: $_pushReceivedCount"),
                    Text(
                      "Last At: ${_lastPushReceivedAt?.toLocal().toString().split('.').first ?? '-'}",
                    ),
                    Text("Source: $_lastPushSource"),
                    Text("Action: $_lastPushAction"),
                    const SizedBox(height: 6),
                    Text(
                      "Raw: ${_lastPushRaw == null ? '-' : jsonEncode(_lastPushRaw)}",
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Normalized: ${_lastPushNormalized == null ? '-' : jsonEncode(_lastPushNormalized)}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Call Queue Section
          if (callQueue.isNotEmpty)
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hourglass_empty, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            "Queued Calls: ${callQueue.length}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _processFirstQueuedCall,
                            icon: const Icon(Icons.phone),
                            label: const Text("Process"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                callQueue.clearAll();
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text("Clear"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: callQueue.length,
                      itemBuilder: (context, index) {
                        final call = callQueue.get(index);
                        if (call == null) return const SizedBox.shrink();
                        return Card(
                          margin: const EdgeInsets.only(right: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  call.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  call.mobileNo,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  call.formattedTime,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // Opportunities List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : opportunities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inbox,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No opportunities assigned",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: fetchOpportunities,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Refresh"),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchOpportunities,
                        child: ListView.builder(
                          itemCount: opportunities.length,
                          itemBuilder: (context, index) {
                            final opp = opportunities[index];
                            return OpportunityCard(
                              opportunity: opp,
                              onPause: () async {
                                final result = await OpportunitiesApi.pauseCall(
                                  opp["name"] ?? "",
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result["message"] ??
                                          (result["success"]
                                              ? "Call paused"
                                              : "Failed to pause"),
                                    ),
                                  ),
                                );
                                if (result["success"] == true) {
                                  fetchOpportunities();
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (callQueue.isNotEmpty)
            FloatingActionButton(
              onPressed: () => _showCallQueueScreen(),
              tooltip: "Call Queue (${callQueue.length})",
              heroTag: "queue_btn",
              backgroundColor: Colors.orange,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  const Icon(Icons.queue_music),
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "${callQueue.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: fetchOpportunities,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
            heroTag: "refresh_btn",
          ),
        ],
      ),
    );
  }
}

class OpportunityCard extends StatelessWidget {
  final Map<String, dynamic> opportunity;
  final VoidCallback onPause;

  const OpportunityCard({
    super.key,
    required this.opportunity,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final customerName = opportunity["customer_name"] ?? "N/A";
    final mobileNo = opportunity["mobile_no"] ?? "N/A";
    final oppName = opportunity["name"] ?? "N/A";
    final amount = opportunity["amount"] ?? "N/A";
    final stage = opportunity["stage"] ?? "N/A";

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mobileNo,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_in_talk, color: Colors.green),
                  onPressed: () {
                    // Trigger call directly
                    _makeCall(context, mobileNo);
                  },
                  tooltip: "Call now",
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Opportunity",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      oppName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Amount",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      amount.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Stage",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      stage,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause),
                  label: const Text("Pause"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == "N/A") return;

    final phonePermission = await Permission.phone.request();

    if (!phonePermission.isGranted) {
      debugPrint("PHONE PERMISSION NOT GRANTED");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone permission not granted")),
        );
      }
      return;
    }

    final success = await launchPhoneCall(phoneNumber);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to launch phone app")),
      );
    }
  }
}

class LeadCallScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const LeadCallScreen({
    super.key,
    required this.data,
  });

  @override
  State<LeadCallScreen> createState() => _LeadCallScreenState();
}

class _LeadCallScreenState extends State<LeadCallScreen> {
  int countdown = 5;
  Timer? timer;
  bool callTriggered = false;
  DateTime? callStartTime;
  Timer? callDurationTimer;
  
  // Call status tracking
  final CallStatusService _callStatusService = CallStatusService();
  bool _callConnected = false;
  bool _completionDialogShown = false;
  int _actualCallDuration = 0;

  @override
  void initState() {
    super.initState();
    _initCallStatusTracking();
    startCountdown();
  }

  /// Initialize call status tracking to detect real call events
  Future<void> _initCallStatusTracking() async {
    try {
      await _callStatusService.initialize();
      await _callStatusService.startMonitoring();

      // Listen to status changes
      _callStatusService.addStatusListener((callInfo) {
        if (!mounted) return;

        debugPrint("[CALL] Status: ${callInfo.status}, Duration: ${callInfo.durationSeconds}s");

        // Track when call connects
        if (callInfo.status == CallStatus.connected) {
          _callConnected = true;
          _actualCallDuration = callInfo.durationSeconds;
          if (mounted) setState(() {});
        }
      });

      // Listen for call end - this is when we show completion dialog
      _callStatusService.addCallEndListener((callInfo) {
        if (!mounted) return;

        debugPrint("[CALL] 📴 Call ended. Actual duration: ${callInfo.durationSeconds}s");
        _actualCallDuration = callInfo.durationSeconds;

        // Show completion dialog ONLY when call actually ends
        if (_callConnected && !_completionDialogShown) {
          _showCallCompletionDialog();
        }
      });
    } catch (e) {
      debugPrint("[CALL] ⚠️ Error initializing call status tracking: $e");
    }
  }

  void startCountdown() {
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) {
        if (countdown <= 1) {
          t.cancel();
          makeCall();
        } else {
          if (!mounted) return;
          setState(() {
            countdown--;
          });
        }
      },
    );
  }

  void _startCallDurationTracking() {
    debugPrint("[CALL] Starting to track call duration");
    callStartTime = DateTime.now();
  }

  Duration _getCallDuration() {
    // Use the actual duration from call status detection if available
    if (_actualCallDuration > 0) {
      return Duration(seconds: _actualCallDuration);
    }
    // Fallback to time-based calculation
    if (callStartTime == null) return Duration.zero;
    return DateTime.now().difference(callStartTime!);
  }

  Future<void> _showCallCompletionDialog() async {
    debugPrint("[CALL] Showing call completion dialog");
    
    if (!mounted) return;
    
    // Prevent showing dialog multiple times
    if (_completionDialogShown) return;
    _completionDialogShown = true;

    final customerName = widget.data["customer_name"]?.toString() ?? "Unknown";
    final doctype = widget.data["doctype"]?.toString() ?? "Lead";
    final docname = widget.data["docname"]?.toString() ?? "";
    final mobileNo = widget.data["mobile_no"]?.toString() ?? "";

    // Stop tracking duration
    callDurationTimer?.cancel();
    final callDuration = _getCallDuration();
    
    debugPrint("[CALL] Final call duration: ${callDuration.inSeconds} seconds");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CallCompletionDialog(
        doctype: doctype,
        docname: docname,
        customerName: customerName,
        mobileNo: mobileNo,
        callDuration: callDuration,
      ),
    ).then((value) {
      // Dialog closed
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> makeCall() async {
    if (callTriggered) return;

    callTriggered = true;
    timer?.cancel();

    final mobileNo = widget.data["mobile_no"]?.toString() ?? "";
    final customerName = widget.data["customer_name"]?.toString() ?? "Unknown";
    final doctype = widget.data["doctype"]?.toString() ?? "Lead";
    final docname = widget.data["docname"]?.toString() ?? "";

    if (mobileNo.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number not available")),
        );
      }
      return;
    }

    // Log call initiation
    final initiatedAt = DateTime.now();
    debugPrint("[CALL] 📞 Initiating call to: $customerName ($mobileNo)");
    
    try {
      // Log to backend
      await CallLogApi.logCallInitiation(
        doctype: doctype,
        docname: docname,
        customerName: customerName,
        mobileNo: mobileNo,
        initiatedAt: initiatedAt,
      );
      debugPrint("[CALL] ✅ Call logged to backend");
    } catch (e) {
      debugPrint("[CALL] ⚠️ Failed to log call: $e");
    }

    // Auto-dial directly without showing dialer
    debugPrint("[CALL] 🚀 Using AutoDialer to initiate call directly");
    
    // Start tracking call duration
    _startCallDurationTracking();
    
    final success = await AutoDialer.autoCall(mobileNo);

    if (!success) {
      debugPrint("[CALL] ❌ AutoDialer failed, trying fallback");
      // Try opening dialer as fallback
      final fallbackSuccess = await AutoDialer.openDialer(mobileNo);
      
      if (!fallbackSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to initiate call")),
        );
        
        // Log error
        await CallLogApi.logCallError(
          doctype: doctype,
          docname: docname,
          customerName: customerName,
          mobileNo: mobileNo,
          errorMessage: "Failed to initiate auto call - both AutoDialer and fallback failed",
        );
      }
    } else {
      debugPrint("[CALL] ✅ Call initiated successfully via AutoDialer");
    }

    // NOTE: Completion dialog now shows automatically when the call actually ends
    // (detected by CallStatusService). No fixed delay needed.
    // The _callStatusService.addCallEndListener handles showing the dialog.
    debugPrint("[CALL] ⏳ Waiting for call to end to show completion dialog...");

    // SAFETY FALLBACK: If call detection fails (no events received within 5 minutes),
    // show the completion dialog anyway so the user isn't stuck.
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted && !_completionDialogShown) {
        debugPrint("[CALL] ⚠️ Safety fallback: showing completion dialog after timeout");
        _showCallCompletionDialog();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    callDurationTimer?.cancel();
    try {
      _callStatusService.stopMonitoring();
    } catch (e) {
      debugPrint("[CALL] Error stopping call status service: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        timer?.cancel();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Incoming Call"),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.call,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                widget.data["customer_name"] ?? "Incoming Call",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.data["mobile_no"] ?? "Unknown",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              if (!callTriggered)
                Text(
                  "Calling in $countdown...",
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Text(
                  "Launching call...",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  timer?.cancel();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
