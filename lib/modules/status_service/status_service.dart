import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../story_model/story_model.dart';

// =====================================================
// STATUS SERVICE - API Calls
// =====================================================
class StatusService {
  static const String baseUrl = 'https://back.ibond.ai/v1';
  static const String _token =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NDgsImVtYWlsIjoiaGFueUBnbWFpbC5jb20iLCJpYXQiOjE3NzMxNDUwNDQsImV4cCI6MTc3NTczNzA0NH0.YWyA66-RJF9riBcEE0myADTimrqBr2mQZ7sYD6jzxY0";
  static String get token => _token;

  /// Create TEXT status
  static Future<StatusModel?> createTextStatus({
    required String content,
    required String visibility,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/status'));

      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['visibility'] = visibility;
      request.fields['content'] = content;
      request.fields['type'] = 'TEXT';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return StatusModel.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
          'Text status failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error: $e');
      return null;
    }
  }

  /// Delete status by ID
  static Future<bool> deleteStatus(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/status/$id'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      debugPrint('DELETE STATUS: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Delete error: $e');
      return false;
    }
  }

  /// Create IMAGE or VIDEO status
  static Future<StatusModel?> createFileStatus({
    required String content,
    required String visibility,
    required String type,
    required File statusFile,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/status'));

      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['visibility'] = visibility;
      request.fields['content'] = content;
      request.fields['type'] = type;

      request.files.add(
        await http.MultipartFile.fromPath('status-file', statusFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('=== FILE STATUS ===');
      debugPrint('Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode == 201) {
        return StatusModel.fromJson(jsonDecode(response.body));
      } else {
        debugPrint(
          'File status failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error: $e');
      return null;
    }
  }
}
