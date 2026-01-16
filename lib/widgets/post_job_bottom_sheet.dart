import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/text_widget.dart';

class PostJobBottomSheet extends StatefulWidget {
  const PostJobBottomSheet({
    super.key,
    required this.shopId,
    this.jobId,
    this.jobData,
    this.isEditing = false,
  });

  final String shopId;
  final String? jobId;
  final Map<String, dynamic>? jobData;
  final bool isEditing;

  static void show(BuildContext context, {required String shopId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PostJobBottomSheet(shopId: shopId),
    );
  }

  @override
  State<PostJobBottomSheet> createState() => _PostJobBottomSheetState();
}

class _PostJobBottomSheetState extends State<PostJobBottomSheet> {
  final _jobNameController = TextEditingController();
  final _rateController = TextEditingController();
  final _requiredController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _linkController = TextEditingController();
  bool _saving = false;
  DateTime? _startDate;
  DateTime? _endDate;

  // Job type options
  final List<String> _jobTypes = [
    'Barista',
    'Cashier',
    'Server',
    'Cook',
    'Baker',
    'Manager',
    'Dishwasher',
    'Host/Hostess',
    'Other'
  ];
  String _selectedJobType = 'Barista';

  // Payment type options
  final List<String> _paymentTypes = [
    'Per Hour',
    'Per Day',
    'Per Month',
    'Fixed Amount'
  ];
  String _selectedPaymentType = 'Per Hour';

  @override
  void initState() {
    super.initState();
    // Populate fields if editing
    if (widget.isEditing && widget.jobData != null) {
      _jobNameController.text = widget.jobData!['title'] ?? '';
      _rateController.text = widget.jobData!['rate'] ?? '';
      // Prefer the canonical "qualifications" field, but fall back to the old key
      _requiredController.text = widget.jobData!['qualifications'] ??
          widget.jobData!['requiredSkills'] ??
          '';
      _descriptionController.text = widget.jobData!['description'] ?? '';
      _emailController.text = widget.jobData!['email'] ?? '';
      _linkController.text = widget.jobData!['link'] ?? '';
      _selectedJobType = widget.jobData!['type'] ?? 'Barista';
      _selectedPaymentType = widget.jobData!['paymentType'] ?? 'Per Hour';

      // Parse start date if it exists
      if (widget.jobData!['startDate'] != null) {
        final startDate = widget.jobData!['startDate'];
        if (startDate is Timestamp) {
          _startDate = startDate.toDate();
        } else if (startDate is String && startDate.isNotEmpty) {
          try {
            _startDate = DateTime.parse(startDate);
          } catch (_) {}
        }
      }

      // Parse end date if it exists
      if (widget.jobData!['endDate'] != null) {
        final endDate = widget.jobData!['endDate'];
        if (endDate is Timestamp) {
          _endDate = endDate.toDate();
        } else if (endDate is String && endDate.isNotEmpty) {
          try {
            _endDate = DateTime.parse(endDate);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _saveJob() async {
    final title = _jobNameController.text.trim();
    final type = _selectedJobType;
    final rate = _rateController.text.trim();
    final requiredSkills = _requiredController.text.trim();
    final description = _descriptionController.text.trim();
    final email = _emailController.text.trim();
    final link = _linkController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the Job name.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      // Fetch shop name and city
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get();

      final shopName = shopDoc.data()?['name'] ??
          shopDoc.data()?['shopName'] ??
          shopDoc.data()?['cafe'] ??
          'Coffee Shop';
      final city = shopDoc.data()?['city'] ?? 'Davao City';
      final shopAddress = shopDoc.data()?['address'] ??
          shopDoc.data()?['location'] ??
          'Address not provided';

      final data = {
        'title': title,
        'type': type,
        'rate': rate,
        'paymentType': _selectedPaymentType,
        'qualifications': requiredSkills,
        'description': description,
        'email': email,
        'link': link,
        'address': shopAddress,
        'startDate': _startDate,
        'endDate': _endDate,
        'status': widget.isEditing ? null : 'pending',
        'shopId': widget.shopId,
        'shopName': shopName,
        'city': city,
        'createdBy': currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'applications': []
      };

      if (widget.isEditing) {
        // Update existing job
        final jobId = (widget.jobId ?? widget.jobData?['id'])?.toString();
        if (jobId == null || jobId.isEmpty) {
          // If we somehow don't have a jobId, fail fast with a clear message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Unable to update job: missing job ID.')),
            );
          }
          return;
        }

        final updateData = Map<String, dynamic>.from(data);
        // Don't override status or existing applications on edit
        updateData.remove('status');
        updateData.remove('applications');

        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('jobs')
            .doc(jobId)
            .update(updateData);

        // Also update in allJobs collection (merge: true preserves status and other fields)
        await FirebaseFirestore.instance
            .collection('allJobs')
            .doc(jobId)
            .set(updateData, SetOptions(merge: true));

        if (mounted) {
          Navigator.pop(context); // Close modal
          Navigator.pop(context); // Close job details screen to refresh
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job updated successfully.')),
          );
        }
      } else {
        // Create new job
        data['createdAt'] = FieldValue.serverTimestamp();

        final jobRef = await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('jobs')
            .add(data);

        // Also save to allJobs collection immediately
        await FirebaseFirestore.instance
            .collection('allJobs')
            .doc(jobRef.id)
            .set({
          ...data,
          'jobId': jobRef.id,
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job posted.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save job: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _jobNameController.dispose();
    _rateController.dispose();
    _requiredController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
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
                      text: widget.isEditing ? 'Edit Job' : 'Post a job',
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
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    // Add padding for keyboard to prevent covering content
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Job name
                        _buildField('Job name', _jobNameController),

                        const SizedBox(height: 20),

                        // Job Type
                        _buildJobTypeDropdown(),

                        const SizedBox(height: 20),

                        // Payment Type
                        _buildPaymentTypeDropdown(),

                        const SizedBox(height: 20),

                        // Rate
                        _buildRateField(),

                        const SizedBox(height: 20),

                        // Start Date
                        _buildStartDatePicker(),

                        const SizedBox(height: 20),

                        // End Date
                        _buildEndDatePicker(),

                        const SizedBox(height: 20),

                        // Qualifications
                        _buildField('Qualifications', _requiredController),

                        const SizedBox(height: 20),

                        // Description
                        _buildField('Description', _descriptionController,
                            isDescription: true),

                        const SizedBox(height: 20),

                        // Email
                        _buildField('Email', _emailController),

                        const SizedBox(height: 20),

                        // Link (Optional)
                        _buildField('Link (Optional)', _linkController),

                        const SizedBox(height: 40),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveJob,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary, // Red color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
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
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool isDescription = false}) {
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
            maxLines: isDescription ? 4 : 1,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(isDescription ? 16 : 12),
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Rate',
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
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLines: 1,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              hintText: 'Enter amount (e.g., 500)',
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              prefixText: '₱ ',
              prefixStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Start Date',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: _startDate != null
                      ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                      : 'Select date',
                  fontSize: 14,
                  color: _startDate != null ? Colors.white : Colors.grey,
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'End Date',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _endDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                _endDate = picked;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: _endDate != null
                      ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                      : 'Select date',
                  fontSize: 14,
                  color: _endDate != null ? Colors.white : Colors.grey,
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Job Type',
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedJobType,
              isExpanded: true,
              dropdownColor: Colors.grey[800],
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.grey,
              ),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              items: _jobTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedJobType = newValue!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Payment Type',
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPaymentType,
              isExpanded: true,
              dropdownColor: Colors.grey[800],
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.grey,
              ),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              items: _paymentTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPaymentType = newValue!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
