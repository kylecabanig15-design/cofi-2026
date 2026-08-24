import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/data/repositories/community_repository.dart';
import 'package:cofi/models/event_model.dart';
import 'package:cofi/models/job_model.dart';
import 'package:cofi/features/networking/all_shared_collections_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/premium_event_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/jobs/job_details_screen.dart';
import 'package:cofi/utils/formatters.dart';

class CommunityTab extends StatelessWidget {
  static final EventRepository _eventRepository = EventRepository();
  static final JobRepository _jobRepository = JobRepository();

  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: StatefulBuilder(
          builder: (context, setState) {
            return RefreshIndicator(
              color: primary,
              backgroundColor: Colors.black87,
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 800));
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextWidget(
                text: 'Events',
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'Baloo2',
                isBold: true,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<CafeEvent>>(
              stream: _eventRepository.watchRecentEvents(),
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
                final docs = snapshot.data ?? const <CafeEvent>[];
                final now = DateTime.now();

                // Separate ongoing and upcoming events
                final ongoingEvents = <CafeEvent>[];
                final upcomingEvents = <CafeEvent>[];

                for (final event in docs) {
                  // Skip paused and archived events
                  if (event.isPaused || event.isArchived) continue;

                  final startDateTime = event.startDate;
                  final endDateTime = event.endDate;

                  // Skip ended events
                  if (endDateTime != null && endDateTime.isBefore(now)) {
                    continue;
                  }

                  // Check if event is ongoing (started but not ended)
                  if (startDateTime != null &&
                      startDateTime.isBefore(now) &&
                      (endDateTime == null || endDateTime.isAfter(now))) {
                    ongoingEvents.add(event);
                  } else if (startDateTime != null &&
                      startDateTime.isAfter(now)) {
                    // Event is upcoming (hasn't started yet)
                    upcomingEvents.add(event);
                  }
                }

                // Sort upcoming events by start date (closest to now first)
                upcomingEvents.sort((a, b) {
                  final aStart = a.startDate;
                  final bStart = b.startDate;
                  if (aStart == null && bStart == null) return 0;
                  if (aStart == null) return 1;
                  if (bStart == null) return -1;
                  return aStart.compareTo(bStart);
                });

                // Prioritize ongoing events, then upcoming
                final allEvents = [...ongoingEvents, ...upcomingEvents];

                if (allEvents.isEmpty) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.event_busy_rounded,
                          size: 36,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 10),
                        TextWidget(
                          text: 'No Upcoming Events',
                          fontSize: 15,
                          isBold: true,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 4),
                        TextWidget(
                          text: 'Check back later for community updates!',
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  );
                }

                // Show snapping list of events matching Explore page style
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
                        itemCount: allEvents.length,
                        itemBuilder: (context, idx) {
                          final event = allEvents[idx];
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
                                'imageUrl': event.imageUrls.isNotEmpty
                                    ? event.imageUrls.first
                                    : null,
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
            ),
            const SizedBox(height: 32),
            // Shared Collections Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   TextWidget(
                    text: 'Shared Collections',
                    fontSize: 18,
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
              padding: const EdgeInsets.only(left: 12),
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
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            // Job Hirings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: StreamBuilder<List<Job>>(
                stream: _jobRepository.watchRecentJobs(),
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

                  final docs = snapshot.data ?? const <Job>[];
                  final currentUser = FirebaseAuth.instance.currentUser;

                  // Filter out jobs with no shopId, paused jobs, archived jobs, and pending/rejected jobs
                  final filteredJobs = docs.where((job) {
                    final status = job.status.toLowerCase();

                    // Only show active and closed jobs
                    final isActive = status == 'active';
                    final isClosed = status == 'closed';

                    return job.shopId.isNotEmpty &&
                        !job.isPaused &&
                        !job.isArchived &&
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
                  final activeJobs = <Job>[];
                  final closedJobs = <Job>[];

                  for (final job in filteredJobs) {
                    if (job.status.toLowerCase() == 'active') {
                      activeJobs.add(job);
                    } else if (job.status.toLowerCase() == 'closed') {
                      closedJobs.add(job);
                    }
                  }

                  final orderedJobs = <Job>[
                    ...activeJobs,
                    ...closedJobs,
                  ];

                  return Column(
                    children: orderedJobs.map((job) {
                      final status = job.status.toLowerCase();
                      final isClosed = status == 'closed';
                      final isOwner = currentUser != null &&
                          job.createdBy != null &&
                          job.createdBy == currentUser.uid;

                      // Only the owner can open closed jobs
                      final canOpen = !isClosed || isOwner;
                      final jobMap = job.toFirestore()
                        ..['id'] = job.id;

                      return GestureDetector(
                        onTap: canOpen
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailsScreen(
                                      job: jobMap,
                                      shopId: job.shopId,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: _buildJobRow(context, jobMap, isClosed: isClosed),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
            );
          },
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
}

