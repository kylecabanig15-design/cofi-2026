import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'dart:io';

class PostPromotionBottomSheet extends StatefulWidget {
  const PostPromotionBottomSheet({
    super.key,
    required this.shopId,
    required this.shopName,
    this.promotionId,
    this.initialData,
  });

  final String shopId;
  final String shopName;
  final String? promotionId;
  final Map<String, dynamic>? initialData;

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required String shopName,
    String? promotionId,
    Map<String, dynamic>? initialData,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PostPromotionBottomSheet(
        shopId: shopId,
        shopName: shopName,
        promotionId: promotionId,
        initialData: initialData,
      ),
    );
  }

  @override
  State<PostPromotionBottomSheet> createState() =>
      _PostPromotionBottomSheetState();
}

class _PostPromotionBottomSheetState extends State<PostPromotionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _offer;
  late final TextEditingController _description;
  late final TextEditingController _terms;
  DateTime? _startDate;
  DateTime? _endDate;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  late String _existingImageUrl;
  bool _saving = false;
  String? _errorMessage;

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? const <String, dynamic>{};
    _title = TextEditingController(text: data['title']?.toString() ?? '');
    _offer = TextEditingController(text: data['offer']?.toString() ?? '');
    _description =
        TextEditingController(text: data['description']?.toString() ?? '');
    _terms = TextEditingController(text: data['terms']?.toString() ?? '');
    _startDate = _readDate(data['startDate']);
    _endDate = _readDate(data['endDate']);
    // Older offers stored a cafe gallery image here. Only images explicitly
    // chosen for a promotion are eligible to be reused.
    _existingImageUrl = data['imageSource'] == 'promotion'
        ? data['imageUrl']?.toString() ?? ''
        : '';
  }

  @override
  void dispose() {
    _title.dispose();
    _offer.dispose();
    _description.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = null;
        }
      } else {
        _endDate =
            DateTime(selected.year, selected.month, selected.day, 23, 59, 59);
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1800,
    );
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String> _uploadImage() async {
    if (_selectedImage == null) return _existingImageUrl;
    final fileName =
        'promotion_${widget.shopId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref =
        FirebaseStorage.instance.ref().child('shop_images').child(fileName);
    final snapshot = await ref.putFile(
      _selectedImage!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _save(String status) async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Complete all required offer details.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Choose both a start and end date.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      setState(
          () => _errorMessage = 'The end date must be after the start date.');
      return;
    }
    if (_selectedImage == null && _existingImageUrl.isEmpty) {
      setState(() => _errorMessage =
          'Add a dedicated offer image before saving or publishing.');
      return;
    }

    setState(() => _saving = true);
    try {
      final shopSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get();
      final shop = shopSnapshot.data() ?? const <String, dynamic>{};
      final imageUrl = await _uploadImage();
      final ref = FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('promotions');
      final data = <String, dynamic>{
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'title': _title.text.trim(),
        'offer': _offer.text.trim(),
        'description': _description.text.trim(),
        'terms': _terms.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'status': status,
        'imageUrl': imageUrl,
        'imageSource': 'promotion',
        'logoUrl': (shop['logoUrl'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.promotionId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await ref.add(data);
      } else {
        await ref.doc(widget.promotionId).update(data);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      CustomToast.showFromMessenger(
        messenger,
        status == 'published'
            ? 'Customers can now discover it in Community.'
            : 'You can return and publish it whenever you are ready.',
        type: ToastType.success,
        title: status == 'published' ? 'Offer published' : 'Draft saved',
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.code == 'permission-denied'
          ? 'Publishing is not enabled on the server yet. Deploy the latest Firestore rules.'
          : 'Could not save this offer (${error.code}). Please try again.');
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Could not save this offer. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BusinessSheetShell(
      accentColor: Colors.amberAccent,
      heightFactor: .92,
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              BusinessSheetHeader(
                title: widget.promotionId == null
                    ? 'Create an offer'
                    : 'Refine your offer',
                subtitle:
                    'Keep the value clear, honest, and easy to understand',
                icon: Icons.sell_outlined,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    const Text(
                      'Tell customers exactly what they receive. Clear offers build more trust.',
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: .4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.white, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const BusinessSectionLabel(
                      step: '01',
                      title: 'Offer artwork',
                      description:
                          'Required. Choose a dedicated image created for this promotion.',
                    ),
                    _buildImagePicker(),
                    const SizedBox(height: 26),
                    const BusinessSectionLabel(
                      step: '02',
                      title: 'Customer value',
                      description:
                          'Lead with the benefit, then explain exactly what is included.',
                    ),
                    _field(_title, 'Offer title', 'Student Study Deal'),
                    const SizedBox(height: 16),
                    _field(_offer, 'Offer label', '20% OFF', maxLength: 24),
                    const SizedBox(height: 16),
                    _field(_description, 'Description',
                        'Get 20% off drinks when you present a valid student ID.',
                        lines: 3),
                    const SizedBox(height: 26),
                    const BusinessSectionLabel(
                      step: '03',
                      title: 'Boundaries',
                      description:
                          'Set clear terms and dates to prevent surprises at checkout.',
                    ),
                    _field(_terms, 'Terms and conditions',
                        'Valid for dine-in only. Cannot be combined with other offers.',
                        lines: 3),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _dateTile('Starts', _startDate, true)),
                        const SizedBox(width: 12),
                        Expanded(child: _dateTile('Ends', _endDate, false)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save('draft'),
                        child: const Text('Save draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save('published'),
                        child: Text(_saving ? 'Saving…' : 'Publish offer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint,
      {int lines = 1, int? maxLength}) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label is required.' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasExisting = _existingImageUrl.isNotEmpty;
    return Material(
      color: BusinessWorkspaceColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _saving ? null : _pickImage,
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_selectedImage != null)
                Image.file(_selectedImage!, fit: BoxFit.cover)
              else if (hasExisting)
                Image.network(
                  _existingImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: BusinessWorkspaceColors.surfaceRaised,
                  ),
                )
              else
                const ColoredBox(
                  color: BusinessWorkspaceColors.surfaceRaised,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.white70, size: 34),
                      SizedBox(height: 9),
                      Text('Add offer image',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Required to publish',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              if (_selectedImage != null || hasExisting)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text('Replace',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, bool start) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pickDate(start: start),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: BusinessWorkspaceColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: BusinessWorkspaceColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 5),
            Text(
                value == null
                    ? 'Choose date'
                    : DateFormat('MMM d, y').format(value),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
