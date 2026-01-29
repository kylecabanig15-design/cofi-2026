import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'event', 'job', 'shop', 'recommendation', 'review'
  final String? relatedId; // ID of the related document (event, job, or shop)
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;
  final bool isAlert; // TRUE for sound-enabled alerts, FALSE for silent notifications
  final String priority; // 'high', 'medium', 'low'

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.imageUrl,
    required this.createdAt,
    required this.isRead,
    this.isAlert = false,
    this.priority = 'low',
  });

  // Factory constructor to create a NotificationModel from Firestore document
  factory NotificationModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      relatedId: data['relatedId'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isAlert: data['isAlert'] ?? false,
      priority: data['priority'] ?? 'low',
    );
  }

  // Method to convert NotificationModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isAlert': isAlert,
      'priority': priority,
    };
  }

  // Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? relatedId,
    String? imageUrl,
    DateTime? createdAt,
    bool? isRead,
    bool? isAlert,
    String? priority,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isAlert: isAlert ?? this.isAlert,
      priority: priority ?? this.priority,
    );
  }
}
