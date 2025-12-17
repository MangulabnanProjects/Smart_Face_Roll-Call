import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _keyBaseUrl = 'server_base_url';
  // Default to your LAN IP so you don't have to type it every time
  static const String _defaultUrl = 'http://192.168.0.10:5000'; 

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? _defaultUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Ensure protocol is present
    if (!url.startsWith('http')) {
      url = 'http://$url';
    }
    await prefs.setString(_keyBaseUrl, url);
  }

  static Future<Map<String, dynamic>> detectFace(File imageFile) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/detect');

    try {
      debugPrint('Sending image to $uri');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Connection failed: $e');
    }
  }
}
