import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/text_widget.dart';
import '../../../widgets/post_event_bottom_sheet.dart';
import '../../../utils/colors.dart';
import 'event_comments_screen.dart';

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
                            bottom: 90,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                imageUrls.length,
                                (index) => Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Left Arrow
                        if (_currentImageIndex > 0)
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 100,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left,
                                      color: Colors.white, size: 28),
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        // Right Arrow
                        if (_currentImageIndex < imageUrls.length - 1)
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 100,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right,
                                      color: Colors.white, size: 28),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
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
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget(
                                text: (e['title'] ?? 'Event').toString(),
                                fontSize: 24,
                                color: Colors.white,
                                isBold: true,
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
                          text: (e['address'] ?? 'Address not specified')
                              .toString(),
                          fontSize: 14,
                          color: Colors.white70,
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
                                    ? _enableEvent(
                                        context, e['shopId'], e['id'])
                                    : _pauseEvent(
                                        context, e['shopId'], e['id']),
                                icon: Icon(
                                    isPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(isPaused ? 'Enable' : 'Pause'),
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
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
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
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app, color: Colors.white),
                        const SizedBox(width: 8),
                        TextWidget(
                          text: 'Tap to participate',
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pauseEvent(
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
          const SnackBar(content: Text('Event paused')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pause event: $e')),
        );
      }
    }
  }

  Future<void> _enableEvent(
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
          const SnackBar(content: Text('Event enabled')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enable event: $e')),
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
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final yr = dt.year.toString();
    return '$yr-$mon-$day';
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
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final yr = dt.year.toString();
    return '$yr-$mon-$day';
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
