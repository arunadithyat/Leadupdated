// Example: How to use the Call Status Tracking Service
// Copy this into your main.dart or use as reference

import 'package:flutter/material.dart';
import 'services/call_status_service.dart';
import 'widgets/call_status_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize call status service
  try {
    final callStatusService = CallStatusService();
    final initialized = await callStatusService.initialize();
    
    if (initialized) {
      debugPrint('✅ CallStatusService initialized');
      
      // Start monitoring
      final started = await callStatusService.startMonitoring();
      if (started) {
        debugPrint('✅ Call monitoring started');
      } else {
        debugPrint('⚠️ Failed to start call monitoring');
      }
    } else {
      debugPrint('❌ Failed to initialize CallStatusService');
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
      body: _currentCall != null
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
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No active call'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      // Test: Show example of how to use call status
                      _showCallStatusExample();
                    },
                    child: const Text('Test Call Status'),
                  ),
                ],
              ),
            ),
    );
  }

  void _showCallStatusExample() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Make a test call to see call status updates here. '
          'You can use your device dialer to call another number.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }
}
