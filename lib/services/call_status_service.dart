import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Call Status Enum
enum CallStatus {
  idle,
  ringing,
  connected,
  disconnected,
  onHold,
  failed,
}

/// Call Information Model with complete null safety
class CallInfo {
  final String phoneNumber;
  final String callerId;
  final CallStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isIncoming;

  CallInfo({
    required this.phoneNumber,
    required this.callerId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.isIncoming = false,
  }) {
    // Validate phoneNumber is not empty
    if (phoneNumber.trim().isEmpty) {
      throw ArgumentError('Phone number cannot be empty');
    }
    // Validate callerId is not empty
    if (callerId.trim().isEmpty) {
      throw ArgumentError('Caller ID cannot be empty');
    }
  }

  /// Get formatted duration safely
  String getFormattedDuration() {
    try {
      int seconds = durationSeconds;
      
      // Validate durationSeconds is not negative
      if (seconds < 0) {
        seconds = 0;
      }

      int hours = seconds ~/ 3600;
      int minutes = (seconds % 3600) ~/ 60;
      int secs = seconds % 60;

      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('[CallInfo] Error formatting duration: $e');
      return '00:00';
    }
  }

  @override
  String toString() => 
    'CallInfo(number: $phoneNumber, status: $status, duration: ${getFormattedDuration()}, '
    'startTime: $startTime, endTime: $endTime)';
}

/// Production-ready Call Status Tracker Service
class CallStatusService {
  static const platform = MethodChannel('com.leadcalling/call_status');
  
  static final CallStatusService _instance = CallStatusService._internal();
  
  factory CallStatusService() {
    return _instance;
  }
  
  CallStatusService._internal();

  // Private state
  final List<Function(CallInfo)> _statusListeners = [];
  final List<Function(CallInfo)> _callEndListeners = [];
  CallInfo? _currentCallInfo;
  bool _isInitialized = false;
  bool _isMonitoring = false;

  // Getters with null safety
  CallInfo? get currentCallInfo => _currentCallInfo;
  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;

