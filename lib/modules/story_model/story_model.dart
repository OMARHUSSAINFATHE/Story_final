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