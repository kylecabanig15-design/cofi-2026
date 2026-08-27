import 'package:cofi/utils/logger.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'dart:io';

class ResponseReviewBottomSheet extends StatefulWidget {
  final String shopId;
  final String reviewId;
  final String reviewText;
  final String reviewAuthor;
  final String ownerName;
  final String? ownerAvatarUrl;
  final bool isEdit;
  final String? existingResponse;
  final String? responseId;
  final String? existingResponseImageUrl;

  const ResponseReviewBottomSheet({
    super.key,
    required this.shopId,
    required this.reviewId,
    required this.reviewText,
    required this.reviewAuthor,
    required this.ownerName,
    this.ownerAvatarUrl,
    this.isEdit = false,
    this.existingResponse,
    this.responseId,
    this.existingResponseImageUrl,
  });

  @override
  State<ResponseReviewBottomSheet> createState() =>
      _ResponseReviewBottomSheetState();
}

class _ResponseReviewBottomSheetState extends State<ResponseReviewBottomSheet> {
  final TextEditingController _responseCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  late String _existingImageUrl;
  bool _removeExistingImage = false;
  bool _isSubmitting = false;

  bool get _hasAttachedImage =>
      _selectedImage != null ||
      (_existingImageUrl.isNotEmpty && !_removeExistingImage);

