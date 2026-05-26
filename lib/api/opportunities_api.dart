import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class OpportunitiesApi {
  static bool _validateOpportunity(dynamic item) {
    if (item is! Map) {
      return false;
    }
    
    // Check for required fields
    if (item['name'] == null || item['name'].toString().isEmpty) {
      return false;
    }
    
    if (item['mobile_no'] == null || item['mobile_no'].toString().isEmpty) {
      return false;
    }
    
    return true;
  }

  static Future<Map<String, dynamic>> getOpportunities() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cookie = prefs.getString("cookie") ?? "";
      final username = prefs.getString("username") ?? "";

      if (cookie.isEmpty || username.isEmpty) {
        return {
          "success": false,
          "message": "Session not found. Please login again.",
          "opportunities": []
        };
      }

      final response = await http.get(
        Uri.parse(AppConfig.opportunitiesApi),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': cookie,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('API request timeout'),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Assuming the API returns a list of opportunities
        // Adjust this based on your actual API response structure
        final opportunities = jsonData["message"] is List
            ? jsonData["message"]
            : jsonData["message"]?["data"] ?? [];

        // Validate opportunities data
        if (opportunities is! List) {
          return {
            "success": false,
            "message": "Invalid opportunity data format",
            "opportunities": []
          };
        }

        // Filter to only valid opportunities
        final validOpportunities = opportunities
            .where((item) => _validateOpportunity(item))
            .toList();

        if (validOpportunities.isEmpty && opportunities.isNotEmpty) {
          return {
            "success": false,
            "message": "No valid opportunities found in response",
            "opportunities": []
          };
        }

        return {
          "success": true,
          "opportunities": validOpportunities
        };
      } else {
        return {
          "success": false,
          "message": "Failed to fetch opportunities",
          "opportunities": []
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
        "opportunities": []
      };
    }
  }

  static Future<Map<String, dynamic>> pauseCall(String opportunityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString("cookie") ?? "";

      final response = await http.post(
        Uri.parse(AppConfig.pauseCallApi),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': cookie,
        },
        body: {
          "opportunity_id": opportunityId,
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": "Call paused successfully"
        };
      } else {
        return {
          "success": false,
          "message": "Failed to pause call"
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString()
      };
    }
  }
}
