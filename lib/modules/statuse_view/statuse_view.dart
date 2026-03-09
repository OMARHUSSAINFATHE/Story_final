import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import '../story_model/story_model.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/cache_service.dart';
import '../status_service/status_service.dart';


class StatusViewPage extends StatefulWidget {
  final StoryModel storyModel;
  final Function(String)? onStoryDeleted;
  final List<StoryModel>? allStories;
  final int currentIndex;
  final Function(int)? onStoryViewed;
  final int initialStoryIndex;
  final Function(String friendId, int storyIndex)? onStoryStarted;
  final Map<String, DateTime>? storiesUploadTimes;

  const StatusViewPage({
    super.key,
    required this.storyModel,
    this.onStoryDeleted,
    this.allStories,
    this.currentIndex = 0,
    this.onStoryViewed,
    this.initialStoryIndex = 0,
    this.onStoryStarted,
    this.storiesUploadTimes,
  });

  @override
  State<StatusViewPage> createState() => _StatusViewPageState();
}

class _StatusViewPageState extends State<StatusViewPage> {
  late PageController _pageController;
  late int _currentStoryIndex;

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  // Progress bar
  Timer? _progressTimer;
  double _progressValue = 0.0;
  bool _isPaused = false; // ✅ للإيقاف المؤقت

  // Cache
  final _cacheService = CacheService();
  final Map<String, String> _cachedVideoPaths = {};
  final Map<String, String> _cachedImagePaths = {};

  DateTime? _currentUploadTime;

  // ✅ key لكل فيديو عشان كل واحد يتعامل معاه بشكل مستقل
  final Map<int, GlobalKey<_VideoStoryWidgetState>> _videoKeys = {};

  GlobalKey<_VideoStoryWidgetState> _getVideoKey(int index) {
    _videoKeys.putIfAbsent(index, () => GlobalKey<_VideoStoryWidgetState>());
    return _videoKeys[index]!;
  }

  @override
  void initState() {
    super.initState();
    _currentStoryIndex = widget.initialStoryIndex;
    _pageController = PageController(initialPage: widget.initialStoryIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPageChanged(widget.initialStoryIndex);
    });

