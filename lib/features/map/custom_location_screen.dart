import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class CustomLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const CustomLocationScreen({super.key, this.initialLocation});

  @override
  State<CustomLocationScreen> createState() => _CustomLocationScreenState();
}

class _CustomLocationScreenState extends State<CustomLocationScreen> {
  LatLng? _selectedLocation;
  String? _selectedLocationName;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // Google Maps API Key (use from your config)
  static const String _googleMapsApiKey =
      'AIzaSyDzqOhK3i_zOQ-6fN8PqfGqM0HkLqVDrMc';

  // Davao City coordinates
  static const LatLng _davaoCityCenter = LatLng(7.0731, 125.6128);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _davaoCityCenter;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    setState(() {
      _isLoading = false;
      _updateMarker();
    });
  }

  void _updateMarker() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation!,
            infoWindow: const InfoWindow(title: 'Shop Location'),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
      });
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedLocationName = 'Loading...';
      _updateMarker();
    });
    _getAddressFromCoordinates(location.latitude, location.longitude);
  }

  void _onMapCreated(GoogleMapController controller) {
    // Map controller created but not used for now
  }

  void _confirmLocation() {
    if (_selectedLocation != null &&
        _selectedLocationName != null &&
        _selectedLocationName != 'Loading...') {
      Navigator.pop(context, {
        'location': _selectedLocation,
        'name': _selectedLocationName,
      });
    }
  }

  Future<void> _getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      debugPrint('Reverse geocoding: lat=$latitude, lon=$longitude');

      // Try Google Geocoding API first
      final String googleUrl =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$_googleMapsApiKey';
      final googleResponse = await http.get(Uri.parse(googleUrl));

      debugPrint(
          'Google Geocoding response status: ${googleResponse.statusCode}');
      if (googleResponse.statusCode == 200) {
        final json = jsonDecode(googleResponse.body);
        final results = json['results'] as List? ?? [];

        if (results.isNotEmpty) {
          final address = results[0]['formatted_address'] as String? ?? '';
          debugPrint('Extracted address from Google: $address');
          setState(() {
            _selectedLocationName = address;
          });
          return;
        }
      }

      // Fallback to OpenStreetMap Nominatim API if Google fails
      debugPrint('Google Geocoding failed, trying Nominatim...');
      final String nominatimUrl =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude';
      final nominatimResponse = await http.get(
        Uri.parse(nominatimUrl),
        headers: {'User-Agent': 'CoFi-App'},
      );

      debugPrint('Nominatim response status: ${nominatimResponse.statusCode}');
      if (nominatimResponse.statusCode == 200) {
        final json = jsonDecode(nominatimResponse.body);
        final address = json['address'] != null
            ? json['display_name'] as String? ?? ''
            : '';

        if (address.isNotEmpty) {
          debugPrint('Extracted address from Nominatim: $address');
          setState(() {
            _selectedLocationName = address;
          });
        }
      } else {
        debugPrint(
            'Nominatim API error: ${nominatimResponse.statusCode} - ${nominatimResponse.body}');
      }
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: TextWidget(
          text: 'Select Shop Location',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation ?? _davaoCityCenter,
                          zoom: 16.0,
                        ),
                        // Listen to camera movement to update location
                        onCameraMove: (CameraPosition position) {
                          setState(() {
                            _selectedLocation = position.target;
                            _selectedLocationName = 'Loading...';
                          });
                        },
                        // When movement stops, fetch the address
                        onCameraIdle: () {
                          if (_selectedLocation != null) {
                            _getAddressFromCoordinates(
                              _selectedLocation!.latitude,
                              _selectedLocation!.longitude,
                            );
                          }
                        },
                        // Disable markers since we use a fixed center pin
                        markers: {},
                        mapType: MapType.normal,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                      ),
                      // Fixed Center Pin
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 50,
                              color: primary,
                            ),
                            // Offset to align the tip of the pin with the center
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: 'Drag the map to position the pin',
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 12),
                        TextWidget(
                          text: 'Location Name:',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 4),
                        TextWidget(
                          text: _selectedLocationName ?? 'Loading...',
                          fontSize: 14,
                          color: Colors.white,
                          isBold: true,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_selectedLocationName != null &&
                                  _selectedLocationName != 'Loading...')
                              ? _confirmLocation
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            disabledBackgroundColor: Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          child: TextWidget(
                            text: (_selectedLocationName == 'Loading...')
                                ? 'Loading address...'
                                : 'Confirm Location',
                            fontSize: 16,
                            color: Colors.white,
                            isBold: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
