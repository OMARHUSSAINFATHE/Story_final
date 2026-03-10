import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../story_model/story_model.dart';

class StatusCard extends StatefulWidget {
  final StoryModel storyModel;
  final bool isViewed;

  const StatusCard({
    super.key,
    required this.storyModel,
    this.isViewed = false,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  final Color backgroundcolor = Colors.green;

  Color get _borderColor =>
      widget.isViewed ? Colors.grey : backgroundcolor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.w,
      height: 250.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor,
          width: 3.w,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              start: 8.w,
              bottom: 10.h,
              end: 8.w,
              child: Text(
                widget.storyModel.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PositionedDirectional(
              start: 60.w,
              bottom: 90.h,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _borderColor,
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      _getAvatarImage(widget.storyModel.avatarUrl),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = widget.storyModel.imageUrl;

    // ✅ video: prefix
    if (url.startsWith('video:')) {
      final videoUrl = url.replaceFirst('video:', '');
      if (videoUrl.startsWith('http')) {
        return Container(
          color: Colors.grey.shade900,
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 48),
          ),
        );
      }
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: videoUrl,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Stack(fit: StackFit.expand, children: [
              Image.memory(snapshot.data!, fit: BoxFit.cover),
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
              ),
            ]);
          }
          return Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 48),
            ),
          );
        },
      );
    }

    // ✅ text: prefix
    if (url.startsWith('text:')) {
      final text = url.replaceFirst('text:', '').split('|color:').first;
      return Container(
        color: const Color(0xFF128C7E),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(text,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    /// 🎥 فيديو بامتداد .mp4
    if (url.toLowerCase().endsWith('.mp4')) {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: url,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Stack(fit: StackFit.expand, children: [
              Image.memory(snapshot.data!, fit: BoxFit.cover),
            ]);
          }
          return _placeholder();
        },
      );
    }

    /// 🖼 صورة محلية
    if (widget.storyModel.isLocalImage) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      } else {
        return _placeholder();
      }
    }

    /// 🌐 صورة من النت
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, _) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, _, __) => _placeholder(),
      );
    }

    /// 📦 صورة من assets
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.broken_image,
            color: Colors.black54, size: 40),
      ),
    );
  }

  ImageProvider _getAvatarImage(String url) {
    if (url.startsWith('http')) {
      return CachedNetworkImageProvider(url);
    }
    return AssetImage(url);
  }
}