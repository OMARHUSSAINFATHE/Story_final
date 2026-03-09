import 'package:dio/dio.dart';
import 'package:story_app/modules/strings.dart';


class StoryModel {
  final String? id;
  final String name;
  final String avatarUrl;
  final String imageUrl;
  final List<String> stories;
  final bool isLocalImage;
  final DateTime? uploadedAt;
  final bool isTextStatus;
  final String? textContent;
  final int? bgColor;
  final int? apiId;                        // ✅ apiId أول story
  final Map<String, int?> storiesApiIds;  // ✅ apiId لكل story

  StoryModel({
    required this.name,
    required this.avatarUrl,
    required this.imageUrl,
    required this.stories,
    this.isLocalImage = false,
    this.id,
    this.uploadedAt,
    this.isTextStatus = false,
    this.textContent,
    this.bgColor,
    this.apiId,
    this.storiesApiIds = const {},
  });
}

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





class DioService {
  final Dio _dio;

  DioService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          receiveDataWhenStatusError: true,
          validateStatus: (status) => status! < 500,
          connectTimeout: const Duration(seconds: 10),
        ),
      );

  Future<Response> get({
    required String url,
    Map<String, dynamic>? headers,
  }) async {
    return await _dio.get(url, options: Options(headers: headers));
  }

  Future<Response> post({
    required String url,
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    return await _dio.post(
      url,
      data: data,
      options: Options(headers: headers),
    );
  }

  Future<Response> put({
    required String url,
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    return await _dio.put(
      url,
      data: data,
      options: Options(headers: headers),
    );
  }

  Future<Response> delete({
    required String url,
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    return await _dio.delete(
      url,
      data: data,
      options: Options(headers: headers),
    );
  }
}
