import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/events/event_details_screen.dart';
import 'package:cofi/features/networking/all_shared_collections_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/jobs/job_details_screen.dart';
import 'package:cofi/widgets/premium_background.dart';
import 'package:intl/intl.dart';
import 'package:cofi/utils/formatters.dart';

class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextWidget(
                        text: 'Latest in',
                        fontSize: 28,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontFamily: 'Baloo2',
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextWidget(
                        text: 'Davao City',
                        fontSize: 28,
                        color: Colors.white,
                        fontFamily: 'Medium',
                        isBold: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Events Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextWidget(
                text: 'Events',
                fontSize: 22,
                color: Colors.white,
                fontFamily: 'Baloo2',
                isBold: true,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('events')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print(snapshot.error);
                  return TextWidget(
                    text: 'Failed to load events',
                    fontSize: 14,
                    color: Colors.redAccent,
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                final now = DateTime.now();

                // Separate ongoing and upcoming events
                final ongoingEvents =
                    <DocumentSnapshot<Map<String, dynamic>>>[];
                final upcomingEvents =
                    <DocumentSnapshot<Map<String, dynamic>>>[];

                for (final d in docs) {
                  final data = d.data();
                  // Skip paused and archived events
                  if (data['isPaused'] == true || data['isArchived'] == true) {
                    continue;
                  }

                  DateTime? startDateTime;
                  DateTime? endDateTime;

                  // Parse start date
                  final startDate = data['startDate'];
                  if (startDate is Timestamp) {
                    startDateTime = startDate.toDate();
                  } else if (startDate is String && startDate.isNotEmpty) {
                    try {
                      startDateTime = DateTime.parse(startDate);
                    } catch (_) {}
                  }

                  // Parse end date
                  final endDate = data['endDate'];
                  if (endDate is Timestamp) {
                    endDateTime = endDate.toDate();
                  } else if (endDate is String && endDate.isNotEmpty) {
                    try {
                      endDateTime = DateTime.parse(endDate);
                    } catch (_) {}
                  }

                  // Skip ended events
                  if (endDateTime != null && endDateTime.isBefore(now)) {
                    continue;
                  }

                  // Check if event is ongoing (started but not ended)
                  if (startDateTime != null &&
                      startDateTime.isBefore(now) &&
                      (endDateTime == null || endDateTime.isAfter(now))) {
                    ongoingEvents.add(d);
                  } else if (startDateTime != null &&
                      startDateTime.isAfter(now)) {
                    // Event is upcoming (hasn't started yet)
                    upcomingEvents.add(d);
                  }
                }

                // Prioritize ongoing events, then upcoming
                final allEvents = [...ongoingEvents, ...upcomingEvents];

                if (allEvents.isEmpty) {
                  return TextWidget(
                    text: 'No upcoming events',
                    fontSize: 14,
                    color: Colors.white60,
                  );
                }

                // Build event card widget for reuse
                Widget buildEventCard(
                    DocumentSnapshot<Map<String, dynamic>> doc) {
                  final eventData = doc.data() ?? {};
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailsScreen(event: {
                            ...eventData,
                            'id': doc.id,
                          }),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(18),
                              image: DecorationImage(
                                  opacity: 0.65,
                                  image: CachedNetworkImageProvider(
                                    eventData['imageUrl'] ?? '',
                                  ),
                                  fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 36,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Check if event is ongoing
                                Builder(
                                  builder: (context) {
                                    final startDate = eventData['startDate'];
                                    final endDate = eventData['endDate'];
                                    DateTime? startDateTime;
                                    DateTime? endDateTime;

                                    if (startDate is Timestamp) {
                                      startDateTime = startDate.toDate();
                                    } else if (startDate is String &&
                                        startDate.isNotEmpty) {
                                      try {
                                        startDateTime =
                                            DateTime.parse(startDate);
                                      } catch (_) {}
                                    }

                                    if (endDate is Timestamp) {
                                      endDateTime = endDate.toDate();
                                    } else if (endDate is String &&
                                        endDate.isNotEmpty) {
                                      try {
                                        endDateTime = DateTime.parse(endDate);
                                      } catch (_) {}
                                    }

                                    final now = DateTime.now();
                                    final isOngoing = startDateTime != null &&
                                        startDateTime.isBefore(now) &&
                                        (endDateTime == null ||
                                            endDateTime.isAfter(now));

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isOngoing)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: TextWidget(
                                              text:
                                                  'TODAY - ${_formatDateTime(startDateTime)}',
                                              fontSize: 11,
                                              color: Colors.white,
                                              isBold: true,
                                            ),
                                          ),
                                        if (!isOngoing)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: TextWidget(
                                              text: 'UPCOMING',
                                              fontSize: 11,
                                              color: Colors.black,
                                              isBold: true,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        TextWidget(
                                          text: (eventData['title'] ?? 'Event')
                                              .toString(),
                                          fontSize: 18,
                                          color: Colors.white,
                                          isBold: true,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 2),
                                        // Date range display
                                        Builder(
                                          builder: (context) {
                                            String dateRange = '';
                                            if (startDateTime != null) {
                                              final startStr = _formatEventDate(
                                                  startDateTime);
                                              if (endDateTime != null) {
                                                final endStr = _formatEventDate(
                                                    endDateTime);
                                                if (startStr == endStr) {
                                                  dateRange = startStr;
                                                } else {
                                                  dateRange =
                                                      '$startStr - $endStr';
                                                }
                                              } else {
                                                dateRange = startStr;
                                              }
                                            }
                                            return TextWidget(
                                              text: dateRange,
                                              fontSize: 12,
                                              color: Colors.white70,
                                              maxLines: 1,
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show scrollable list of events
                return SizedBox(
                  height: 240,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: PageView.builder(
                      clipBehavior: Clip.none,
                      padEnds: false,
                      controller: PageController(viewportFraction: 0.93),
                      itemCount: allEvents.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: buildEventCard(allEvents[idx]),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Shared Collections Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   TextWidget(
                    text: 'Shared Collections',
                    fontSize: 22,
                    color: Colors.white,
                    fontFamily: 'Baloo2',
                    isBold: true,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllSharedCollectionsScreen(),
                        ),
                      );
                    },
                    child: TextWidget(
                      text: 'See All',
                      fontSize: 14,
                      color: primary,
                      isBold: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('sharedCollections')
                    .limit(15) // Fetch a small pool to randomize from
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return TextWidget(
                      text: 'Failed to load shared collections',
                      fontSize: 14,
                      color: Colors.redAccent,
                    );
                  }
                  final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data?.docs ?? []);
                  
                  // Filter out private collections (legacy docs might miss the isPrivate field)
                  final publicDocs = docs.where((d) {
                    final data = d.data();
                    return data['isPrivate'] != true;
                  }).toList();

                  if (publicDocs.isEmpty) {
                    return TextWidget(
                      text: 'No shared collections yet',
                      fontSize: 14,
                      color: Colors.white60,
                    );
                  }

                  // RANDOMIZE and limit to 5 (Spotify Style)
                  publicDocs.shuffle();
                  final displayedDocs = publicDocs.take(5).toList();
                  
                  return SizedBox(
                    height: 180,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayedDocs.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final d = displayedDocs[index];
                        final collection = d.data();
                        return _buildSharedCollectionCard(
                            context, collection, d.id);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            // Job Hirings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextWidget(
                text: 'Job Hirings',
                fontSize: 22,
                color: Colors.white,
                fontFamily: 'Baloo2',
                isBold: true,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('jobs')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print(snapshot.error);
                    return TextWidget(
                      text: 'Failed to load jobs',
                      fontSize: 14,
                      color: Colors.redAccent,
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final currentUser = FirebaseAuth.instance.currentUser;

                  // Filter out jobs with no shopId, paused jobs, archived jobs, and pending/rejected jobs
                  final filteredJobs = docs.where((d) {
                    final job = d.data();
                    final shopId = job['shopId'];
                    final isPaused = job['isPaused'] as bool? ?? false;
                    final isArchived = job['isArchived'] as bool? ?? false;
                    final status =
                        (job['status'] as String? ?? 'pending').toLowerCase();

                    // Only show active and closed jobs
                    final isActive = status == 'active';
                    final isClosed = status == 'closed';

                    return shopId != null &&
                        shopId.toString().isNotEmpty &&
                        !isPaused &&
                        !isArchived &&
                        (isActive || isClosed);
                  }).toList();

                  if (filteredJobs.isEmpty) {
                    return TextWidget(
                      text: 'No jobs available',
                      fontSize: 14,
                      color: Colors.white60,
                    );
                  }

                  // Prioritize open (active) jobs, then closed jobs
                  final activeJobs =
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final closedJobs =
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  for (final d in filteredJobs) {
                    final status = (d.data()['status'] as String? ?? 'pending')
                        .toLowerCase();
                    if (status == 'active') {
                      activeJobs.add(d);
                    } else if (status == 'closed') {
                      closedJobs.add(d);
                    }
                  }

                  final orderedJobs =
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[
                    ...activeJobs,
                    ...closedJobs,
                  ];

                  return Column(
                    children: orderedJobs.map((d) {
                      final job = d.data();
                      final status =
                          (job['status'] as String? ?? 'pending').toLowerCase();
                      final isClosed = status == 'closed';
                      final createdBy = job['createdBy'] as String?;
                      final isOwner = currentUser != null &&
                          createdBy != null &&
                          createdBy == currentUser.uid;

                      // Only the owner can open closed jobs
                      final canOpen = !isClosed || isOwner;

                      return GestureDetector(
                        onTap: canOpen
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailsScreen(
                                      job: {
                                        ...job,
                                        'id': d.id,
                                      },
                                      shopId: d['shopId'],
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: _buildJobRow(context, job, isClosed: isClosed),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobRow(BuildContext context, Map<String, dynamic> job,
      {required bool isClosed}) {
    final title = (job['title'] ?? 'Job').toString();
    final shopId = job['shopId'] as String?;

    if (shopId == null || shopId.isEmpty) {
      // Fallback if no shopId
      return Padding(
        padding: const EdgeInsets.only(left: 0, right: 0, bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child:
                    Icon(Icons.bookmark_border, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 16),
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
                      if (isClosed)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const TextWidget(
                            text: 'CLOSED',
                            fontSize: 10,
                            color: Colors.white,
                            isBold: true,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  TextWidget(
                    text: job['shopName'] ??
                        job['cafe'] ??
                        job['name'] ??
                        'Coffee Shop',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 4),
                      TextWidget(
                        text: job['city'] ?? 'Davao City',
                        fontSize: 13,
                        color: Colors.white54,
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

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('shops').doc(shopId).get(),
      builder: (context, shopSnapshot) {
        String shopName =
            job['shopName'] ?? job['cafe'] ?? job['name'] ?? 'Coffee Shop';
        String city = job['city'] ?? 'Davao City';

        // If we have shop data, use those fields as priority
        if (shopSnapshot.hasData && shopSnapshot.data != null) {
          final shopData = shopSnapshot.data!.data();
          if (shopData != null) {
            shopName = shopData['name'] ??
                shopData['shopName'] ??
                shopData['cafe'] ??
                shopName;
            city = shopData['city'] ?? city;
          }
        }

        final displayCity = formatAddress(city);

        return Padding(
          padding: const EdgeInsets.only(left: 0, right: 0, bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.bookmark_border,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
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
                            maxLines: 1,
                          ),
                        ),
                        if (isClosed)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const TextWidget(
                              text: 'CLOSED',
                              fontSize: 10,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    TextWidget(
                      text: shopName,
                      fontSize: 13,
                      color: Colors.white70,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white54, size: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            displayCity,
                            style: TextStyle(
                              fontSize: displayCity.length > 30 ? 8.5 : 9.5,
                              color: Colors.white54,
                              overflow: TextOverflow.ellipsis,
                            ),
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
        );
      },
    );
  }

  // bool _isEventToday(Map<String, dynamic> data) {
  //   DateTime? dt;
  //   final sd = data['startDate'];
  //   if (sd is Timestamp) {
  //     dt = sd.toDate();
  //   } else if (sd is String) {
  //     dt = DateTime.tryParse(sd);
  //   }
  //   if (dt == null) {
  //     final d = data['date'];
  //     if (d is String) {
  //       dt = DateTime.tryParse(d);
  //     } else if (d is Timestamp) {
  //       dt = d.toDate();
  //     }
  //   }
  //   if (dt == null) return false;
  //   final now = DateTime.now();
  //   final today = DateTime(now.year, now.month, now.day);
  //   final that = DateTime(dt.year, dt.month, dt.day);
  //   return that == today;
  // }

  // String _eventSubtitle(Map<String, dynamic> event) {
  //   final date = event['date'];
  //   final start = event['startDate'];
  //   if (date is String && date.isNotEmpty) return date;
  //   if (start is String && start.isNotEmpty) return start;
  //   return '';
  // }

  Widget _buildSharedCollectionCard(BuildContext context,
      Map<String, dynamic> collection, String collectionId) {
    final title = collection['title'] ?? 'Untitled Collection';
    final shopCount = collection['shopCount'] ?? 0;
    final List<String> previewLogos = ((collection['previewLogos'] as List?)?.cast<String>() ?? []);
    
    return GestureDetector(
      onTap: () {
        _showCollectionDetailsBottomSheet(context, collectionId, collection);
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Responsive Logo Background (Spotify Style)
            Positioned.fill(
              child: previewLogos.isEmpty
                  ? CachedNetworkImage(
                      imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=2070&auto=format&fit=crop',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                    )
                  : (previewLogos.length < 4)
                      ? CachedNetworkImage(
                          imageUrl: previewLogos[0],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[900]),
                          errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                        )
                      : GridView.count(
                          crossAxisCount: 2,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < 4; i++)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: previewLogos[i],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.white10),
                                  errorWidget: (context, url, error) => Container(color: Colors.grey[850]),
                                ),
                              ),
                          ],
                        ),
            ),
            // High-legibility Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.4, 0.85],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.collections_bookmark,
                      color: primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextWidget(
                    text: title,
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.local_cafe, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      TextWidget(
                        text: '$shopCount Shops',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionDetailsBottomSheet(BuildContext context,
      String collectionId, Map<String, dynamic> collection) {
    final title = collection['title'] ?? 'Untitled Collection';
    final shopCount = collection['shopCount'] ?? 0;
    final sharedAt = collection['sharedAt'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Visual Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.collections_bookmark,
                color: primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Baloo2',
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_cafe, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                TextWidget(
                  text: '$shopCount coffee shops',
                  fontSize: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time_filled, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                TextWidget(
                  text: sharedAt != null ? _formatTimestamp(sharedAt) : 'Recently',
                  fontSize: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 12),
                Icon(Icons.person, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                TextWidget(
                  text: collection['sharedBy'] ?? 'Community',
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/sharedCollection',
                    arguments: {
                      'collectionId': collectionId,
                      'title': title,
                    },
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Explore Collection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

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

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatEventDate(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}
