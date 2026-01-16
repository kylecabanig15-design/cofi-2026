import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utils/colors.dart';

class EventCommentsScreen extends StatefulWidget {
  final String eventId;
  final String shopId;
  const EventCommentsScreen(
      {super.key, required this.eventId, required this.shopId});

  @override
  State<EventCommentsScreen> createState() => _EventCommentsScreenState();
}

class _EventCommentsScreenState extends State<EventCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('events')
          .doc(widget.eventId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? 'Anonymous',
        'userEmail': _currentUser!.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextWidget(
          text: 'Event Comments',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: Column(
        children: [
          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('events')
                  .doc(widget.eventId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextWidget(
                      text: 'Error loading comments',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  );
                }
                final comments = snapshot.data?.docs ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: TextWidget(
                      text: 'No comments yet. Be the first to comment!',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index].data();
                    return _buildCommentCard(comment);
                  },
                );
              },
            ),
          ),
          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                top: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Row(
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primary,
                  child: _currentUser?.photoURL != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: _currentUser!.photoURL!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[800]),
                            errorWidget: (context, url, error) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                // Text Input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send Button
                IconButton(
                  onPressed: _isPosting ? null : _postComment,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: primary,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final timestamp = comment['timestamp'] as Timestamp?;
    final DateTime? commentTime = timestamp?.toDate();
    final String timeText =
        commentTime != null ? _formatCommentTime(commentTime) : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[700],
            child: comment['userPhotoUrl'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: comment['userPhotoUrl'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (context, url, error) {
                        return const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Name and Time
                Row(
                  children: [
                    TextWidget(
                      text: comment['userName'] ?? 'Anonymous',
                      fontSize: 14,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(width: 8),
                    TextWidget(
                      text: timeText,
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Comment Text
                TextWidget(
                  text: comment['text'] ?? '',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format date for older comments
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      return '$month/$day/$year';
    }
  }
}
