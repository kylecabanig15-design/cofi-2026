import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cofi/widgets/coffee_shop_details_bottom_sheet.dart';
import 'package:cofi/widgets/selected_shop_card.dart';

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
  Map<String, dynamic>? _selectedShopData;
  String? _selectedShopId;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    // ----------------------------------------------------------------------
    // STEP A: Coordinate Acquisition (Permission & GPS)
    // ----------------------------------------------------------------------
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        print('Location services are disabled.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enable Location Services')));
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check if location permissions are granted
      print('Checking location permission status...');
      var status = await Permission.locationWhenInUse.status;
      print('Initial status: $status');
      
      if (status.isPermanentlyDenied) {
        print('Location permission permanently denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied. Please enable in settings.'),
              action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      if (!status.isGranted) {
        print('Requesting location permission...');
        status = await Permission.locationWhenInUse.request();
        print('New status: $status');
        if (!status.isGranted) {
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionGranted = false;
          });
          return;
        }
      }

      setState(() {
        _locationPermissionGranted = true;
      });

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Center map on user's location ONLY if no shop is selected
      if (_userLocation != null && _mapController != null && _selectedShopId == null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation!, 14),
        );
      }
    } catch (e) {
      print('Error getting user location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
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
    // Prioritize selected shop location if one is selected
    if (_selectedShopId != null && _selectedShopData != null) {
      final lat = (_selectedShopData!['latitude'] as num?)?.toDouble();
      final lng = (_selectedShopData!['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 18),
        );
      }
    } else if (_userLocation != null) {
      // Otherwise fallback to user location
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14),
      );
    }
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: user != null
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
            : null,
        builder: (context, userSnap) {
          Set<String> bookmarks = {};
          if (userSnap.hasData && userSnap.data?.data() != null) {
            final u = userSnap.data!.data();
            bookmarks = ((u?['bookmarks'] as List?)?.cast<String>() ?? []).toSet();
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .where('isVerified', isEqualTo: true)
                .snapshots(),
            builder: (context, shopSnap) {
              if (shopSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = shopSnap.data?.docs ?? [];
              
              return Stack(
                children: [
                   // 1. Map Layer
                  _buildMapLayer(docs),

                  // 2. Back Button
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                        ),
                      ),
                    ),
                  ),

                  // 3. Cafe List Bottom Sheet (Visible when no shop selected)
                  if (_selectedShopId == null)
                    _buildCafeListSheet(docs, bookmarks),

                  // 4. Selected Shop Card (Visible when shop selected)
                  if (_selectedShopId != null && _selectedShopData != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: SelectedShopCard(
                        data: _selectedShopData!,
                        shopId: _selectedShopId!,
                        isBookmarked: bookmarks.contains(_selectedShopId),
                        onClose: () {
                          setState(() {
                            _selectedShopId = null;
                            _selectedShopData = null;
                            // Optionally recenter map nicely or do nothing
                          });
                        },
                        onToggleBookmark: () => _toggleBookmark(user, _selectedShopId!, bookmarks.contains(_selectedShopId)),
                        onTap: () => _showShopDetails(_selectedShopId!, _selectedShopData!, bookmarks),
                      ),
                    ),

                  // 5. Recenter Button
                  if (_showRecenterButton)
                    Positioned(
                      bottom: _selectedShopId != null ? 150 : 120, // Move up if card is shown, though list obscures it usually
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: _recenterToUserLocation,
                        backgroundColor: Colors.white,
                        mini: true,
                        child: const Icon(Icons.my_location, color: Colors.black87),
                      ),
                    ),
                  
                  // 6. Loading Location Indicator
                  if (_isLoadingLocation)
                    Positioned(
                      top: 60,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Getting your location...',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ========================================================================
  // HAVERSINE FORMULA & GEOSPATIAL LOGIC
  // ========================================================================
  //
  // This section of the codebase handles the visual and logical representation
  // of café locations. It calculates distances using the HAVERSINE FORMULA.
  //
  // Formula:
  //   a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)
  //   c = 2 * asin(sqrt(a))
  //   Distance (d) = R * c
  // ========================================================================
  Widget _buildMapLayer(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final markers = <Marker>{};
    for (final doc in docs) {
      final data = doc.data();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          onTap: () => _selectShop(doc.id, data),
        ),
      );
    }

     LatLng? initialCenter;
    
    // 1. Try selected shop
    if (_selectedShopId != null && _selectedShopData != null) {
      final lat = (_selectedShopData!['latitude'] as num?)?.toDouble();
      final lng = (_selectedShopData!['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        initialCenter = LatLng(lat, lng);
      }
    }

    // 2. Try user location
    initialCenter ??= _userLocation;

    // 3. Fallback to markers or default
    initialCenter ??= (markers.isNotEmpty
            ? markers.first.position
            : const LatLng(7.0647, 125.6088));

    return GoogleMap(
      key: const ValueKey('google_map_view'), // PREVENTS MAP RESET ON REBUILD
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: 14,
      ),
      markers: markers,
      myLocationEnabled: _locationPermissionGranted,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      onTap: (_) {
        if (_selectedShopId != null) {
          setState(() {
            _selectedShopId = null;
            _selectedShopData = null;
          });
        }
      },
      padding: const EdgeInsets.only(bottom: 120), // Constant padding to avoid layout shifts
    );
  }

  Widget _buildCafeListSheet(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Set<String> bookmarks) {
    if (docs.isEmpty) return const SizedBox.shrink();

    final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    // ----------------------------------------------------------------------
    // STEP C: Distance Ranking (Ascending Sort)
    // ----------------------------------------------------------------------
    // Uses the Haversine logic (Geolocator.distanceBetween) to sort the 
    // list so that the physically closest café is at index 0.
    // ========================================================================
    if (_userLocation != null) {
      sortedDocs.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();
        final latA = (dataA['latitude'] as num?)?.toDouble() ?? 0;
        final lngA = (dataA['longitude'] as num?)?.toDouble() ?? 0;
        final latB = (dataB['latitude'] as num?)?.toDouble() ?? 0;
        final lngB = (dataB['longitude'] as num?)?.toDouble() ?? 0;

        // ------------------------------------------------------------------
        // STEP B: Real-time Distance Computation
        // ------------------------------------------------------------------
        // Geolocator.distanceBetween abstracts the Haversine math 
        // for native high-performance computation.
        final distA = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          latA,
          lngA,
        );
        final distB = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          latB,
          lngB,
        );
        return distA.compareTo(distB); // Return ascending order (nearest first)
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 5),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Nearby Cafes (${docs.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Bold',
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              // List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data();
                    final name = (data['name'] as String?) ?? 'Unknown';
                    final address = (data['address'] as String?) ?? '';
                    final num embeddedRating = (data['ratings'] as num?) ?? 0.0;
                    final int embeddedCount = (data['reviews'] as List?)?.length ?? 0;
                    
                    // Logic for ratings adapted from CafeDetailsScreen

                     // Calculate average rating from reviews list


                    

                    final gallery = (data['gallery'] as List?)?.cast<String>() ?? [];
                    final imageUrl = gallery.isNotEmpty ? gallery[0] : '';

                    return InkWell(
                      onTap: () => _selectShop(doc.id, data),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[800],
                                child: imageUrl.isNotEmpty
                                    ? Image.network(imageUrl, fit: BoxFit.cover)
                                    : const Icon(Icons.store, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    address,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  const SizedBox(height: 4),
                                  // Live ratings from subcollection (most accurate)
                                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: FirebaseFirestore.instance
                                        .collection('shops')
                                        .doc(doc.id)
                                        .collection('reviews')
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      double rating = 0.0;
                                      int count = 0;
                                      
                                      if (snapshot.hasData) {
                                        final docs = snapshot.data!.docs;
                                        final scores = docs
                                            .map((d) => d.data()['rating'])
                                            .whereType<num>()
                                            .map((n) => n.toDouble())
                                            .toList();
                                        count = scores.length;
                                        if (count > 0) {
                                          rating = scores.reduce((a, b) => a + b) / count;
                                        }
                                      } else {
                                        // Fallback to embedded data while loading
                                        rating = embeddedRating.toDouble();
                                        count = embeddedCount;
                                      }

                                      return Row(
                                        children: [
                                          const Icon(Icons.star, size: 14, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            ' ($count)',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  )
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectShop(String id, Map<String, dynamic> data) {
    // 1. Update UI state first
    setState(() {
      _selectedShopId = id;
      _selectedShopData = data;
      _showRecenterButton = false;
    });

    final latRaw = data['latitude'];
    final lngRaw = data['longitude'];
    
    final double? lat = (latRaw is num) ? latRaw.toDouble() : double.tryParse(latRaw?.toString() ?? '');
    final double? lng = (lngRaw is num) ? lngRaw.toDouble() : double.tryParse(lngRaw?.toString() ?? '');

    // 2. Animate camera after the frame build ensures the map is ready and layout is stable
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 18),
        );
      });
    }
  }

  Future<void> _toggleBookmark(User? user, String shopId, bool isBookmarked) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to bookmark shops')),
      );
      return;
    }
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
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

  void _showShopDetails(String shopId, Map<String, dynamic> data, Set<String> bookmarks) {
    final name = (data['name'] as String?) ?? 'Unknown';
    final address = (data['address'] as String?) ?? '';
    final embeddedAvg = ((data['ratings'] as num?)?.toDouble() ?? 0.0);
    final embeddedCount = ((data['reviews'] as List?)?.length ?? 0);
    final hours = _formatTodayHours((data['schedule'] as Map<String, dynamic>?) ?? {});
    final gallery = (data['gallery'] as List?)?.cast<String>() ?? [];
    final imageUrl = gallery.isNotEmpty ? gallery[0] : '';
    final logoUrl = (data['logoUrl'] as String?) ?? '';

    CoffeeShopDetailsBottomSheet.show(
      context,
      imageUrl: imageUrl,
      shopId: shopId,
      name: name,
      location: address,
      hours: hours,
      rating: '${embeddedAvg.toStringAsFixed(1)} ($embeddedCount)',
      isBookmarked: bookmarks.contains(shopId),
      onToggleBookmark: () => _toggleBookmark(FirebaseAuth.instance.currentUser, shopId, bookmarks.contains(shopId)),
      logoUrl: logoUrl,
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
