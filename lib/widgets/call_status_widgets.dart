import 'package:flutter/material.dart';
import 'dart:async';
import 'call_status_service_production.dart';

/// Production-ready Call Status Display Widget
class CallStatusDisplay extends StatefulWidget {
  final CallInfo? callInfo;
  final VoidCallback? onHangup;

  const CallStatusDisplay({
    Key? key,
    this.callInfo,
    this.onHangup,
  }) : super(key: key);

  @override
  State<CallStatusDisplay> createState() => _CallStatusDisplayState();
}

class _CallStatusDisplayState extends State<CallStatusDisplay> {
  late Timer _durationTimer;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    
    // Safety check: ensure callInfo is not null and status is connected
    if (widget.callInfo?.status == CallStatus.connected) {
      _startDurationTimer();
    }
  }

  @override
  void didUpdateWidget(CallStatusDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    try {
      // Check if status changed to connected
      if (widget.callInfo?.status == CallStatus.connected && !_isTimerRunning) {
        _startDurationTimer();
      } 
      // Check if status changed from connected to something else
      else if (widget.callInfo?.status != CallStatus.connected && _isTimerRunning) {
        _stopDurationTimer();
      }
    } catch (e) {
      debugPrint('[CallStatusDisplay] Error in didUpdateWidget: $e');
    }
  }

  void _startDurationTimer() {
    try {
      if (_isTimerRunning) {
        debugPrint('[CallStatusDisplay] ⚠️ Timer already running');
        return;
      }

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        try {
          if (mounted) {
            setState(() {
              _elapsedSeconds++;
            });
          } else {
            timer.cancel();
            _isTimerRunning = false;
          }
        } catch (e) {
          debugPrint('[CallStatusDisplay] Error in timer callback: $e');
          timer.cancel();
          _isTimerRunning = false;
        }
      });

      _isTimerRunning = true;
      debugPrint('[CallStatusDisplay] ✅ Duration timer started');
    } catch (e) {
      debugPrint('[CallStatusDisplay] ❌ Error starting timer: $e');
      _isTimerRunning = false;
    }
  }

  void _stopDurationTimer() {
    try {
      if (_isTimerRunning && _durationTimer.isActive) {
        _durationTimer.cancel();
        _isTimerRunning = false;
        debugPrint('[CallStatusDisplay] ✅ Duration timer stopped');
      }
    } catch (e) {
      debugPrint('[CallStatusDisplay] Error stopping timer: $e');
      _isTimerRunning = false;
    }
  }

  String _formatDuration(int seconds) {
    try {
      // Validate seconds
      if (seconds < 0) {
        return '00:00';
      }

      int minutes = seconds ~/ 60;
      int secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('[CallStatusDisplay] Error formatting duration: $e');
      return '00:00';
    }
  }

  @override
  void dispose() {
    try {
      _stopDurationTimer();
    } catch (e) {
      debugPrint('[CallStatusDisplay] Error in dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Null safety check
      if (widget.callInfo == null) {
        return const SizedBox.shrink();
      }

      final callInfo = widget.callInfo!;
      
      // Validate call info
      if (callInfo.phoneNumber.isEmpty) {
        return const Center(child: Text('Invalid call info'));
      }

      final statusColor = CallStatusService.getStatusColor(callInfo.status);
      final statusText = CallStatusService.getStatusText(callInfo.status);
      final duration = callInfo.status == CallStatus.connected 
          ? _formatDuration(_elapsedSeconds)
          : callInfo.getFormattedDuration();

      return SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor.withOpacity(0.3), statusColor.withOpacity(0.1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phone Number
              Text(
                callInfo.phoneNumber,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (callInfo.status == CallStatus.ringing || 
                        callInfo.status == CallStatus.connected)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildPulseAnimation(statusColor),
                      ),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Duration
              Text(
                duration,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ) ?? TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: statusColor),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (callInfo.status == CallStatus.ringing || 
                  callInfo.status == CallStatus.connected)
                ElevatedButton.icon(
                  onPressed: () {
                    try {
                      widget.onHangup?.call();
                    } catch (e) {
                      debugPrint('[CallStatusDisplay] Error in hangup: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.call_end),
                  label: const Text('End Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),

              // Call Ended Message
              if (callInfo.status == CallStatus.disconnected)
                Column(
                  children: [
                    const Text('Call Ended', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        try {
                          Navigator.pop(context);
                        } catch (e) {
                          debugPrint('[CallStatusDisplay] Error closing: $e');
                        }
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallStatusDisplay] Error in build: $e');
      return Center(child: Text('Error displaying call: $e'));
    }
  }

  Widget _buildPulseAnimation(Color color) {
    try {
      return SizedBox(
        width: 12,
        height: 12,
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallStatusDisplay] Error building pulse: $e');
      return const SizedBox.shrink();
    }
  }
}

/// Call Status Indicator Widget (Small badge for lead cards)
class CallStatusIndicator extends StatelessWidget {
  final CallStatus? status;
  final int durationSeconds;

  const CallStatusIndicator({
    Key? key,
    this.status,
    this.durationSeconds = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      // Null safety check
      if (status == null) {
        return const SizedBox.shrink();
      }

      // Validate duration
      final validDuration = durationSeconds < 0 ? 0 : durationSeconds;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CallStatusService.getStatusColor(status!),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CallStatusService.getStatusText(status!),
            style: TextStyle(
              color: CallStatusService.getStatusColor(status!),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (validDuration > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${(validDuration ~/ 60).toString().padLeft(2, '0')}:${(validDuration % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      );
    } catch (e) {
      debugPrint('[CallStatusIndicator] Error in build: $e');
      return const SizedBox.shrink();
    }
  }
}

/// Call Status Monitor Widget for integration in screens
class CallStatusMonitor extends StatefulWidget {
  final String? leadName;
  final String? phoneNumber;
  final Widget? fallbackWidget;

  const CallStatusMonitor({
    Key? key,
    this.leadName,
    this.phoneNumber,
    this.fallbackWidget,
  }) : super(key: key);

  @override
  State<CallStatusMonitor> createState() => _CallStatusMonitorState();
}

class _CallStatusMonitorState extends State<CallStatusMonitor> {
  late CallStatusService _callStatusService;
  CallInfo? _currentCall;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      _callStatusService = CallStatusService();
      
      // Initialize service
      final initialized = await _callStatusService.initialize();
      if (!initialized) {
        debugPrint('[CallStatusMonitor] Failed to initialize service');
        return;
      }

      // Add listeners
      _callStatusService.addStatusListener(_onCallStatusChanged);
      
      // Start monitoring
      final started = await _callStatusService.startMonitoring();
      if (!started) {
        debugPrint('[CallStatusMonitor] Failed to start monitoring');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[CallStatusMonitor] Error initializing service: $e');
    }
  }

  void _onCallStatusChanged(CallInfo callInfo) {
    try {
      if (mounted) {
        setState(() {
          _currentCall = callInfo;
        });
      }
    } catch (e) {
      debugPrint('[CallStatusMonitor] Error updating call status: $e');
    }
  }

  @override
  void dispose() {
    try {
      _callStatusService.removeStatusListener(_onCallStatusChanged);
      _callStatusService.stopMonitoring();
    } catch (e) {
      debugPrint('[CallStatusMonitor] Error in dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (!_isInitialized) {
        return widget.fallbackWidget ?? const SizedBox.shrink();
      }

      // Check if we have a matching call
      if (_currentCall == null || 
          (widget.phoneNumber != null && 
           _currentCall!.phoneNumber != widget.phoneNumber)) {
        return widget.fallbackWidget ?? const SizedBox.shrink();
      }

      return CallStatusDisplay(
        callInfo: _currentCall,
        onHangup: () {
          try {
            Navigator.pop(context);
          } catch (e) {
            debugPrint('[CallStatusMonitor] Error in hangup: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('[CallStatusMonitor] Error in build: $e');
      return widget.fallbackWidget ?? 
        Center(child: Text('Error: ${e.toString()}'));
    }
  }
}
