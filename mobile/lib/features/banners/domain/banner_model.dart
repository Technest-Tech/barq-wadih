/// Banner model matching the BannerResource API response.
class BannerModel {
  final int id;
  final String title;
  final String imageUrl;
  final String? imageUrlMobile;
  final String linkType; // 'ad', 'whatsapp', 'url', 'none'
  final int? linkAdId;
  final String? linkWhatsapp;
  final String? linkUrl;
  final String position;
  final int sortOrder;

  const BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.imageUrlMobile,
    required this.linkType,
    this.linkAdId,
    this.linkWhatsapp,
    this.linkUrl,
    required this.position,
    required this.sortOrder,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id:             json['id'] as int,
      title:          json['title'] as String? ?? '',
      imageUrl:       json['image_url'] as String? ?? '',
      imageUrlMobile: json['image_url_mobile'] as String?,
      linkType:       json['link_type'] as String? ?? 'none',
      linkAdId:       json['link_ad_id'] as int?,
      linkWhatsapp:   json['link_whatsapp'] as String?,
      linkUrl:        json['link_url'] as String?,
      position:       json['position'] as String? ?? '',
      sortOrder:      json['sort_order'] as int? ?? 0,
    );
  }
}
