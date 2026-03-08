import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════════
//  CacheService
// ═══════════════════════════════════════════════════════
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static final CacheManager imageCache = CacheManager(
    Config(
      'status_images',
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: 'status_images'),
    ),
  );

  static final CacheManager videoCache = CacheManager(
    Config(
      'status_videos',
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: 'status_videos'),
    ),
  );

  Future<File?> cacheImage(String url) async {
    try { return await imageCache.getSingleFile(url); }
    catch (e) { debugPrint('Error caching image: $e'); return null; }
  }

  Future<File?> cacheVideo(String url) async {
    try { return await videoCache.getSingleFile(url); }
    catch (e) { debugPrint('Error caching video: $e'); return null; }
  }

  Future<bool> isInCache(String url, {bool isVideo = false}) async {
    try {
      final info = await (isVideo ? videoCache : imageCache).getFileFromCache(url);
      return info != null;
    } catch (_) { return false; }
  }

  Future<File?> getFromCache(String url, {bool isVideo = false}) async {
    try {
      final info = await (isVideo ? videoCache : imageCache).getFileFromCache(url);
      return info?.file;
    } catch (e) { debugPrint('Error getting from cache: $e'); return null; }
  }

  Stream<FileResponse> downloadWithProgress(String url, {bool isVideo = false}) =>
      (isVideo ? videoCache : imageCache).getFileStream(url);

  Future<void> removeFromCache(String url, {bool isVideo = false}) async {
    try { await (isVideo ? videoCache : imageCache).removeFile(url); }
    catch (e) { debugPrint('Error removing: $e'); }
  }

  Future<void> clearImageCache() async {
    try { await imageCache.emptyCache(); }
    catch (e) { debugPrint('Error clearing images: $e'); }
  }

  Future<void> clearVideoCache() async {
    try { await videoCache.emptyCache(); }
    catch (e) { debugPrint('Error clearing videos: $e'); }
  }

  Future<void> clearAllCache() async {
    await clearImageCache();
    await clearVideoCache();
  }

  Future<File?> saveLocalFileToCache(String filePath, String key) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final isVid = filePath.toLowerCase().endsWith('.mp4') ||
          filePath.toLowerCase().endsWith('.mov') ||
          filePath.toLowerCase().endsWith('.avi');
      final bytes = await file.readAsBytes();
      return await (isVid ? videoCache : imageCache)
          .putFile(key, bytes, fileExtension: isVid ? 'mp4' : 'jpg');
    } catch (e) { debugPrint('Error saving to cache: $e'); return null; }
  }

  /// حجم الـ Cache مقسّم: صور + فيديوهات + بيانات (JSON)
  Future<CacheSizeInfo> getCacheSize() async {
    int imageCount = 0, imageSize = 0;
    int videoCount = 0, videoSize = 0;
    int dataCount  = 0, dataSize  = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is! File) continue;
          final size = await entity.length();
          final name = entity.path.toLowerCase();

          if (name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.avi')) {
            videoCount++; videoSize += size;
          } else if (name.endsWith('.jpg') || name.endsWith('.jpeg') ||
              name.endsWith('.png') || name.endsWith('.webp')) {
            imageCount++; imageSize += size;
          } else if (name.endsWith('.json')) {
            dataCount++; dataSize += size;
          }
        }
      }
    } catch (e) { debugPrint('Error getting cache size: $e'); }

    return CacheSizeInfo(
      imageCount: imageCount, imageSize: imageSize,
      videoCount: videoCount, videoSize: videoSize,
      dataCount:  dataCount,  dataSize:  dataSize,
    );
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ═══════════════════════════════════════════════════════
//  Model لبيانات الحجم
// ═══════════════════════════════════════════════════════
class CacheSizeInfo {
  final int imageCount, imageSize;
  final int videoCount, videoSize;
  final int dataCount,  dataSize;

  CacheSizeInfo({
    required this.imageCount, required this.imageSize,
    required this.videoCount, required this.videoSize,
    required this.dataCount,  required this.dataSize,
  });

  int get totalSize => imageSize + videoSize + dataSize;
  int get totalCount => imageCount + videoCount + dataCount;
}

