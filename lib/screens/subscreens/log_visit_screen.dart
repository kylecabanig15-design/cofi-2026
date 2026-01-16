import 'package:cofi/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LogVisitScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String shopAddress;
  final String logo;

  const LogVisitScreen(
      {super.key,
      required this.shopId,
      required this.logo,
      required this.shopName,
      required this.shopAddress});

  @override
  State<LogVisitScreen> createState() => _LogVisitScreenState();
}

class _LogVisitScreenState extends State<LogVisitScreen> {
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  // Visit tags for categorizing the visit context
  final Set<String> _selectedTags = {};
  final List<String> _availableTags = [
    'Business Meeting',
    'Chill / Hangout',
    'Study Session',
    'Group Gathering',
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to log a visit.')));
        return;
      }
      final data = {
        'userId': user.uid,
        'userEmail': user.email,
        'note': _noteCtrl.text.trim(),
        'tags': _selectedTags.toList(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('visits')
          .add(data);

      // Also record this shopId in the user's `visited` array so counts match Explore/Collections
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'visited': FieldValue.arrayUnion([widget.shopId])
        }, SetOptions(merge: true));
      } catch (_) {
        // No-op: UI feedback below still applies
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Visit logged')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextWidget(
          text: 'Log your visit',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[800],
                    image: widget.logo.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(widget.logo),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: widget.shopName,
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    TextWidget(
                      text: widget.shopAddress,
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextWidget(
              text: 'Write a note',
              fontSize: 16,
              color: Colors.white,
              isBold: true,
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 5,
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[800],
                hintText: 'Write your note here...',
                hintStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextWidget(
              text: 'What was your visit context?',
              fontSize: 16,
              color: Colors.white,
              isBold: true,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: TextWidget(
                    text: tag,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  backgroundColor: Colors.grey[800],
                  selectedColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: TextWidget(
                  text: _submitting ? 'Submitting...' : 'Submit',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
