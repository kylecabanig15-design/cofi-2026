import 'package:cofi/utils/logger.dart';
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
import 'package:cofi/features/business/widgets/job_applications_sheet.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:provider/provider.dart';
import 'package:cofi/services/user_session.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Chats',
    'Jobs',
    'Events',
    'Cafés',
    'Others'
  ];
  String _accountType = 'user';
  UserSession? _session;

  // Cached per-role stream. Recreating getUserNotifications() on every build
  // (filter-chip taps, pull-to-refresh) tore down and re-attached the live
  // Firestore listener, flashing a spinner and churning snapshot listeners.
  // Only a role change needs a new stream.
  Stream<List<NotificationModel>>? _notificationsStream;

  String _mapTypeToFilter(String type) {
    if (type == 'chat') return 'Chats';
    if (type.contains('job') || type == 'business_application') return 'Jobs';
    if (type.contains('event')) return 'Events';
    if (type == 'shop' ||
        type == 'recommendation' ||
        type == 'review' ||
        type == 'review_reply') {
      return 'Cafés';
    }
    return 'Others';
  }

  Map<String, List<NotificationModel>> _groupNotifications(
      List<NotificationModel> notifications) {
    final grouped = {
      'Today': <NotificationModel>[],
      'This Week': <NotificationModel>[],
      'Older': <NotificationModel>[],
    };

    final now = DateTime.now();
    for (var n in notifications) {
      if (_selectedFilter != 'All' &&
          _mapTypeToFilter(n.type) != _selectedFilter) {
        continue;
      }

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
    // Role is resolved synchronously here AND kept reactive below: UserSession
    // may still be resolving the user doc on cold start, so a one-shot read
    // pinned business owners to the 'user' feed.
    _session = context.read<UserSession>();
    _accountType = (_session?.isBusiness ?? false) ? 'business' : 'user';
    _session?.addListener(_handleSessionChanged);
    // Check for new data and create notifications, then mark all as read
    // for the current role once the screen is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.checkForNewData();
      _notificationService.markAllAsRead(role: _accountType);
    });
  }

  /// Fires whenever UserSession notifies (e.g. user doc finished loading and
  /// isBusiness flips). Reloads the feed for the new role and reruns the
  /// mark-all-read pass so business notifications don't linger unread.
  void _handleSessionChanged() {
    if (!mounted) return;
    final newRole = (_session?.isBusiness ?? false) ? 'business' : 'user';
    if (newRole == _accountType) return;
    setState(() => _accountType = newRole);
    // Cached stream must be rebuilt for the new role; StreamBuilder in
    // build() picks up the new stream from setState. Mark-all-read must
    // cover the newly active role as well.
    _notificationsStream =
        _notificationService.getUserNotifications(role: newRole);
    _notificationService.markAllAsRead(role: newRole);
  }

  @override
  void dispose() {
    _session?.removeListener(_handleSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary, size: 26),
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
            icon: const Icon(Icons.more_vert, color: primary),
            onSelected: (value) {
              if (value == 'read') {
                _notificationService.markAllAsRead(role: _accountType);
                CustomToast.showSuccess(
                  context,
                  'Every notification is now marked as read.',
                  title: 'Inbox updated',
                );
              } else if (value == 'clear') {
                _showClearAllDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'read',
                child: Text('Mark all as read',
                    style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear all',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: _notificationsStream ??=
                  _notificationService.getUserNotifications(role: _accountType),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primary),
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
                          color: primary,
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
                        const Icon(Icons.filter_list_off,
                            size: 48, color: primary),
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
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                            child: TextWidget(
                              text: sectionKey,
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.5),
                              isBold: true,
                            ),
                          ),
                          ...sectionItems.map((notification) {
                            return Dismissible(
                              key: Key(notification.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 28),
                                margin: const EdgeInsets.only(
                                    bottom: 12, right: 16, left: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0x00FF3B30), Color(0x22FF3B30)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: const Color(0x33FF3B30)),
                                ),
                                child: const FaIcon(FontAwesomeIcons.trashCan,
                                    color: Color(0xFFFF3B30), size: 22),
                              ),
                              onDismissed: (_) {
                                _notificationService
                                    .deleteNotification(notification.id);
                              },
                              child: _buildNotificationItem(notification),
                            );
                          }),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? primary : const Color(0xFF171513),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final isUnread = !notification.isRead;
    final hasImage = notification.imageUrl?.trim().isNotEmpty == true;
    final typeColor = _getNotificationColor(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isUnread ? typeColor.withValues(alpha: 0.03) : const Color(0xFF141210),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUnread
              ? typeColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.03),
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isUnread) {
              _notificationService.markAsRead(notification.id);
            }
            _navigateToRelatedContent(notification);
          },
          onLongPress: () => _showDeleteDialog(notification.id),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1F1C1A),
                            border: Border.all(
                              color: isUnread
                                  ? typeColor.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: hasImage
                                ? CachedNetworkImage(
                                    imageUrl: notification.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        _buildIconContainer(notification.type, typeColor),
                                    errorWidget: (_, __, ___) =>
                                        _buildIconContainer(notification.type, typeColor),
                                  )
                                : _buildIconContainer(notification.type, typeColor),
                          ),
                        ),
                      ),
                      if (hasImage)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141210),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2.5),
                            ),
                            child: Center(
                              child: FaIcon(
                                _getNotificationIcon(notification.type),
                                color: typeColor,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextWidget(
                              text: notification.title,
                              fontSize: 15,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextWidget(
                            text: _formatTimestamp(notification.createdAt),
                            fontSize: 12,
                            color: isUnread ? typeColor : Colors.white38,
                            isBold: isUnread,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextWidget(
                        text: notification.body,
                        fontSize: 14,
                        color: const Color(0xFFAAA39D),
                        maxLines: 3,
                      ),
                      if (notification.isAlert ||
                          notification.priority == 'high') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: typeColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.solidBell,
                                color: typeColor,
                                size: 10,
                              ),
                              const SizedBox(width: 5),
                              TextWidget(
                                text: notification.isAlert
                                    ? 'Important'
                                    : 'Priority',
                                fontSize: 11,
                                color: typeColor,
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(left: 14, top: 4),
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(String type, Color color) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [color.withValues(alpha: 0.6), color],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Center(
        child: FaIcon(
          _getNotificationIcon(type),
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'event':
      case 'event_participation':
        return const Color(0xFF62B79A); // _visitTeal
      case 'job':
      case 'job_application':
      case 'business_application':
        return const Color(0xFFE2A85C); // _ownerGold
      case 'shop':
      case 'recommendation':
        return const Color(0xFFB590D6); // _saveViolet
      case 'review':
      case 'review_reply':
      case 'chat':
        return const Color(0xFF78A7E8); // _feedbackBlue
      default:
        return primary;
    }
  }

  FaIconData _getNotificationIcon(String type) {
    switch (type) {
      case 'event':
        return FontAwesomeIcons.solidCalendarCheck;
      case 'job':
        return FontAwesomeIcons.briefcase;
      case 'job_application':
      case 'business_application':
        return FontAwesomeIcons.fileContract;
      case 'shop':
        return FontAwesomeIcons.store;
      case 'chat':
        return FontAwesomeIcons.solidCommentDots;
      case 'event_participation':
        return FontAwesomeIcons.userGroup;
      case 'recommendation':
        return FontAwesomeIcons.wandMagicSparkles;
      case 'review':
        return FontAwesomeIcons.solidStarHalfStroke;
      case 'review_reply':
        return FontAwesomeIcons.replyAll;
      default:
        return FontAwesomeIcons.solidBell;
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
                if (!mounted) return;
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
            debugLog('Error navigating to event: $e');
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
                if (!mounted) return;
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
            debugLog('Error navigating to job: $e');
          }
        }
        break;
      case 'shop':
      case 'review':
      case 'review_reply':
      case 'recommendation':
        // createRecommendationNotification stores a shop id in relatedId,
        // so recommendations route exactly like shops.
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
            debugLog('Error navigating to ${notification.type}: $e');
          }
        }
        break;
      case 'job_application':
        // Recipient is the applicant; there is no named-routeable screen
        // that shows application details from here, so surface the status
        // inline as a dialog instead of dead-ending.
        CustomDialog.showInfo(
          context: context,
          title: notification.title,
          message: notification.body,
          buttonText: 'Close',
          icon: Icons.work_outline_rounded,
        );
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
                  conversationId: notification.relatedId ??
                      notification.metadata!['conversationId'],
                ),
              ),
            );
          } catch (e) {
            debugLog('Error navigating to chat: $e');
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
            debugLog('Error navigating to business applications: $e');
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
              final eventData = eventSnapshot.data();
              if (eventData != null) {
                if (!mounted) return;
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
            debugLog('Error navigating to event participation: $e');
          }
        }
        break;
    }
  }

  Future<void> _showDeleteDialog(String notificationId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await CustomDialog.confirm(
      context: context,
      title: 'Delete notification?',
      message: 'This notification will be permanently removed.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await _notificationService.deleteNotification(notificationId);
      if (mounted) setState(() {});
      CustomToast.showFromMessenger(
        messenger,
        'The notification was removed.',
        type: ToastType.success,
        title: 'Notification deleted',
      );
    } catch (_) {
      CustomToast.showFromMessenger(
        messenger,
        'We could not delete the notification. Please try again.',
        type: ToastType.error,
        title: 'Delete failed',
      );
    }
  }

  Future<void> _showClearAllDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await CustomDialog.confirm(
      context: context,
      title: 'Clear all notifications?',
      message: 'Every notification in your inbox will be permanently removed.',
      confirmText: 'Clear all',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await _notificationService.deleteAllNotifications();
      if (mounted) setState(() {});
      CustomToast.showFromMessenger(
        messenger,
        'Your notification inbox is now clear.',
        type: ToastType.success,
        title: 'Notifications cleared',
      );
    } catch (_) {
      CustomToast.showFromMessenger(
        messenger,
        'We could not clear notifications. Please try again.',
        type: ToastType.error,
        title: 'Clear failed',
      );
    }
  }
}
