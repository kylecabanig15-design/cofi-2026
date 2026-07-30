import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/models/notification_model.dart';
import 'package:cofi/services/notification_service.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/events/event_details_screen.dart';
import 'package:cofi/features/jobs/job_details_screen.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cofi/features/jobs/job_chat_screen.dart';
import 'package:cofi/features/business/business_profile_screen.dart';
import 'package:cofi/features/business/widgets/job_applications_sheet.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Chats', 'Jobs', 'Events', 'Cafés', 'Others'];
  String _accountType = 'user';
  bool _isLoadingRole = true;

  String _mapTypeToFilter(String type) {
    if (type == 'chat') return 'Chats';
    if (type.contains('job') || type == 'business_application') return 'Jobs';
    if (type.contains('event')) return 'Events';
    if (type == 'shop' || type == 'recommendation' || type == 'review') return 'Cafés';
    return 'Others';
  }

  Map<String, List<NotificationModel>> _groupNotifications(List<NotificationModel> notifications) {
    final grouped = {
      'Today': <NotificationModel>[],
      'This Week': <NotificationModel>[],
      'Older': <NotificationModel>[],
    };
    
    final now = DateTime.now();
    for (var n in notifications) {
      if (_selectedFilter != 'All' && _mapTypeToFilter(n.type) != _selectedFilter) continue;
      
      final diff = now.difference(n.createdAt);
      if (diff.inDays == 0 && now.day == n.createdAt.day) {
        grouped['Today']!.add(n);
      } else if (diff.inDays < 7) {
        grouped['This Week']!.add(n);
      } else {
        grouped['Older']!.add(n);
      }
    }
    
    return grouped;
  }

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _accountType = prefs.getString('account_type') ?? 'user';
        _isLoadingRole = false;
      });
    }
    // Check for new data and create notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.checkForNewData();
      // Mark all notifications as read when screen opens
      _notificationService.markAllAsRead(role: _accountType);
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
            color: Colors.grey[900],
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'read') {
                _notificationService.markAllAsRead(role: _accountType);
                CustomToast.showSuccess(context, 'All marked as read');
              } else if (value == 'clear') {
                _showClearAllDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'read',
                child: Text('Mark all as read', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear all', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoadingRole 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : StreamBuilder<List<NotificationModel>>(
                  stream: _notificationService.getUserNotifications(role: _accountType),
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

          final grouped = _groupNotifications(notifications);
          final hasItems = grouped.values.any((list) => list.isNotEmpty);

          if (!hasItems) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_list_off, size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  TextWidget(
                    text: 'No $_selectedFilter notifications',
                    fontSize: 16,
                    color: Colors.grey[500],
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: grouped.keys.length,
              itemBuilder: (context, sectionIndex) {
                final sectionKey = grouped.keys.elementAt(sectionIndex);
                final sectionItems = grouped[sectionKey]!;

                if (sectionItems.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: TextWidget(
                        text: sectionKey,
                        fontSize: 14,
                        color: Colors.white70,
                        isBold: true,
                      ),
                    ),
                    ...sectionItems.map((notification) {
                      return Dismissible(
                        key: Key(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          _notificationService.deleteNotification(notification.id);
                        },
                        child: _buildNotificationItem(notification),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: Colors.grey[900],
              selectedColor: primary.withOpacity(0.3),
              checkmarkColor: primary,
              labelStyle: TextStyle(
                color: isSelected ? primary : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? primary : Colors.transparent,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final bool isAlert = notification.isAlert;
    
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // ALERT: Gradient background for premium feel
          // NOTIFICATION: Simple dark background
          gradient: isAlert
              ? LinearGradient(
                  colors: [
                    _getNotificationColor(notification.type).withOpacity(0.15),
                    _getNotificationColor(notification.type).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isAlert 
              ? null 
              : (notification.isRead 
                  ? Colors.transparent 
                  : Colors.white.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAlert 
                ? _getNotificationColor(notification.type).withOpacity(0.4)
                : Colors.white12,
            width: isAlert ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert/Notification icon with enhanced sizing for alerts
            Container(
              width: isAlert ? 56 : 48,
              height: isAlert ? 56 : 48,
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type),
                borderRadius: BorderRadius.circular(isAlert ? 16 : 24),
                boxShadow: isAlert
                    ? [
                        BoxShadow(
                          color: _getNotificationColor(notification.type)
                              .withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: notification.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(isAlert ? 16 : 24),
                      child: CachedNetworkImage(
                        imageUrl: notification.imageUrl!,
                        width: isAlert ? 56 : 48,
                        height: isAlert ? 56 : 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildIconContainer(
                            notification.type, isAlert),
                        errorWidget: (context, url, error) =>
                            _buildIconContainer(notification.type, isAlert),
                      ),
                    )
                  : _buildIconContainer(notification.type, isAlert),
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
                        child: Row(
                          children: [
                            Flexible(
                              child: TextWidget(
                                text: notification.title,
                                fontSize: isAlert ? 17 : 16,
                                color: Colors.white,
                                isBold: isAlert || !notification.isRead,
                              ),
                            ),
                            // Sound badge for alerts
                            if (isAlert) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: primary.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.volume_up,
                                      color: primary,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    TextWidget(
                                      text: 'ALERT',
                                      fontSize: 10,
                                      color: primary,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                  const SizedBox(height: 6),
                  TextWidget(
                    text: notification.body,
                    fontSize: 14,
                    color: Colors.white70,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextWidget(
                        text: _formatTimestamp(notification.createdAt),
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      if (notification.priority == 'high') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TextWidget(
                            text: 'HIGH PRIORITY',
                            fontSize: 10,
                            color: Colors.orange,
                            isBold: true,
                          ),
                        ),
                      ],
                    ],
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

  Widget _buildIconContainer(String type, bool isAlert) {
    return Icon(
      _getNotificationIcon(type),
      color: Colors.white,
      size: isAlert ? 28 : 24,
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'event':
        return Colors.purple;
      case 'job':
        return Colors.green;
      case 'job_application':
      case 'business_application':
        return Colors.orange;
      case 'shop':
        return Colors.blue;
      case 'chat':
        return Colors.teal;
      case 'event_participation':
        return Colors.purpleAccent;
      case 'recommendation':
        return primary; // Distinct coffee/brown color for recommendations
      case 'review':
        return Colors.amber; // Gold color for review alerts
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
      case 'business_application':
        return Icons.work_history;
      case 'shop':
        return Icons.store;
      case 'chat':
        return Icons.chat;
      case 'event_participation':
        return Icons.group_add;
      case 'recommendation':
        return Icons.auto_awesome; // Sparkle icon for AI recommendations
      case 'review':
        return Icons.rate_review; // Review icon
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
      case 'review':
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
      case 'chat':
        if (notification.metadata != null) {
          try {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JobChatScreen(
                  jobId: notification.metadata!['jobId'] ?? '',
                  jobTitle: notification.metadata!['jobTitle'] ?? 'Job',
                  shopId: notification.metadata!['shopId'] ?? '',
                  posterId: notification.metadata!['posterId'] ?? '',
                  applicantId: notification.metadata!['applicantId'] ?? '',
                  applicationId: notification.metadata!['applicationId'] ?? '',
                ),
              ),
            );
          } catch (e) {
            print('Error navigating to chat: $e');
          }
        }
        break;
      case 'business_application':
        if (notification.metadata != null) {
          try {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => JobApplicationsBottomSheet(
                shopId: notification.metadata!['shopId'] ?? '',
              ),
            );
          } catch (e) {
            print('Error navigating to business applications: $e');
          }
        }
        break;
      case 'event_participation':
        if (notification.relatedId != null && notification.metadata != null) {
          try {
            // Fetch the shop event
            final eventSnapshot = await FirebaseFirestore.instance
                .collection('shops')
                .doc(notification.metadata!['shopId'])
                .collection('events')
                .doc(notification.relatedId)
                .get();

            if (eventSnapshot.exists) {
              final eventData = eventSnapshot.data() as Map<String, dynamic>?;
              if (eventData != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailsScreen(
                      event: {
                        ...eventData,
                        'id': notification.relatedId,
                        'shopId': notification.metadata!['shopId'],
                      },
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error navigating to event participation: $e');
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
              try {
                await _notificationService.deleteAllNotifications();
                if (mounted) {
                  CustomToast.showSuccess(context, 'Notifications cleared');
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  CustomToast.showError(context, 'Failed to clear notifications');
                }
              }
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
