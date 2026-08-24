import 'package:cofi/data/repositories/community_repository.dart';
import 'package:cofi/models/event_model.dart';
import 'package:flutter/material.dart';
import 'package:cofi/widgets/premium_event_card.dart';

class ExploreEventsSection extends StatefulWidget {
  const ExploreEventsSection({super.key});

  @override
  State<ExploreEventsSection> createState() => _ExploreEventsSectionState();
}

class _ExploreEventsSectionState extends State<ExploreEventsSection> {
  final EventRepository _eventRepository = EventRepository();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<List<CafeEvent>>(
      stream: _eventRepository.watchUpcomingEvents(),
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
        final upcomingEvents = (snapshot.data ?? const <CafeEvent>[])
            .where((e) => e.endDate == null || e.endDate!.isAfter(now))
            .toList();

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
                  final event = upcomingEvents[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: PremiumEventCard(
                      event: {
                        'title': event.title,
                        'address': event.address,
                        'startDate': event.startDate,
                        'endDate': event.endDate,
                        'about': event.about,
                        'email': event.email,
                        'link': event.link,
                        'imageUrls': event.imageUrls,
                        'imageUrl':
                            event.imageUrls.isNotEmpty ? event.imageUrls.first : null,
                        'latitude': event.latitude,
                        'longitude': event.longitude,
                        'status': event.status,
                        'participantsCount': event.participantsCount,
                        'shopId': event.shopId,
                        'isPaused': event.isPaused,
                        'isArchived': event.isArchived,
                      },
                      eventId: event.id,
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
}