  /// Initialize the service safely
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        debugPrint('[CallStatusService] Already initialized, skipping...');
        return true;
      }

      platform.setMethodCallHandler(_handleMethodCall);
      _isInitialized = true;
      debugPrint('[CallStatusService] ✅ Initialized successfully');
      return true;
    } on PlatformException catch (e) {
      debugPrint('[CallStatusService] ❌ PlatformException during init: ${e.code} - ${e.message}');
      _isInitialized = false;
      return false;
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Unexpected error during init: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Handle method calls from native code with comprehensive error checking
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      debugPrint('[CallStatusService] Received: ${call.method} - ${call.arguments}');

      // Validate arguments exist
      if (call.arguments == null) {
        debugPrint('[CallStatusService] ⚠️ Null arguments received for ${call.method}');
        return null;
      }

      switch (call.method) {
        case 'phone_state_changed':
          await _handlePhoneStateChanged(call.arguments);
          break;

        case 'call_state_update':
          await _handleCallStateUpdate(call.arguments);
          break;

        default:
          debugPrint('[CallStatusService] ⚠️ Unknown method: ${call.method}');
      }
    } on PlatformException catch (e) {
      debugPrint('[CallStatusService] ❌ PlatformException: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error handling method call: $e');
    }
  }

  /// Handle phone state changed safely
  Future<void> _handlePhoneStateChanged(dynamic args) async {
    try {
      if (args is! Map) {
        debugPrint('[CallStatusService] ⚠️ Invalid arguments type for phone_state_changed');
        return;
      }

      final Map<dynamic, dynamic> arguments = args as Map<dynamic, dynamic>;
      
      // Safely extract values with defaults
      final stateStr = arguments['state']?.toString() ?? 'UNKNOWN';
      final phoneNumber = arguments['number']?.toString() ?? 'Unknown';

      if (phoneNumber.isEmpty || phoneNumber == 'Unknown') {
        debugPrint('[CallStatusService] ⚠️ Empty or invalid phone number');
      }

      final status = _parseStatus(stateStr);
      debugPrint('[CallStatusService] State: $status, Phone: $phoneNumber');

      _updateCallStatus(status, phoneNumber);
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error handling phone state: $e');
    }
  }

  /// Handle call state update safely
  Future<void> _handleCallStateUpdate(dynamic args) async {
    try {
      if (args is! Map) {
        debugPrint('[CallStatusService] ⚠️ Invalid arguments type for call_state_update');
        return;
      }

      final Map<dynamic, dynamic> arguments = args as Map<dynamic, dynamic>;

      // Safely extract duration
      int duration = 0;
      try {
        final durationValue = arguments['duration'];
        if (durationValue is int) {
          duration = durationValue;
        } else if (durationValue is String) {
          duration = int.tryParse(durationValue) ?? 0;
        }
      } catch (e) {
        debugPrint('[CallStatusService] ⚠️ Error parsing duration: $e');
        duration = 0;
      }

      // Validate duration is not negative
      if (duration < 0) {
        debugPrint('[CallStatusService] ⚠️ Negative duration detected, setting to 0');
        duration = 0;
      }

      final stateStr = arguments['state']?.toString() ?? 'UNKNOWN';
      final status = _parseStatus(stateStr);

      _updateCallDuration(duration);
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error handling call state update: $e');
    }
  }

  /// Parse call status from string with fallback
  CallStatus _parseStatus(String? state) {
    try {
      if (state == null || state.isEmpty) {
        return CallStatus.idle;
      }

      switch (state.toUpperCase().trim()) {
        case 'RINGING':
        case 'INCOMING':
          return CallStatus.ringing;
        case 'OFFHOOK':
        case 'ACTIVE':
        case 'CONNECTED':
          return CallStatus.connected;
        case 'IDLE':
          return CallStatus.idle;
        case 'DISCONNECTED':
          return CallStatus.disconnected;
        case 'ON_HOLD':
          return CallStatus.onHold;
        case 'FAILED':
          return CallStatus.failed;
        default:
          debugPrint('[CallStatusService] ⚠️ Unknown status: $state');
          return CallStatus.idle;
      }
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error parsing status: $e');
      return CallStatus.idle;
    }
  }

  /// Update call status with comprehensive error handling
  void _updateCallStatus(CallStatus status, String phoneNumber) {
    try {
      // Validate phone number
      if (phoneNumber.trim().isEmpty) {
        debugPrint('[CallStatusService] ⚠️ Empty phone number, ignoring status update');
        return;
      }

      debugPrint('[CallStatusService] Status: $status, Phone: $phoneNumber');

      if (status == CallStatus.idle || status == CallStatus.disconnected) {
        // Call ended
        if (_currentCallInfo != null) {
          try {
            final endTime = DateTime.now();
            final duration = endTime.difference(_currentCallInfo!.startTime).inSeconds;

            // Validate duration
            final validDuration = duration < 0 ? 0 : duration;

            _currentCallInfo = CallInfo(
              phoneNumber: _currentCallInfo!.phoneNumber,
              callerId: _currentCallInfo!.callerId,
              status: status,
              startTime: _currentCallInfo!.startTime,
              endTime: endTime,
              durationSeconds: validDuration,
              isIncoming: _currentCallInfo!.isIncoming,
            );

            debugPrint('[CallStatusService] Call ended: ${_currentCallInfo!.getFormattedDuration()}');
            
            _notifyStatusListeners(_currentCallInfo!);
            _notifyCallEndListeners(_currentCallInfo!);
          } catch (e) {
            debugPrint('[CallStatusService] ❌ Error processing call end: $e');
          } finally {
            _currentCallInfo = null;
          }
        }
      } else if (status == CallStatus.ringing) {
        // Call starting
        try {
          _currentCallInfo = CallInfo(
            phoneNumber: phoneNumber,
            callerId: phoneNumber,
            status: status,
            startTime: DateTime.now(),
            isIncoming: false,
          );
          _notifyStatusListeners(_currentCallInfo!);
        } catch (e) {
          debugPrint('[CallStatusService] ❌ Error creating CallInfo for ringing: $e');
        }
      } else if (status == CallStatus.connected) {
        // Call active
        try {
          if (_currentCallInfo == null) {
            _currentCallInfo = CallInfo(
              phoneNumber: phoneNumber,
              callerId: phoneNumber,
              status: status,
              startTime: DateTime.now(),
              isIncoming: false,
            );
          } else {
            _currentCallInfo = CallInfo(
              phoneNumber: _currentCallInfo!.phoneNumber,
              callerId: _currentCallInfo!.callerId,
              status: status,
              startTime: _currentCallInfo!.startTime,
              isIncoming: _currentCallInfo!.isIncoming,
            );
          }
          _notifyStatusListeners(_currentCallInfo!);
        } catch (e) {
          debugPrint('[CallStatusService] ❌ Error creating CallInfo for connected: $e');
        }
      }
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Unexpected error in _updateCallStatus: $e');
    }
  }

  /// Update call duration with validation
  void _updateCallDuration(int durationSeconds) {
    try {
      // Validate duration
      if (durationSeconds < 0) {
        debugPrint('[CallStatusService] ⚠️ Negative duration $durationSeconds, ignoring');
        return;
      }

      if (_currentCallInfo != null && _currentCallInfo!.status == CallStatus.connected) {
        try {
          _currentCallInfo = CallInfo(
            phoneNumber: _currentCallInfo!.phoneNumber,
            callerId: _currentCallInfo!.callerId,
            status: _currentCallInfo!.status,
            startTime: _currentCallInfo!.startTime,
            durationSeconds: durationSeconds,
            isIncoming: _currentCallInfo!.isIncoming,
          );
          _notifyStatusListeners(_currentCallInfo!);
        } catch (e) {
          debugPrint('[CallStatusService] ❌ Error updating duration: $e');
        }
      }
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Unexpected error in _updateCallDuration: $e');
    }
  }

  /// Add status listener with validation
  void addStatusListener(Function(CallInfo)? listener) {
    try {
      if (listener == null) {
        debugPrint('[CallStatusService] ⚠️ Null listener provided, ignoring');
        return;
      }
      _statusListeners.add(listener);
      debugPrint('[CallStatusService] Status listener added (total: ${_statusListeners.length})');
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error adding listener: $e');
    }
  }

  /// Remove status listener safely
  void removeStatusListener(Function(CallInfo)? listener) {
    try {
      if (listener == null) {
        debugPrint('[CallStatusService] ⚠️ Null listener provided, ignoring');
        return;
      }
      _statusListeners.remove(listener);
      debugPrint('[CallStatusService] Status listener removed (total: ${_statusListeners.length})');
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error removing listener: $e');
    }
  }

  /// Add call end listener with validation
  void addCallEndListener(Function(CallInfo)? listener) {
    try {
      if (listener == null) {
        debugPrint('[CallStatusService] ⚠️ Null listener provided, ignoring');
        return;
      }
      _callEndListeners.add(listener);
      debugPrint('[CallStatusService] Call end listener added (total: ${_callEndListeners.length})');
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error adding call end listener: $e');
    }
  }

  /// Remove call end listener safely
  void removeCallEndListener(Function(CallInfo)? listener) {
    try {
      if (listener == null) {
        debugPrint('[CallStatusService] ⚠️ Null listener provided, ignoring');
        return;
      }
      _callEndListeners.remove(listener);
      debugPrint('[CallStatusService] Call end listener removed (total: ${_callEndListeners.length})');
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error removing call end listener: $e');
    }
  }

  /// Notify all status listeners safely
  void _notifyStatusListeners(CallInfo callInfo) {
    final listenersCount = _statusListeners.length;
    debugPrint('[CallStatusService] Notifying $listenersCount status listeners');

    for (int i = 0; i < _statusListeners.length; i++) {
      try {
        _statusListeners[i](callInfo);
      } catch (e) {
        debugPrint('[CallStatusService] ❌ Status listener[$i] error: $e');
        // Don't remove listener, just log the error
      }
    }
  }

  /// Notify all call end listeners safely
  void _notifyCallEndListeners(CallInfo callInfo) {
    final listenersCount = _callEndListeners.length;
    debugPrint('[CallStatusService] Notifying $listenersCount call end listeners');

    for (int i = 0; i < _callEndListeners.length; i++) {
      try {
        _callEndListeners[i](callInfo);
      } catch (e) {
        debugPrint('[CallStatusService] ❌ Call end listener[$i] error: $e');
        // Don't remove listener, just log the error
      }
    }
  }

  /// Start monitoring with comprehensive error handling
  Future<bool> startMonitoring() async {
    try {
      if (!_isInitialized) {
        debugPrint('[CallStatusService] ❌ Service not initialized, cannot start monitoring');
        return false;
      }

      if (_isMonitoring) {
        debugPrint('[CallStatusService] ⚠️ Already monitoring, skipping...');
        return true;
      }

      try {
        final result = await platform.invokeMethod<bool>('startCallMonitoring');
        _isMonitoring = result ?? false;
        
        if (_isMonitoring) {
          debugPrint('[CallStatusService] ✅ Monitoring started successfully');
        } else {
          debugPrint('[CallStatusService] ❌ Monitoring returned false');
        }
        return _isMonitoring;
      } on PlatformException catch (e) {
        debugPrint('[CallStatusService] ❌ PlatformException: ${e.code} - ${e.message}');
        _isMonitoring = false;
        return false;
      }
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error starting monitoring: $e');
      _isMonitoring = false;
      return false;
    }
  }

  /// Stop monitoring safely
  Future<bool> stopMonitoring() async {
    try {
      if (!_isMonitoring) {
        debugPrint('[CallStatusService] ⚠️ Not currently monitoring, skipping...');
        return true;
      }

      try {
        final result = await platform.invokeMethod<bool>('stopCallMonitoring');
        _isMonitoring = result == false;
        
        if (!_isMonitoring) {
          debugPrint('[CallStatusService] ✅ Monitoring stopped successfully');
        }
        return !_isMonitoring;
      } on PlatformException catch (e) {
        debugPrint('[CallStatusService] ❌ PlatformException: ${e.code} - ${e.message}');
        return false;
      }
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error stopping monitoring: $e');
      return false;
    }
  }

  /// Get status color with fallback
  static Color getStatusColor(CallStatus status) {
    try {
      switch (status) {
        case CallStatus.ringing:
          return Colors.orange;
        case CallStatus.connected:
          return Colors.green;
        case CallStatus.disconnected:
          return Colors.red;
        case CallStatus.idle:
          return Colors.grey;
        case CallStatus.onHold:
          return Colors.amber;
        case CallStatus.failed:
          return Colors.red;
        default:
          return Colors.grey;
      }
    } catch (e) {
      debugPrint('[CallStatusService] Error getting status color: $e');
      return Colors.grey;
    }
  }

  /// Get status text with fallback
  static String getStatusText(CallStatus status) {
    try {
      switch (status) {
        case CallStatus.ringing:
          return 'Ringing...';
        case CallStatus.connected:
          return 'Connected';
        case CallStatus.disconnected:
          return 'Disconnected';
        case CallStatus.idle:
          return 'Idle';
        case CallStatus.onHold:
          return 'On Hold';
        case CallStatus.failed:
          return 'Failed';
        default:
          return 'Unknown';
      }
    } catch (e) {
      debugPrint('[CallStatusService] Error getting status text: $e');
      return 'Unknown';
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await stopMonitoring();
      _statusListeners.clear();
      _callEndListeners.clear();
      _currentCallInfo = null;
      _isInitialized = false;
      debugPrint('[CallStatusService] ✅ Disposed successfully');
    } catch (e) {
      debugPrint('[CallStatusService] ❌ Error disposing: $e');
    }
  }
}
