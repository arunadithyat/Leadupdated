import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class CallLogApi {
  /// Log a call initiation
  static Future<Map<String, dynamic>> logCallInitiation({
    required String doctype,
    required String docname,
    required String customerName,
    required String mobileNo,
    required DateTime initiatedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString("cookie") ?? "";
      final username = prefs.getString("username") ?? "";

      if (cookie.isEmpty || username.isEmpty) {
        return {
          "success": false,
          "message": "Session not found",
        };
      }

      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/api/resource/Call%20Log"),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookie,
          'X-Frappe-CSRF-Token': await _getCsrfToken(cookie),
        },
        body: jsonEncode({
          "data": {
            "doctype": "Call Log",
            "doctype_reference": doctype,
            "docname_reference": docname,
            "customer_name": customerName,
            "mobile_number": mobileNo,
            "initiated_at": initiatedAt.toIso8601String(),
            "initiated_by": username,
            "initiated_status": "Success",
            "call_status": "Initiated",
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.body;
        if (body.isNotEmpty) {
          final jsonData = jsonDecode(body);
          debugPrint("[CALLLOG] ✅ Call logged: $jsonData");
          return {
            "success": true,
            "message": "Call logged successfully",
            "data": jsonData,
          };
        }
      }

      debugPrint("[CALLLOG] ❌ Failed to log call: ${response.statusCode}");
      return {
        "success": false,
        "message": "Failed to log call (${response.statusCode})",
      };
    } catch (e) {
      debugPrint("[CALLLOG] ❌ ERROR logging call: $e");
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Update call with duration and final status
  static Future<Map<String, dynamic>> updateCallLog({
    required String callLogName,
    required int callDuration,
    required String callStatus,
    required bool attended,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString("cookie") ?? "";

      if (cookie.isEmpty) {
        return {
          "success": false,
          "message": "Session not found",
        };
      }

      final response = await http.put(
        Uri.parse("${AppConfig.baseUrl}/api/resource/Call%20Log/$callLogName"),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookie,
          'X-Frappe-CSRF-Token': await _getCsrfToken(cookie),
        },
        body: jsonEncode({
          "data": {
            "call_duration": callDuration,
            "call_status": callStatus,
            "attended": attended ? 1 : 0,
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        debugPrint("[CALLLOG] ✅ Call updated: $jsonData");
        return {
          "success": true,
          "message": "Call updated successfully",
        };
      }

      return {
        "success": false,
        "message": "Failed to update call (${response.statusCode})",
      };
    } catch (e) {
      debugPrint("[CALLLOG] ❌ ERROR updating call: $e");
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Log error/failure
  static Future<Map<String, dynamic>> logCallError({
    required String doctype,
    required String docname,
    required String customerName,
    required String mobileNo,
    required String errorMessage,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString("cookie") ?? "";
      final username = prefs.getString("username") ?? "";

      if (cookie.isEmpty || username.isEmpty) {
        return {
          "success": false,
          "message": "Session not found",
        };
      }

      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/api/resource/Error%20Log"),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookie,
          'X-Frappe-CSRF-Token': await _getCsrfToken(cookie),
        },
        body: jsonEncode({
          "data": {
            "doctype": "Error Log",
            "title": "Call Initiation Error - $customerName",
            "error": errorMessage,
            "reference_doctype": doctype,
            "reference_name": docname,
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("[ERRORLOG] ✅ Error logged");
        return {
          "success": true,
          "message": "Error logged successfully",
        };
      }

      return {
        "success": false,
        "message": "Failed to log error",
      };
    } catch (e) {
      debugPrint("[ERRORLOG] ❌ ERROR logging error: $e");
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Get CSRF token
  static Future<String> _getCsrfToken(String cookie) async {
    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/api/method/frappe.auth.get_csrf_token"),
        headers: {
          'Cookie': cookie,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['message'] ?? '';
      }
      return '';
    } catch (e) {
      debugPrint("[CSRF] ERROR: $e");
      return '';
    }
  }
}
