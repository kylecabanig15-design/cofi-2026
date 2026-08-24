import 'package:cofi/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
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
  // Indicates if we have finished checking permissions, so the map can render.
  bool _isPermissionResolved = false;
  // Tracks whether the user has manually moved the map.
  // When true, we skip the auto-center after GPS resolves so we don't
  // hijack the camera away from where the user is looking.
  bool _userHasInteracted = false;
  // True only while a real finger is down on the map. onCameraMove also fires
  // for programmatic animateCamera calls, so we use raw pointer events to
  // distinguish genuine gestures from GPS/recenter animations.
  bool _mapPointerActive = false;
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.35);
  
  // Tracks the live camera position. If the native map is forced to rebuild 
  // (e.g., when myLocationEnabled changes), we restore exactly to this spot.
  CameraPosition? _currentCameraPosition;

  // Cached streams to prevent map rebuilds on setState
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _shopsStream;

  // Memoized per-shop review streams. Rebuilding the cafe list sheet (recenter
  // toggle, shop select, bookmark change) previously created a fresh Firestore
  // subscription PER ROW — N listener churns per interaction. Reusing the same
  // Stream instance keeps StreamBuilders subscribed across rebuilds.
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
      _reviewStreams = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStreamFor(String shopId) {
    return _reviewStreams.putIfAbsent(
      shopId,
      () => FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('reviews')
          .limit(10)
          .snapshots(),
    );
  }

  BitmapDescriptor? _customMarker;

  @override
  void dispose() {
    _sheetExtent.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
    
    _shopsStream = FirebaseFirestore.instance
        .collection('shops')
        .where('isVerified', isEqualTo: true)
        .snapshots();
        
    // ----------------------------------------------------------------------
    // STEP A: Coordinate Acquisition (Permission & GPS)
    // ----------------------------------------------------------------------
    _getUserLocation();
  }

  Future<void> _loadCustomMarker() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/cofi_icon_red_white_pin.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 120, // 120px is crisp but not overwhelmingly large for a map pin
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null && mounted) {
        setState(() {
          _customMarker = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint('Error loading custom marker: $e');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugLog('Location service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        debugLog('Location services are disabled.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enable Location Services')));
        }
        setState(() {
          _isPermissionResolved = true;
          _isLoadingLocation = false;
        });
        return;
      }

      // Check if location permissions are granted
      debugLog('Checking location permission status...');
      var status = await Permission.locationWhenInUse.status;
      debugLog('Initial status: $status');
      
      if (status.isPermanentlyDenied) {
        debugLog('Location permission permanently denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied. Please enable in settings.'),
              action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
            ),
          );
        }
        setState(() {
          _isPermissionResolved = true;
          _isLoadingLocation = false;
        });
        return;
      }

      if (!status.isGranted) {
        debugLog('Requesting location permission...');
        status = await Permission.locationWhenInUse.request();
        debugLog('New status: $status');
        if (!status.isGranted) {
          setState(() {
            _isLoadingLocation = false;
            _locationPermissionGranted = false;
            _isPermissionResolved = true;
          });
          return;
        }
      }

      // PERMISSION RESOLVED.
      // Build the GoogleMap NOW with myLocationEnabled: true from the very start.
      // This prevents the native map from ever flashing or tearing down!
      setState(() {
        _locationPermissionGranted = true;
        _isPermissionResolved = true;
      });

      // Now wait for the slow GPS fetch (1-2 seconds)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Apply the location without touching map permission properties
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Only auto-center if the user hasn't moved the map themselves yet
      if (_userLocation != null && _mapController != null && _selectedShopId == null && !_userHasInteracted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation!, 14),
        );
      }
    } catch (e) {
      debugLog('Error getting user location: $e');
      if (mounted) {
        setState(() {
          _isPermissionResolved = true;
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _recenterToUserLocation() {
    if (_userLocation != null && _mapController != null) {
      // Reset the interaction flag so the map can auto-center again if needed
      _userHasInteracted = false;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14),
      );
      setState(() => _showRecenterButton = false);
    } else {
      _getUserLocation();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedShopId != null && _selectedShopData != null) {
      final lat = (_selectedShopData!['latitude'] as num?)?.toDouble();
      final lng = (_selectedShopData!['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 17.5)),
        );
      }
    } else if (_userLocation != null && !_userHasInteracted) {
      // Only fly to user location on map creation if they haven't moved it yet
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14),
      );
    }
  }

  // Fires continuously as camera moves — NO setState here to avoid rebuild loops
  void _onCameraMove(CameraPosition position) {
    _currentCameraPosition = position;

    // Only record interaction when the camera is moving under a real finger.
    // Programmatic animations (GPS auto-center, marker focus) have no active
    // pointer, so they no longer flip this flag.
    if (_mapPointerActive && !_userHasInteracted) {
      _userHasInteracted = true;
    }
  }

  void _onMapPointerDown(PointerDownEvent event) {
    _mapPointerActive = true;
  }

  void _onMapPointerUp(PointerEvent event) {
    _mapPointerActive = false;
  }

  // Fires once when the camera fully stops moving (gesture or programmatic)
  void _onCameraIdle() {
    if (_userLocation == null) return;

    // Get current camera position without a setState
    _mapController?.getVisibleRegion().then((bounds) {
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      final distance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        center.latitude,
        center.longitude,
      );
      final shouldShow = distance > 300;
      if (shouldShow != _showRecenterButton) {
        setState(() => _showRecenterButton = shouldShow);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, userSnap) {
          Set<String> bookmarks = {};
          if (userSnap.hasData && userSnap.data?.data() != null) {
            final u = userSnap.data!.data();
            bookmarks = ((u?['bookmarks'] as List?)?.cast<String>() ?? []).toSet();
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _shopsStream,
            builder: (context, shopSnap) {
              if (shopSnap.connectionState == ConnectionState.waiting || !_isPermissionResolved) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
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
                        onToggleBookmark: () {
                          if (_selectedShopId != null) {
                            _toggleBookmark(user, _selectedShopId!, bookmarks.contains(_selectedShopId));
                          }
                        },
                        onTap: () {
                          if (_selectedShopId != null && _selectedShopData != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CafeDetailsScreen(shopId: _selectedShopId!, shop: _selectedShopData!),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                  // 5. Recenter Button
                  if (_showRecenterButton)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: SafeArea(
                        child: FloatingActionButton(
                          heroTag: 'recenter',
                          onPressed: _recenterToUserLocation,
                          backgroundColor: Colors.white,
                          mini: true,
                          child: const Icon(Icons.my_location, color: Colors.black87),
                        ),
                      ),
                    ),
                  
                  // 6. Zoom Controls (+/-)
                  ValueListenableBuilder<double>(
                    valueListenable: _sheetExtent,
                    builder: (context, extent, child) {
                      // Hide the zoom controls when the sheet is pulled fully up (extent >= 0.7)
                      if (_selectedShopId != null || extent < 0.7) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        
                        // If a shop is selected, it anchors above the custom SelectedShopCard.
                        // Otherwise, it dynamically floats snugly above the bottom sheet's current height.
                        final bottomPosition = _selectedShopId != null 
                            ? 150.0 
                            : (extent * screenHeight) + 8.0;

                        return Positioned(
                          bottom: bottomPosition,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FloatingActionButton(
                                heroTag: 'zoomIn',
                                onPressed: () {
                                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                                },
                                backgroundColor: Colors.white,
                                mini: true,
                                child: const Icon(Icons.add, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                heroTag: 'zoomOut',
                                onPressed: () {
                                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                                },
                                backgroundColor: Colors.white,
                                mini: true,
                                child: const Icon(Icons.remove, color: Colors.black87),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
          anchor: const Offset(0.5, 1.0), // Anchors the pin exactly at its bottom tip so it doesn't crop or float
          icon: _customMarker ?? BitmapDescriptor.defaultMarkerWithHue(355.0),
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

    // If the map was already moved, preserve that exact position across rebuilds.
    final initialPos = _currentCameraPosition ?? CameraPosition(
      target: initialCenter,
      zoom: 14,
    );

    // Listener tracks real touch gestures on the map so onCameraMove can tell
    // user pans apart from programmatic camera animations.
    return Listener(
      onPointerDown: _onMapPointerDown,
      onPointerUp: _onMapPointerUp,
      onPointerCancel: _onMapPointerUp,
      child: GoogleMap(
      key: const ValueKey('google_map_view'),
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      initialCameraPosition: initialPos,
      markers: markers,
      myLocationEnabled: _locationPermissionGranted,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onTap: (_) {
        if (_selectedShopId != null) {
          setState(() {
            _selectedShopId = null;
            _selectedShopData = null;
          });
        }
      },
      padding: const EdgeInsets.only(bottom: 120),
      ),
    );
  }

  // ========================================================================
  // HARD 2KM DISTANCE THRESHOLD (Panel Requirement)
  // ========================================================================
  // The "Nearby" feature must only show cafés within 1km radius.
  // This is a hard filter, NOT user-configurable.
  static const double _nearbyThresholdMeters = 2000.0;

  /// Calculate distance from user to a shop in meters.
  /// Returns null when the shop has no usable coordinates so callers can
  /// exclude it from the Nearby list (consistent with the marker layer).
  double? _calculateDistanceToShop(Map<String, dynamic> data) {
    if (_userLocation == null) return null;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      lat,
      lng,
    );
  }

  Widget _buildCafeListSheet(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Set<String> bookmarks) {
    if (docs.isEmpty) return const SizedBox.shrink();

    // ----------------------------------------------------------------------
    // STEP 1: FILTER - Only include shops within 2km radius
    // ----------------------------------------------------------------------
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = [];
    
    if (_userLocation != null) {
      for (final doc in docs) {
        final distance = _calculateDistanceToShop(doc.data());
        // Skip shops without coordinates — we can't compute a real distance
        if (distance == null) continue;
        if (distance <= _nearbyThresholdMeters) {
          filteredDocs.add(doc);
        }
      }
      
      // ----------------------------------------------------------------------
      // STEP 2: SORT - Ascending order (nearest first)
      // ----------------------------------------------------------------------
      // Uses the Haversine logic (Geolocator.distanceBetween) to sort the 
      // list so that the physically closest café is at index 0.
      filteredDocs.sort((a, b) {
        // All docs in filteredDocs passed the null-coordinate filter above
        final distA = _calculateDistanceToShop(a.data())!;
        final distB = _calculateDistanceToShop(b.data())!;
        return distA.compareTo(distB);
      });
    } else {
      // No location - show all but warn user
      filteredDocs = List.from(docs);
    }

    final double screenHeight = MediaQuery.of(context).size.height;
    // Calculate a safe minimum size to fit the 70px toolbar height perfectly.
    // This makes the design responsive across different OS and device sizes.
    final double safeMinSize = (75.0 / screenHeight).clamp(0.08, 0.35);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (_sheetExtent.value != notification.extent) {
          _sheetExtent.value = notification.extent;
        }
        return true;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.35,
        minChildSize: safeMinSize,
        maxChildSize: 0.8,
        snap: true,
        snapSizes: [safeMinSize, 0.35, 0.8],
        builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 70,
                primary: false,
                titleSpacing: 0,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nearby Cafes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Bold',
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _userLocation != null ? '${filteredDocs.length} within 2km' : '${filteredDocs.length} total',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ), // Closes SliverAppBar
              if (filteredDocs.isEmpty && _userLocation != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text(
                          'No cafes within 2km',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try exploring the map for more options',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data();
                      final name = (data['name'] as String?) ?? 'Unknown';
                      final address = (data['address'] as String?) ?? '';
                      final num embeddedRating = (data['ratings'] as num?) ?? 0.0;
                      final int embeddedCount = (data['reviews'] as List?)?.length ?? 0;
                      
                      final gallery = (data['gallery'] as List?)?.cast<String>() ?? [];
                      final imageUrl = gallery.isNotEmpty ? gallery[0] : '';

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _selectShop(doc.id, data),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.black26,
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(imageUrl, fit: BoxFit.cover)
                                        : const Icon(Icons.store, color: Colors.white54, size: 30),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: -0.3,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              address,
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                        stream: _reviewsStreamFor(doc.id),
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
                                            rating = embeddedRating.toDouble();
                                            count = embeddedCount;
                                          }

                                          return Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      rating.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '($count reviews)',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filteredDocs.length,
                  ),
                ),
            ],
          ),
        );
      },
    ));
  }

  void _selectShop(String id, Map<String, dynamic> data) {
    // Extract coords BEFORE setState so we don't trigger an extra rebuild
    final latRaw = data['latitude'];
    final lngRaw = data['longitude'];
    final double? lat = (latRaw is num) ? latRaw.toDouble() : double.tryParse(latRaw?.toString() ?? '');
    final double? lng = (lngRaw is num) ? lngRaw.toDouble() : double.tryParse(lngRaw?.toString() ?? '');

    // Update selection state
    setState(() {
      _selectedShopId = id;
      _selectedShopData = data;
      _showRecenterButton = false;
    });

    // Delay camera animation so the widget rebuild fully settles first.
    // This prevents the black/white tile flash caused by animating during a rebuild.
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(lat, lng), zoom: 17.0),
            ),
          );
        }
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
      // update() fails when the user doc doesn't exist yet. Only seed the
      // array when ADDING — re-adding on a failed removal would silently
      // undo the user's action.
      if (!isBookmarked) {
        await ref.set({
          'bookmarks': [shopId],
        }, SetOptions(merge: true));
      }
    }
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
