import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final headers = await getHeaders();

    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await getHeaders();

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
      body: jsonEncode(body),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await getHeaders();

    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
      body: jsonEncode(body),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final headers = await getHeaders();

    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
    );

    return jsonDecode(response.body);
  }
}
