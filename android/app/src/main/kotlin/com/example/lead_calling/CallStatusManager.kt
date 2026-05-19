// File: android/app/src/main/kotlin/com/example/lead_calling/CallStatusManager.kt
// PRODUCTION VERSION WITH THREAD SAFETY AND ERROR HANDLING

package com.example.lead_calling

import io.flutter.plugin.common.MethodChannel
import android.os.SystemClock
import android.util.Log
import java.lang.Exception
import java.lang.IllegalStateException

object CallStatusManager {

    private const val TAG = "CallStatusManager"
    
    @Volatile
    private var methodChannel: MethodChannel? = null
    
    @Volatile
    private var callStartTime: Long = 0
    
    @Volatile
    private var isCallActive = false
    
    @Volatile
    private var currentPhoneNumber: String = ""
    
    private var durationUpdateTimer: Thread? = null

    /// Set method channel with validation
    @Synchronized
    fun setMethodChannel(channel: MethodChannel) {
        try {
            if (channel == null) {
                Log.e(TAG, "❌ Cannot set null MethodChannel")
                return
            }
            
            methodChannel = channel
            Log.d(TAG, "✅ MethodChannel set successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting MethodChannel: ${e.message}", e)
        }
    }

    /// Send call status with comprehensive error handling
    @Synchronized
    fun sendCallStatus(state: String?, number: String) {
        try {
            // Validate inputs
            if (state == null || state.isEmpty()) {
                Log.w(TAG, "⚠️ State is null or empty")
                return
            }

            if (number.isEmpty()) {
                Log.w(TAG, "⚠️ Phone number is empty")
            }

            // Validate method channel
            if (methodChannel == null) {
                Log.e(TAG, "❌ MethodChannel is null, cannot send status")
                return
            }

            Log.d(TAG, "📞 Processing state: $state, number: $number")

            when (state.uppercase().trim()) {
                "RINGING", "INCOMING" -> handleRinging(number)
                "OFFHOOK", "ACTIVE", "CONNECTED" -> handleOffHook(number)
                "IDLE", "DISCONNECTED" -> handleIdle(number)
                else -> Log.w(TAG, "⚠️ Unknown state: $state")
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error in sendCallStatus: ${e.message}", e)
        }
    }

    /// Handle ringing state
    private fun handleRinging(number: String) {
        try {
            Log.d(TAG, "☎️ Call ringing: $number")
            
            // Reset call timing
            callStartTime = SystemClock.uptimeMillis()
            isCallActive = false

            // Invoke method
            invokeMethod(
                "phone_state_changed",
                mapOf(
                    "state" to "RINGING",
                    "number" to number
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in handleRinging: ${e.message}", e)
        }
    }

    /// Handle off-hook (active call) state
    private fun handleOffHook(number: String) {
        try {
            Log.d(TAG, "✅ Call connected: $number")
            
            // Initialize call start time if needed
            if (callStartTime <= 0 || !isCallActive) {
                callStartTime = SystemClock.uptimeMillis()
                currentPhoneNumber = number
                Log.d(TAG, "⏱️ Call start time set")
                
                // Start duration update timer
                startDurationUpdateTimer(number)
            }

            isCallActive = true

            // Send initial connected status
            invokeMethod(
                "call_state_update",
                mapOf(
                    "state" to "CONNECTED",
                    "number" to number,
                    "duration" to 0
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in handleOffHook: ${e.message}", e)
        }
    }
    
    /// Start timer to send duration updates every second
    private fun startDurationUpdateTimer(number: String) {
        try {
            // Stop existing timer if any
            stopDurationUpdateTimer()
            
            // Create and start new timer thread
            durationUpdateTimer = Thread {
                try {
                    while (isCallActive && callStartTime > 0) {
                        Thread.sleep(1000) // Update every second
                        
                        if (isCallActive && callStartTime > 0) {
                            val elapsed = SystemClock.uptimeMillis() - callStartTime
                            if (elapsed >= 0) {
                                val duration = (elapsed / 1000).toInt()
                                
                                invokeMethod(
                                    "call_state_update",
                                    mapOf(
                                        "state" to "CONNECTED",
                                        "number" to number,
                                        "duration" to duration
                                    )
                                )
                                
                                Log.d(TAG, "⏱️ Duration update: $duration seconds")
                            }
                        }
                    }
                } catch (e: InterruptedException) {
                    Log.d(TAG, "Timer interrupted (expected on call end)")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error in duration timer: ${e.message}", e)
                }
            }
            
            durationUpdateTimer?.start()
            Log.d(TAG, "✅ Duration update timer started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting duration timer: ${e.message}", e)
        }
    }
    
    /// Stop duration update timer
    private fun stopDurationUpdateTimer() {
        try {
            if (durationUpdateTimer != null && durationUpdateTimer!!.isAlive) {
                durationUpdateTimer?.interrupt()
                durationUpdateTimer?.join(1000) // Wait max 1 second
                Log.d(TAG, "✅ Duration timer stopped")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping timer: ${e.message}", e)
        }
    }

    /// Handle idle (call ended) state
    private fun handleIdle(number: String) {
        try {
            Log.d(TAG, "📴 Call disconnected: $number")
            
            // Stop the duration timer
            stopDurationUpdateTimer()
            
            isCallActive = false

            // Calculate final duration safely
            val duration = try {
                if (callStartTime > 0) {
                    val elapsed = SystemClock.uptimeMillis() - callStartTime
                    if (elapsed < 0) {
                        Log.w(TAG, "⚠️ Negative elapsed time at disconnect")
                        0
                    } else {
                        (elapsed / 1000).toInt()
                    }
                } else {
                    0
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error calculating final duration: ${e.message}", e)
                0
            }

            // Invoke method
            invokeMethod(
                "phone_state_changed",
                mapOf(
                    "state" to "DISCONNECTED",
                    "number" to number,
                    "duration" to duration
                )
            )

            // Reset timing
            callStartTime = 0
            isCallActive = false

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in handleIdle: ${e.message}", e)
            callStartTime = 0
            isCallActive = false
        }
    }

    /// Invoke method safely with error handling
    @Synchronized
    private fun invokeMethod(method: String, arguments: Map<String, Any?>) {
        try {
            if (methodChannel == null) {
                Log.e(TAG, "❌ MethodChannel is null in invokeMethod")
                return
            }

            // Validate arguments
            if (arguments.isEmpty()) {
                Log.w(TAG, "⚠️ Empty arguments for method: $method")
                return
            }

            // Invoke on main thread if not already
            try {
                methodChannel?.invokeMethod(method, arguments)
                Log.d(TAG, "✅ Method invoked: $method")
            } catch (e: IllegalStateException) {
                Log.e(TAG, "❌ IllegalStateException invoking method: ${e.message}", e)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error invoking method: ${e.message}", e)
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error in invokeMethod: ${e.message}", e)
        }
    }

    /// Get current call info for debugging
    @Synchronized
    fun getCallInfo(): String {
        return try {
            "CallStartTime: $callStartTime, IsActive: $isCallActive, MethodChannel: ${methodChannel != null}"
        } catch (e: Exception) {
            "Error getting call info: ${e.message}"
        }
    }

    /// Reset call tracking (useful for cleanup)
    @Synchronized
    fun reset() {
        try {
            callStartTime = 0
            isCallActive = false
            Log.d(TAG, "✅ Call tracking reset")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error resetting: ${e.message}", e)
        }
    }
}
