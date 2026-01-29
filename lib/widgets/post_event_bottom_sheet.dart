import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'text_widget.dart';
import 'package:cofi/features/map/custom_location_screen.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/utils/colors.dart';

class PostEventBottomSheet extends StatefulWidget {
  const PostEventBottomSheet({super.key, required this.shopId});

  final String shopId;

  static void show(BuildContext context, {required String shopId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PostEventBottomSheet(shopId: shopId),
    );
  }

  @override
  State<PostEventBottomSheet> createState() => _PostEventBottomSheetState();
}

class _PostEventBottomSheetState extends State<PostEventBottomSheet> {
  final _eventNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _aboutController = TextEditingController();
  final _emailController = TextEditingController();
  final _linkController = TextEditingController();
  bool _saving = false;

  // Date variables
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Image picker related variables
  final ImagePicker _picker = ImagePicker();

  final List<File> _selectedImages = [];


  // Map related variables
  // double _latitude = 37.7749; // Default to San Francisco
  // double _longitude = -122.4194;
  // GoogleMapController? _mapController;

  // Location selection
  String _locationType = 'my_location'; // 'my_location' or 'custom_location'
  LatLng? _selectedLocation;
  bool _locationReady = false;

  // Autocomplete related variables


  @override
  void initState() {
    super.initState();
    // Ensure location services and permission are enabled on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationReady();
    });
  }

  Future<void> _saveEvent() async {
    final title = _eventNameController.text.trim();
    final address = _addressController.text.trim();
    final about = _aboutController.text.trim();
    final email = _emailController.text.trim();
    final link = _linkController.text.trim();

    if (title.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter Event Name and select both start and end dates.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Get location based on selection
      double? latitude;
      double? longitude;

      if (_locationType == 'my_location') {
        final position = await _getCurrentPosition();
        latitude = position?.latitude;
        longitude = position?.longitude;
      } else if (_selectedLocation != null) {
        latitude = _selectedLocation!.latitude;
        longitude = _selectedLocation!.longitude;
      }

      // Check if location is valid
      if (latitude == null || longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location required. Please enable location or select a custom location.')),
        );
        if (mounted) setState(() => _saving = false);
        return;
      }

      // Upload images if selected
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImagesToFirebase();
      }

      // Combine date and time into DateTime objects
      final startDateTime = _startDate != null && _startTime != null
          ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day,
              _startTime!.hour, _startTime!.minute)
          : _startDate;

      final endDateTime = _endDate != null && _endTime != null
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
              _endTime!.hour, _endTime!.minute)
          : _endDate;

      final data = {
        'title': title,
        'address': address,
        'startDate': startDateTime,
        'endDate': endDateTime,
        'about': about,
        'email': email,
        'link': link,
        'imageUrls': imageUrls,
        'imageUrl': imageUrls.isNotEmpty
            ? imageUrls.first
            : null, // Store single image URL
        'latitude': latitude,
        'longitude': longitude,
        'status': 'pending',
        'participantsCount': 0,
        'shopId': widget.shopId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('events')
          .add(data);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event posted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<String>> _uploadImagesToFirebase() async {
    List<String> downloadUrls = [];
    if (_selectedImages.isEmpty) return downloadUrls;

    try {
      for (var i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final ref = FirebaseStorage.instance
            .ref()
            .child('shop_events')
            .child(widget.shopId)
            .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');

        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      }
      return downloadUrls;
    } catch (e) {
      debugPrint('Error uploading images: $e');
      rethrow;
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          // Add new images to the list, limiting to 5 total
          final remainingSlots = 5 - _selectedImages.length;
          if (remainingSlots > 0) {
            final imagesToAdd = pickedFiles
                .take(remainingSlots)
                .map((e) => File(e.path))
                .toList();
            _selectedImages.addAll(imagesToAdd);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 5 images allowed')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _ensureLocationReady() async {
    if (!mounted) return;
    while (mounted) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Enable Location Services'),
            content: const Text(
                'Please turn on Location Services to post an event with your current location.'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () {
                  // Retry check
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        // Loop and re-check
        continue;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Permission Needed'),
            content: const Text(
                'Please grant location permission in App Settings to continue.'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Open App Settings'),
              ),
              TextButton(
                onPressed: () {
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        continue;
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        if (mounted) setState(() => _locationReady = true);
        break;
      }
      // If still denied (not forever), loop to request again
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectCustomLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomLocationScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final selectedLocation = result['location'];
        final locationName = result['name'];
        if (selectedLocation is LatLng) {
          _selectedLocation = selectedLocation;
        }
        if (locationName is String) {
          _addressController.text = locationName;
        }
      });
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextWidget(
                    text: 'Post an Event',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Name
                      _buildField('Event Name', _eventNameController),

                      const SizedBox(height: 20),

                      // Image Carousel
                      SizedBox(
                        height: 200,
                        child: _selectedImages.isEmpty
                            ? GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[700]!,
                                      width: 1,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: Colors.white54,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      TextWidget(
                                        text: 'Add up to 5 photos',
                                        fontSize: 14,
                                        color: Colors.white54,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length +
                                    (_selectedImages.length < 5 ? 1 : 0),
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  if (index == _selectedImages.length) {
                                    // Add button at the end
                                    return GestureDetector(
                                      onTap: _pickImages,
                                      child: Container(
                                        width: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[700]!),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.add,
                                              color: Colors.white, size: 30),
                                        ),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _selectedImages[index],
                                          width: 280,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 20),

                      // Start Date
                      _buildDateField('Start Date', _startDate, (date) {
                        setState(() {
                          _startDate = date;
                          // Ensure end date is not before start date
                          if (_endDate != null &&
                              _endDate!.isBefore(_startDate!)) {
                            _endDate = _startDate;
                          }
                        });
                      }),

                      const SizedBox(height: 20),

                      // End Date
                      _buildDateField('End Date', _endDate, (date) {
                        setState(() {
                          _endDate = date;
                          // Ensure end date is not before start date
                          if (_startDate != null &&
                              _endDate!.isBefore(_startDate!)) {
                            _endDate = _startDate;
                          }
                        });
                      }),

                      const SizedBox(height: 20),

                      // Start Time
                      _buildTimeField('Start Time', _startTime, (time) {
                        setState(() {
                          _startTime = time;
                        });
                      }),

                      const SizedBox(height: 12),

                      // End Time
                      _buildTimeField('End Time', _endTime, (time) {
                        setState(() {
                          _endTime = time;
                        });
                      }),

                      const SizedBox(height: 20),

                      // Shop Location Section (moved above Address)
                      TextWidget(
                        text: 'Location',
                        fontSize: 16,
                        color: Colors.white,
                        isBold: true,
                      ),
                      const SizedBox(height: 12),

                      // Location Type Selection
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: TextWidget(
                                text: 'My Current Location',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              subtitle: TextWidget(
                                text: 'Use my current location for the event',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              value: 'my_location',
                              groupValue: _locationType,
                              onChanged: (value) {
                                setState(() {
                                  _locationType = value!;
                                });
                              },
                              activeColor: primary,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            RadioListTile<String>(
                              title: TextWidget(
                                text: 'Custom Location',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              subtitle: TextWidget(
                                text: 'Select a custom location on the map',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              value: 'custom_location',
                              groupValue: _locationType,
                              onChanged: (value) {
                                setState(() {
                                  _locationType = value!;
                                });
                              },
                              activeColor: primary,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ],
                        ),
                      ),

                      // Show selected custom location info
                      if (_locationType == 'custom_location' &&
                          _selectedLocation != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextWidget(
                                  text:
                                      'Selected: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              TextButton(
                                onPressed: _selectCustomLocation,
                                child: const Text('Change',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                      // Custom location selection button
                      if (_locationType == 'custom_location')
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _selectCustomLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                            child: TextWidget(
                              text: _selectedLocation == null
                                  ? 'Select Location on Map'
                                  : 'Change Location',
                              fontSize: 16,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Location requirement notice for my location
                      if (_locationType == 'my_location' && !_locationReady)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_off,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Location required',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Please enable Location Services and grant permission to proceed.',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                    if (!_locationReady)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: GestureDetector(
                                          onTap: _ensureLocationReady,
                                          child: const Text(
                                            'Check Again',
                                            style: TextStyle(
                                                color: Colors.amber,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Address Field (Below location logic)
                      _buildField('Address', _addressController),

                      const SizedBox(height: 20),

                      // About
                      _buildField('About', _aboutController),

                      const SizedBox(height: 20),

                      // Email
                      _buildField('Email', _emailController),

                      const SizedBox(height: 20),

                      // Link (Optional)
                      _buildField('Link (Optional)', _linkController),

                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFE53E3E), // Red color
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : TextWidget(
                                  text: 'Save',
                                  fontSize: 16,
                                  color: Colors.white,
                                  isBold: true,
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
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

  Widget _buildField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
      String label, DateTime? selectedDate, Function(DateTime) onDateChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onDateChanged(picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  selectedDate != null
                      ? _formatDate(selectedDate)
                      : 'Select $label',
                  style: TextStyle(
                    color:
                        selectedDate != null ? Colors.grey : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Widget _buildTimeField(String label, TimeOfDay? selectedTime,
      Function(TimeOfDay) onTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
            );
            if (picked != null) {
              onTimeChanged(picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  selectedTime != null
                      ? '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                      : 'Select $label',
                  style: TextStyle(
                    color:
                        selectedTime != null ? Colors.grey : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EditEventBottomSheet extends StatefulWidget {
  const EditEventBottomSheet({
    super.key,
    required this.eventId,
    required this.shopId,
    required this.eventData,
  });

  final String eventId;
  final String shopId;
  final Map<String, dynamic> eventData;

  @override
  State<EditEventBottomSheet> createState() => _EditEventBottomSheetState();
}

class _EditEventBottomSheetState extends State<EditEventBottomSheet> {
  late final TextEditingController _eventNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _aboutController;
  late final TextEditingController _emailController;
  late final TextEditingController _linkController;
  bool _saving = false;

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Location selection
  String _locationType = 'my_location'; // 'my_location' or 'custom_location'
  LatLng? _selectedLocation;
  bool _locationReady = false;

  // Image related variables
  final ImagePicker _picker = ImagePicker();
  final List<File> _newImages = [];
  List<String> _existingImageUrls = [];
  final bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    _eventNameController =
        TextEditingController(text: widget.eventData['title'] ?? '');
    _addressController =
        TextEditingController(text: widget.eventData['address'] ?? '');
    _aboutController =
        TextEditingController(text: widget.eventData['about'] ?? '');
    _emailController =
        TextEditingController(text: widget.eventData['email'] ?? '');
    _linkController =
        TextEditingController(text: widget.eventData['link'] ?? '');

    // Parse dates and times
    if (widget.eventData['startDate'] != null) {
      final startDate = widget.eventData['startDate'];
      DateTime? parsedStart;
      if (startDate is Timestamp) {
        parsedStart = startDate.toDate();
      } else if (startDate is DateTime) {
        parsedStart = startDate;
      } else if (startDate is String) {
        try {
          parsedStart = DateTime.parse(startDate);
        } catch (_) {}
      }
      if (parsedStart != null) {
        _startDate =
            DateTime(parsedStart.year, parsedStart.month, parsedStart.day);
        _startTime =
            TimeOfDay(hour: parsedStart.hour, minute: parsedStart.minute);
      }
    }

    if (widget.eventData['endDate'] != null) {
      final endDate = widget.eventData['endDate'];
      DateTime? parsedEnd;
      if (endDate is Timestamp) {
        parsedEnd = endDate.toDate();
      } else if (endDate is DateTime) {
        parsedEnd = endDate;
      } else if (endDate is String) {
        try {
          parsedEnd = DateTime.parse(endDate);
        } catch (_) {}
      }
      if (parsedEnd != null) {
        _endDate = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);
        _endTime = TimeOfDay(hour: parsedEnd.hour, minute: parsedEnd.minute);
      }
    }

    // Load existing coordinates
    if (widget.eventData['latitude'] != null &&
        widget.eventData['longitude'] != null) {
      double lat = widget.eventData['latitude'] is double
          ? widget.eventData['latitude']
          : (widget.eventData['latitude'] as num).toDouble();
      double lng = widget.eventData['longitude'] is double
          ? widget.eventData['longitude']
          : (widget.eventData['longitude'] as num).toDouble();

      _selectedLocation = LatLng(lat, lng);
      _locationType = 'custom_location';
    }

    // Initialize existing images
    if (widget.eventData['imageUrls'] != null) {
      _existingImageUrls = List<String>.from(widget.eventData['imageUrls']);
    } else if (widget.eventData['imageUrl'] != null) {
      _existingImageUrls.add(widget.eventData['imageUrl']);
    }

    // Ensure location services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationReady();
    });
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    final title = _eventNameController.text.trim();
    final address = _addressController.text.trim();
    final about = _aboutController.text.trim();
    final email = _emailController.text.trim();
    final link = _linkController.text.trim();

    if (title.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter Event Name and select both start and end dates.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      double? latitude;
      double? longitude;

      if (_locationType == 'my_location') {
        final position = await _getCurrentPosition();
        latitude = position?.latitude;
        longitude = position?.longitude;
      } else if (_selectedLocation != null) {
        latitude = _selectedLocation!.latitude;
        longitude = _selectedLocation!.longitude;
      }

      // Check if location is valid
      if (latitude == null || longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location required. Please enable location or select a custom location.')),
        );
        if (mounted) setState(() => _saving = false);
        return;
      }

      // Upload new images
      List<String> newImageUrls = [];
      if (_newImages.isNotEmpty) {
        newImageUrls = await _uploadImagesToFirebase();
      }

      // Combine existing and new URLs
      final List<String> finalImageUrls = [
        ..._existingImageUrls,
        ...newImageUrls
      ];

      final startDateTime = _startDate != null && _startTime != null
          ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day,
              _startTime!.hour, _startTime!.minute)
          : _startDate;

      final endDateTime = _endDate != null && _endTime != null
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
              _endTime!.hour, _endTime!.minute)
          : _endDate;

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('events')
          .doc(widget.eventId)
          .update({
        'title': title,
        'address': address,
        'startDate': startDateTime,
        'endDate': endDateTime,
        'about': about,
        'email': email,
        'link': link,
        'imageUrls': finalImageUrls,
        'imageUrl': finalImageUrls.isNotEmpty
            ? finalImageUrls.first
            : null, // Backward compatibility
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update event: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          // Calculate remaining slots
          final currentCount = _existingImageUrls.length + _newImages.length;
          final remainingSlots = 5 - currentCount;

          if (remainingSlots > 0) {
            final imagesToAdd = pickedFiles
                .take(remainingSlots)
                .map((e) => File(e.path))
                .toList();
            _newImages.addAll(imagesToAdd);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 5 images allowed')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<List<String>> _uploadImagesToFirebase() async {
    List<String> downloadUrls = [];
    if (_newImages.isEmpty) return downloadUrls;

    try {
      for (var i = 0; i < _newImages.length; i++) {
        final file = _newImages[i];
        final ref = FirebaseStorage.instance
            .ref()
            .child('shop_events')
            .child(widget.shopId)
            .child('${DateTime.now().millisecondsSinceEpoch}_new_$i.jpg');

        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      }
      return downloadUrls;
    } catch (e) {
      debugPrint('Error uploading images: $e');
      rethrow;
    }
  }

  Future<void> _ensureLocationReady() async {
    if (!mounted) return;
    while (mounted) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Enable Location Services'),
            content: const Text(
                'Please turn on Location Services to post an event with your current location.'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () {
                  // Retry check
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        // Loop and re-check
        continue;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Permission Needed'),
            content: const Text(
                'Please grant location permission in App Settings to continue.'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Open App Settings'),
              ),
              TextButton(
                onPressed: () {
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        continue;
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        if (mounted) setState(() => _locationReady = true);
        break;
      }
      // If still denied (not forever), loop to request again
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectCustomLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomLocationScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final selectedLocation = result['location'];
        final locationName = result['name'];
        if (selectedLocation is LatLng) {
          _selectedLocation = selectedLocation;
        }
        if (locationName is String) {
          _addressController.text = locationName;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextWidget(
                    text: 'Edit Event',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField('Event Name', _eventNameController),
                      const SizedBox(height: 20),

                      // Image Carousel
                      TextWidget(
                        text: 'Event Images (Max 5)',
                        fontSize: 16,
                        color: Colors.white,
                        isBold: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: (_existingImageUrls.isEmpty &&
                                _newImages.isEmpty)
                            ? GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[700]!,
                                      width: 1,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: Colors.white54,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      TextWidget(
                                        text: 'Add photos',
                                        fontSize: 14,
                                        color: Colors.white54,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _existingImageUrls.length +
                                    _newImages.length +
                                    (_existingImageUrls.length +
                                                _newImages.length <
                                            5
                                        ? 1
                                        : 0),
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  // Add button at the end
                                  if (index ==
                                      _existingImageUrls.length +
                                          _newImages.length) {
                                    return GestureDetector(
                                      onTap: _pickImages,
                                      child: Container(
                                        width: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[700]!),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.add,
                                              color: Colors.white, size: 30),
                                        ),
                                      ),
                                    );
                                  }

                                  // Existing Images
                                  if (index < _existingImageUrls.length) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: _existingImageUrls[index],
                                            width: 280,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              width: 280,
                                              height: 200,
                                              color: Colors.grey[800],
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              width: 280,
                                              height: 200,
                                              color: Colors.grey[800],
                                              child: const Center(
                                                  child: Icon(Icons.error,
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () =>
                                                _removeExistingImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // New Images
                                  final newIndex =
                                      index - _existingImageUrls.length;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _newImages[newIndex],
                                          width: 280,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () =>
                                              _removeNewImage(newIndex),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 20),
                      _buildDateField('Start Date', _startDate, (date) {
                        setState(() {
                          _startDate = date;
                          if (_endDate != null &&
                              _endDate!.isBefore(_startDate!)) {
                            _endDate = _startDate;
                          }
                        });
                      }),
                      const SizedBox(height: 20),
                      _buildDateField('End Date', _endDate, (date) {
                        setState(() {
                          _endDate = date;
                          if (_startDate != null &&
                              _endDate!.isBefore(_startDate!)) {
                            _endDate = _startDate;
                          }
                        });
                      }),
                      const SizedBox(height: 20),
                      _buildTimeField('Start Time', _startTime, (time) {
                        setState(() {
                          _startTime = time;
                        });
                      }),
                      const SizedBox(height: 12),
                      _buildTimeField('End Time', _endTime, (time) {
                        setState(() {
                          _endTime = time;
                        });
                      }),
                      const SizedBox(height: 20),
                      // Shop Location Section (moved above Address)
                      TextWidget(
                        text: 'Location',
                        fontSize: 16,
                        color: Colors.white,
                        isBold: true,
                      ),
                      const SizedBox(height: 12),

                      // Location Type Selection
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title: TextWidget(
                                text: 'My Current Location',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              subtitle: TextWidget(
                                text: 'Use my current location for the event',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              value: 'my_location',
                              groupValue: _locationType,
                              onChanged: (value) {
                                setState(() {
                                  _locationType = value!;
                                });
                              },
                              activeColor: primary,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            RadioListTile<String>(
                              title: TextWidget(
                                text: 'Custom Location',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              subtitle: TextWidget(
                                text: 'Select a custom location on the map',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              value: 'custom_location',
                              groupValue: _locationType,
                              onChanged: (value) {
                                setState(() {
                                  _locationType = value!;
                                });
                              },
                              activeColor: primary,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ],
                        ),
                      ),

                      // Show selected custom location info
                      if (_locationType == 'custom_location' &&
                          _selectedLocation != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextWidget(
                                  text:
                                      'Selected: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              TextButton(
                                onPressed: _selectCustomLocation,
                                child: const Text('Change',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                      // Custom location selection button
                      if (_locationType == 'custom_location')
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _selectCustomLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                            child: TextWidget(
                              text: _selectedLocation == null
                                  ? 'Select Location on Map'
                                  : 'Change Location',
                              fontSize: 16,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Location requirement notice for my location
                      if (_locationType == 'my_location' && !_locationReady)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_off,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Location required',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Please enable Location Services and grant permission to proceed.',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                    if (!_locationReady)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: GestureDetector(
                                          onTap: _ensureLocationReady,
                                          child: const Text(
                                            'Check Again',
                                            style: TextStyle(
                                                color: Colors.amber,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Address Field (Below location logic)
                      _buildField('Address', _addressController),
                      const SizedBox(height: 20),
                      _buildField('About', _aboutController),
                      const SizedBox(height: 20),
                      _buildField('Email', _emailController),
                      const SizedBox(height: 20),
                      _buildField('Link (Optional)', _linkController),
                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveEvent,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : TextWidget(
                                  text: 'Save',
                                  fontSize: 16,
                                  color: Colors.white,
                                  isBold: true,
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
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

  Widget _buildField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
      String label, DateTime? selectedDate, Function(DateTime) onDateChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onDateChanged(picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  selectedDate != null
                      ? _formatDate(selectedDate)
                      : 'Select $label',
                  style: TextStyle(
                    color:
                        selectedDate != null ? Colors.grey : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, TimeOfDay? selectedTime,
      Function(TimeOfDay) onTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
            );
            if (picked != null) {
              onTimeChanged(picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  selectedTime != null
                      ? '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                      : 'Select $label',
                  style: TextStyle(
                    color:
                        selectedTime != null ? Colors.grey : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
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
}
