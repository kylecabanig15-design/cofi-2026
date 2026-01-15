import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewResponse {
  final String id;
  final String ownerName;
  final String ownerAvatarUrl;
  final String responseText;
  final DateTime createdAt;

  ReviewResponse({
    required this.id,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.responseText,
    required this.createdAt,
  });

  factory ReviewResponse.fromFirestore(Map<String, dynamic> data, String id) {
    return ReviewResponse(
      id: id,
      ownerName: data['ownerName'] ?? '',
      ownerAvatarUrl: data['ownerAvatarUrl'] ?? '',
      responseText: data['responseText'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerName': ownerName,
      'ownerAvatarUrl': ownerAvatarUrl,
      'responseText': responseText,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Review {
  final String id;
  final String userId;
  final String authorName;
  final String text;
  final int rating;
  final List<String> tags;
  final String? imageUrl;
  final DateTime createdAt;
  final List<ReviewResponse> responses;

  Review({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.text,
    required this.rating,
    required this.tags,
    this.imageUrl,
    required this.createdAt,
    required this.responses,
  });

  factory Review.fromFirestore(Map<String, dynamic> data, String id) {
    final responses = (data['responses'] as List?)
            ?.map((r) => ReviewResponse.fromFirestore(
                r as Map<String, dynamic>, r['id'] as String? ?? ''))
            .toList() ??
        [];
    return Review(
      id: id,
      userId: data['userId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      text: data['text'] ?? '',
      rating: data['rating'] ?? 0,
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      responses: responses,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'authorName': authorName,
      'text': text,
      'rating': rating,
      'tags': tags,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'responses': responses.map((r) => r.toFirestore()).toList(),
    };
  }
}
