import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  const Promotion({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.title,
    required this.offer,
    required this.description,
    required this.terms,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.imageUrl,
    required this.logoUrl,
    this.imageSource = '',
  });

  final String id;
  final String shopId;
  final String shopName;
  final String title;
  final String offer;
  final String description;
  final String terms;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String imageUrl;
  final String logoUrl;
  final String imageSource;

  bool get isPublished => status.toLowerCase() == 'published';
  bool get hasDedicatedImage =>
      imageSource == 'promotion' && imageUrl.trim().isNotEmpty;

  bool isActiveAt(DateTime now) =>
      isPublished &&
      startDate != null &&
      endDate != null &&
      !startDate!.isAfter(now) &&
      endDate!.isAfter(now);

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Promotion.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return Promotion(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      shopName: (data['shopName'] ?? 'Local café').toString(),
      title: (data['title'] ?? 'Special offer').toString(),
      offer: (data['offer'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      terms: (data['terms'] ?? '').toString(),
      startDate: _date(data['startDate']),
      endDate: _date(data['endDate']),
      status: (data['status'] ?? 'draft').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      logoUrl: (data['logoUrl'] ?? '').toString(),
      imageSource: (data['imageSource'] ?? '').toString(),
    );
  }
}
