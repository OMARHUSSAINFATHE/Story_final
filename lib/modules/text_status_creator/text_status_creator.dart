import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// =====================================================
// STATUS MODEL
// =====================================================
class StatusModel {
  final String type;
  final String content;
  final String? fileUrl;
  final String? fileName;
  final String visibility;
  final String expiresAt;
  final Map<String, dynamic> user;
  final int id;
  final String createdAt;
  final String updatedAt;
  

  StatusModel({
    required this.type,
    required this.content,
    this.fileUrl,
    this.fileName,
    required this.visibility,
    required this.expiresAt,
    required this.user,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      type: json['type'] ?? 'TEXT',
      content: json['content'] ?? '',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      visibility: json['visibility'] ?? 'FRIENDS',
      expiresAt: json['expiresAt'] ?? '',
      user: json['user'] ?? {},
      id: json['id'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

// =====================================================
// STATUS SERVICE - API Calls
// =====================================================
class StatusService {
  static const String baseUrl = 'https://back.ibond.ai/v1';
  static const String _token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NDgsImVtYWlsIjoiaGFueUBnbWFpbC5jb20iLCJpYXQiOjE3NzI5Njc5NjksImV4cCI6MTc3NTU1OTk2OX0.LbsK9FFxFI0DbNM4974Pb3FAGEvxJzKoAsrj0wd9u_4';

  /// Create TEXT status
  static Future<StatusModel?> createTextStatus({
    required String content,
    required String visibility,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/status'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['visibility'] = visibility;
      request.fields['content'] = content;
      request.fields['type'] = 'TEXT';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return StatusModel.fromJson(jsonDecode(response.body));
      } else {
        debugPrint('Text status failed: ${response.statusCode} - ${response.body}');
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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/status'),
      );

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
        debugPrint('File status failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error: $e');
      return null;
    }
  }
}

// =====================================================
// TEXT STATUS CREATOR SCREEN
// =====================================================
class TextStatusCreator extends StatefulWidget {
  const TextStatusCreator({super.key});

  @override
  State<TextStatusCreator> createState() => _TextStatusCreatorState();
}

class _TextStatusCreatorState extends State<TextStatusCreator> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedVisibility = 'FRIENDS';
  bool _isLoading = false;
  Color _selectedBgColor = const Color(0xFF128C7E);
  double _fontSize = 24.0;

  final List<Color> _bgColors = [
    const Color(0xFF128C7E),
    const Color(0xFF075E54),
    const Color(0xFF1877F2),
    const Color(0xFFE53935),
    const Color(0xFF8E24AA),
    const Color(0xFFF57C00),
    const Color(0xFF000000),
    const Color(0xFF37474F),
  ];

  final Map<String, String> _visibilityOptions = {
    'FRIENDS': 'الأصدقاء',
    'PUBLIC': 'الجميع',
    'ONLY_ME': 'أنا فقط',
  };

  Future<void> _publishStatus() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اكتب محتوى الحالة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await StatusService.createTextStatus(
      content: _contentController.text.trim(),
      visibility: _selectedVisibility,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نشر الحالة بنجاح! ID: ${result.id}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء نشر الحالة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedVisibility,
            onSelected: (val) => setState(() => _selectedVisibility = val),
            itemBuilder: (_) => _visibilityOptions.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _visibilityOptions[_selectedVisibility]!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : TextButton(
                    onPressed: _publishStatus,
                    child: const Text(
                      'نشر',
                      style: TextStyle(
                        color: Color(0xFF25D366),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: _selectedBgColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'اكتب حالتك هنا...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 22),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.text_fields, color: Colors.white54, size: 16),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 14,
                    max: 48,
                    activeColor: const Color(0xFF25D366),
                    inactiveColor: Colors.grey,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                ),
                const Icon(Icons.text_fields, color: Colors.white, size: 24),
              ],
            ),
          ),
          Container(
            height: 64,
            color: Colors.grey[900],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _bgColors.length,
              itemBuilder: (_, i) {
                final color = _bgColors[i];
                final isSelected = color == _selectedBgColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBgColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}