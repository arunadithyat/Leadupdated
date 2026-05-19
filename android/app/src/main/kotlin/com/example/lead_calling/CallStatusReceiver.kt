// File: android/app/src/main/kotlin/com/example/lead_calling/CallStatusReceiver.kt
// PRODUCTION VERSION WITH COMPREHENSIVE ERROR HANDLING

package com.example.lead_calling

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log
import java.lang.Exception

class CallStatusReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallStatusReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        try {
            // Validate inputs
            if (context == null) {
                Log.e(TAG, "❌ Context is null")
                return
            }

            if (intent == null) {
                Log.e(TAG, "❌ Intent is null")
                return
            }

            // Validate action
            val action = intent.action
            if (action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
                Log.w(TAG, "⚠️ Unexpected action: $action")
                return
            }

            // Safely extract state
            val state: String? = try {
                intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error getting EXTRA_STATE: ${e.message}", e)
                null
            }

            // Safely extract incoming number
            val incomingNumber: String? = try {
                intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error getting EXTRA_INCOMING_NUMBER: ${e.message}", e)
                null
            }

            // Validate state
            if (state == null || state.isEmpty()) {
                Log.w(TAG, "⚠️ State is null or empty")
                return
            }

            // Log the state
            Log.d(TAG, "📞 State: $state, Number: ${incomingNumber ?: "Unknown"}")

            // Validate state value
            if (!isValidState(state)) {
                Log.w(TAG, "⚠️ Invalid state value: $state")
                return
            }

            // Send to manager
            try {
                CallStatusManager.sendCallStatus(state, incomingNumber ?: "")
                Log.d(TAG, "✅ Status sent to manager")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error sending status to manager: ${e.message}", e)
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error in onReceive: ${e.message}", e)
        }
    }

    /// Validate if state is a known telephony state
    private fun isValidState(state: String): Boolean {
        return state in listOf(
            TelephonyManager.EXTRA_STATE_IDLE,
            TelephonyManager.EXTRA_STATE_OFFHOOK,
            TelephonyManager.EXTRA_STATE_RINGING,
            "IDLE",
            "OFFHOOK",
            "RINGING"
        )
    }
}
