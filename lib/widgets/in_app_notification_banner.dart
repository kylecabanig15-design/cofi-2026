import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cofi/models/notification_model.dart';
import 'package:cofi/services/notification_service.dart';

class InAppNotificationBannerManager extends StatefulWidget {
  final Widget child;

  const InAppNotificationBannerManager({super.key, required this.child});

  @override
  State<InAppNotificationBannerManager> createState() =>
      _InAppNotificationBannerManagerState();
}

class _InAppNotificationBannerManagerState
    extends State<InAppNotificationBannerManager> {
  StreamSubscription? _sub;
  NotificationModel? _currentNotification;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sub = NotificationService().inAppBannerStream.listen((notification) {
      if (mounted) {
        setState(() {
          _currentNotification = notification;
        });

        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _currentNotification = null;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final nav = Navigator.of(context);
    final notification = _currentNotification;

    setState(() {
      _currentNotification = null;
    });

    if (notification == null) return;

    if (notification.type == 'chat') {
      nav.pushNamed('/jobChat', arguments: {
        ...?notification.metadata,
        'conversationId': notification.relatedId,
      });
    } else {
      nav.pushNamed('/notifications'); // Default fallback
    }

    NotificationService().markAsRead(notification.id);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentNotification != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -100, end: 0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _handleTap,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < 0) {
                    setState(() {
                      _currentNotification = null;
                    });
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(
                          0xFF1E1E1E), // Solid dark grey, like Instagram
                      borderRadius: BorderRadius.circular(30), // Rounded pill
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconForType(_currentNotification!.type),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentNotification!.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight
                                      .w600, // Semi-bold like Instagram
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentNotification!.body,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                                maxLines: 1, // Usually just 1 line for body
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'now',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'job':
        return Icons.work_outline;
      case 'job_application':
        return Icons.assignment_ind_outlined;
      case 'business_application':
        return Icons.person_add_alt;
      case 'review':
        return Icons.star_outline;
      case 'event':
        return Icons.event;
      case 'event_participation':
        return Icons.how_to_reg;
      case 'recommendation':
        return Icons.recommend_outlined;
      case 'shop':
        return Icons.storefront_outlined;
      default:
        return Icons.notifications_none;
    }
  }
}
