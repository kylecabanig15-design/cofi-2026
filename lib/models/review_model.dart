import 'package:cloud_firestore/cloud_firestore.dart';

/// Accepts Timestamp, ISO String, DateTime or null (→ null).
DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Epoch placeholder so missing dates sort to the bottom instead of being
/// faked as "today". No widget renders this value directly (screens read
/// raw Firestore data), so the sentinel never surfaces in the UI.
DateTime get _epochDate => DateTime.fromMillisecondsSinceEpoch(0);

class ReviewResponse {
  final String id;
  final String ownerName;
  final String ownerAvatarUrl;
  final String responseText;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewResponse({
    required this.id,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.responseText,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReviewResponse.fromFirestore(Map<String, dynamic> data, String id) {
    return ReviewResponse(
      id: id,
      ownerName: data['ownerName'] ?? '',
      ownerAvatarUrl: data['ownerAvatarUrl'] ?? '',
      responseText: data['responseText'] ?? '',
      createdAt: _parseDate(data['createdAt']) ?? _epochDate,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerName': ownerName,
      'ownerAvatarUrl': ownerAvatarUrl,
      'responseText': responseText,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

class Review {
  final String id;
  final String userId;

  /// Reads authorName with fallback to legacy `name`.
  final String authorName;
  final String? authorPhotoUrl;
  final String text;

  /// Reads text with fallback to legacy `comment`.
  final int rating;
  final List<String> tags;
  final String? imageUrl;
  final DateTime createdAt;
  final List<ReviewResponse> responses;

  Review({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.rating,
    required this.tags,
    this.imageUrl,
    required this.createdAt,
    required this.responses,
  });

  factory Review.fromFirestore(Map<String, dynamic> data, String id) {
    final responses = ((data['responses'] as List?) ?? [])
        .whereType<Map>()
        .map((r) => ReviewResponse.fromFirestore(
            Map<String, dynamic>.from(r),
            (r['id'] as String?) ?? ''))
        .toList();
    return Review(
      id: id,
      userId: data['userId'] ?? '',
      authorName: data['authorName'] as String? ??
          data['name'] as String? ??
          'Anonymous',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      text: data['text'] as String? ?? data['comment'] as String? ?? '',
      rating: data['rating'] ?? 0,
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      imageUrl: data['imageUrl'] as String?,
      createdAt: _parseDate(data['createdAt']) ?? _epochDate,
      responses: responses,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'rating': rating,
      'tags': tags,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'responses': responses.map((r) => r.toFirestore()).toList(),
    };
  }
}
