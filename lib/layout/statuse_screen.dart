import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:story_app/modules/statuse_card/statuse_card.dart';
import 'package:story_app/modules/statuse_view/statuse_view.dart';
import 'package:story_app/modules/story_model/story_model.dart';
import 'package:story_app/modules/text_status_creator/text_status_creator.dart';
import 'package:story_app/modules/text_status_creator/media_status_creator.dart';
import 'package:story_app/services/cache_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  List<Map<String, dynamic>> _friends = [];
  Map<String, Set<int>> _viewedMap = {};
  String _searchQuery = '';
  List<String> _myStories = [];
  Map<String, DateTime> _myStoriesUploadTime = {};
  Map<String, int> _myStoriesApiIds = {}; // ✅ apiId لكل story
  bool _isLoading = true;
  String? _error;

  static const _friendsKey = 'friends_data';
  static const _viewedKey = 'viewed_data';
  static const _expiryHours = 24;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final friends = await _loadFriendsFromCache();
      final viewedMap = await _loadViewedFromCache();

      if (friends.isEmpty) {
        final demos = _getDemoFriends();
        await _saveFriendsToCache(demos);
        setState(() {
          _friends = demos;
          _viewedMap = viewedMap;
          _isLoading = false;
        });
      } else {
        setState(() {
          _friends = friends;
          _viewedMap = viewedMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadFriendsFromCache() async {
    try {
      final info = await CacheService.imageCache.getFileFromCache(_friendsKey);
      if (info == null) return [];
      final raw = await info.file.readAsString();
      final list = jsonDecode(raw) as List;
      final now = DateTime.now();
      return list
          .cast<Map<String, dynamic>>()
          .where((item) {
            final savedAt = DateTime.tryParse(item['savedAt'] ?? '');
            if (savedAt == null) return false;
            return now.difference(savedAt).inHours < _expiryHours;
          })
          .map((item) {
            final savedAt = DateTime.parse(item['savedAt']);
            final remainingHrs =
                _expiryHours - DateTime.now().difference(savedAt).inHours;
            return {...item, 'remainingHours': remainingHrs};
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveFriendsToCache(List<Map<String, dynamic>> friends) async {
    try {
      final bytes = utf8.encode(jsonEncode(friends));
      await CacheService.imageCache.putFile(
        _friendsKey,
        bytes,
        fileExtension: 'json',
      );
    } catch (_) {}
  }

  Future<Map<String, Set<int>>> _loadViewedFromCache() async {
    try {
      final info = await CacheService.imageCache.getFileFromCache(_viewedKey);
      if (info == null) return {};
      final raw = await info.file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.map(
        (k, v) => MapEntry(k, Set<int>.from((v as List).map((e) => e as int))),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveViewedToCache(Map<String, Set<int>> viewedMap) async {
    try {
      final data = viewedMap.map((k, v) => MapEntry(k, v.toList()));
      final bytes = utf8.encode(jsonEncode(data));
      await CacheService.imageCache.putFile(
        _viewedKey,
        bytes,
        fileExtension: 'json',
      );
    } catch (_) {}
  }

  void _markViewed(String friendId, int storyIndex) {
    final newMap = Map<String, Set<int>>.from(
      _viewedMap.map((k, v) => MapEntry(k, Set<int>.from(v))),
    );
    newMap.putIfAbsent(friendId, () => {});
    newMap[friendId]!.add(storyIndex);
    setState(() => _viewedMap = newMap);
    _saveViewedToCache(newMap);
  }

  void _deleteMyStory(String path) {
    setState(() {
      _myStories = List.from(_myStories)..remove(path);
      _myStoriesUploadTime = Map.from(_myStoriesUploadTime)..remove(path);
      _myStoriesApiIds = Map.from(_myStoriesApiIds)..remove(path);
    });
  }

  void _onSearchChanged(String q) => setState(() => _searchQuery = q);

  List<Map<String, dynamic>> get _sortedFriends {
    final unviewed = <Map<String, dynamic>>[];
    final viewed = <Map<String, dynamic>>[];
    for (final item in _friends) {
      final id = item['id'] as String;
      final vSet = _viewedMap[id] ?? {};
      final stories = item['stories'] as List;
      vSet.isNotEmpty && vSet.length >= stories.length
          ? viewed.add(item)
          : unviewed.add(item);
    }
    final sorted = [...unviewed, ...viewed];
    if (_searchQuery.isEmpty) return sorted;
    return sorted
        .where(
          (i) => (i['name'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  // ════════════════════════════════════════
  //  Create Text Status → API
  // ════════════════════════════════════════
  Future<void> _createTextStatus() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TextStatusCreator()),
    );
    if (result is StatusModel && mounted) {
      final key = 'text:${result.content}';
      setState(() {
        _myStories = List.from(_myStories)..add(key);
        _myStoriesUploadTime = Map.from(_myStoriesUploadTime)
          ..[key] = DateTime.now();
        _myStoriesApiIds = Map.from(_myStoriesApiIds)..[key] = result.id; // ✅
      });
    }
  }

  // ════════════════════════════════════════
  //  Create Media Status → API (صور/فيديو)
  // ════════════════════════════════════════
  Future<void> _createMediaStatus(ImageSource source, String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaStatusCreator(source: source, type: type),
      ),
    );
    if (result is StatusModel && mounted) {
      final path = result.fileUrl != null
          ? 'https://back.ibond.ai${result.fileUrl}'
          : result.content;
      setState(() {
        _myStories = List.from(_myStories)..add(path);
        _myStoriesUploadTime = Map.from(_myStoriesUploadTime)
          ..[path] = DateTime.now();
        _myStoriesApiIds = Map.from(_myStoriesApiIds)..[path] = result.id; // ✅
      });
    }
  }

  void _showAddStatusOptions() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.text_fields, color: Colors.white),
                ),
                title: const Text(
                  'Text Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Create a text status'),
                onTap: () {
                  Navigator.pop(context);
                  _createTextStatus();
                },
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.grey),
                title: const Text('Camera Image'),
                onTap: () {
                  Navigator.pop(context);
                  _createMediaStatus(ImageSource.camera, 'IMAGE');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.grey),
                title: const Text('Gallery Image'),
                onTap: () {
                  Navigator.pop(context);
                  _createMediaStatus(ImageSource.gallery, 'IMAGE');
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.grey),
                title: const Text('Camera Video'),
                onTap: () {
                  Navigator.pop(context);
                  _createMediaStatus(ImageSource.camera, 'VIDEO');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.grey),
                title: const Text('Gallery Video'),
                onTap: () {
                  Navigator.pop(context);
                  _createMediaStatus(ImageSource.gallery, 'VIDEO');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFriendStatus(int filteredIndex) {
    final list = _sortedFriends;
    final item = list[filteredIndex];
    final friendId = item['id'] as String;
    final stories = List<String>.from(item['stories'] as List);

    final allModels = list.map((i) {
      final s = List<String>.from(i['stories'] as List);
      return StoryModel(
        id: i['id'] as String,
        name: i['name'] as String,
        avatarUrl: i['avatar'] as String,
        imageUrl: s.first,
        stories: s,
        uploadedAt: DateTime.tryParse(i['savedAt'] as String? ?? ''),
      );
    }).toList();

    final viewedSet = _viewedMap[friendId] ?? {};
    int startIndex = 0;
    for (int i = 0; i < stories.length; i++) {
      if (!viewedSet.contains(i)) {
        startIndex = i;
        break;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewPage(
          storyModel: allModels[filteredIndex],
          allStories: allModels,
          currentIndex: filteredIndex,
          initialStoryIndex: startIndex,
          onStoryStarted: (fId, idx) => _markViewed(fId, idx),
          onStoryViewed: (_) {},
        ),
      ),
    );
  }

  // ✅ بناء الـ StoryModel لـ My Status مع الـ apiIds
  StoryModel _buildMyStatusModel() {
    // نبني Map من story path → apiId عشان الـ view يعرف يمسح
    final storiesWithIds = _myStories.map((path) {
      return {'path': path, 'apiId': _myStoriesApiIds[path]};
    }).toList();

    return StoryModel(
      name: 'My Status',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      imageUrl: _myStories.first,
      stories: List.from(_myStories),
      isLocalImage:
          !_myStories.first.startsWith('http') &&
          !_myStories.first.startsWith('text:'),
      id: '1',
      uploadedAt: _myStoriesUploadTime[_myStories.first],
      apiId: _myStoriesApiIds[_myStories.first], // ✅ أول story
      storiesApiIds: Map.fromEntries(
        // ✅ كل الـ stories
        _myStories.map((p) => MapEntry(p, _myStoriesApiIds[p])),
      ),
    );
  }


  ///Status friends
  List<Map<String, dynamic>> _getDemoFriends() => [
    {
      'id': 'friend_1',
      'name': 'medo 1',
      'avatar':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      'stories': [
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800',
        'https://www.w3schools.com/tags/mov_bbb.mp4',
        'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=800',
      ],
      'savedAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'friend_2',
      'name': 'Ahmed 2',
      'avatar':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      'stories': [
        'https://www.w3schools.com/tags/mov_bbb.mp4',
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800',
        'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=800',
      ],
      'savedAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'friend_3',
      'name': 'Mohamed Ahmed 3',
      'avatar':
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
      'stories': [
        'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=800',
        'https://www.w3schools.com/tags/mov_bbb.mp4',
      ],
      'savedAt': DateTime.now().toIso8601String(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
        elevation: 0,
      
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStatusOptions,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final sortedItems = _sortedFriends;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              counterStyle: TextStyle(height: 10.h),
              hintText: 'Search for friends',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: GridView.builder(
              itemCount: sortedItems.length + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                // ── My Status Card ──────────────────
                if (index == 0) {
                  final hasStories = _myStories.isNotEmpty;
                  return GestureDetector(
                    onTap: hasStories
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatusViewPage(
                                storyModel: _buildMyStatusModel(), // ✅
                                allStories: null,
                                storiesUploadTimes: Map.from(
                                  _myStoriesUploadTime,
                                ),
                                onStoryDeleted: (s) => _deleteMyStory(s),
                              ),
                            ),
                          )
                        : _showAddStatusOptions,
                    child: _MyStatusCard(
                      myStories: _myStories,
                      hasStories: hasStories,
                    ),
                  );
                }

                // ── Friend Status Card ───────────────
                final fi = index - 1;
                final item = sortedItems[fi];
                final friendId = item['id'] as String;
                final stories = List<String>.from(item['stories'] as List);
                final vSet = _viewedMap[friendId] ?? {};
                final allSeen =
                    vSet.isNotEmpty && vSet.length >= stories.length;

                return GestureDetector(
                  onTap: () => _openFriendStatus(fi),
                  child: StatusCard(
                    storyModel: StoryModel(
                      id: friendId,
                      name: item['name'] as String,
                      avatarUrl: item['avatar'] as String,
                      imageUrl: stories.first,
                      stories: stories,
                    ),
                    isViewed: allSeen,
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

// ═══════════════════════════════════════════════════════
//  My Status Card Widget
// ═══════════════════════════════════════════════════════
class _MyStatusCard extends StatelessWidget {
  final List<String> myStories;
  final bool hasStories;
  const _MyStatusCard({required this.myStories, required this.hasStories});

  bool get _firstIsText => hasStories && myStories.first.startsWith('text:');

  String get _textContent => myStories.first.replaceFirst('text:', '');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!hasStories)
              Container(
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.add_a_photo,
                  size: 50,
                  color: Colors.grey,
                ),
              )
            else if (_firstIsText)
              Container(
                color: const Color(0xFF128C7E),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _textContent,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            else
              getVideo(myStories.first),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            const Positioned(
              left: 8,
              bottom: 15,
              right: 8,
              child: Text(
                'My Status',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            if (!hasStories)
              Positioned(
                right: 4,
                bottom: 105,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _checkThumbnial() {
    if (myStories.first.startsWith('http')) {
      return Image.network(
        myStories.first,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey),
      );
    } else {
      return Image.file(
        File(myStories.first),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey),
      );
    }
  }

  Widget getVideo(String url){
    return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: url,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                ),
                
              ],
            );
          }

          return Container();
        },
      );
  }
}
