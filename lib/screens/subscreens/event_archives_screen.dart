import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Event Archives',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SafeArea(
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
              return Center(
                child: TextWidget(
                  text: 'No archived events',
                  fontSize: 16,
                  color: Colors.white70,
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: archivedEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final event = archivedEvents[index].data();
                final eventId = archivedEvents[index].id;

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
    );
  }

  Widget _buildArchivedEventCard({
    required String eventId,
    required Map<String, dynamic> event,
    required VoidCallback onDelete,
  }) {
    final title = (event['title'] ?? 'Event') as String;
    final address = (event['address'] ?? '') as String;
    final startDateRaw = event['startDate'];
    final endDateRaw = event['endDate'];
    final imageUrl = (event['imageUrl'] ?? '') as String;

    String dateRange = 'Date TBD';

    DateTime? startDateTime;
    DateTime? endDateTime;

    // Parse startDate
    if (startDateRaw is Timestamp) {
      startDateTime = startDateRaw.toDate();
    } else if (startDateRaw is String && startDateRaw.isNotEmpty) {
      try {
        startDateTime = DateTime.parse(startDateRaw);
      } catch (_) {}
    }

    // Parse endDate
    if (endDateRaw is Timestamp) {
      endDateTime = endDateRaw.toDate();
    } else if (endDateRaw is String && endDateRaw.isNotEmpty) {
      try {
        endDateTime = DateTime.parse(endDateRaw);
      } catch (_) {}
    }

    if (startDateTime != null) {
      if (endDateTime != null) {
        dateRange =
            '${_formatDate(startDateTime)} - ${_formatDate(endDateTime)}';
      } else {
        dateRange = _formatDate(startDateTime);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                      ),
                      child: TextWidget(
                        text: 'Delete',
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Future<void> _deleteEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: TextWidget(
          text: 'Delete Event',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
        content: TextWidget(
          text: 'Are you sure you want to delete this archived event?',
          fontSize: 14,
          color: Colors.white70,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: TextWidget(
              text: 'Cancel',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: TextWidget(
              text: 'Delete',
              fontSize: 14,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('events')
            .doc(eventId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
