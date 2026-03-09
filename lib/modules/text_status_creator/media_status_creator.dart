import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import '../text_status_creator/text_status_creator.dart';

class MediaStatusCreator extends StatefulWidget {
  final ImageSource source;
  final String type;

  const MediaStatusCreator({super.key, required this.source, required this.type});

  @override
  State<MediaStatusCreator> createState() => _MediaStatusCreatorState();
}

class _MediaStatusCreatorState extends State<MediaStatusCreator> {
  File? _selectedFile;
  late String _fileType;
  final TextEditingController _captionController = TextEditingController();
  String _selectedVisibility = 'FRIENDS';
  bool _isLoading = false;
  bool _isCompressing = false;
  double _compressProgress = 0.0;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isPlaying = true;

  final ImagePicker _picker = ImagePicker();

  final Map<String, String> _visibilityOptions = {
    'FRIENDS': 'الأصدقاء',
    'PUBLIC': 'الجميع',
  };

  @override
  void initState() {
    super.initState();
    _fileType = widget.type;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickFile());
  }

  Future<void> _pickFile() async {
    await _disposeVideo();

    if (widget.type == 'VIDEO') {
      final XFile? picked = await _picker.pickVideo(
        source: widget.source,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked != null) {
        setState(() { _isCompressing = true; _compressProgress = 0; });

        final subscription = VideoCompress.compressProgress$.subscribe((progress) {
          if (mounted) setState(() => _compressProgress = progress / 100);
        });

        try {
          final MediaInfo? compressed = await VideoCompress.compressVideo(
            picked.path,
            quality: VideoQuality.LowQuality,  // ✅ أقل جودة = أصغر حجم
            deleteOrigin: false,
            includeAudio: true,
            frameRate: 24,
          );

          subscription.unsubscribe();
          if (!mounted) return;
          setState(() => _isCompressing = false);

          final File compressedFile = compressed?.file ?? File(picked.path);
          final sizeMB = compressedFile.lengthSync() / (1024 * 1024);
          debugPrint('📦 Compressed size: ${sizeMB.toStringAsFixed(1)} MB');

          if (sizeMB > 10) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('الفيديو لسه كبير (${sizeMB.toStringAsFixed(1)} MB) — اختار فيديو أقصر'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }

          setState(() { _selectedFile = compressedFile; _fileType = 'VIDEO'; });
          await _initVideo(compressedFile);

        } catch (e) {
          subscription.unsubscribe();
          if (mounted) setState(() => _isCompressing = false);
          debugPrint('Compression error: $e');
        }
      }
    } else {
      final XFile? picked = await _picker.pickImage(
        source: widget.source,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() { _selectedFile = File(picked.path); _fileType = 'IMAGE'; });
      }
    }
  }

  Future<void> _initVideo(File file) async {
    final controller = VideoPlayerController.file(file);
    _videoController = controller;
    await controller.initialize();
    if (!mounted) return;
    await controller.setLooping(true);
    await controller.play();
    setState(() { _videoInitialized = true; _isPlaying = true; });
  }

  Future<void> _disposeVideo() async {
    await _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;
  }

  void _togglePlay() {
    if (_videoController == null) return;
    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _publishStatus() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك اختار صورة أو فيديو')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await StatusService.createFileStatus(
      content: _captionController.text.trim(),
      visibility: _selectedVisibility,
      type: _fileType,
      statusFile: _selectedFile!,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفع ${_fileType == 'IMAGE' ? 'الصورة' : 'الفيديو'} بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء الرفع - تأكد من اتصال الإنترنت'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    VideoCompress.dispose();
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
                  Text(_visibilityOptions[_selectedVisibility]!,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoading
                ? const Center(child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : TextButton(
                    onPressed: _publishStatus,
                    child: const Text('نشر',
                      style: TextStyle(color: Color(0xFF25D366), fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isCompressing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _compressProgress > 0 ? _compressProgress : null,
                        color: const Color(0xFF25D366),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'جاري ضغط الفيديو... ${(_compressProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'قد يستغرق بعض الوقت',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : _selectedFile == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _fileType == 'IMAGE'
                  ? _buildImagePreview()
                  : _buildVideoPreview(),
          ),
          if (_selectedFile != null && !_isCompressing) ...[
           
            Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text('اختار تاني', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_selectedFile!, fit: BoxFit.contain),
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    if (!_videoInitialized || _videoController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('جاري تحميل الفيديو...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          Center(
            child: AnimatedOpacity(
              opacity: _isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF25D366),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}