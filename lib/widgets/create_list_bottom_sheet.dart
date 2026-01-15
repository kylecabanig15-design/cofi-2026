import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/text_widget.dart';
import '../../utils/colors.dart';
import '../screens/subscreens/shop_selection_screen.dart';

class CreateListBottomSheet extends StatefulWidget {
  const CreateListBottomSheet({super.key});

  @override
  State<CreateListBottomSheet> createState() => _CreateListBottomSheetState();
}

class _CreateListBottomSheetState extends State<CreateListBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  // Reuse the same tag names as shops use in submit_shop_screen.dart
  final Map<String, bool> _selectedTags = {
    'Specialty Coffee': false,
    'Matcha Drinks': false,
    'Pastries': false,
    'Work-Friendly (Wi-Fi + outlets)': false,
    'Pet-Friendly': false,
    'Parking Available': false,
    'Family Friendly': false,
    'Study Sessions': false,
    'Night Café (Open Late)': false,
    'Minimalist / Modern': false,
    'Rustic / Cozy': false,
    'Outdoor / Garden': false,
    'Seaside / Scenic': false,
    'Artsy / Aesthetic': false,
    'Instagrammable': false,
  };

  // Collection type selection
  String _collectionType = 'filter'; // 'filter' or 'custom'
  List<String> _selectedShopIds = []; // For custom collections

  // Check if save button should be enabled
  bool get _isSaveButtonEnabled {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;

    if (_collectionType == 'filter') {
      // Check if any tags are selected
      return _selectedTags.values.any((selected) => selected);
    } else {
      // Custom collection - check if any shops are selected
      return _selectedShopIds.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget(
                    text: 'Create a List',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Collection Type Selection
              TextWidget(
                text: 'Collection Type',
                fontSize: 16,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _collectionType = 'filter'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _collectionType == 'filter'
                              ? primary
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                          border: _collectionType == 'filter'
                              ? Border.all(color: primary, width: 2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.filter_list,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            TextWidget(
                              text: 'Filter Based',
                              fontSize: 14,
                              color: Colors.white,
                              isBold: true,
                            ),
                            const SizedBox(height: 4),
                            TextWidget(
                              text: 'Auto-populate based on tags',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _collectionType = 'custom'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _collectionType == 'custom'
                              ? primary
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                          border: _collectionType == 'custom'
                              ? Border.all(color: primary, width: 2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.handshake,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            TextWidget(
                              text: 'Custom Collection',
                              fontSize: 14,
                              color: Colors.white,
                              isBold: true,
                            ),
                            const SizedBox(height: 4),
                            TextWidget(
                              text: 'Manually select cafes',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Collection Name Field
              TextWidget(
                text: 'Collection Name',
                fontSize: 16,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Perfect Cafe shops for nights out',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white24, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Description Field
              TextWidget(
                text: 'Description',
                fontSize: 16,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add list description',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white24, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Show different content based on collection type
              if (_collectionType == 'filter') ...[
                // Filters: Tags
                TextWidget(
                  text: 'Filters (optional)',
                  fontSize: 16,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                TextWidget(
                  text: 'Select tags to auto-filter shops in this list',
                  fontSize: 12,
                  color: Colors.white70,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _selectedTags.keys.map((t) {
                    final selected = _selectedTags[t] ?? false;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTags[t] = !selected),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? primary : Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextWidget(
                          text: t,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Custom Collection: Shop Selection
                TextWidget(
                  text: 'Select Cafes',
                  fontSize: 16,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(height: 8),
                TextWidget(
                  text: 'Search and manually add cafes to your collection',
                  fontSize: 12,
                  color: Colors.white70,
                ),
                const SizedBox(height: 12),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () async {
                      // Navigate to shop selection screen
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShopSelectionScreen(
                            initiallySelectedShopIds: _selectedShopIds,
                          ),
                        ),
                      );

                      if (result != null && result is List<String>) {
                        setState(() {
                          _selectedShopIds = result;
                        });
                      }
                    },
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: TextWidget(
                      text: _selectedShopIds.isEmpty
                          ? 'Search and add cafes'
                          : '${_selectedShopIds.length} cafe${_selectedShopIds.length == 1 ? '' : 's'} selected',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaveButtonEnabled
                      ? () async {
                          final name = _nameController.text.trim();
                          final description =
                              _descriptionController.text.trim();
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Sign in to create lists')),
                            );
                            return;
                          }
                          try {
                            final listsCol = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('lists');
                            final now = FieldValue.serverTimestamp();
                            DocumentReference docRef;

                            if (_collectionType == 'custom') {
                              // Custom collection - save selected shops

                              docRef = await listsCol.add({
                                'name': name,
                                'description': description,
                                'createdAt': now,
                                'updatedAt': now,
                                'type': 'custom',
                              });

                              // Add selected shops to the items subcollection
                              for (final shopId in _selectedShopIds) {
                                await docRef.collection('items').add({
                                  'shopId': shopId,
                                  'addedAt': now,
                                });
                              }
                            } else {
                              // Filter-based collection
                              final selectedTags = _selectedTags.entries
                                  .where((e) => e.value)
                                  .map((e) => e.key)
                                  .toList();
                              docRef = await listsCol.add({
                                'name': name,
                                'description': description,
                                'createdAt': now,
                                'updatedAt': now,
                                'type': 'filter',
                                if (selectedTags.isNotEmpty)
                                  'filters': {
                                    'tags': selectedTags,
                                  },
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context, docRef.id);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to create list: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSaveButtonEnabled ? primary : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: TextWidget(
                    text: _isSaveButtonEnabled ? 'Save' : '',
                    fontSize: 16,
                    color: Colors.white,
                    isBold: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // static void show(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     isScrollControlled: true,
  //     builder: (context) => const CreateListBottomSheet(),
  //   );
  // }
}
