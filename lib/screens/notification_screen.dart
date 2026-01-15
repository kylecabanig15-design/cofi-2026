import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/colors.dart';
import '../widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/subscreens/event_details_screen.dart';
import '../screens/job_details_screen.dart';
import '../screens/subscreens/cafe_details_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Check for new data and create notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.checkForNewData();
      // Mark all notifications as read when screen opens
      _notificationService.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: TextWidget(
          text: 'Notifications',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[800],
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _notificationService.markAllAsRead();
                setState(() {});
              } else if (value == 'clear_all') {
                _showClearAllDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'mark_all_read',
                child: Text(
                  'Mark all as read',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear_all',
                child: Text(
                  'Clear all',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: TextWidget(
                text: 'Error loading notifications',
                fontSize: 16,
                color: Colors.redAccent,
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  TextWidget(
                    text: 'No notifications yet',
                    fontSize: 18,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  TextWidget(
                    text:
                        'You\'ll see notifications for new events, jobs, and shops here',
                    fontSize: 14,
                    color: Colors.grey[500],
                    align: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              return;
            },
            color: primary,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(
                color: Colors.white24,
                thickness: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return GestureDetector(
      onTap: () {
        // Mark as read when tapped
        if (!notification.isRead) {
          _notificationService.markAsRead(notification.id);
        }

        // Navigate to related content
        _navigateToRelatedContent(notification);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: notification.isRead
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.05),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification icon/image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type),
                borderRadius: BorderRadius.circular(24),
              ),
              child: notification.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CachedNetworkImage(
                        imageUrl: notification.imageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getNotificationColor(notification.type),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            _getNotificationIcon(notification.type),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getNotificationColor(notification.type),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            _getNotificationIcon(notification.type),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      _getNotificationIcon(notification.type),
                      color: Colors.white,
                      size: 24,
                    ),
            ),

            const SizedBox(width: 16),

            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextWidget(
                          text: notification.title,
                          fontSize: 16,
                          color: Colors.white,
                          isBold: !notification.isRead,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextWidget(
                    text: notification.body,
                    fontSize: 14,
                    color: Colors.white70,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  TextWidget(
                    text: _formatTimestamp(notification.createdAt),
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _showDeleteDialog(notification.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'event':
        return Colors.purple;
      case 'job':
        return Colors.green;
      case 'job_application':
        return Colors.orange;
      case 'shop':
        return Colors.blue;
      default:
        return primary;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'event':
        return Icons.event;
      case 'job':
        return Icons.work;
      case 'job_application':
        return Icons.work_history;
      case 'shop':
        return Icons.store;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _navigateToRelatedContent(NotificationModel notification) async {
    switch (notification.type) {
      case 'event':
        if (notification.relatedId != null) {
          try {
            // Fetch the full event data
            // First try to find which shop contains this event
            final shopsSnapshot =
                await FirebaseFirestore.instance.collection('shops').get();
            DocumentSnapshot? eventDoc;

            for (final shopDoc in shopsSnapshot.docs) {
              final eventSnapshot = await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopDoc.id)
                  .collection('events')
                  .doc(notification.relatedId)
                  .get();

              if (eventSnapshot.exists) {
                eventDoc = eventSnapshot;
                break;
              }
            }

            if (eventDoc != null && eventDoc.exists) {
              final eventData = eventDoc.data() as Map<String, dynamic>?;
              if (eventData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailsScreen(
                      event: {
                        ...eventData,
                        'id': notification.relatedId,
                      },
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error navigating to event: $e');
          }
        }
        break;
      case 'job':
        if (notification.relatedId != null) {
          try {
            // Fetch the full job data
            // First try to find which shop contains this job
            final shopsSnapshot =
                await FirebaseFirestore.instance.collection('shops').get();
            DocumentSnapshot? jobDoc;

            for (final shopDoc in shopsSnapshot.docs) {
              final jobSnapshot = await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopDoc.id)
                  .collection('jobs')
                  .doc(notification.relatedId)
                  .get();

              if (jobSnapshot.exists) {
                jobDoc = jobSnapshot;
                break;
              }
            }

            if (jobDoc != null && jobDoc.exists) {
              final jobData = jobDoc.data() as Map<String, dynamic>?;
              if (jobData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JobDetailsScreen(
                      job: {
                        ...jobData,
                        'id': notification.relatedId,
                      },
                      shopId: jobData['shopId'] ?? '',
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error navigating to job: $e');
          }
        }
        break;
      case 'shop':
        if (notification.relatedId != null) {
          try {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CafeDetailsScreen(
                  shopId: notification.relatedId!,
                ),
              ),
            );
          } catch (e) {
            print('Error navigating to shop: $e');
          }
        }
        break;
    }
  }

  void _showDeleteDialog(String notificationId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Notification',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this notification?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _notificationService.deleteNotification(notificationId);
              setState(() {});
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to clear all notifications?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Implementation for clearing all notifications would go here
              setState(() {});
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
