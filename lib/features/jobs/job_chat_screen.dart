import 'package:cofi/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/services/notification_service.dart';
import 'package:cofi/widgets/custom_toast.dart';

class JobChatScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String shopId;
  final String posterId;
  final String applicantId;
  final String applicationId;
  final String? conversationId;

  const JobChatScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.shopId,
    required this.posterId,
    required this.applicantId,
    required this.applicationId,
    this.conversationId,
  });

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserName;
  String? _otherUserName;
  late String _posterId;
  late String _applicantId;
  late String _shopId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _posterId = widget.posterId;
    _applicantId = widget.applicantId;
    _shopId = widget.shopId;
    _fetchUserNames();

    // Set active chat ID to suppress notifications while viewing
    final chatId = _getChatId();
    NotificationService().setActiveChat(chatId);

    // Mark existing notifications for this chat as read
    _markChatAsRead(chatId);
  }

  Future<void> _markChatAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final notifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'chat')
          .where('relatedId', isEqualTo: chatId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }

      // We don't decrement the local storage counter directly here,
      // but it will be handled properly when the user checks notifications.
    } catch (e) {
      debugLog('Error marking chat as read: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Only clear the suppression if THIS chat is still the active one —
    // when chats are stacked (e.g. a notification tap opens chat B on top
    // of chat A), popping B must not unsuppress the now-visible A.
    final chatId = _getChatId();
    if (NotificationService().activeChatId == chatId) {
      NotificationService().setActiveChat(null);
    }
    super.dispose();
  }

  Future<void> _fetchUserNames() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get current user's name
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      // Prefer the participants stored on the conversation. Notification
      // metadata can be missing on older notifications.
      if ((_posterId.isEmpty || _applicantId.isEmpty || _shopId.isEmpty) &&
          widget.conversationId?.isNotEmpty == true) {
        final chatDoc = await _firestore
            .collection('job_chats')
            .doc(widget.conversationId)
            .get();
        final chatData = chatDoc.data();
        _posterId = (chatData?['posterId'] as String?) ?? _posterId;
        _applicantId = (chatData?['applicantId'] as String?) ?? _applicantId;
        _shopId = (chatData?['shopId'] as String?) ?? _shopId;
      }

      final String otherUserId =
          currentUser.uid == _posterId ? _applicantId : _posterId;

      // Get other user's name
      final otherUserDoc = otherUserId.isEmpty
          ? null
          : await _firestore.collection('users').doc(otherUserId).get();

      // Applicants are messaging a café, not the personal account that owns
      // it, so use the public shop name for the business side of the chat.
      final shopDoc = _shopId.isEmpty
          ? null
          : await _firestore.collection('shops').doc(_shopId).get();

      final currentData = currentUserDoc.data();
      final otherData = otherUserDoc?.data();
      final shopName = _nonEmpty(shopDoc?.data()?['name']) ??
          _nonEmpty(shopDoc?.data()?['shopName']);
      final currentUserIsPoster = currentUser.uid == _posterId;

      if (!mounted) return;
      setState(() {
        _currentUserName = currentUserIsPoster
            ? shopName ??
                _userDisplayName(
                  currentData,
                  authDisplayName: currentUser.displayName,
                )
            : _userDisplayName(
                currentData,
                authDisplayName: currentUser.displayName,
              );
        _otherUserName = currentUserIsPoster
            ? _userDisplayName(otherData)
            : shopName ?? _userDisplayName(otherData);
        _isLoading = false;
      });
    } catch (e) {
      debugLog('Error loading chat participant names: $e');
      if (!mounted) return;
      setState(() {
        _currentUserName = _nonEmpty(currentUser.displayName) ?? 'User';
        _otherUserName = 'User';
        _isLoading = false;
      });
    }
  }

  String _userDisplayName(
    Map<String, dynamic>? data, {
    String? authDisplayName,
  }) {
    final firstName = _nonEmpty(data?['firstName']);
    final lastName = _nonEmpty(data?['lastName']);
    final fullNameFromParts =
        [firstName, lastName].whereType<String>().join(' ').trim();

    return _nonEmpty(data?['name']) ??
        _nonEmpty(data?['displayName']) ??
        _nonEmpty(fullNameFromParts) ??
        _nonEmpty(authDisplayName) ??
        'User';
  }

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _getChatId() {
    final storedConversationId = widget.conversationId?.trim();
    if (storedConversationId != null && storedConversationId.isNotEmpty) {
      return storedConversationId;
    }

    // Create a consistent chat ID by sorting the user IDs
    final List<String> userIds = [_posterId, _applicantId];
    userIds.sort();
    return '${userIds[0]}_${userIds[1]}_${widget.jobId}';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // A fast reply can happen before the initial profile lookup completes.
    // Wait for it so the recipient sees the actual sender name.
    if (_currentUserName == null) {
      await _fetchUserNames();
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final chatId = _getChatId();
      // The other participant in the chat
      final recipientId =
          currentUser.uid == _posterId ? _applicantId : _posterId;
      final message = {
        'text': messageText,
        'senderId': currentUser.uid,
        'recipientId': recipientId,
        'senderName': _currentUserName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      final chatRef = _firestore.collection('job_chats').doc(chatId);
      final docRef = chatRef.collection('messages').doc();
      final messageId = docRef.id;

      // Create/update the thread and its message atomically. The rules use
      // getAfter() to verify membership even for the first message.
      final batch = _firestore.batch();
      batch.set(
          chatRef,
          {
            'jobId': widget.jobId,
            'jobTitle': widget.jobTitle,
            'shopId': _shopId,
            'posterId': _posterId,
            'applicantId': _applicantId,
            'applicationId': widget.applicationId,
            'lastMessage': messageText,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': currentUser.uid,
            'participants': [_posterId, _applicantId],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      batch.set(docRef, message);
      await batch.commit();

      // Notify the recipient
      final recipientRole = recipientId == _applicantId ? 'user' : 'business';
      try {
        await NotificationService().createChatNotification(
          recipientId,
          _currentUserName ?? 'User',
          messageText,
          chatId,
          widget.jobId,
          widget.jobTitle,
          _shopId,
          _posterId,
          _applicantId,
          widget.applicationId,
          messageId,
          Timestamp.now(),
          recipientRole: recipientRole,
        );
      } catch (e) {
        debugLog('Error sending chat notification: $e');
      }

      // Scroll to bottom
      if (!mounted) return;
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      CustomToast.showError(
        context,
        'Your message was not sent. Check your connection and try again.',
        title: 'Message not sent',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Marks incoming unread messages as read while the chat screen is open.
  /// Only touches the 'isRead'/'readAt' keys, matching the security rules
  /// that allow recipients to mark their own messages read.
  Future<void> _markIncomingMessagesRead(
      List<QueryDocumentSnapshot> docs) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();
    var pending = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] != currentUser.uid && data['isRead'] == false) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
        pending++;
      }
    }
    if (pending > 0) {
      try {
        await batch.commit();
      } catch (e) {
        debugLog('Error marking messages read: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Please log in to access chat',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding:
              const EdgeInsets.only(top: 40, left: 8, right: 16, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: primary.withValues(alpha: 0.2),
                child: Text(
                  _isLoading
                      ? '...'
                      : (_otherUserName ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading ? 'Loading...' : (_otherUserName ?? 'Chat'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.work, color: Colors.white54, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.jobTitle,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('job_chats')
                  .doc(_getChatId())
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugLog(
                      'Error loading chat ${_getChatId()}: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Unable to load messages',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hi to ${_otherUserName ?? 'them'}!',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                // While the chat is open, mark incoming messages as read
                _markIncomingMessagesRead(messages);

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isFromMe = message['senderId'] == currentUser.uid;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final time = timestamp != null
                        ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                        : '';

                    // Add subtle spacing between messages from different senders
                    bool isFirstInGroup = true;
                    if (index > 0) {
                      final prevMessage =
                          messages[index - 1].data() as Map<String, dynamic>;
                      isFirstInGroup =
                          prevMessage['senderId'] != message['senderId'];
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: 6,
                        top: isFirstInGroup ? 12 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: isFromMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isFromMe) ...[
                            if (isFirstInGroup ||
                                index == messages.length - 1 ||
                                (index < messages.length - 1 &&
                                    (messages[index + 1].data() as Map<String,
                                            dynamic>)['senderId'] ==
                                        currentUser.uid))
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey[800],
                                child: Text(
                                  (message['senderName'] as String? ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 28),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: isFromMe
                                    ? const LinearGradient(
                                        colors: [primary, Color(0xFF6B9F71)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isFromMe ? null : Colors.grey[850],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft:
                                      Radius.circular(isFromMe ? 20 : 4),
                                  bottomRight:
                                      Radius.circular(isFromMe ? 4 : 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isFromMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['text'] as String? ?? '',
                                    style: TextStyle(
                                      color: isFromMe
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.9),
                                      fontSize: 15,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      color: isFromMe
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isFromMe)
                            const SizedBox(
                                width:
                                    12), // Give some breathing room on the right
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, Color(0xFF6B9F71)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
