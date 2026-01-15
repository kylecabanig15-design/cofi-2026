import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/widgets/app_text_form_field.dart';
import 'package:cofi/widgets/button_widget.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/screens/home_screen.dart';

class JobApplicationScreen extends StatefulWidget {
  final Map<String, dynamic>? job;
  final String shopId;
  const JobApplicationScreen({super.key, this.job, required this.shopId});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _coverLetterController = TextEditingController();

  String? _resumePath;
  String _resumeFileName = 'No file selected';
  bool _isLoading = false;
  bool _hasApplied = false;
  String? _userAccountType;
  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    _checkUserTypeAndApplicationStatus();
    _populateUserFields();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _checkUserTypeAndApplicationStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Check user account type
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      setState(() {
        _userAccountType = userData?['accountType'] as String? ?? 'user';
      });

      // Check if user has already applied
      final jobDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('jobs')
          .doc(widget.job!['id'])
          .get();

      final jobData = jobDoc.data();
      final applications = jobData?['applications'] as List<dynamic>? ?? [];

      final hasApplied = applications.any((app) =>
          app['applicantId'] == currentUser.uid &&
          app['status'] != 'withdrawn');

      setState(() {
        _hasApplied = hasApplied;
      });
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  Future<void> _populateUserFields() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      if (userData != null) {
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? currentUser.email ?? '';
          _phoneController.text = userData['phone'] ?? '';
        });
      }
    } catch (e) {
      print('Error populating user fields: $e');
    }
  }

  Future<void> _pickResume() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _resumePath = result.files.single.path;
          _resumeFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitApplication() async {
    if (_formKey.currentState!.validate()) {
      if (_resumePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your resume/CV'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please accept the authorization terms to submit your application'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if user is a business owner
      if (_userAccountType == 'business') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business accounts cannot apply for jobs'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if user has already applied
      if (_hasApplied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied for this position'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final job = widget.job ?? <String, dynamic>{};
        final jobId = job['id'] ?? job['documentId'] ?? '';

        if (jobId.isEmpty) {
          throw Exception('Job ID not found');
        }

        // Upload resume to Firebase Storage
        final file = File(_resumePath!);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$_resumeFileName';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('job_applications')
            .child(jobId)
            .child(fileName);

        final uploadTask = await storageRef.putFile(file);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        // Get current user
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        // Create application data
        final applicationData = {
          'applicantId': currentUser.uid,
          'applicantName': _nameController.text,
          'applicantEmail': _emailController.text,
          'applicantPhone': _phoneController.text,
          'resumeUrl': downloadUrl,
          'resumeFileName': _resumeFileName,
          'coverLetter': _coverLetterController.text,
          'appliedAt': Timestamp.now(),
          'jobId': jobId,
          'status': 'pending',
        };

        // Update the applications array field in the job document
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('jobs')
            .doc(widget.job!['id'])
            .update({
          'applications': FieldValue.arrayUnion([applicationData])
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job ?? <String, dynamic>{};

    // Check if user is a business owner
    if (_userAccountType == 'business') {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: TextWidget(
            text: 'Job Application',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.business_center,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                TextWidget(
                  text: 'Business Account Detected',
                  fontSize: 24,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Business accounts cannot apply for jobs. You can post jobs and manage applications from your business dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                ButtonWidget(
                  label: 'Go to Business Dashboard',
                  onPressed: () {
                    // Navigate to home screen with profile tab (index 3) selected
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const HomeScreen(initialTabIndex: 3),
                      ),
                      (route) => false,
                    );
                  },
                  width: double.infinity,
                  color: primary,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check if user has already applied
    if (_hasApplied) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: TextWidget(
            text: 'Job Application',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                TextWidget(
                  text: 'Application Already Submitted',
                  fontSize: 24,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You have already applied for this position. The employer will review your application and contact you if they are interested.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                ButtonWidget(
                  label: 'Go Back',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  width: double.infinity,
                  color: primary,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: TextWidget(
          text: 'Job Application',
          fontSize: 20,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Details Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: job['title'] ?? 'Job Position',
                      fontSize: 18,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: job['address'] ?? 'Location',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information Section
              Row(
                children: [
                  TextWidget(
                    text: 'Personal Information',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '*',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Fields marked with * are required',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              AppTextFormField(
                controller: _nameController,
                labelText: 'Full Name *',
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              AppTextFormField(
                controller: _emailController,
                labelText: 'Email Address *',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              AppTextFormField(
                controller: _phoneController,
                labelText: 'Phone Number *',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Resume Upload Section
              Row(
                children: [
                  TextWidget(
                    text: 'Resume/CV',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '*',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _resumePath != null ? primary : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: _resumePath != null ? primary : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextWidget(
                            text: _resumeFileName,
                            fontSize: 14,
                            color: _resumePath != null
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ButtonWidget(
                      label: 'Upload Resume/CV',
                      onPressed: _pickResume,
                      width: double.infinity,
                      height: 40,
                      fontSize: 14,
                      color: primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Cover Letter Section
              TextWidget(
                text: 'Cover Letter (Optional)',
                fontSize: 18,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextFormField(
                  controller: _coverLetterController,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText:
                        'Tell us why you\'re interested in this position...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Authorization Checkbox
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (bool? value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                            });
                          },
                          fillColor: WidgetStateProperty.all(primary),
                          checkColor: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _acceptTerms = !_acceptTerms;
                              });
                            },
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text:
                                        'I accept to submit my application and authorize ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'CoFi',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        ' to process my personal data for recruitment purposes. I understand that my information will be handled according to the privacy policy and data protection regulations.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_acceptTerms)
                      const Text(
                        'You must accept the authorization to submit your application',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              ButtonWidget(
                label: 'Submit Application',
                onPressed: _submitApplication,
                width: double.infinity,
                isLoading: _isLoading,
                color: primary,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
