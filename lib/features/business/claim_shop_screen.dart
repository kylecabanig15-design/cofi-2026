import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class ClaimShopScreen extends StatefulWidget {
  const ClaimShopScreen({super.key});

  @override
  State<ClaimShopScreen> createState() => _ClaimShopScreenState();
}

class _ClaimShopScreenState extends State<ClaimShopScreen> {
  final TextEditingController _searchController = TextEditingController();
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

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isDirectClaim = false;
  String? _preselectedShopId;
  String? _preselectedShopName;
  bool _isDirectClaimValidating = false;
  String? _directClaimError;
  
  // Legal consent checkboxes
  bool _acceptAttestation = false;
  bool _acceptTerms = false;
  bool _acceptDataProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['preselectShopId'] != null) {
        setState(() {
          _isDirectClaim = true;
          _preselectedShopId = args['preselectShopId'];
          _preselectedShopName = args['preselectShopName'];
          _searchController.text = _preselectedShopName ?? '';
        });
        _validateDirectClaim(args['preselectShopId']);
      }
    });
    _searchShops('');
  }

  Future<void> _validateDirectClaim(String shopId) async {
    setState(() {
      _isDirectClaimValidating = true;
      _directClaimError = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      if (!doc.exists) {
        setState(() => _directClaimError = 'Shop not found.');
        return;
      }

      final data = doc.data()!;
      final isVerified = data['isVerified'] == true;
      final ownerId = data['ownerId'];
      final submissionType = data['submissionType']?.toString().toLowerCase();
      final approvalStatus = data['approvalStatus']?.toString().toLowerCase();

      if (ownerId != null && ownerId.toString().trim().isNotEmpty) {
        setState(() => _directClaimError = 'This shop is already claimed.');
      } else if (submissionType != 'community') {
        setState(() => _directClaimError = 'This shop cannot be claimed (business submission).');
      } else if (approvalStatus == null || approvalStatus.isEmpty) {
        setState(() => _directClaimError = 'This shop is not eligible for claiming (legacy shop).');
      }
    } catch (e) {
      setState(() => _directClaimError = 'Failed to validate shop: $e');
    } finally {
      setState(() => _isDirectClaimValidating = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _legalNameController.dispose();
    _roleController.dispose();
    _docRefController.dispose();
    super.dispose();
  }

  Future<void> _searchShops(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .get();

      final results = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((data) {
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            final address = (data['address'] as String?)?.toLowerCase() ?? '';
            final searchLower = query.toLowerCase().trim();
            
            final ownerId = data['ownerId'];
            final submissionType = data['submissionType']?.toString().toLowerCase();
            final isVerified = data['isVerified'] == true;
            final approvalStatus = data['approvalStatus']?.toString().toLowerCase();
            
            // Allow claiming of community-added shops that:
            // 1. Have NO ownerId (unclaimed)
            // 2. Are EXPLICITLY 'community' type (not business)
            // 3. Have approvalStatus set (from new RBAC system, not legacy)
            final isClaimable = (ownerId == null || ownerId.toString().trim().isEmpty) && 
                               (submissionType == 'community') &&
                               (approvalStatus != null && approvalStatus.isNotEmpty);

            if (!isClaimable) return false;

            // If query is empty, allow all (will be sorted/limited below)
            if (searchLower.isEmpty) return true;

            return (name.contains(searchLower) || address.contains(searchLower));
          })
          .toList();

      // Sort: Most recent first, then by name
      results.sort((a, b) {
        final aTime = a['postedAt'] as Timestamp?;
        final bTime = b['postedAt'] as Timestamp?;
        
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        
        // If timestamps are missing, prioritize 'community' type as a secondary sort
        final aComm = (a['submissionType']?.toString().toLowerCase() == 'community');
        final bComm = (b['submissionType']?.toString().toLowerCase() == 'community');
        if (aComm && !bComm) return -1;
        if (!aComm && bComm) return 1;
        
        return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
      });

      setState(() {
        // Show up to 50 results
        _searchResults = results.take(50).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _showVerificationForm(String shopId, String shopName) async {
    setState(() {
      _acceptAttestation = false;
      _acceptTerms = false;
      _acceptDataProcessing = false;
      _permitImage = null;
      _idImage = null;
      _isSubmitting = false;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                
                // Header section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.15),
                        primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.verified_user, color: primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWidget(
                                  text: 'Ownership Verification',
                                  fontSize: 20,
                                  color: Colors.white,
                                  isBold: true,
                                ),
                                const SizedBox(height: 4),
                                TextWidget(
                                  text: shopName,
                                  fontSize: 14,
                                  color: primary,
                                  isBold: true,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Form section
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _legalNameController,
                        label: 'Business Legal Name',
                        hint: 'As shown on official documents',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: _roleController,
                        label: 'Your Role',
                        hint: 'e.g. Owner, Manager, Authorized Agent',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: _docRefController,
                        label: 'Verification Reference',
                        hint: 'e.g. Business Permit # or Tax ID',
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 18),
                      TextWidget(
                        text: 'Required Documents',
                        fontSize: 13,
                        color: Colors.white70,
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildImagePickerTile(
                        label: 'Business Permit / BIR COR',
                        image: _permitImage,
                        icon: Icons.assignment_outlined,
                        onTap: () => _pickImage(true, setModalState),
                      ),
                      const SizedBox(height: 12),
                      _buildImagePickerTile(
                        label: "Authorized Representative's ID",
                        image: _idImage,
                        icon: Icons.badge_outlined,
                        onTap: () => _pickImage(false, setModalState),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // FRAUD WARNING - Critical Legal Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: 'FRAUD WARNING',
                              fontSize: 13,
                              color: Colors.red[300]!,
                              isBold: true,
                            ),
                            const SizedBox(height: 4),
                            TextWidget(
                              text: 'Submitting false information or claiming a business you do not own is fraud and may result in legal action, account termination, and criminal prosecution.',
                              fontSize: 11,
                              color: Colors.white70,
                              maxLines: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // LEGAL CONSENT CHECKBOXES
                _buildConsentCheckbox(
                  value: _acceptAttestation,
                  onChanged: (val) => setModalState(() {
                    _acceptAttestation = val ?? false;
                  }),
                  label: 'I declare under penalty of law that I am the authorized representative of this business and all information provided is true and accurate.',
                  isRequired: true,
                ),
                
                const SizedBox(height: 12),
                
                _buildConsentCheckbox(
                  value: _acceptTerms,
                  onChanged: (val) => setModalState(() {
                    _acceptTerms = val ?? false;
                  }),
                  label: 'I accept the Terms & Conditions and understand that my claim will be reviewed.',
                  isRequired: true,
                ),
                
                const SizedBox(height: 12),
                
                _buildConsentCheckbox(
                  value: _acceptDataProcessing,
                  onChanged: (val) => setModalState(() {
                    _acceptDataProcessing = val ?? false;
                  }),
                  label: 'I consent to the processing of my data for verification purposes and agree that additional documents may be requested.',
                  isRequired: true,
                ),
                
                const SizedBox(height: 20),
                
                // Info box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[300], size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextWidget(
                          text: 'You may be asked to upload physical documents during the review process.',
                          fontSize: 12,
                          color: Colors.white60,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submitClaim(shopId, shopName, setModalState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: primary.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: primary.withOpacity(0.3),
                    ),
                    child: _isSubmitting 
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Submit Verification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Future<void> _pickImage(bool isPermit, Function(void Function()) setModalState) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Critical Compression to save cost
        maxWidth: 1200,
      );
      if (image != null) {
        setModalState(() {
          if (isPermit) {
            _permitImage = image;
          } else {
            _idImage = image;
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Widget _buildImagePickerTile({
    required String label,
    required XFile? image,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: image != null ? primary.withOpacity(0.5) : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: image != null ? primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                image != null ? Icons.check_circle : icon,
                color: image != null ? primary : Colors.white54,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: label,
                    fontSize: 14,
                    color: Colors.white,
                    isBold: true,
                  ),
                  TextWidget(
                    text: image != null ? 'Image Selected' : 'Tap to upload photo',
                    fontSize: 12,
                    color: image != null ? primary : Colors.white38,
                  ),
                ],
              ),
            ),
            if (image != null) 
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.path),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.add_a_photo_outlined, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: TextWidget(
            text: label,
            fontSize: 13,
            color: Colors.white70,
            isBold: true,
          ),
        ),
        TextFormField(
          controller: controller,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: primary.withOpacity(0.7), size: 20),
            ),
            filled: true,
            fillColor: const Color(0xFF242424),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: primary.withOpacity(0.5),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
          ),
          validator: (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
        ),
      ],
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required bool isRequired,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: primary,
            checkColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: TextWidget(
              text: label,
              fontSize: 12,
              color: Colors.white70,
              maxLines: 4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitClaim(String shopId, String shopName, Function(void Function()) setModalState) async {
    if (!_formKey.currentState!.validate()) return;
    
    // Legal validation
    if (!_acceptAttestation || !_acceptTerms || !_acceptDataProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept all legal requirements to proceed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Document validation
    if (_permitImage == null || _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both required documents.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setModalState(() => _isSubmitting = true);

    try {
      // Check for existing pending claim
      final existing = await FirebaseFirestore.instance
          .collection('shop_claims')
          .where('shopId', isEqualTo: shopId)
          .where('claimantId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        setModalState(() => _isSubmitting = false);
        if (mounted) {
          Navigator.pop(context); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Claim request already pending review.')),
          );
        }
        return;
      }

      // 1. Upload Permit Image
      final permitRef = FirebaseStorage.instance
          .ref()
          .child('shop_claims/${user.uid}/$shopId/permit_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final permitUpload = await permitRef.putFile(File(_permitImage!.path));
      final permitUrl = await permitUpload.ref.getDownloadURL();

      // 2. Upload ID Image
      final idRef = FirebaseStorage.instance
          .ref()
          .child('shop_claims/${user.uid}/$shopId/id_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final idUpload = await idRef.putFile(File(_idImage!.path));
      final idUrl = await idUpload.ref.getDownloadURL();

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('shop_claims').add({
        'shopId': shopId,
        'shopName': shopName,
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

      if (mounted) {
        Navigator.pop(context); // Close sheet
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: primary.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle_outline, color: primary),
                const SizedBox(width: 12),
                const Text('Claim Submitted', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              'Your verification documents have been received. Our team will review your claim and contact you within 3-5 business days.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Exit claim screen
                },
                child: Text('GREAT', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setModalState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit claim: $e')),
        );
      }
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
        centerTitle: true,
        title: TextWidget(
          text: 'Claim Shop',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isDirectClaim)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search for your shop...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: _searchShops,
                  ),
                ),
              ),
            
            // Info banner explaining what shops are shown
            if (!_isDirectClaim)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextWidget(
                          text: 'Showing unverified community-added shops. These shops are pending admin approval.',
                          fontSize: 12,
                          color: Colors.white70,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (_searchResults.isNotEmpty && !_isDirectClaim && !_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    TextWidget(
                      text: 'Found ${_searchResults.length} unclaimed shops',
                      fontSize: 13,
                      color: primary,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: _isSearching || _isDirectClaimValidating
                  ? const Center(child: CircularProgressIndicator())
                  : _directClaimError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                TextWidget(
                                  text: _directClaimError!,
                                  fontSize: 16,
                                  color: Colors.white70,
                                  align: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : (_isDirectClaim || _searchResults.isNotEmpty)
                          ? ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _isDirectClaim ? 1 : _searchResults.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final shop = _isDirectClaim 
                                    ? {'id': _preselectedShopId, 'name': _preselectedShopName, 'address': 'Currently viewing', 'submissionType': 'community'} 
                                    : _searchResults[index];
                                final name = shop['name'] as String? ?? 'Unknown';
                                final address = shop['address'] as String? ?? '';
                                final shopId = shop['id'] as String;

                                return _buildShopResultCard(shop, shopId, name, address);
                              },
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: TextWidget(
                                  text: _searchController.text.trim().isEmpty
                                      ? 'Recent unclaimed shops'
                                      : 'No matches found',
                                  fontSize: 16,
                                  color: Colors.white70,
                                  align: TextAlign.center,
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopResultCard(Map<String, dynamic> shop, String shopId, String name, String address) {
    return GestureDetector(
      onTap: () => _showVerificationForm(shopId, name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: _isDirectClaim ? Border.all(color: primary.withOpacity(0.5)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_cafe, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: name,
                    fontSize: 16,
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextWidget(
                          text: address,
                          fontSize: 14,
                          color: Colors.white70,
                          maxLines: 1,
                        ),
                      ),
                      if (shop['submissionType'] == 'community') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COMMUNITY',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Verification status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending, color: Colors.orange, size: 10),
                        const SizedBox(width: 4),
                        const Text(
                          'PENDING VERIFICATION',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.verified_user, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}
