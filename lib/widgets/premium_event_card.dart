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
    final startDateTime = _parseEventDate(event['startDate'] ?? event['date']);
    final endDateTime = _parseEventDate(event['endDate']);

    final now = DateTime.now();
    final isOngoing = startDateTime != null &&
        !startDateTime.isAfter(now) &&
        (endDateTime == null || endDateTime.isAfter(now));
    final isEnded = endDateTime != null && !endDateTime.isAfter(now);
    final isDateMissing = startDateTime == null;

    final isPaused = event['isPaused'] == true;

    final shopId = (event['shopId'] ?? '').toString();
    final embeddedLogo = (event['logoUrl'] ?? '').toString();
    final embeddedShopName =
        (event['shopName'] ?? event['cafeName'] ?? '').toString();

    if (shopId.isNotEmpty &&
        (embeddedLogo.isEmpty || embeddedShopName.isEmpty)) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future:
            FirebaseFirestore.instance.collection('shops').doc(shopId).get(),
        builder: (context, snapshot) {
          final shop = snapshot.data?.data();
          return _buildVisualCard(
            context,
            isPaused: isPaused,
            isOngoing: isOngoing,
            isEnded: isEnded,
            isDateMissing: isDateMissing,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            logoUrl: embeddedLogo.isNotEmpty
                ? embeddedLogo
                : (shop?['logoUrl'] ?? '').toString(),
            shopName: embeddedShopName.isNotEmpty
                ? embeddedShopName
                : (shop?['name'] ?? 'Local café').toString(),
          );
        },
      );
    }

    return _buildVisualCard(
      context,
      isPaused: isPaused,
      isOngoing: isOngoing,
      isEnded: isEnded,
      isDateMissing: isDateMissing,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      logoUrl: embeddedLogo,
      shopName: embeddedShopName.isEmpty ? 'Local café' : embeddedShopName,
    );
  }

  Widget _buildVisualCard(
    BuildContext context, {
    required bool isPaused,
    required bool isOngoing,
    required bool isEnded,
    required bool isDateMissing,
    required DateTime? startDateTime,
    required DateTime? endDateTime,
    required String logoUrl,
    required String shopName,
  }) {
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
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
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFF1E1E1E)),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(Icons.event,
                          color: Colors.white24, size: 48),
                    ),
                  )
                else
                  Container(color: const Color(0xFF1E1E1E)),

                // Same dark-exposure treatment used by Special Offers.
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: isPaused ? .72 : .45),
                        Colors.black.withValues(alpha: isPaused ? .9 : .96),
                      ],
                    ),
                  ),
                ),

                // Status badge
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getBadgeColor(
                          isPaused, isOngoing, isEnded, isDateMissing),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextWidget(
                      text: _getBadgeText(
                          isPaused, isOngoing, isEnded, isDateMissing),
                      fontSize: 10,
                      color: Colors.white,
                      isBold: true,
                    ),
                  ),
                ),

                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .68),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextWidget(
                          text: startDateTime == null
                              ? 'TBD'
                              : _month(startDateTime),
                          fontSize: 9,
                          color: Colors.white70,
                          isBold: true,
                        ),
                        TextWidget(
                          text: startDateTime?.day.toString() ?? '—',
                          fontSize: 18,
                          color: Colors.white,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),

                // Content (Bottom)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              shape: BoxShape.circle,
                              image: logoUrl.isEmpty
                                  ? null
                                  : DecorationImage(
                                      image:
                                          CachedNetworkImageProvider(logoUrl),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            child: logoUrl.isEmpty
                                ? const Icon(Icons.local_cafe,
                                    color: Colors.white, size: 15)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextWidget(
                              text: shopName,
                              fontSize: 13,
                              color: Colors.white,
                              isBold: true,
                              maxLines: 1,
                            ),
                          ),
                          if ((event['participantsCount'] as num?) != null) ...[
                            const Icon(Icons.people_alt_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            TextWidget(
                              text:
                                  '${(event['participantsCount'] as num).toInt()} going',
                              fontSize: 11,
                              color: Colors.white70,
                              isBold: true,
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 17),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: Colors.white70, size: 13),
                          const SizedBox(width: 5),
                          TextWidget(
                            text:
                                _timeRange(context, startDateTime, endDateTime),
                            fontSize: 12,
                            color: Colors.white70,
                            isBold: true,
                          ),
                          if ((event['address'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              decoration: const BoxDecoration(
                                color: Colors.white54,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 13),
                            const SizedBox(width: 3),
                            Expanded(
                              child: TextWidget(
                                text: _shortAddress(
                                    (event['address'] ?? '').toString()),
                                fontSize: 12,
                                color: Colors.white70,
                                maxLines: 1,
                              ),
                            ),
                          ],
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

  DateTime? _parseEventDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  Color _getBadgeColor(
      bool isPaused, bool isOngoing, bool isEnded, bool isDateMissing) {
    if (isPaused) return Colors.red.shade700;
    if (isOngoing) return Colors.green.shade600;
    if (isEnded) return Colors.grey.shade700;
    if (isDateMissing) return Colors.blueGrey.shade700;
    return Colors.amber.shade700;
  }

  String _getBadgeText(
      bool isPaused, bool isOngoing, bool isEnded, bool isDateMissing) {
    if (isPaused) return 'PAUSED';
    if (isOngoing) return 'LIVE NOW';
    if (isEnded) return 'ENDED';
    if (isDateMissing) return 'DATE TBD';
    return 'UPCOMING';
  }

  String _month(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[date.month - 1];
  }

  String _timeRange(
      BuildContext context, DateTime? startDate, DateTime? endDate) {
    if (startDate == null) return 'Time TBD';
    final start = TimeOfDay.fromDateTime(startDate).format(context);
    if (endDate == null) return start;
    final end = TimeOfDay.fromDateTime(endDate).format(context);
    return '$start–$end';
  }

  String _shortAddress(String address) {
    final firstPart = address.split(',').first.trim();
    return firstPart.isEmpty ? address : firstPart;
  }
}
