// File: android/app/src/main/kotlin/com/example/lead_calling/MainActivity.kt
// PRODUCTION VERSION WITH COMPREHENSIVE ERROR HANDLING

package com.example.lead_calling

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.IntentFilter
import android.content.Context
import android.telephony.TelephonyManager
import android.util.Log
import java.lang.Exception

class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.leadcalling/call_status"
    private val TAG = "CallMonitoring"
    
    private var callStatusReceiver: CallStatusReceiver? = null
    private var isMonitoring = false
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            // Create MethodChannel
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            
            if (methodChannel == null) {
                Log.e(TAG, "❌ Failed to create MethodChannel")
                return
            }

            // Set method call handler
            methodChannel?.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startCallMonitoring" -> {
                            Log.d(TAG, "📞 startCallMonitoring called")
                            val success = startCallMonitoring()
                            result.success(success)
                        }
                        "stopCallMonitoring" -> {
                            Log.d(TAG, "📞 stopCallMonitoring called")
                            val success = stopCallMonitoring()
                            result.success(success)
                        }
                        else -> {
                            Log.w(TAG, "⚠️ Unknown method: ${call.method}")
                            result.notImplemented()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error in method call handler: ${e.message}", e)
                    result.error("ERROR", e.message, null)
                }
            }

            // Initialize call status manager with method channel
            try {
                CallStatusManager.setMethodChannel(methodChannel!!)
                Log.d(TAG, "✅ CallStatusManager initialized with MethodChannel")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error initializing CallStatusManager: ${e.message}", e)
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in configureFlutterEngine: ${e.message}", e)
        }
    }

    /// Start call monitoring with error handling
    private fun startCallMonitoring(): Boolean {
        return try {
            if (isMonitoring) {
                Log.w(TAG, "⚠️ Already monitoring, returning true")
                return true
            }

            // Check if receiver is already created
            if (callStatusReceiver != null) {
                Log.w(TAG, "⚠️ Receiver already exists")
                return true
            }

            // Create broadcast receiver
            callStatusReceiver = CallStatusReceiver()
            if (callStatusReceiver == null) {
                Log.e(TAG, "❌ Failed to create CallStatusReceiver")
                return false
            }

            // Create intent filter
            val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)

            // Register receiver with error handling
            try {
                registerReceiver(callStatusReceiver, filter, Context.RECEIVER_EXPORTED)
                isMonitoring = true
                Log.d(TAG, "✅ Call monitoring started successfully")
                true
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error registering receiver: ${e.message}", e)
                callStatusReceiver = null
                isMonitoring = false
                false
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error in startCallMonitoring: ${e.message}", e)
            isMonitoring = false
            false
        }
    }

    /// Stop call monitoring with error handling
    private fun stopCallMonitoring(): Boolean {
        return try {
            if (!isMonitoring) {
                Log.w(TAG, "⚠️ Not currently monitoring")
                return true
            }

            if (callStatusReceiver == null) {
                Log.w(TAG, "⚠️ Receiver is null, setting monitoring to false")
                isMonitoring = false
                return true
            }

            try {
                unregisterReceiver(callStatusReceiver)
                isMonitoring = false
                callStatusReceiver = null
                Log.d(TAG, "✅ Call monitoring stopped successfully")
                true
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error unregistering receiver: ${e.message}", e)
                isMonitoring = false
                callStatusReceiver = null
                false
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error in stopCallMonitoring: ${e.message}", e)
            isMonitoring = false
            false
        }
    }

    override fun onDestroy() {
        try {
            // Clean up monitoring
            if (isMonitoring) {
                stopCallMonitoring()
            }

            // Clean up method channel
            methodChannel = null

            Log.d(TAG, "✅ MainActivity destroyed")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onDestroy: ${e.message}", e)
        } finally {
            super.onDestroy()
        }
    }
}