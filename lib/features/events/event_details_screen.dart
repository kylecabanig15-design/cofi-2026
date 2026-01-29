import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/utils/formatters.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/post_event_bottom_sheet.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/features/events/event_comments_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? event;
  const EventDetailsScreen({super.key, this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event ?? <String, dynamic>{};
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final eventOwnerId = e['userId'] as String?;
    final isOwner = currentUserId != null &&
        eventOwnerId != null &&
        currentUserId == eventOwnerId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // Event Image Carousel
                  Builder(builder: (context) {
                    final List<String> imageUrls = [];
                    if (e['imageUrls'] != null) {
                      imageUrls.addAll(
                          (e['imageUrls'] as List).map((e) => e.toString()));
                    } else if (e['imageUrl'] != null) {
                      imageUrls.add(e['imageUrl'].toString());
                    }

                    if (imageUrls.isEmpty) return const SizedBox.shrink();

                    return Stack(
                      children: [
                        SizedBox(
                          height: 400,
                          width: double.infinity,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemCount: imageUrls.length,
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  image: DecorationImage(
                                    opacity: 0.65,
                                    image: CachedNetworkImageProvider(
                                        imageUrls[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Dot Indicator
                        if (imageUrls.length > 1)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  imageUrls.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _currentImageIndex == index ? 8 : 6,
                                    height: _currentImageIndex == index ? 8 : 6,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Left arrow button
                        if (imageUrls.length > 1)
                          Positioned(
                            left: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Right arrow button
                        if (imageUrls.length > 1)
                          Positioned(
                            right: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (e['title'] ?? 'Event').toString(),
                                style: const TextStyle(
                                  fontSize: 23,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'QRegular',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              // Cafe/Shop name with logo
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('shops')
                                    .doc(e['shopId'] as String?)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || !snapshot.data!.exists) {
                                    return const SizedBox.shrink();
                                  }
                                  final shopData = snapshot.data!.data() as Map<String, dynamic>?;
                                  final shopName = shopData?['name'] as String? ?? '';
                                  final shopLogo = shopData?['logoUrl'] as String? ?? '';
                                  if (shopName.isEmpty) return const SizedBox.shrink();
                                  
                                  return Row(
                                    children: [
                                      // Cafe logo
                                      if (shopLogo.isNotEmpty)
                                        Container(
                                          width: 24,
                                          height: 24,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: shopLogo,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.store,
                                                  size: 12,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.store,
                                                  size: 12,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Cafe name
                                      Expanded(
                                        child: Text(
                                          shopName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                            fontFamily: 'QRegular',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // About Section
                        TextWidget(
                          text: 'About',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: (e['about'] ?? 'No description provided')
                              .toString(),
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 24),
                        // Date Section
                        TextWidget(
                          text: 'Start Date',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: _formatEventDate(e),
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 24),
                        TextWidget(
                          text: 'End Date',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: _formatEventDate1(e),
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 24),
                        // Start Time
                        TextWidget(
                          text: 'Start Time',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: _formatEventTime(e['startDate']),
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 24),
                        // End Time
                        TextWidget(
                          text: 'End Time',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: _formatEventTime(e['endDate']),
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 24),
                        // Address Section with Map
                        TextWidget(
                          text: 'Location',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: formatAddress((e['address'] ?? 'Address not specified').toString()),
                          fontSize: 14,
                          color: Colors.white70,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        // Google Map
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[800],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  _getLatitude(e),
                                  _getLongitude(e),
                                ),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('event'),
                                  position: LatLng(
                                    _getLatitude(e),
                                    _getLongitude(e),
                                  ),
                                  infoWindow: InfoWindow(
                                    title: e['title'] ?? 'Event',
                                    snippet: e['address'] ?? 'Location',
                                  ),
                                ),
                              },
                              zoomControlsEnabled: true,
                              myLocationButtonEnabled: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email Section
                        TextWidget(
                          text: 'Email',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: (e['email'] ?? 'N/A').toString(),
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 100), // Space for button
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Buttons
            if (isOwner)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Builder(
                  builder: (context) {
                    final isPaused = (e['isPaused'] as bool?) ?? false;
                    return Column(
                      children: [
                        // Owner Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Open edit event bottom sheet
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (context) => EditEventBottomSheet(
                                      eventId: e['id'] ?? '',
                                      shopId: e['shopId'] ?? '',
                                      eventData: e,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => isPaused
                                    ? _publishEvent(
                                        context, e['shopId'], e['id'])
                                    : _unpublishEvent(
                                        context, e['shopId'], e['id']),
                                icon: Icon(
                                    isPaused ? Icons.cloud_upload : Icons.cloud_off),
                                label: Text(isPaused ? 'Publish' : 'Unpublish'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isPaused ? Colors.green : Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _archiveEvent(
                                    context, e['shopId'], e['id']),
                                icon: const Icon(Icons.archive),
                                label: const Text('Archive'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              )
            else
              // Non-owner view: Check account type and show appropriate UI
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: currentUserId != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .snapshots()
                    : null,
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data();
                  final accountType = userData?['accountType'] as String? ?? 'user';
                  final isBusinessAccount = accountType == 'business';

                  // Check if user is already a participant
                  return StreamBuilder<DocumentSnapshot>(
                    stream: currentUserId != null
                        ? FirebaseFirestore.instance
                            .collection('shops')
                            .doc(e['shopId'])
                            .collection('events')
                            .doc(e['id'])
                            .collection('participants')
                            .doc(currentUserId)
                            .snapshots()
                        : null,
                    builder: (context, participantSnapshot) {
                      final isParticipating = participantSnapshot.data?.exists ?? false;

                      // Get participant count
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('shops')
                            .doc(e['shopId'])
                            .collection('events')
                            .doc(e['id'])
                            .collection('participants')
                            .snapshots(),
                        builder: (context, countSnapshot) {
                          final participantCount = countSnapshot.data?.docs.length ?? 0;

                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                // Business account restriction message
                                if (isBusinessAccount)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.business_center,
                                          color: Colors.orange,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextWidget(
                                            text: 'Business accounts cannot join events',
                                            fontSize: 14,
                                            color: Colors.white,
                                            isBold: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Participant count display
                                if (participantCount > 0)
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
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('View'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (viewParticipants == true && context.mounted) {
                                        _showParticipantsList(context, e);
                                      }
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[850],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.people,
                                            color: primary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextWidget(
                                              text: '$participantCount ${participantCount == 1 ? 'Participant' : 'Participants'}',
                                              fontSize: 16,
                                              color: Colors.white,
                                              isBold: true,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.white54,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Action buttons row
                                Row(
                                  children: [
                                    // Join/Participating button (only for normal users)
                                    if (!isBusinessAccount)
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (isParticipating) {
                                              _leaveEvent(context, e);
                                            } else {
                                              _joinEvent(context, e);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isParticipating
                                                ? Colors.green
                                                : primary,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                isParticipating
                                                    ? Icons.check_circle
                                                    : Icons.event_available,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              TextWidget(
                                                text: isParticipating
                                                    ? 'Participating ✓'
                                                    : 'Join Event',
                                                fontSize: 16,
                                                color: Colors.white,
                                                isBold: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // Spacing between buttons
                                    if (!isBusinessAccount) const SizedBox(width: 12),

                                    // Comments button
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EventCommentsScreen(
                                                eventId: e['id'] ?? '',
                                                shopId: e['shopId'] ?? '',
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[800],
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.comment,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            TextWidget(
                                              text: 'Comments',
                                              fontSize: 16,
                                              color: Colors.white,
                                              isBold: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinEvent(BuildContext context, Map<String, dynamic> e) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join events')),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Join Event', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to join this event?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final shopId = e['shopId'] as String?;
      final eventId = e['id'] as String?;

      if (shopId == null || eventId == null) {
        throw Exception('Invalid event data');
      }

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();

      // Run transaction to ensure data consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final participantRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('events')
            .doc(eventId)
            .collection('participants')
            .doc(currentUser.uid);

        final eventRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('events')
            .doc(eventId);

        // Check if already participating
        final participantSnap = await transaction.get(participantRef);
        if (participantSnap.exists) {
          throw Exception('Already participating');
        }

        // Add participant
        transaction.set(participantRef, {
          'userId': currentUser.uid,
          'userName': userData?['name'] ?? currentUser.displayName ?? 'User',
          'userPhotoUrl': userData?['photoUrl'] ?? currentUser.photoURL ?? '',
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // Increment participant count
        transaction.update(eventRef, {
          'participantsCount': FieldValue.increment(1),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You're in! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join event: $e')),
        );
      }
    }
  }

  Future<void> _leaveEvent(BuildContext context, Map<String, dynamic> e) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Leave Event', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave this event?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final shopId = e['shopId'] as String?;
      final eventId = e['id'] as String?;

      if (shopId == null || eventId == null) {
        throw Exception('Invalid event data');
      }

      // Run transaction to ensure data consistency
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final participantRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('events')
            .doc(eventId)
            .collection('participants')
            .doc(currentUser.uid);

        final eventRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('events')
            .doc(eventId);

        // Remove participant
        transaction.delete(participantRef);

        // Decrement participant count
        transaction.update(eventRef, {
          'participantsCount': FieldValue.increment(-1),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the event')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave event: $e')),
        );
      }
    }
  }

  void _showParticipantsList(BuildContext context, Map<String, dynamic> e) {
    final shopId = e['shopId'] as String?;
    final eventId = e['id'] as String?;

    if (shopId == null || eventId == null) return;

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
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
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
                    separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                    itemBuilder: (context, index) {
                      final participantData =
                          snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final name = participantData['userName'] as String? ?? 'User';
                      final photoUrl = participantData['userPhotoUrl'] as String? ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primary,
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

  Future<void> _unpublishEvent(
      BuildContext context, String? shopId, String? eventId) async {
    if (shopId == null || eventId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('events')
          .doc(eventId)
          .update({'isPaused': true});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event unpublished')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unpublish event: $e')),
        );
      }
    }
  }

  Future<void> _publishEvent(
      BuildContext context, String? shopId, String? eventId) async {
    if (shopId == null || eventId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('events')
          .doc(eventId)
          .update({'isPaused': false});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event published')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish event: $e')),
        );
      }
    }
  }

  Future<void> _archiveEvent(
      BuildContext context, String? shopId, String? eventId) async {
    if (shopId == null || eventId == null) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Archive Event', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to archive this event?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('events')
          .doc(eventId)
          .update({'isArchived': true});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event archived')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive event: $e')),
        );
      }
    }
  }

  String _formatEventDate(Map<String, dynamic> e) {
    // Try 'date' first, then 'startDate'. Accept String or Timestamp.
    DateTime? dt;
    final d = e['date'];
    if (d is Timestamp) dt = d.toDate();
    if (d is String && d.isNotEmpty) {
      dt = DateTime.tryParse(d);
    }
    final sd = e['startDate'];
    if (dt == null) {
      if (sd is Timestamp) dt = sd.toDate();
      if (sd is String && sd.isNotEmpty) dt = DateTime.tryParse(sd);
    }
    if (dt == null) return 'Date not set';
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  String _formatEventDate1(Map<String, dynamic> e) {
    // Try 'date' first, then 'startDate'. Accept String or Timestamp.
    DateTime? dt;
    final d = e['date'];
    if (d is Timestamp) dt = d.toDate();
    if (d is String && d.isNotEmpty) {
      dt = DateTime.tryParse(d);
    }
    final sd = e['endDate'];
    if (dt == null) {
      if (sd is Timestamp) dt = sd.toDate();
      if (sd is String && sd.isNotEmpty) dt = DateTime.tryParse(sd);
    }
    if (dt == null) return 'Date not set';
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  String _formatEventTime(dynamic dateTime) {
    DateTime? dt;
    if (dateTime is Timestamp) {
      dt = dateTime.toDate();
    } else if (dateTime is String && dateTime.isNotEmpty) {
      dt = DateTime.tryParse(dateTime);
    } else if (dateTime is DateTime) {
      dt = dateTime;
    }
    if (dt == null) return 'Time not set';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  double _getLatitude(Map<String, dynamic> e) {
    final lat = e['latitude'];
    if (lat is double) return lat;
    if (lat is int) return lat.toDouble();
    // Default to a center location (e.g., San Francisco)
    return 37.7749;
  }

  double _getLongitude(Map<String, dynamic> e) {
    final lng = e['longitude'];
    if (lng is double) return lng;
    if (lng is int) return lng.toDouble();
    // Default to a center location (e.g., San Francisco)
    return -122.4194;
  }
}
