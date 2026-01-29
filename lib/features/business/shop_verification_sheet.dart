import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class ShopVerificationSheet extends StatefulWidget {
  final String shopId;
  final String shopName;
  final bool isVerificationFlow;

  const ShopVerificationSheet({
    super.key,
    required this.shopId,
    required this.shopName,
    this.isVerificationFlow = false,
  });

  @override
  State<ShopVerificationSheet> createState() => _ShopVerificationSheetState();
}

class _ShopVerificationSheetState extends State<ShopVerificationSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _docRefController = TextEditingController();
  
  // Document Uploads
  XFile? _permitImage;
  XFile? _idImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // Legal consent checkboxes
  bool _acceptAttestation = false;
  bool _acceptTerms = false;
  bool _acceptDataProcessing = false;

  @override
  void dispose() {
    _legalNameController.dispose();
    _roleController.dispose();
    _docRefController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isPermit) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
      );
      
      if (image != null) {
        setState(() {
          if (isPermit) {
            _permitImage = image;
          } else {
            _idImage = image;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;

    if (_permitImage == null || _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both required documents.')),
      );
      return;
    }

    if (!_acceptAttestation || !_acceptTerms || !_acceptDataProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept all legal agreements to proceed.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. Upload Documents
      String permitUrl = '';
      String idUrl = '';

      // Upload Permit
      final permitRef = FirebaseStorage.instance
          .ref()
          .child('verification_docs')
          .child('${widget.shopId}_permit_${DateTime.now().millisecondsSinceEpoch}');
      await permitRef.putFile(File(_permitImage!.path));
      permitUrl = await permitRef.getDownloadURL();

      // Upload ID
      final idRef = FirebaseStorage.instance
          .ref()
          .child('verification_docs')
          .child('${widget.shopId}_id_${DateTime.now().millisecondsSinceEpoch}');
      await idRef.putFile(File(_idImage!.path));
      idUrl = await idRef.getDownloadURL();

      // 2. Check for existing pending claims
      final existingClaims = await FirebaseFirestore.instance
          .collection('shop_claims')
          .where('shopId', isEqualTo: widget.shopId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingClaims.docs.isNotEmpty) {
        // If user already has a pending claim, don't allow duplicate
        for (var doc in existingClaims.docs) {
          if (doc['claimantId'] == user.uid) {
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You already have a pending verification for this shop.')),
              );
              Navigator.pop(context); // Close sheet
            }
            return;
          }
        }
      }

      // 3. Save to Firestore
      if (widget.isVerificationFlow) {
        // DIRECT SUBMISSION: Update the existing shop doc directly
        // This keeps it in the "Business Submissions" list and avoids creating a duplicate "Claim" entry.
        await FirebaseFirestore.instance.collection('shops').doc(widget.shopId).update({
          'businessLegalName': _legalNameController.text.trim(),
          'applicantRole': _roleController.text.trim(),
          'verificationDocReference': _docRefController.text.trim(),
          'permitImageUrl': permitUrl,
          'idImageUrl': idUrl,
          'approvalStatus': 'awaiting_verification', // Ensure status is set
          // Audit Trail (embedded in shop doc for direct submissions)
          'legalAttestation': _acceptAttestation,
          'legalTermsAccepted': _acceptTerms,
          'dataProcessingConsent': _acceptDataProcessing,
          'verificationSubmittedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // CLAIM FLOW: Create a separate claim request for an EXISTING shop
        await FirebaseFirestore.instance.collection('shop_claims').add({
          'shopId': widget.shopId,
          'shopName': widget.shopName,
          'claimantId': user.uid,
          'claimantEmail': user.email,
          'businessLegalName': _legalNameController.text.trim(),
          'applicantRole': _roleController.text.trim(),
          'verificationDocReference': _docRefController.text.trim(),
          'permitImageUrl': permitUrl,
          'idImageUrl': idUrl,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          // Legal Consent - Audit Trail
          'legalAttestation': _acceptAttestation,
          'legalTermsAccepted': _acceptTerms,
          'dataProcessingConsent': _acceptDataProcessing,
          'legalConsentVersion': '1.0',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isVerificationFlow 
              ? 'Verification documents submitted successfully!' 
              : 'Claim request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 1. Pop the verification sheet
        Navigator.pop(context);
        
        // 2. Pop the SubmitShopScreen or ClaimShopScreen
        Navigator.pop(context);
        
        // 3. Pop the BusinessDashboardScreen (Get Started bridge) to return to ProfileTab
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary.withOpacity(0.15), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primary.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: primary, size: 32),
                        ),
                        const SizedBox(height: 16),
                        TextWidget(
                          text: widget.isVerificationFlow ? 'Business Verification' : 'Ownership Verification',
                          fontSize: 22,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: widget.isVerificationFlow 
                              ? 'Please provide documentation to verify your business submission.'
                              : 'To claim "${widget.shopName}", we need to verify your business identity.',
                          fontSize: 14,
                          color: Colors.white70,
                          align: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Legal Information'),
                        _buildTextField(
                          controller: _legalNameController,
                          label: 'Registered Business Name',
                          hint: 'e.g., CoFi Coffee Roasters Inc.',
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        _buildTextField(
                          controller: _roleController,
                          label: 'Your Position / Title',
                          hint: 'e.g., Owner, Manager, Authorized Rep',
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        _buildTextField(
                          controller: _docRefController,
                          label: 'Business Registration / TIN',
                          hint: 'e.g., 123-456-789-000',
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        
                        const SizedBox(height: 32),
                        _buildSectionHeader('Verification Documents'),
                        TextWidget(
                          text: 'Photos must be clear and readable. Accepted formats: JPG, PNG.',
                          fontSize: 13,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(child: _buildUploadCard('Business Permit\n(BIR / DTI / Mayor\'s)', _permitImage, true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildUploadCard('Your Government\nIssued ID', _idImage, false)),
                          ],
                        ),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Legal Consent'),
                        _buildCheckbox(
                          'I attest that I am the authorized owner or representative of this business.',
                          _acceptAttestation,
                          (v) => setState(() => _acceptAttestation = v!),
                        ),
                        _buildCheckbox(
                          'I accept the Terms of Service and Merchant Agreement.',
                          _acceptTerms,
                          (v) => setState(() => _acceptTerms = v!),
                        ),
                        _buildCheckbox(
                          'I consent to the processing of my personal data for verification purposes.',
                          _acceptDataProcessing,
                          (v) => setState(() => _acceptDataProcessing = v!),
                        ),

                        const SizedBox(height: 40),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitClaim,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              disabledBackgroundColor: Colors.grey[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Submit Verification',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: TextWidget(
                              text: 'Cancel',
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(text: label, fontSize: 13, color: Colors.white70),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(String label, XFile? file, bool isPermit) {
    return GestureDetector(
      onTap: () => _pickImage(isPermit),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? primary : Colors.white10,
            width: file != null ? 2 : 1,
          ),
          image: file != null ? DecorationImage(
            image: FileImage(File(file.path)),
            fit: BoxFit.cover,
          ) : null,
        ),
        child: file == null ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: Colors.white24, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ) : Stack(
          children: [
            Container(color: Colors.black26),
            const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: primary,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