    _loadCache();
  }

  Future<void> _loadCache() async {
    final stories = widget.storyModel.stories;
    await Future.wait(stories.map((story) async {
      if (!story.startsWith('http')) return;
      try {
        if (_isVideo(story)) {
          File? f = await _cacheService.getFromCache(story, isVideo: true);
          f ??= await _cacheService.cacheVideo(story).timeout(const Duration(seconds: 30)).catchError((_) => null);
          if (f != null && mounted) setState(() => _cachedVideoPaths[story] = f!.path);
        } else {
          File? f = await _cacheService.getFromCache(story);
          f ??= await _cacheService.cacheImage(story).timeout(const Duration(seconds: 15)).catchError((_) => null);
          if (f != null && mounted) setState(() => _cachedImagePaths[story] = f!.path);
        }
      } catch (_) {}
    }));
  }

  // ════════════════════════════════════════
  //  Progress Bar
  // ════════════════════════════════════════
  void _startProgress(Duration duration) {
    _progressTimer?.cancel();
    if (!mounted) return;
    setState(() { _progressValue = 0.0; _isPaused = false; });

    final stepMs = 50;
    final steps  = duration.inMilliseconds / stepMs;
    int count    = 0;

    _progressTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) {
      if (_isPaused) return; // ✅ لو متوقف، اتجاهل الـ tick
      count++;
      if (!mounted) { t.cancel(); return; }
      final newVal = count / steps;
      setState(() => _progressValue = newVal.clamp(0.0, 1.0));
      if (count >= steps) {
        t.cancel();
        _nextStory();
      }
    });
  }

  void _pauseProgress() {
    if (_isPaused) return;
    setState(() => _isPaused = true);
    _videoKeys[_currentStoryIndex]?.currentState?.pause(); // ✅ وقّف الفيديو الحالي
  }

  void _resumeProgress() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    _videoKeys[_currentStoryIndex]?.currentState?.resume(); // ✅ استكمل الفيديو الحالي
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    setState(() => _isPaused = false);
  }

  // ════════════════════════════════════════
  //  Page Changed
  // ════════════════════════════════════════
  void _onPageChanged(int index) {
    if (!mounted) return;
    _currentStoryIndex = index;
    setState(() => _progressValue = 0.0);

    if (widget.storiesUploadTimes != null) {
      final path = widget.storyModel.stories[index];
      setState(() => _currentUploadTime = widget.storiesUploadTimes![path]);
    }

    if (widget.storyModel.id != null && widget.storyModel.id != 'my_status') {
      widget.onStoryStarted?.call(widget.storyModel.id!, index);
    }

    final story = widget.storyModel.stories[index];
    if (!_isVideo(story)) {
      _startProgress(const Duration(seconds: 5));
    }
  }

  // ════════════════════════════════════════
  //  Navigation
  // ════════════════════════════════════════
  void _nextStory() {
    _stopProgress();
    final total = widget.storyModel.stories.length;
    if (_currentStoryIndex < total - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _onAllDone();
    }
  }

  void _prevStory() {
    _stopProgress();
    if (_currentStoryIndex > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      setState(() => _progressValue = 0.0);
      _onPageChanged(0);
    }
  }

  void _onAllDone() {
    widget.onStoryViewed?.call(widget.currentIndex);
    final all = widget.allStories;
    if (all == null || widget.currentIndex >= all.length - 1) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final next = widget.currentIndex + 1;
    if (mounted) {
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, _, _) => StatusViewPage(
          storyModel:     all[next],
          allStories:     all,
          currentIndex:   next,
          onStoryViewed:  widget.onStoryViewed,
          onStoryStarted: widget.onStoryStarted,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ));
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  //  Helpers
  // ════════════════════════════════════════
  bool _isVideo(String s) =>
      ['.mp4', '.mov', '.avi', '.mkv', '.webm'].any((e) => s.toLowerCase().endsWith(e));
  bool _isBase64(String s) => s.startsWith('data:image/');
  bool _isUrl(String s)    => s.startsWith('http');
  bool _isFile(String s)   => File(s).existsSync();

  // ✅ إزالة prefix "text:" من النص
  bool _isTextStory(String s) => s.startsWith('text:');
  String _extractText(String s) => s.replaceFirst('text:', '');

  String _formatTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1)  return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    return 'Yesterday';
  }

  ImageProvider? _getAvatar(String url) {
    if (url.isEmpty) return null;
    if (_isUrl(url))  return NetworkImage(url);
    if (_isFile(url)) return FileImage(File(url));
    return null;
  }

  // ════════════════════════════════════════
  //  Save / Delete
  // ════════════════════════════════════════
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final s = await Permission.storage.request();
      final p = await Permission.photos.request();
      final v = await Permission.videos.request();
      return s.isGranted || p.isGranted || v.isGranted;
    }
    return (await Permission.photos.request()).isGranted;
  }

  Future<void> _saveCurrentStory() async {
    final story = widget.storyModel.stories[_currentStoryIndex];
    if (!_isFile(story)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Only local files can be saved'),
          backgroundColor: Colors.red));
      return;
    }
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    if (!await _requestPermission()) {
      if (mounted) { Navigator.pop(context); return; }
    }
    bool ok = false;
    try {
      if (_isVideo(story)) {
        final r = await Process.run('cp', [story, '/sdcard/DCIM/']);
        ok = r.exitCode == 0;
      }
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✓ Saved' : '✗ Save Failed'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _deleteCurrentStory() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Status'),
      content: const Text('Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete')),
      ],
    ));
    if (ok != true || !mounted) return;

    final story  = widget.storyModel.stories[_currentStoryIndex];
    // ✅ جيب الـ apiId من الـ map أو من الـ model مباشرة
    final apiId  = widget.storyModel.storiesApiIds[story] ?? widget.storyModel.apiId;

    // ✅ امسح من السيرفر لو عندنا الـ id
    if (apiId != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      final deleted = await StatusService.deleteStatus(apiId);
      if (mounted) Navigator.pop(context); // أقفل الـ loading

      if (!deleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('  حدث خطأأثناءالحذف الحالة '), backgroundColor: Colors.red),
        );
        return;
      }
    }

    // امسح الملف المحلي لو موجود
    if (_isFile(story)) { try { await File(story).delete(); } catch (_) {} }

    widget.storyModel.stories.removeAt(_currentStoryIndex);
    widget.onStoryDeleted?.call(story);

    if (!mounted) return;
    if (widget.storyModel.stories.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () { if (mounted) Navigator.pop(context); });
    } else {
      setState(() {
        if (_currentStoryIndex >= widget.storyModel.stories.length) {
          _currentStoryIndex = widget.storyModel.stories.length - 1;
        }
      });
    }
  }

  void _sendReply() {
    final msg = _replyController.text.trim();
    if (msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reply sent: $msg'),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating));
    _replyController.clear();
    setState(() {});
  }

  // ════════════════════════════════════════
  //  Story Content Builder
  // ════════════════════════════════════════
  Widget _buildStoryContent(int index) {
    final story = widget.storyModel.stories[index];

    // ── Text Story ✅ ───────────────────────
    if (_isTextStory(story)) {
      final text = _extractText(story);
      return ColoredBox(
        color: const Color(0xFF128C7E),
        child: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(offset: Offset(0,1), blurRadius: 4, color: Colors.black45)],
            ),
          ),
        )),
      );
    }

    // ── Base64 ─────────────────────────────
    if (_isBase64(story)) {
      try {
        final bytes = base64Decode(story.split(',').last);
        final file  = File('${Directory.systemTemp.path}/s_$index.png')
          ..writeAsBytesSync(bytes);
        return SizedBox.expand(child: Image.file(file, fit: BoxFit.contain));
      } catch (_) {
        return _errorWidget('Cannot decode image');
      }
    }

    // ── Video ──────────────────────────────
    if (_isVideo(story)) {
      final path = story.startsWith('http')
          ? (_cachedVideoPaths[story] ?? story)
          : story;
      final isNetworkFallback = story.startsWith('http') && !_cachedVideoPaths.containsKey(story);
      return _VideoStoryWidget(
        key:        _getVideoKey(index),
        path:       path,
        isNetwork:  isNetworkFallback,
        onComplete: _nextStory,
        onReady: (dur) {
          if (mounted) _startProgress(dur);
        },
      );
    }

    // ── URL Image ──────────────────────────
    if (_isUrl(story)) {
      final cached = _cachedImagePaths[story];
      if (cached != null) {
        return SizedBox.expand(child: Image.file(File(cached), fit: BoxFit.contain));
      }
      return SizedBox.expand(
        child: Image.network(
          story,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, prog) => prog == null
              ? child
              : const ColoredBox(color: Colors.black,
              child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))),
          errorBuilder: (_, _, _) => _errorWidget('Cannot load image'),
        ),
      );
    }

    // ── Local File Image ───────────────────
    if (_isFile(story)) {
      return SizedBox.expand(
          child: Image.file(File(story), fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _errorWidget('Cannot load image')));
    }

    return _errorWidget('Cannot load content');
  }

  Widget _errorWidget(String msg) => ColoredBox(
      color: Colors.black,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
        const SizedBox(height: 8),
        Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ])));

  // ════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final stories = widget.storyModel.stories;
    final total   = stories.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Stories ────────────────────────
        PageView.builder(
          controller:  _pageController,
          itemCount:   total,
          physics:     const NeverScrollableScrollPhysics(),
          onPageChanged: _onPageChanged,
          itemBuilder: (_, i) => _buildStoryContent(i),
        ),

        // ✅ Gesture Layer — يفصل بين الضغط القصير والطويل
        Positioned.fill(
          child: GestureDetector(
            onLongPressStart: (_) => _pauseProgress(),   // ضغط طويل → وقف
            onLongPressEnd:   (_) => _resumeProgress(),  // رفع الإصبع → استكمال
            onTapUp: (d) {
              final half = MediaQuery.of(context).size.width / 2;
              d.globalPosition.dx > half ? _nextStory() : _prevStory();
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
            },
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),

        // ── Progress Bars ──────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: List.generate(total, (i) {
                  double val;
                  if (i < _currentStoryIndex)      val = 1.0;
                  else if (i == _currentStoryIndex) val = _progressValue;
                  else                              val = 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value:            val,
                          backgroundColor:  Colors.white30,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          minHeight:        2.5,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),

        // ── Header ─────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.only(top: 48, left: 16, right: 8, bottom: 8),
            decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.65), Colors.transparent])),
            child: SafeArea(bottom: false, child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white30,
                backgroundImage: _getAvatar(widget.storyModel.avatarUrl),
                child: widget.storyModel.avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white60) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.storyModel.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(offset: Offset(0,1), blurRadius: 3, color: Colors.black54)])),
                  if (_currentUploadTime != null || widget.storyModel.uploadedAt != null)
                    Text(_formatTime(_currentUploadTime ?? widget.storyModel.uploadedAt!),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
              if (widget.storyModel.id == '1')
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'delete') _deleteCurrentStory();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Row(children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 26)),
            ])),
          ),
        ),

        // ── Reply Bar ──────────────────────
        if (widget.storyModel.id != '1')
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
              child: SafeArea(top: false, child: Row(children: [
                Expanded(child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white30)),
                  child: TextField(
                    controller: _replyController,
                    focusNode:  _replyFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                        hintText: 'Reply to ${widget.storyModel.name}...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (v) { if (v.trim().isNotEmpty) _sendReply(); },
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _replyController.text.trim().isEmpty ? null : _sendReply,
                  child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                          color: _replyController.text.trim().isEmpty
                              ? Colors.white24 : const Color(0xFF25D366),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.send, color: Colors.white, size: 22)),
                ),
              ])),
            ),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Video Story Widget
