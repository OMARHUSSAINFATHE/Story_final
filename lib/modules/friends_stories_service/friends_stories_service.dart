import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:story_app/modules/story_model/story_model.dart';
import '../status_service/status_service.dart';

// ═══════════════════════════════════════════════════════
//  FriendsStoriesService
//  بيجيب استوريات الأصدقاء من الـ API ويحولها لـ StoryModel
// ═══════════════════════════════════════════════════════
class FriendsStoriesService {
  static Future<List<StoryModel>> fetchFriendsStories() async {
    try {
      final response = await http.get(
        Uri.parse('${StatusService.baseUrl}/status/friends'),
        headers: {'Authorization': 'Bearer ${StatusService.token}'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> rawList = data is List
          ? data
          : (data['data'] ?? data['statuses'] ?? []);

      // نجمّع الـ stories حسب الـ user
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final item in rawList) {
        final user      = item['user'] as Map<String, dynamic>? ?? {};
        final userId    = user['id']?.toString() ?? 'unknown';
        final userName  = user['name'] ?? user['email'] ?? 'Unknown';
        final avatarUrl = user['avatar'] ?? user['profilePicture'] ?? '';

        grouped.putIfAbsent(userId, () => {
          'id':      userId,
          'name':    userName,
          'avatar':  avatarUrl,
          'stories': <Map<String, dynamic>>[],
        });

        (grouped[userId]!['stories'] as List).add(item);
      }

      return grouped.values.map((group) {
        final storiesList = (group['stories'] as List).cast<Map<String, dynamic>>();
        final paths  = <String>[];
        final apiIds = <String, int?>{};
        final times  = <String, DateTime>{};

        for (final s in storiesList) {
          final type      = s['type'] ?? 'IMAGE';
          final content   = s['content'] ?? '';
          final fileUrl   = s['fileUrl'];
          final sId       = s['id'] as int?;
          final createdAt = s['createdAt'] != null
              ? DateTime.tryParse(s['createdAt']) : null;

          String path;
          if (type == 'TEXT') {
            path = 'text:$content';
          } else if (type == 'VIDEO' || (fileUrl != null &&
              (fileUrl as String).toLowerCase().contains('.mp4'))) {
            path = fileUrl != null
                ? 'video:https://back.ibond.ai$fileUrl'
                : 'video:$content';
          } else {
            path = fileUrl != null
                ? 'https://back.ibond.ai$fileUrl'
                : content;
          }

          paths.add(path);
          apiIds[path] = sId;
          if (createdAt != null) times[path] = createdAt;
        }

        return StoryModel(
          id:            group['id'] as String,
          name:          group['name'] as String,
          avatarUrl:     group['avatar'] as String,
          imageUrl:      paths.first,
          stories:       paths,
          storiesApiIds: apiIds,
          uploadedAt:    times[paths.first],
        );
      }).toList();

    } catch (e) {
      debugPrint('FriendsStoriesService error: $e');
      return [];
    }
  }
}
