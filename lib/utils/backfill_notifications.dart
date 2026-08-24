import 'package:cofi/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/services/notification_service.dart';

class BackfillNotifications {
  static Future<void> runBackfill() async {
    debugLog('🔄 Starting notification backfill process...');
    final firestore = FirebaseFirestore.instance;
    final notificationService = NotificationService();

    try {
      // 1. Backfill Job Applications for Businesses
      final shopsSnapshot = await firestore.collection('shops').get();
      
      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final ownerId = shopData['ownerId'] as String?;
        final shopId = shopDoc.id;
        
        if (ownerId == null) continue;

        final jobsSnapshot = await shopDoc.reference.collection('jobs').get();
        for (final jobDoc in jobsSnapshot.docs) {
          final jobData = jobDoc.data();
          final jobId = jobDoc.id;
          final applications = jobData['applications'] as List<dynamic>? ?? [];

          for (final application in applications) {
            if (application is Map<String, dynamic>) {
              final applicationId = application['id'] ?? '${jobId}_${application['applicantId']}';
              final applicantName = application['applicantName'] ?? 'Applicant';
              final appliedAt = application['appliedAt'] as Timestamp?;
              
              if (appliedAt != null) {
                debugLog('Backfilling application notification: $applicationId');
                await notificationService.createApplicationNotificationForBusiness(
                  ownerId,
                  applicationId,
                  applicantName,
                  jobId,
                  jobData['title'] ?? 'Job',
                  appliedAt,
                  shopId,
                );

                // Backfill for applicant (user)
                await notificationService.createJobApplicationNotification(
                  application['applicantId'],
                  applicationId,
                  applicantName,
                  application['status'] ?? 'pending',
                  appliedAt,
                  jobId,
                  jobData['title'] ?? 'Job',
                  shopData['name'] ?? 'Café',
                );
              }
            }
          }
        }

        // 3. Backfill Reviews
        final reviewsSnapshot = await shopDoc.reference.collection('reviews').get();
        for (final reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data();
          final reviewId = reviewDoc.id;
          final authorName = reviewData['authorName'] ?? 'A user';
          final reviewText = reviewData['text'] ?? '';
          final rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
          final imageUrl = reviewData['imageUrl'];
          final createdAt = reviewData['createdAt'] as Timestamp?;

          if (createdAt != null) {
            debugLog('Backfilling review notification: $reviewId');
            await notificationService.createReviewNotification(
              ownerId,
              reviewId,
              shopId,
              shopData['name'] ?? 'a café',
              authorName,
              reviewText,
              rating,
              imageUrl,
              createdAt,
            );
          }
        }

        // 4. Backfill Event Participations
        final eventsSnapshot = await shopDoc.reference.collection('events').get();
        for (final eventDoc in eventsSnapshot.docs) {
          final eventData = eventDoc.data();
          final eventId = eventDoc.id;
          final eventTitle = eventData['title'] ?? 'Event';

          final participantsSnapshot = await eventDoc.reference.collection('participants').get();
          for (final participantDoc in participantsSnapshot.docs) {
            final participantData = participantDoc.data();
            final participantId = participantDoc.id;
            final participantName = participantData['userName'] ?? 'A user';
            final joinedAt = participantData['joinedAt'] as Timestamp?;

            if (joinedAt != null && participantId != ownerId) {
              debugLog('Backfilling event participation notification: $participantId for event $eventId');
              await notificationService.createEventParticipationNotification(
                ownerId,
                eventId,
                eventTitle,
                shopId,
                participantName,
                participantId,
                joinedAt,
              );
            }
          }
        }
      }

      // 2. Backfill Job Chats
      final chatsSnapshot = await firestore.collection('job_chats').get();
      for (final chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final chatId = chatDoc.id;
        final jobId = chatData['jobId'] ?? '';
        final jobTitle = chatData['jobTitle'] ?? '';
        final shopId = chatData['shopId'] ?? '';
        final posterId = chatData['posterId'] ?? '';
        final applicantId = chatData['applicantId'] ?? '';
        final applicationId = chatData['applicationId'] ?? '';

        final messagesSnapshot = await chatDoc.reference.collection('messages').get();
        for (final messageDoc in messagesSnapshot.docs) {
          final messageData = messageDoc.data();
          final messageId = messageDoc.id;
          final senderId = messageData['senderId'];
          final senderName = messageData['senderName'] ?? 'User';
          final text = messageData['text'] ?? '';
          final timestamp = messageData['timestamp'] as Timestamp?;

          if (timestamp != null && senderId != null) {
            final recipientId = senderId == posterId ? applicantId : posterId;
            final recipientRole = recipientId == applicantId ? 'user' : 'business';
            debugLog('Backfilling chat message notification: $messageId');
            await notificationService.createChatNotification(
              recipientId,
              senderName,
              text,
              chatId,
              jobId,
              jobTitle,
              shopId,
              posterId,
              applicantId,
              applicationId,
              messageId,
              timestamp,
              recipientRole: recipientRole,
            );
          }
        }
      }

      debugLog('✅ Notification backfill completed successfully.');
    } catch (e) {
      debugLog('❌ Error during backfill: $e');
    }
  }
}
