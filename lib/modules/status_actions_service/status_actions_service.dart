import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class StatusActionsService {
  /// حفظ صورة في الجاليري
  static Future<bool> saveImage(String path, {bool isLocal = true}) async {
    try {
      // طلب الأذونات
      final permission = await _requestPermission();
      if (!permission) {
        debugPrint('Permission denied');
        return false;
      }

      String? filePath;

      if (isLocal) {
        // ملف محلي
        filePath = path;
      } else if (path.startsWith('http')) {
        // تحميل من الإنترنت
        filePath = await _downloadFile(path, isVideo: false);
        if (filePath == null) return false;
      } else {
        filePath = path;
      }

      // حفظ في الجاليري
      final result = await GallerySaver.saveImage(filePath);
      return result ?? false;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return false;
    }
  }

  /// حفظ فيديو في الجاليري
  static Future<bool> saveVideo(String path, {bool isLocal = true}) async {
    try {
      // طلب الأذونات
      final permission = await _requestPermission();
      if (!permission) {
        debugPrint('Permission denied');
        return false;
      }

      String? filePath;

      if (isLocal) {
        // ملف محلي
        filePath = path;
      } else if (path.startsWith('http')) {
        // تحميل من الإنترنت
        filePath = await _downloadFile(path, isVideo: true);
        if (filePath == null) return false;
      } else {
        filePath = path;
      }

      // حفظ في الجاليري
      final result = await GallerySaver.saveVideo(filePath);
      return result ?? false;
    } catch (e) {
      debugPrint('Error saving video: $e');
      return false;
    }
  }

  /// تحميل ملف من الإنترنت
  static Future<String?> _downloadFile(String url, {required bool isVideo}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final extension = isVideo ? 'mp4' : 'jpg';
      final filename = 'status_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${dir.path}/$filename');

      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  /// طلب الأذونات
  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();

      // Android 13+ (API 33+)
      if (androidInfo >= 33) {
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        return photos.isGranted && videos.isGranted;
      }
      // Android 10-12
      else if (androidInfo >= 29) {
        return true; // Scoped Storage - لا يحتاج إذن
      }
      // Android 9 وأقدم
      else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } else if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      return photos.isGranted;
    }

    return false;
  }

  /// الحصول على إصدار Android
  static Future<int> _getAndroidVersion() async {
    try {
      // يمكن استخدام device_info_plus
      return 33; // افتراضي
    } catch (e) {
      return 33;
    }
  }

  /// حذف ملف محلي
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  /// تحديد نوع الملف
  static bool isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }
}

/// Dialog للتأكيد على الحذف
class DeleteConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Status'),
      content: const Text('Are you sure you want to delete this status?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Progress Dialog للحفظ
class SavingProgressDialog extends StatelessWidget {
  const SavingProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Saving to gallery...'),
        ],
      ),
    );
  }
}