// ═══════════════════════════════════════════════════════
//  صفحة Cache Management الكاملة
// ═══════════════════════════════════════════════════════
class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  final _cache = CacheService();
  CacheSizeInfo? _info;
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final info = await _cache.getCacheSize();
    if (mounted) setState(() { _info = info; _loading = false; });
  }

  Future<void> _clearAll() async {
    setState(() => _clearing = true);
    await _cache.clearAllCache();
    await _load();
    setState(() => _clearing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Cache cleared successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearImages() async {
    setState(() => _clearing = true);
    await _cache.clearImageCache();
    await _load();
    setState(() => _clearing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Image cache cleared'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearVideos() async {
    setState(() => _clearing = true);
    await _cache.clearVideoCache();
    await _load();
    setState(() => _clearing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Video cache cleared'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Cache Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clearing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.red),
                      SizedBox(height: 16),
                      Text('Clearing cache...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── بطاقة الإجمالي ──────────────────────
                        _TotalCard(info: _info!, cache: _cache),
                        const SizedBox(height: 16),

                        // ── تفاصيل ───────────────────────────────
                        const Text('Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),

                        _CacheTypeCard(
                          icon: Icons.image_rounded,
                          color: Colors.blue,
                          label: 'Images',
                          count: _info!.imageCount,
                          size: _cache.formatBytes(_info!.imageSize),
                          onClear: _info!.imageCount > 0 ? _clearImages : null,
                        ),
                        const SizedBox(height: 8),
                        _CacheTypeCard(
                          icon: Icons.videocam_rounded,
                          color: Colors.red,
                          label: 'Videos',
                          count: _info!.videoCount,
                          size: _cache.formatBytes(_info!.videoSize),
                          onClear: _info!.videoCount > 0 ? _clearVideos : null,
                        ),
                        const SizedBox(height: 8),
                        _CacheTypeCard(
                          icon: Icons.data_object_rounded,
                          color: Colors.orange,
                          label: 'App Data',
                          count: _info!.dataCount,
                          size: _cache.formatBytes(_info!.dataSize),
                          onClear: null, // بيانات الـ app مش بنمسحها
                          clearLabel: 'Protected',
                        ),

                        const SizedBox(height: 24),

                        // ── زرار Clear All ───────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _info!.totalCount > 0 ? _confirmClearAll : null,
                            icon: const Icon(Icons.delete_sweep_rounded),
                            label: const Text('Clear All Cache',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'Cache will be rebuilt automatically when needed',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Cache?'),
        content: Text(
          'This will delete ${_cache.formatBytes(_info!.totalSize)} of cached files.\n'
          'They will be re-downloaded when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _clearAll(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  بطاقة الإجمالي
// ═══════════════════════════════════════════════════════
class _TotalCard extends StatelessWidget {
  final CacheSizeInfo info;
  final CacheService cache;
  const _TotalCard({required this.info, required this.cache});

  @override
  Widget build(BuildContext context) {
    final percent = info.totalSize == 0
        ? 0.0
        : (info.imageSize + info.videoSize) / (info.totalSize == 0 ? 1 : info.totalSize);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Cache Size',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            cache.formatBytes(info.totalSize),
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // شريط مقسّم: صور / فيديوهات
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              backgroundColor: Colors.red.withOpacity(0.6),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _dot(Colors.blue), const SizedBox(width: 4),
              Text('Images  ', style: _legendStyle),
              _dot(Colors.red), const SizedBox(width: 4),
              Text('Videos', style: _legendStyle),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _StatChip(label: '${info.imageCount}', sublabel: 'images', color: Colors.blue),
            const SizedBox(width: 8),
            _StatChip(label: '${info.videoCount}', sublabel: 'videos', color: Colors.red),
            const SizedBox(width: 8),
            _StatChip(label: '${info.dataCount}',  sublabel: 'data files', color: Colors.orange),
          ]),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 8, height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  TextStyle get _legendStyle =>
      const TextStyle(color: Colors.white60, fontSize: 12);
}

class _StatChip extends StatelessWidget {
  final String label, sublabel;
  final Color color;
  const _StatChip({required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sublabel, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  بطاقة نوع الـ Cache
// ═══════════════════════════════════════════════════════
class _CacheTypeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, size;
  final int count;
  final VoidCallback? onClear;
  final String clearLabel;

  const _CacheTypeCard({
    required this.icon, required this.color,
    required this.label, required this.count,
    required this.size, this.onClear,
    this.clearLabel = 'Clear',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$count files • $size',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(clearLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(clearLabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Dialog بسيط (للـ AppBar)
// ═══════════════════════════════════════════════════════
class CacheManagementDialog extends StatelessWidget {
  const CacheManagementDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // بدل dialog → افتح الصفحة الكاملة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CacheManagementPage()));
    });
    return const SizedBox.shrink();
  }
}
