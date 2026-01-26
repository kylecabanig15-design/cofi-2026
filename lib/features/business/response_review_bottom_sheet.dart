import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  @override
  State<ResponseReviewBottomSheet> createState() =>
      _ResponseReviewBottomSheetState();
}

class _ResponseReviewBottomSheetState extends State<ResponseReviewBottomSheet> {
  final TextEditingController _responseCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // If editing, populate with existing response
    if (widget.isEdit && widget.existingResponse != null) {
      _responseCtrl.text = widget.existingResponse!;
    }
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitResponse() async {
    if (_responseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a response')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to respond')),
        );
        return;
      }

      // Get owner data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final ownerName = (userData?['name'] as String?) ?? 'Owner';
      final ownerAvatarUrl = (userData?['avatarUrl'] as String?);
      final shopName = (userData?['shopName'] as String?);

      if (widget.isEdit && widget.responseId != null) {
        // Edit existing response
        final reviewDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('reviews')
            .doc(widget.reviewId)
            .get();

        final responses = (reviewDoc.data()?['responses'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final index = responses.indexWhere((r) => r['id'] == widget.responseId);

        if (index != -1) {
          responses[index]['responseText'] = _responseCtrl.text.trim();
          responses[index]['updatedAt'] = Timestamp.now();

          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .collection('reviews')
              .doc(widget.reviewId)
              .update({'responses': responses});
        }
      } else {
        // Add new response
        final responseId = FirebaseFirestore.instance.collection('_').doc().id;

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
              'createdAt': Timestamp.now(),
            }
          ]),
        });

        // Send notification to the reviewer
        await _sendReplyNotification(user.uid, shopName);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.isEdit
                ? 'Response updated successfully'
                : 'Response posted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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

      // Create notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(reviewerUserId)
          .collection('notifications')
          .add({
        'type': 'reply_to_review',
        'shopId': widget.shopId,
        'shopName': shopName ?? 'Café Owner',
        'message': 'Your review has been replied to',
        'timestamp': Timestamp.now(),
        'read': false,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              TextWidget(
                text: widget.isEdit ? 'Edit Response' : 'Respond to Review',
                fontSize: 20,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 24),

              // Review being responded to
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
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
              TextWidget(
                text: 'Your Response',
                fontSize: 16,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _responseCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  hintText: 'Write your response...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: TextWidget(
                        text: 'Cancel',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitResponse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: TextWidget(
                        text: _isSubmitting
                            ? (widget.isEdit ? 'Updating...' : 'Posting...')
                            : (widget.isEdit
                                ? 'Update Response'
                                : 'Post Response'),
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
