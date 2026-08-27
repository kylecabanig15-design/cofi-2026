import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:cofi/utils/formatters.dart';
import 'package:cofi/widgets/custom_toast.dart';

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
      builder: (context) => BusinessWorkspaceTheme(
        accentColor: Colors.redAccent,
        child: PostJobBottomSheet(shopId: shopId),
      ),
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
      _rateController.text = formatNumberWithCommas(widget.jobData!['rate']);
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
    final rate = _rateController.text.replaceAll(',', '').trim();
    final requiredSkills = _requiredController.text.trim();
    final description = _descriptionController.text.trim();
    final email = _emailController.text.trim();
    final link = _linkController.text.trim();

    if (title.isEmpty) {
      CustomToast.showWarning(
        context,
        'Add a clear job title before saving.',
        title: 'Job title required',
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
        'status': widget.isEditing ? null : 'active',
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
            CustomToast.showError(
              context,
              'Close this form and open the job again before retrying.',
              title: 'Job could not be identified',
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

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, updateData);
          CustomToast.showFromMessenger(
            messenger,
            'Applicants will now see the latest job details.',
            type: ToastType.success,
            title: 'Job updated',
          );
        }
      } else {
        // Create new job
        data['createdAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('jobs')
            .add(data);

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          CustomToast.showFromMessenger(
            messenger,
            'The opening is now visible in Work in Coffee.',
            type: ToastType.success,
            title: 'Job published',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomToast.showError(
          context,
          'We could not save the job. Check your connection and try again.',
          title: 'Job not saved',
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
        decoration: const BoxDecoration(
          color: BusinessWorkspaceColors.canvas,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              BusinessSheetHeader(
                title: widget.isEditing ? 'Refine this role' : 'Open a role',
                subtitle: 'Set clear expectations for your future teammate',
                icon: Icons.person_search_outlined,
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
                        const BusinessSectionLabel(
                          step: '01',
                          title: 'Role basics',
                          description:
                              'Name the role and make compensation easy to understand.',
                        ),
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

                        const SizedBox(height: 28),

                        const BusinessSectionLabel(
                          step: '02',
                          title: 'Who will succeed here',
                          description:
                              'Describe the work and the qualifications that matter.',
                        ),

                        // Qualifications
                        _buildField('Qualifications', _requiredController,
                            isMultiline: true),

                        const SizedBox(height: 20),

                        // Description
                        _buildField('Description', _descriptionController,
                            isMultiline: true),

                        const SizedBox(height: 28),

                        const BusinessSectionLabel(
                          step: '03',
                          title: 'Application route',
                          description:
                              'Tell candidates where they can follow up.',
                        ),

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
                          child: FilledButton(
                            onPressed: _saving ? null : _saveJob,
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
      {bool isMultiline = false}) {
    return TextField(
      controller: controller,
      minLines: isMultiline ? 4 : 1,
      maxLines: isMultiline ? null : 1,
      keyboardType: isMultiline ? TextInputType.multiline : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildRateField() {
    return TextField(
      controller: _rateController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [ThousandsSeparatorInputFormatter()],
      maxLines: 1,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: const InputDecoration(
        labelText: 'Rate',
        hintText: '500',
        prefixText: '₱ ',
      ),
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
              color: BusinessWorkspaceColors.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: BusinessWorkspaceColors.line),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: _startDate != null
                      ? DateFormat('MMM dd, yyyy').format(_startDate!)
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
              color: BusinessWorkspaceColors.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: BusinessWorkspaceColors.line),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: _endDate != null
                      ? DateFormat('MMM dd, yyyy').format(_endDate!)
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
    return DropdownButtonFormField<String>(
      initialValue: _selectedJobType,
      dropdownColor: BusinessWorkspaceColors.surfaceRaised,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: const InputDecoration(labelText: 'Job type'),
      items: _jobTypes
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) setState(() => _selectedJobType = newValue);
      },
    );
  }

  Widget _buildPaymentTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPaymentType,
      dropdownColor: BusinessWorkspaceColors.surfaceRaised,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: const InputDecoration(labelText: 'Payment type'),
      items: _paymentTypes
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) setState(() => _selectedPaymentType = newValue);
      },
    );
  }
}
