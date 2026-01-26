import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/button_widget.dart';
import 'package:cofi/widgets/post_job_bottom_sheet.dart';
import 'package:cofi/utils/colors.dart';
import 'job_application_screen.dart';
import 'job_archives_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? job;
  final String shopId;
  const JobDetailsScreen({super.key, this.job, required this.shopId});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _isJobCreator = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if user is the creator of this job
      final jobCreatedBy = widget.job?['createdBy'] as String?;
      final isCreator = jobCreatedBy == currentUser.uid;

      setState(() {
        _isJobCreator = isCreator;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking user type: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getShopName() async {
    try {
      final shopId = widget.job?['shopId'];
      if (shopId == null || shopId.toString().isEmpty) {
        return widget.job?['shopName'] ?? 'Unknown Shop';
      }

      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId.toString())
          .get();

      if (shopDoc.exists) {
        final data = shopDoc.data();
        return data?['name'] ??
            data?['shopName'] ??
            data?['cafe'] ??
            widget.job?['shopName'] ??
            'Unknown Shop';
      }
      return widget.job?['shopName'] ?? 'Unknown Shop';
    } catch (e) {
      print('Error fetching shop name: $e');
      return widget.job?['shopName'] ?? 'Unknown Shop';
    }
  }

  Future<String> _getShopAddress() async {
    try {
      final shopId = widget.job?['shopId'];
      if (shopId == null || shopId.toString().isEmpty) {
        return widget.job?['address'] ?? 'Address not specified';
      }

      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId.toString())
          .get();

      if (shopDoc.exists) {
        final data = shopDoc.data();
        return data?['address'] ??
            data?['location'] ??
            widget.job?['address'] ??
            'Address not specified';
      }
      return widget.job?['address'] ?? 'Address not specified';
    } catch (e) {
      print('Error fetching shop address: $e');
      return widget.job?['address'] ?? 'Address not specified';
    }
  }

  Future<void> _closeJobApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Close Job Application',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to close this job application? This will prevent new users from applying.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final jobId = widget.job?['id'] ?? widget.job?['jobId'];
        final shopId = widget.shopId;

        if (jobId == null || jobId.toString().isEmpty) {
          throw Exception('Job ID not found');
        }

        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('jobs')
            .doc(jobId.toString())
            .update({
          'status': 'closed',
          'closedAt': Timestamp.now(),
        });

        // Also update in allJobs (merge to avoid missing-doc errors)
        await FirebaseFirestore.instance
            .collection('allJobs')
            .doc(jobId.toString())
            .set({
          'status': 'closed',
          'closedAt': Timestamp.now(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job application closed successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Wait a moment for the stream to update, then pop
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error closing job: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        print('Error closing job: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final j = widget.job ?? <String, dynamic>{};
    final isJobClosed = j['status'] == 'closed';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: _isJobCreator
            ? [
                if (!isJobClosed)
                  IconButton(
                    icon: const Icon(Icons.archive, color: Colors.orange),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A1A),
                          title: const Text(
                            'Archive Job',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'Are you sure you want to archive this job? It will be moved to Job Archives, removed from active listings, and you will not be able to reopen or bring it back.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Archive',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        _archiveJob(context, widget.job!['id'], widget.shopId);
                      }
                    },
                    tooltip: 'Archive Job',
                  ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextWidget(
                            text: (j['title'] ?? 'Job').toString(),
                            fontSize: 24,
                            color: Colors.white,
                            isBold: true,
                          ),
                        ),
                        if (isJobClosed)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.8),
                              ),
                            ),
                            child: const Text(
                              'CLOSED',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Shop name - fetched from shop collection
                    FutureBuilder<String>(
                      future: _getShopName(),
                      builder: (context, snapshot) {
                        return TextWidget(
                          text: snapshot.data ?? 'Unknown Shop',
                          fontSize: 14,
                          color: Colors.grey[400],
                          isBold: true,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Address - fetched from shop collection
                    FutureBuilder<String>(
                      future: _getShopAddress(),
                      builder: (context, snapshot) {
                        return TextWidget(
                          text: snapshot.data ?? 'Address not specified',
                          fontSize: 13,
                          color: Colors.white54,
                          maxLines: 5,
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Type Section
                    TextWidget(
                      text: 'Type',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: (j['type'] ?? 'Unknown').toString(),
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),

                    // Rate Section
                    TextWidget(
                      text: 'Rate',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text:
                          '₱ ${(j['rate'] ?? 'TBD').toString()} ${_formatPaymentType(j['paymentType'] as String?)}',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),

                    // Qualifications Section
                    TextWidget(
                      text: 'Qualifications',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: (j['qualifications'] ??
                              j['required'] ??
                              'Not specified')
                          .toString(),
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),

                    // Start Date Section
                    TextWidget(
                      text: 'Start Date',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: _formatDate(j['startDate']),
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),

                    // End Date Section
                    TextWidget(
                      text: 'End Date',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: _formatDate(j['endDate']),
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),

                    // Description Section
                    TextWidget(
                      text: 'Description',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: (j['description'] ?? 'No description provided')
                          .toString(),
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),

                    // Location Map Section
                    TextWidget(
                      text: 'Location',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<LatLng>(
                      future: _getShopCoordinates(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('Unable to load map'),
                            ),
                          );
                        }

                        final coords = snapshot.data!;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 200,
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: coords,
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('shop_location'),
                                  position: coords,
                                  infoWindow: const InfoWindow(
                                    title: 'Shop Location',
                                  ),
                                ),
                              },
                              zoomControlsEnabled: true,
                              myLocationButtonEnabled: false,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Fixed Bottom Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBottomButton(j, isJobClosed),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(Map<String, dynamic> job, bool isJobClosed) {
    if (_isJobCreator) {
      // Job creator view with Edit and Close/Open buttons
      final jobStatus = (job['status'] as String?) ?? 'active';
      final jobStatusLower = jobStatus.toLowerCase();
      final isPending = jobStatusLower == 'pending';
      final isClosedStatus = jobStatusLower == 'closed';

      return Row(
        children: [
          // Edit Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isPending
                  ? null
                  : () {
                      // Open edit job bottom sheet
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) => PostJobBottomSheet(
                          shopId: job['shopId'] ?? '',
                          jobId: job['id'],
                          jobData: job,
                          isEditing: true,
                        ),
                      );
                    },
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending ? Colors.grey : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Close / Open Applications Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isPending
                  ? null
                  : () {
                      if (isClosedStatus) {
                        _openJobApplication();
                      } else {
                        _closeJobApplication();
                      }
                    },
              icon: Icon(isClosedStatus ? Icons.lock_open : Icons.lock_outline),
              label: Text(isClosedStatus ? 'Open' : 'Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending
                    ? Colors.grey
                    : (isClosedStatus ? Colors.green : Colors.red),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Archive Button
        ],
      );
    } else {
      if (isJobClosed) {
        return ButtonWidget(
          label: 'Application Closed',
          onPressed: () {}, // Empty function to disable button
          width: double.infinity,
          color: Colors.grey,
        );
      } else {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _applyNow(context),
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
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.touch_app, color: Colors.red, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                TextWidget(
                  text: 'Apply now!',
                  fontSize: 16,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _archiveJob(
      BuildContext context, String jobId, String shopId) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('jobs')
          .doc(jobId)
          .update({
        'isArchived': true,
      });

      // Also archive in allJobs
      await FirebaseFirestore.instance.collection('allJobs').doc(jobId).update({
        'isArchived': true,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job archived - moved to Job Archives'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate directly to Job Archives for this shop
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => JobArchivesScreen(shopId: shopId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<LatLng> _getShopCoordinates() async {
    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get();

      final data = shopDoc.data();
      final latitude = (data?['latitude'] as num?)?.toDouble() ?? 7.0896;
      final longitude = (data?['longitude'] as num?)?.toDouble() ?? 125.6180;

      return LatLng(latitude, longitude);
    } catch (e) {
      print('Error getting shop coordinates: $e');
      // Default to Davao City coordinates
      return LatLng(7.0896, 125.6180);
    }
  }

  String _formatDate(dynamic v) {
    if (v is Timestamp) {
      final dt = v.toDate();
      return _fmt(dt);
    }
    if (v is String && v.isNotEmpty) {
      final dt = DateTime.tryParse(v);
      if (dt != null) return _fmt(dt);
    }
    return 'Unknown';
  }

  String _fmt(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final yr = dt.year.toString();
    return '$yr-$mon-$day';
  }

  Future<void> _openJobApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Reopen Job Application',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to reopen this job application? New users will be able to apply again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reopen',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final jobId = widget.job?['id'] ?? widget.job?['jobId'];
        final shopId = widget.shopId;

        if (jobId == null || jobId.toString().isEmpty) {
          throw Exception('Job ID not found');
        }

        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('jobs')
            .doc(jobId.toString())
            .update({
          'status': 'active',
          'closedAt': FieldValue.delete(),
        });

        // Also update in allJobs (merge to avoid missing-doc errors)
        await FirebaseFirestore.instance
            .collection('allJobs')
            .doc(jobId.toString())
            .set({
          'status': 'active',
          'closedAt': FieldValue.delete(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job application reopened successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Wait a moment for the stream to update, then pop
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error reopening job: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        print('Error reopening job: $e');
      }
    }
  }

  Future<void> _applyNow(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JobApplicationScreen(job: widget.job, shopId: widget.shopId),
      ),
    );
  }

  String _formatPaymentType(String? paymentType) {
    if (paymentType == null || paymentType.isEmpty) {
      return '';
    }
    return '/ ${paymentType.toLowerCase()}';
  }
}
