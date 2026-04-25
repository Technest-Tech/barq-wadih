// lib/features/stories/domain/story_model.dart

class StoryItem {
  final int id;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String? imageUrl;
  final String title;
  final String? description;
  final DateTime createdAt;
  final bool isSeen;
  final String? adCategory;
  final int? adId;
  final String? contactPhone;
  final String? price;

  const StoryItem({
    required this.id,
    required this.ownerName,
    this.ownerAvatarUrl,
    this.imageUrl,
    required this.title,
    this.description,
    required this.createdAt,
    this.isSeen = false,
    this.adCategory,
    this.adId,
    this.contactPhone,
    this.price,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] as int,
      ownerName: json['owner_name'] as String? ?? '',
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      imageUrl: json['image_url'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      isSeen: json['is_seen'] as bool? ?? false,
      adCategory: json['ad_category'] as String?,
      adId: json['ad_id'] as int?,
      contactPhone: json['contact_phone'] as String?,
      price: json['price'] as String?,
    );
  }
}
