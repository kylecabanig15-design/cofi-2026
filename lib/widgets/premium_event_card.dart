import 'dart:ui';
import 'package:cofi/features/events/event_details_screen.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PremiumEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String eventId;
  final double width;
  final double height;

  const PremiumEventCard({
    super.key,
    required this.event,
    required this.eventId,
    this.width = double.infinity,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Determine Event Status (Ongoing, Upcoming, Paused)
    final startDate = event['startDate'];
    final endDate = event['endDate'];
    DateTime? startDateTime;
    DateTime? endDateTime;

    if (startDate is Timestamp) {
      startDateTime = startDate.toDate();
    } else if (startDate is String && startDate.isNotEmpty) {
      try {
        startDateTime = DateTime.parse(startDate);
      } catch (_) {}
    }

    if (endDate is Timestamp) {
      endDateTime = endDate.toDate();
    } else if (endDate is String && endDate.isNotEmpty) {
      try {
        endDateTime = DateTime.parse(endDate);
      } catch (_) {}
    }

    final now = DateTime.now();
    final isOngoing = startDateTime != null &&
        startDateTime.isBefore(now) &&
        (endDateTime == null || endDateTime.isAfter(now));
    
    final isPaused = event['isPaused'] == true;

    // 2. Build Card
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: {
                ...event,
                'id': eventId,
              }),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                if (event['imageUrl']?.toString().startsWith('http') == true)
                  CachedNetworkImage(
                    imageUrl: event['imageUrl'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: const Color(0xFF1E1E1E)),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(Icons.event, color: Colors.white24, size: 48),
                    ),
                  )
                else
                  Container(color: const Color(0xFF1E1E1E)),

                // Paused Overlay (Darker)
                if (isPaused)
                  Container(color: Colors.black.withOpacity(0.6)),

                // Gradient Overlay for Text Readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),

                // Top Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getBadgeColor(isPaused, isOngoing).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                        child: TextWidget(
                          text: _getBadgeText(isPaused, isOngoing),
                          fontSize: 11,
                          color: Colors.white,
                          isBold: true,
                        ),
                      ),
                    ),
                  ),
                ),

                // Content (Bottom)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextWidget(
                        text: (event['title'] ?? 'Event').toString(),
                        fontSize: 20,
                        color: Colors.white,
                        isBold: true,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextWidget(
                              text: _eventSubtitle(event),
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
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

  Color _getBadgeColor(bool isPaused, bool isOngoing) {
    if (isPaused) return Colors.red.shade700;
    if (isOngoing) return Colors.green.shade600;
    return Colors.amber.shade700;
  }

  String _getBadgeText(bool isPaused, bool isOngoing) {
    if (isPaused) return 'PAUSED';
    if (isOngoing) return 'ONGOING TODAY';
    return 'UPCOMING';
  }

  String _eventSubtitle(Map<String, dynamic> event) {
    final date = event['date'];
    final start = event['startDate'];
    final end = event['endDate'];

    DateTime? startDate;
    DateTime? endDate;

    if (start is Timestamp) {
      startDate = start.toDate();
    } else if (start is String && start.isNotEmpty) {
      try { startDate = DateTime.parse(start); } catch (_) {}
    }

    if (end is Timestamp) {
      endDate = end.toDate();
    } else if (end is String && end.isNotEmpty) {
      try { endDate = DateTime.parse(end); } catch (_) {}
    }

    if (startDate != null) {
      if (endDate != null && endDate.year == startDate.year &&
          endDate.month == startDate.month && endDate.day == startDate.day) {
        return _formatDate(startDate);
      } else if (endDate != null) {
        return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
      } else {
        return _formatDate(startDate);
      }
    }

    if (date is String && date.isNotEmpty) return date;
    return 'Date TBD';
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
