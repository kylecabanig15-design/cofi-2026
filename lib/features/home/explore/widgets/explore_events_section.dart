import 'package:cofi/features/events/event_details_screen.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/widgets/premium_event_card.dart';

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

        // Sort by startDate ascending (soonest first)
        upcomingEvents.sort((a, b) {
          DateTime? aStart = _parseDate(a.data()['startDate']);
          DateTime? bStart = _parseDate(b.data()['startDate']);
          if (aStart == null && bStart == null) return 0;
          if (aStart == null) return 1;
          if (bStart == null) return -1;
          return aStart.compareTo(bStart);
        });

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
          height: 240,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.white, Colors.white.withOpacity(0.6)],
                  stops: [0.0, 0.88, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: PageView.builder(
                padEnds: false,
                controller: PageController(viewportFraction: 0.96),
                physics: const BouncingScrollPhysics(),
                itemCount: upcomingEvents.length,
                itemBuilder: (context, idx) {
                  final event = upcomingEvents[idx].data();
                  final eventId = upcomingEvents[idx].id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: PremiumEventCard(
                      event: event,
                      eventId: eventId,
                      width: double.infinity,
                      height: 200,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try { return DateTime.parse(value); } catch (_) {}
    }
    return null;
  }
}
