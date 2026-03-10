import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:story_app/modules/story_model/story_model.dart';
import 'package:story_app/modules/statuse_card/statuse_card.dart';
import 'package:story_app/modules/statuse_view/statuse_view.dart';
import '../status_service/status_service.dart';

// ═══════════════════════════════════════════════════════
//  Friends Stories Screen
//  بتجيب استوريات الأصدقاء من الـ API وتعرضها
// ═══════════════════════════════════════════════════════

class FriendsStoriesScreen extends StatefulWidget {
  const FriendsStoriesScreen({super.key});

  @override
  State<FriendsStoriesScreen> createState() => _FriendsStoriesScreenState();
}

class _FriendsStoriesScreenState extends State<FriendsStoriesScreen> {
  List<StoryModel> _friendsStories = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  // ── Viewed tracking ────────────────────
  final Map<String, Set<int>> _viewedMap = {};

  @override
  void initState() {
    super.initState();
    _fetchFriendsStories();
  }

  // ════════════════════════════════════════
  //  Fetch من الـ API
  // ════════════════════════════════════════
  Future<void> _fetchFriendsStories() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await http.get(
        Uri.parse('${StatusService.baseUrl}/status/friends'),
        headers: {'Authorization': 'Bearer ${StatusService.token}'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // الـ API ممكن يرجع List أو Map فيه data
        final List<dynamic> rawList = data is List ? data : (data['data'] ?? data['statuses'] ?? []);

        // نجمّع الـ stories حسب الـ user
        final Map<String, Map<String, dynamic>> grouped = {};

        for (final item in rawList) {
          final user      = item['user'] as Map<String, dynamic>? ?? {};
          final userId    = user['id']?.toString() ?? 'unknown';
          final userName  = user['name'] ?? user['email'] ?? 'Unknown';
          final avatarUrl = user['avatar'] ?? user['profilePicture'] ?? '';

          if (!grouped.containsKey(userId)) {
            grouped[userId] = {
              'id':      userId,
              'name':    userName,
              'avatar':  avatarUrl,
              'stories': <Map<String, dynamic>>[],
            };
          }

          grouped[userId]!['stories'].add(item);
        }

        // نحوّل لـ StoryModel
        final List<StoryModel> models = grouped.values.map((group) {
          final storiesList = group['stories'] as List<Map<String, dynamic>>;

          // نبني قائمة الـ paths والـ apiIds
          final paths    = <String>[];
          final apiIds   = <String, int?>{};
          final times    = <String, DateTime>{};

          for (final s in storiesList) {
            final type     = s['type'] ?? 'IMAGE';
            final content  = s['content'] ?? '';
            final fileUrl  = s['fileUrl'];
            final sId      = s['id'] as int?;
            final createdAt = s['createdAt'] != null
                ? DateTime.tryParse(s['createdAt'])
                : null;

            String path;
            if (type == 'TEXT') {
              path = 'text:$content';
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

        setState(() {
          _friendsStories = models;
          _isLoading      = false;
        });
      } else {
        setState(() {
          _error     = 'فشل تحميل الاستوريات (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error     = 'تحقق من الإنترنت وحاول تاني';
        _isLoading = false;
      });
      debugPrint('Fetch friends stories error: $e');
    }
  }

  // ════════════════════════════════════════
  //  Viewed Tracking
  // ════════════════════════════════════════
  void _markViewed(String friendId, int storyIndex) {
    setState(() {
      _viewedMap.putIfAbsent(friendId, () => {});
      _viewedMap[friendId]!.add(storyIndex);
    });
  }

  bool _isAllViewed(StoryModel model) {
    final vSet = _viewedMap[model.id] ?? {};
    return vSet.isNotEmpty && vSet.length >= model.stories.length;
  }

  // ════════════════════════════════════════
  //  Open Story
  // ════════════════════════════════════════
  void _openStory(int index) {
    final filtered = _filteredStories;
    final model    = filtered[index];
    final vSet     = _viewedMap[model.id] ?? {};

    // ابدأ من أول story لم تتشاهد
    int startIndex = 0;
    for (int i = 0; i < model.stories.length; i++) {
      if (!vSet.contains(i)) { startIndex = i; break; }
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StatusViewPage(
        storyModel:     model,
        allStories:     filtered,
        currentIndex:   index,
        initialStoryIndex: startIndex,
        onStoryStarted: (fId, idx) => _markViewed(fId, idx),
        onStoryViewed:  (_) {},
      ),
    ));
  }

  // ════════════════════════════════════════
  //  Filter
  // ════════════════════════════════════════
  List<StoryModel> get _filteredStories {
    if (_searchQuery.isEmpty) return _friendsStories;
    return _friendsStories.where((s) =>
        s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ════════════════════════════════════════
  //  Sort — غير المشاهدة الأول
  // ════════════════════════════════════════
  List<StoryModel> get _sortedStories {
    final list     = _filteredStories;
    final unviewed = list.where((s) => !_isAllViewed(s)).toList();
    final viewed   = list.where((s) => _isAllViewed(s)).toList();
    return [...unviewed, ...viewed];
  }

  // ════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends Stories'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFriendsStories,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('جاري تحميل الاستوريات...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchFriendsStories,
            icon: const Icon(Icons.refresh),
            label: const Text('حاول تاني'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ]),
      );
    }

    final stories = _sortedStories;

    if (stories.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.people_outline, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          const Text('مفيش استوريات دلوقتي', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchFriendsStories,
            child: const Text('تحديث'),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFriendsStories,
      color: Colors.green,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [

          // ── Search ─────────────────────────
          TextField(
            onChanged: (q) => setState(() => _searchQuery = q),
            decoration: InputDecoration(
              hintText: 'ابحث عن صديق...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''))
                  : null,
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),

          // ── Count ──────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${stories.length} ${stories.length == 1 ? 'story' : 'stories'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),

          // ── Grid ───────────────────────────
          Expanded(
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: stories.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                final model   = stories[index];
                final allSeen = _isAllViewed(model);
                // الـ real index في الـ sorted list
                final realIndex = _sortedStories.indexOf(model);

                return GestureDetector(
                  onTap: () => _openStory(realIndex),
                  child: StatusCard(
                    storyModel: model,
                    isViewed:   allSeen,
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}