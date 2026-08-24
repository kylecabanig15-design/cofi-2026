import 'package:cloud_firestore/cloud_firestore.dart';

class VisitLog {
  final String id;
  final String userId;
  final String userEmail;
  final String note;
  final List<String> tags;
  final DateTime createdAt;

  VisitLog({
    required this.id,
    required this.userId,
    this.userEmail = '',
    this.note = '',
    this.tags = const [],
    required this.createdAt,
  });

  factory VisitLog.fromFirestore(Map<String, dynamic> data, String id) {
    return VisitLog(
      id: id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      note: data['note'] as String? ?? '',
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'userEmail': userEmail,
        'note': note,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
