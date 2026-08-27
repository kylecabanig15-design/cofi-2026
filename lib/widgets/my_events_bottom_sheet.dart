import 'package:cofi/widgets/post_event_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/events/event_details_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';

class MyEventsBottomSheet extends StatelessWidget {
  const MyEventsBottomSheet({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: BusinessWorkspaceColors.canvas,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            BusinessSheetHeader(
              title: 'Event board',
              subtitle: 'Upcoming and currently running gatherings',
              icon: Icons.event_available_rounded,
              action: IconButton.filled(
                tooltip: 'Create event',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  PostEventBottomSheet.show(context, shopId: shopId);
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ),

            // Events List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .collection('events')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: TextWidget(
                          text: 'Failed to load events',
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      );
                    }
                    final allDocs = snapshot.data?.docs ?? [];

                    // Filter out finished events (but show paused events for owner)
                    final now = DateTime.now();
                    final upcomingDocs = allDocs.where((doc) {
                      final data = doc.data();

                      // Exclude archived events
                      if (data['isArchived'] == true) {
                        return false;
                      }

                      final endDate = data['endDate'];

                      DateTime? endDateTime;
                      if (endDate is Timestamp) {
                        endDateTime = endDate.toDate();
                      } else if (endDate is String && endDate.isNotEmpty) {
                        try {
                          endDateTime = DateTime.parse(endDate);
                        } catch (_) {}
                      }

                      // Only show if event hasn't finished yet
                      if (endDateTime != null) {
                        return endDateTime.isAfter(now);
                      }

                      // Fallback: check startDate
                      final startDate = data['startDate'];
                      DateTime? startDateTime;
                      if (startDate is Timestamp) {
                        startDateTime = startDate.toDate();
                      } else if (startDate is String && startDate.isNotEmpty) {
                        try {
                          startDateTime = DateTime.parse(startDate);
                        } catch (_) {}
                      }

                      if (startDateTime != null) {
                        final endOfStartDay = DateTime(
                          startDateTime.year,
                          startDateTime.month,
                          startDateTime.day,
                          23,
                          59,
                          59,
                        );
                        return now.isBefore(endOfStartDay);
                      }

                      return true; // Show if no dates found
                    }).toList();

                    if (upcomingDocs.isEmpty) {
                      return const BusinessEmptyState(
                        icon: Icons.event_note_outlined,
                        title: 'Nothing on the board',
                        message:
                            'Create an event when your café has something worth gathering for.',
                      );
                    }
                    final totalParticipants = upcomingDocs.fold<int>(
                      0,
                      (total, doc) =>
                          total +
                          ((doc.data()['participantsCount'] as num?)?.toInt() ??
                              0),
                    );
                    final paused = upcomingDocs
                        .where((doc) => doc.data()['isPaused'] == true)
                        .length;
                    return Column(
                      children: [
                        BusinessMetricsStrip(
                          items: [
                            BusinessMetricData(
                                '${upcomingDocs.length}', 'On board'),
                            BusinessMetricData(
                                '$totalParticipants', 'Participants'),
                            BusinessMetricData('$paused', 'Paused'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.separated(
                            itemCount: upcomingDocs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final data = upcomingDocs[index].data();
                              final title =
                                  (data['title'] as String?) ?? 'Untitled';
                              final status =
                                  (data['status'] as String?) ?? 'pending';
                              final participants =
                                  data['participantsCount'] is int
                                      ? data['participantsCount'] as int
                                      : 0;
                              final statusColor =
                                  status.toLowerCase() == 'approved'
                                      ? Colors.green
                                      : status.toLowerCase() == 'rejected'
                                          ? Colors.red
                                          : Colors.orange;
                              return _buildEventItem(
                                context: context,
                                image: (data['imageUrl'] as String?) ?? '',
                                about: (data['about'] as String?) ??
                                    'No event description yet.',
                                title: title,
                                status: status.isEmpty || status == 'pending'
                                    ? ''
                                    : status[0].toUpperCase() +
                                        status.substring(1),
                                statusColor: statusColor,
                                participants: participants,
                                eventData: data,
                                eventId: upcomingDocs[index].id,
                                shopId: shopId,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem({
    required BuildContext context,
    required String title,
    required String about,
    required String status,
    required String image,
    required Color statusColor,
    required int participants,
    required Map<String, dynamic> eventData,
    required String eventId,
    required String shopId,
  }) {
    return GestureDetector(
      onTap: () {
        // Add shopId, id, and ensure userId is present for ownership check
        final completeEventData = Map<String, dynamic>.from(eventData);
        completeEventData['shopId'] = shopId;
        completeEventData['id'] = eventId;
        // Ensure userId is present (should already be from Firestore)
        if (!completeEventData.containsKey('userId')) {
          completeEventData['userId'] =
              FirebaseAuth.instance.currentUser?.uid ?? '';
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(event: completeEventData),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BusinessWorkspaceColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BusinessWorkspaceColors.line),
        ),
        child: Row(
          children: [
            // Event Icon
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: BusinessWorkspaceColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    image: image.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(image),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: image.isEmpty
                      ? Icon(
                          Icons.event_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        )
                      : null,
                ),
                // Paused overlay badge
                if (eventData['isPaused'] == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[900]!, width: 1),
                      ),
                      child: const Icon(
                        Icons.pause,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Event Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextWidget(
                          text: title,
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                      ),
                      if (eventData['isPaused'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TextWidget(
                            text: 'PAUSED',
                            fontSize: 10,
                            color: Colors.white,
                            isBold: true,
                          ),
                        ),
                    ],
                  ),
                  TextWidget(
                    text: about,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Participant Badge on the right
            GestureDetector(
              onTap: () async {
                // Show confirmation dialog
                final viewParticipants = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      'View Participants',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Do you want to view all participants?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                );

                if (viewParticipants == true && context.mounted) {
                  _showParticipantsList(context, eventData, eventId, shopId);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people,
                      color: primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    TextWidget(
                      text: participants.toString(),
                      fontSize: 14,
                      color: Colors.white,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showParticipantsList(
    BuildContext context,
    Map<String, dynamic> eventData,
    String eventId,
    String shopId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  TextWidget(
                    text: 'Participants',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                ],
              ),
            ),
            // Participants List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopId)
                    .collection('events')
                    .doc(eventId)
                    .collection('participants')
                    .orderBy('joinedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: TextWidget(
                        text: 'No participants yet',
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white24),
                    itemBuilder: (context, index) {
                      final participantData = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      final name =
                          participantData['userName'] as String? ?? 'User';
                      final photoUrl =
                          participantData['userPhotoUrl'] as String? ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE53E3E),
                          backgroundImage: photoUrl.isNotEmpty
                              ? CachedNetworkImageProvider(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: TextWidget(
                          text: name,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context, {required String shopId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BusinessWorkspaceTheme(
        accentColor: Colors.blueAccent,
        child: MyEventsBottomSheet(shopId: shopId),
      ),
    );
  }
}