// ═══════════════════════════════════════════════════════
class _VideoStoryWidget extends StatefulWidget {
  final String path;
  final bool isNetwork;
  final VoidCallback onComplete;
  final Function(Duration) onReady;

  const _VideoStoryWidget({
    super.key,
    required this.path,
    required this.isNetwork,
    required this.onComplete,
    required this.onReady,
  });

  @override
  State<_VideoStoryWidget> createState() => _VideoStoryWidgetState();
}

class _VideoStoryWidgetState extends State<_VideoStoryWidget> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    _ctrl = widget.isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
        : VideoPlayerController.file(File(widget.path));

    try {
      await _ctrl.initialize();
      if (!mounted) return;

      final raw = _ctrl.value.duration;
      final max = const Duration(seconds: 30);
      final dur = raw > max ? max : raw;

      setState(() => _initialized = true);
      _ctrl.play();
      widget.onReady(dur);

      _timer = Timer(dur, () {
        if (mounted) widget.onComplete();
      });
    } catch (e) {
      debugPrint('Video error: $e');
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
      }
    }
  }

  // ✅ pause و resume للفيديو
  void pause()  => _ctrl.pause();
  void resume() => _ctrl.play();

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const ColoredBox(color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)));
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width:  _ctrl.value.size.width,
          height: _ctrl.value.size.height,
          child: VideoPlayer(_ctrl),
        ),
      ),
    );
  }
}