import 'package:cofi/features/events/event_details_screen.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExploreEventsSection extends StatefulWidget {
  const ExploreEventsSection({super.key});

  @override
  State<ExploreEventsSection> createState() => _ExploreEventsSectionState();
}

class _ExploreEventsSectionState extends State<ExploreEventsSection> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _eventsStream = FirebaseFirestore.instance
        .collectionGroup('events')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 230,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Failed to load events',
                style: TextStyle(color: Colors.white70)),
          );
        }
        final docs = snapshot.data?.docs ?? [];

        // Auto-archive finished events (mark them as archived)
        for (final doc in docs) {
          final event = doc.data();
          final endDate = event['endDate'];
          bool isFinished = false;

          if (endDate is String && endDate.isNotEmpty) {
            try {
              final end = DateTime.parse(endDate);
              isFinished = end.isBefore(now);
            } catch (_) {}
          }

          // If event is finished and not yet marked as archived, mark it
          if (isFinished && event['isArchived'] != true) {
            doc.reference.update({'isArchived': true}).catchError((_) {});
          }
        }

        // Filter to only show UPCOMING events (not started, not ended)
        // NOTE: Paused events are still shown with a visual indicator
        final upcomingEvents = docs.where((doc) {
          final event = doc.data();

          // First: Check if event has ended
          final endDate = event['endDate'];
          DateTime? endDateTime;
          if (endDate is Timestamp) {
            endDateTime = endDate.toDate();
          } else if (endDate is String && endDate.isNotEmpty) {
            try {
              endDateTime = DateTime.parse(endDate);
            } catch (_) {}
          }

          // If event has ended, don't show
          if (endDateTime != null && endDateTime.isBefore(now)) {
            return false;
          }

          // Second: Check if event has started
          final startDate = event['startDate'];
          DateTime? startDateTime;
          if (startDate is Timestamp) {
            startDateTime = startDate.toDate();
          } else if (startDate is String && startDate.isNotEmpty) {
            try {
              startDateTime = DateTime.parse(startDate);
            } catch (_) {}
          }

          // Only show if start date is in the future (hasn't started yet)
          if (startDateTime != null) {
            return startDateTime.isAfter(now);
          }

          // If no valid dates found, don't show
          return false;
        }).toList();

        if (upcomingEvents.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.event_busy_rounded, size: 32, color: Colors.white38),
                SizedBox(height: 8),
                Text(
                  'No upcoming events',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcomingEvents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final event = upcomingEvents[idx].data();
              final eventId = upcomingEvents[idx].id;
              return SizedBox(
                width: 360,
                height: 220,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (event['imageUrl']
                                  ?.toString()
                                  .startsWith('http') ==
                              true)
                            CachedNetworkImage(
                              imageUrl: event['imageUrl'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[900]),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[900],
                                child: const Icon(Icons.event,
                                    color: Colors.white24, size: 48),
                              ),
                            ),
                          // Paused overlay
                          if (event['isPaused'] == true)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ),
                          // Content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top badges
                              Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: event['isPaused'] == true
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: TextWidget(
                                            text: 'PAUSED',
                                            fontSize: 12,
                                            color: Colors.white,
                                            isBold: true,
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: TextWidget(
                                            text: 'UPCOMING',
                                            fontSize: 12,
                                            color: Colors.black,
                                            isBold: true,
                                          ),
                                        ),
                                ),
                              ),
                              // Bottom text
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextWidget(
                                        text: (event['title'] ?? 'Event')
                                            .toString(),
                                        fontSize: 18,
                                        color: Colors.white,
                                        isBold: true,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      TextWidget(
                                        text: _eventSubtitle(event),
                                        fontSize: 14,
                                        color: Colors.white,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _eventSubtitle(Map<String, dynamic> event) {
    final date = event['date'];
    final start = event['startDate'];
    final end = event['endDate'];

    // Try startDate first
    DateTime? startDate;
    DateTime? endDate;

    // Parse startDate
    if (start is Timestamp) {
      startDate = start.toDate();
    } else if (start is String && start.isNotEmpty) {
      try {
        startDate = DateTime.parse(start);
      } catch (_) {}
    }

    // Parse endDate
    if (end is Timestamp) {
      endDate = end.toDate();
    } else if (end is String && end.isNotEmpty) {
      try {
        endDate = DateTime.parse(end);
      } catch (_) {}
    }

    if (startDate != null) {
      if (endDate != null &&
          endDate.year == startDate.year &&
          endDate.month == startDate.month &&
          endDate.day == startDate.day) {
        // Same day event
        return _formatDate(startDate);
      } else if (endDate != null) {
        // Multi-day event
        return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
      } else {
        return _formatDate(startDate);
      }
    }

    // Try simple date field
    if (date is String && date.isNotEmpty) return date;

    // Only return TBD if truly no dates exist
    return 'Date TBD';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
