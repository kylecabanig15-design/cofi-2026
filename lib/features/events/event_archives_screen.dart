import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:cofi/widgets/custom_toast.dart';

class EventArchivesScreen extends StatefulWidget {
  final String shopId;

  const EventArchivesScreen({required this.shopId, super.key});

  @override
  State<EventArchivesScreen> createState() => _EventArchivesScreenState();
}

class _EventArchivesScreenState extends State<EventArchivesScreen> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: BusinessWorkspaceColors.canvas,
      appBar: AppBar(
        backgroundColor: BusinessWorkspaceColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Past events',
          fontSize: 18,
          color: BusinessWorkspaceColors.paper,
          isBold: true,
        ),
      ),
      body: BusinessWorkspaceTheme(
        accentColor: Colors.grey,
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(widget.shopId)
                .collection('events')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: TextWidget(
                    text: 'Error loading archives',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                );
              }

              final allEvents = snapshot.data?.docs ?? [];

              // Filter to only show archived events (explicitly archived or ended)
              final archivedEvents = allEvents.where((doc) {
                final event = doc.data();

                // Check if explicitly marked as archived
                if (event['isArchived'] == true) {
                  return true;
                }

                // Check if end date has passed (only end date matters for auto-archiving)
                final endDate = event['endDate'];
                DateTime? endDateTime;

                if (endDate is Timestamp) {
                  endDateTime = endDate.toDate();
                } else if (endDate is String && endDate.isNotEmpty) {
                  try {
                    endDateTime = DateTime.parse(endDate);
                  } catch (_) {}
                }

                if (endDateTime != null && endDateTime.isBefore(now)) {
                  return true;
                }

                // If not explicitly archived and end date hasn't passed, don't show
                return false;
              }).toList();

              if (archivedEvents.isEmpty) {
                return const BusinessEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Your event history is empty',
                  message:
                      'Finished and archived events will stay here for reference.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: archivedEvents.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const BusinessPageIntro(
                      eyebrow: 'Event ledger',
                      title: 'Past gatherings',
                      description:
                          'Keep a clean history of what your café has hosted.',
                      icon: Icons.history_rounded,
                    );
                  }
                  final event = archivedEvents[index - 1].data();
                  final eventId = archivedEvents[index - 1].id;

                  return _buildArchivedEventCard(
                    eventId: eventId,
                    event: event,
                    onDelete: () => _deleteEvent(eventId),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedEventCard({
    required String eventId,
    required Map<String, dynamic> event,
    required VoidCallback onDelete,
  }) {
    // Legacy docs may hold non-string values here — coerce safely instead
    // of hard-casting, which would throw during build.
    String asString(dynamic v, String fallback) =>
        v is String ? v : (v?.toString() ?? fallback);
    final title = asString(event['title'], 'Event');
    final address = asString(event['address'], '');
    final imageUrl = asString(event['imageUrl'], '');

    String dateRange = 'Date TBD';

    DateTime? startDateTime;
    DateTime? endDateTime;

    // Parse startDate
    final d = event['date'];
    if (d is Timestamp) {
      startDateTime = d.toDate();
    } else if (d is String && d.isNotEmpty) {
      startDateTime = DateTime.tryParse(d);
    }

    final sd = event['startDate'];
    if (startDateTime == null) {
      if (sd is Timestamp) {
        startDateTime = sd.toDate();
      } else if (sd is String && sd.isNotEmpty) {
        startDateTime = DateTime.tryParse(sd);
      }
    }

    // Parse endDate
    final ed = event['endDate'];
    if (ed is Timestamp) {
      endDateTime = ed.toDate();
    } else if (ed is String && ed.isNotEmpty) {
      endDateTime = DateTime.tryParse(ed);
    }

    if (startDateTime != null) {
      if (endDateTime != null) {
        dateRange =
            '${_formatDate(startDateTime)} - ${_formatDate(endDateTime)}';
      } else {
        dateRange = _formatDate(startDateTime);
      }
    } else {
      if (d is String && d.isNotEmpty) {
        dateRange = d;
      } else if (sd is String && sd.isNotEmpty) {
        dateRange = sd;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[800],
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) => Center(
                  child: Icon(Icons.image, color: Colors.white38, size: 50),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 18,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    TextWidget(
                      text: dateRange,
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextWidget(
                        text: address,
                        fontSize: 14,
                        color: Colors.white70,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: .35),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete permanently'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Future<void> _deleteEvent(String eventId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await CustomDialog.confirm(
      context: context,
      title: 'Delete archived event?',
      message: 'This permanently removes the event and its archive record.',
      confirmText: 'Delete event',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('events')
            .doc(eventId)
            .delete();

        CustomToast.showFromMessenger(
          messenger,
          'The archived event was permanently removed.',
          type: ToastType.success,
          title: 'Event deleted',
        );
      } catch (_) {
        CustomToast.showFromMessenger(
          messenger,
          'We could not delete the event. Please try again.',
          type: ToastType.error,
          title: 'Delete failed',
        );
      }
    }
  }
}