  @override
  void initState() {
    super.initState();
    // If editing, populate with existing response
    if (widget.isEdit && widget.existingResponse != null) {
      _responseCtrl.text = widget.existingResponse!;
    }
    _existingImageUrl = widget.existingResponseImageUrl?.trim() ?? '';
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() {
      _selectedImage = File(image.path);
      _removeExistingImage = false;
    });
  }

  Future<String> _resolveResponseImage(
    String ownerId,
    String responseId,
  ) async {
    if (_selectedImage == null) {
      return _removeExistingImage ? '' : _existingImageUrl;
    }
    final ref = FirebaseStorage.instance
        .ref()
        // Reuse the deployed review-image storage scope; the filename keeps
        // owner responses distinct from guest review uploads.
        .child('review_images')
        .child('response_${widget.shopId}_${ownerId}_$responseId.jpg');
    final upload = await ref.putFile(
      _selectedImage!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return upload.ref.getDownloadURL();
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitResponse() async {
    if (_responseCtrl.text.trim().isEmpty) {
      CustomToast.showWarning(
        context,
        'Write a short reply before posting.',
        title: 'Response is empty',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        CustomToast.showWarning(
          context,
          'Sign in to reply to guest feedback.',
          title: 'Sign-in required',
        );
        return;
      }

      // Get owner data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      // Prefer the name passed in by the caller, then fall back to the user
      // doc fields (firstName/displayName; legacy docs may have 'name').
      final ownerName = widget.ownerName.isNotEmpty
          ? widget.ownerName
          : (userData?['firstName'] as String?) ??
              (userData?['displayName'] as String?) ??
              (userData?['name'] as String?) ??
              'Owner';
      // Writers store the profile photo under 'photoUrl' (see
      // user_model.dart / google_sign_in_service.dart) — 'avatarUrl' was
      // always empty.
      final ownerAvatarUrl = (userData?['photoUrl'] as String?) ??
          user.photoURL ??
          widget.ownerAvatarUrl;
      final shopName = (userData?['shopName'] as String?);
      final responseId = widget.responseId ??
          FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .collection('reviews')
              .doc(widget.reviewId)
              .collection('responses')
              .doc()
              .id;
      final responseImageUrl =
          await _resolveResponseImage(user.uid, responseId);

      if (widget.isEdit && widget.responseId != null) {
        // Edit existing response. Runs inside a transaction so a concurrent
        // arrayUnion (a new reply being added) can't be clobbered by the
        // read-modify-write of the whole responses array.
        final reviewRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('reviews')
            .doc(widget.reviewId);

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final reviewDoc = await tx.get(reviewRef);

          // Defensive extraction: legacy docs may hold non-map entries
          final rawResponses =
              (reviewDoc.data()?['responses'] as List?) ?? const [];
          final responses = rawResponses
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
          final index =
              responses.indexWhere((r) => r['id'] == widget.responseId);

          if (index == -1) {
            throw Exception('Response not found. It may have been deleted.');
          }

          responses[index]['responseText'] = _responseCtrl.text.trim();
          // Firestore sentinels are not supported inside an array value.
          responses[index]['updatedAt'] = Timestamp.now();
          if (responseImageUrl.isEmpty) {
            responses[index].remove('imageUrl');
          } else {
            responses[index]['imageUrl'] = responseImageUrl;
          }

          tx.update(reviewRef, {'responses': responses});
        });
      } else {
        // Add new response
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('reviews')
            .doc(widget.reviewId)
            .update({
          'responses': FieldValue.arrayUnion([
            {
              'id': responseId,
              'ownerName': ownerName,
              'ownerAvatarUrl': ownerAvatarUrl ?? '',
              'responseText': _responseCtrl.text.trim(),
              // This map is embedded inside an arrayUnion, so use a concrete
              // timestamp rather than a serverTimestamp field sentinel.
              'createdAt': Timestamp.now(),
              if (responseImageUrl.isNotEmpty) 'imageUrl': responseImageUrl,
            }
          ]),
        });

        // Send notification to the reviewer
        await _sendReplyNotification(user.uid, shopName);
      }

      if (_removeExistingImage && _existingImageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(_existingImageUrl).delete();
        } catch (_) {
          // The response is already updated; an old missing image is harmless.
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      CustomToast.showFromMessenger(
        messenger,
        widget.isEdit
            ? 'Your changes are now visible to the guest.'
            : 'Your reply is now visible below the review.',
        type: ToastType.success,
        title: widget.isEdit ? 'Response updated' : 'Response posted',
      );
    } catch (_) {
      if (!mounted) return;
      CustomToast.showError(
        context,
        'We could not save your response. Please try again.',
        title: 'Response not saved',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendReplyNotification(String ownerId, String? shopName) async {
    try {
      // Get the review author's ID to send notification
      final reviewDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('reviews')
          .doc(widget.reviewId)
          .get();

      final reviewerUserId = reviewDoc.data()?['userId'] as String?;
      if (reviewerUserId == null) return;

      // Create notification using the schema NotificationModel.fromFirestore
      // reads (title/body/createdAt/isRead) so recipients see real content.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(reviewerUserId)
          .collection('notifications')
          .add({
        'title': '💬 ${shopName ?? 'A café'} replied to your review',
        'body': 'Your review has been replied to',
        'type': 'review_reply',
        'relatedId': widget.shopId,
        'createdAt': Timestamp.now(),
        'isRead': false,
        'recipientRole': 'user',
      });
    } catch (e) {
      debugLog('Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BusinessWorkspaceTheme(
      accentColor: Colors.orangeAccent,
      child: Container(
        decoration: const BoxDecoration(
          color: BusinessWorkspaceColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BusinessSheetHeader(
                title:
                    widget.isEdit ? 'Refine your reply' : 'Reply as the café',
                subtitle:
                    'A thoughtful, specific response builds more trust than a generic thank-you',
                icon: Icons.reply_all_rounded,
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Review being responded to
                    Container(
                      decoration: BoxDecoration(
                        color: BusinessWorkspaceColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: BusinessWorkspaceColors.line),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget(
                            text: widget.reviewAuthor,
                            fontSize: 14,
                            color: Colors.white,
                            isBold: true,
                          ),
                          const SizedBox(height: 8),
                          TextWidget(
                            text: widget.reviewText,
                            fontSize: 13,
                            color: Colors.white70,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Response input
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your response',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 17),
                          label:
                              Text(_hasAttachedImage ? 'Replace' : 'Add image'),
                        ),
                        const SizedBox(width: 4),
                        const Text('1 max',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _responseCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: 'Write your response...'),
                    ),
                    const SizedBox(height: 12),
                    _buildImageAttachment(),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submitResponse,
                            child: Text(
                              _isSubmitting
                                  ? (widget.isEdit
                                      ? 'Updating...'
                                      : 'Posting...')
                                  : (widget.isEdit
                                      ? 'Update Response'
                                      : 'Post Response'),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildImageAttachment() {
    if (!_hasAttachedImage) return const SizedBox.shrink();

    return Container(
      height: 138,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_selectedImage != null)
            Image.file(_selectedImage!, fit: BoxFit.cover)
          else
            Image.network(_existingImageUrl, fit: BoxFit.cover),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Remove image',
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() {
                        _selectedImage = null;
                        _removeExistingImage = true;
                      }),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .72),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: TextButton.icon(
              onPressed: _isSubmitting ? null : _pickImage,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .72),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Replace'),
            ),
          ),
        ],
      ),
    );
  }
}
