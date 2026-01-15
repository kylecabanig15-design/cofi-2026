import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/colors.dart';
import '../../widgets/coffee_shop_details_bottom_sheet.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _showRecenterButton = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location permissions are granted
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Center map on user's location
      if (_userLocation != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation!, 14),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _recenterToUserLocation() {
    if (_userLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14),
      );
      setState(() {
        _showRecenterButton = false;
      });
    } else {
      _getUserLocation();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    if (_showRecenterButton || _userLocation == null) return;

    final distance = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      position.target.latitude,
      position.target.longitude,
    );

    if (distance > 500 && !_showRecenterButton) {
      setState(() {
        _showRecenterButton = true;
      });
    } else if (distance <= 500 && _showRecenterButton) {
      setState(() {
        _showRecenterButton = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user != null
          ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                Set<String> bookmarks = {};
                if (userSnap.hasData) {
                  final u = userSnap.data!.data();
                  bookmarks = ((u?['bookmarks'] as List?)?.cast<String>() ?? [])
                      .toSet();
                }
                return _buildMapView(bookmarks, user);
              },
            )
          : _buildMapView(<String>{}, null),
    );
  }

  Widget _buildMapView(Set<String> bookmarks, User? user) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final markers = <Marker>{};

        Future<void> toggleBookmark(String shopId, bool isBookmarked) async {
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to bookmark shops')),
            );
            return;
          }
          final ref =
              FirebaseFirestore.instance.collection('users').doc(user.uid);
          try {
            await ref.update({
              'bookmarks': isBookmarked
                  ? FieldValue.arrayRemove([shopId])
                  : FieldValue.arrayUnion([shopId])
            });
          } catch (e) {
            await ref.set({
              'bookmarks': [shopId],
            }, SetOptions(merge: true));
          }
        }

        for (final doc in docs) {
          final data = doc.data();
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          final name = (data['name'] as String?) ?? 'Unknown';
          final address = (data['address'] as String?) ?? '';
          final embeddedAvg = ((data['ratings'] as num?)?.toDouble() ?? 0.0);
          final embeddedCount = ((data['reviews'] as List?)?.length ?? 0);
          final hours = _formatTodayHours(
              (data['schedule'] as Map<String, dynamic>?) ?? {});
          final isBM = bookmarks.contains(doc.id);

          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: name,
                snippet: address,
                onTap: () {
                  final gallery =
                      (data['gallery'] as List?)?.cast<String>() ?? [];
                  final imageUrl = gallery.isNotEmpty ? gallery[0] : '';
                  CoffeeShopDetailsBottomSheet.show(
                    imageUrl: imageUrl,
                    context,
                    shopId: doc.id,
                    name: name,
                    location: address,
                    hours: hours,
                    rating:
                        '${embeddedAvg.toStringAsFixed(1)} ($embeddedCount)',
                    isBookmarked: isBM,
                    onToggleBookmark: () => toggleBookmark(doc.id, isBM),
                  );
                },
              ),
            ),
          );
        }

        final initialCenter = _userLocation ??
            (markers.isNotEmpty
                ? markers.first.position
                : const LatLng(7.0647, 125.6088));

        return Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMove,
              initialCameraPosition: CameraPosition(
                target: initialCenter,
                zoom: 14,
              ),
              markers: markers,
              myLocationEnabled: _userLocation != null,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
            if (_showRecenterButton)
              Positioned(
                bottom: 30,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _recenterToUserLocation,
                  backgroundColor: primary,
                  mini: true,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                  ),
                ),
              ),
            if (_isLoadingLocation)
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Getting your location...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatTodayHours(Map<String, dynamic> schedule) {
    try {
      final dayKeys = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      final now = DateTime.now();
      final idx = (now.weekday - 1).clamp(0, 6);
      final key = dayKeys[idx];
      final m = (schedule[key] as Map?)?.cast<String, dynamic>() ?? {};
      final isOpen = (m['isOpen'] as bool?) ?? false;
      if (!isOpen) return 'Closed today';
      final open = (m['open'] as String?) ?? '';
      final close = (m['close'] as String?) ?? '';
      if (open.isEmpty || close.isEmpty) return 'Mixed Hours · Tap to view';
      String fmt(String hhmm) {
        final parts = hhmm.split(':');
        if (parts.length != 2) return hhmm;
        int h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12;
        if (h == 0) h = 12;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }

      return '${fmt(open)} - ${fmt(close)}';
    } catch (_) {
      return 'Mixed Hours · Tap to view';
    }
  }
}
