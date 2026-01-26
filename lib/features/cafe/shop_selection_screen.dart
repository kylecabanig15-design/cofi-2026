import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/utils/colors.dart';

class ShopSelectionScreen extends StatefulWidget {
  final List<String> initiallySelectedShopIds;

  const ShopSelectionScreen({
    super.key,
    required this.initiallySelectedShopIds,
  });

  @override
  State<ShopSelectionScreen> createState() => _ShopSelectionScreenState();
}

class _ShopSelectionScreenState extends State<ShopSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedShopIds = {};
  List<DocumentSnapshot<Map<String, dynamic>>> _allShops = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _filteredShops = [];

  @override
  void initState() {
    super.initState();
    _selectedShopIds = Set.from(widget.initiallySelectedShopIds);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _filterShops();
      });
    });
    _fetchShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchShops() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .where('isVerified', isEqualTo: true)
        .get();

    setState(() {
      _allShops = snapshot.docs;
      _filterShops();
    });
  }

  void _filterShops() {
    if (_searchQuery.isEmpty) {
      _filteredShops = _allShops;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredShops = _allShops.where((shop) {
        final data = shop.data();
        if (data == null) return false;
        final name = ((data['name'] ?? '') as String).toLowerCase();
        final address = ((data['address'] ?? '') as String).toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }
  }

  void _toggleShopSelection(String shopId) {
    setState(() {
      if (_selectedShopIds.contains(shopId)) {
        _selectedShopIds.remove(shopId);
      } else {
        _selectedShopIds.add(shopId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextWidget(
          text: 'Select Cafes',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedShopIds.toList());
            },
            child: TextWidget(
              text: 'Done (${_selectedShopIds.length})',
              fontSize: 16,
              color: primary,
              isBold: true,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search cafes...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                ],
              ),
            ),
          ),
          // Selected shops count
          if (_selectedShopIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[900],
              child: TextWidget(
                text:
                    '${_selectedShopIds.length} cafe${_selectedShopIds.length == 1 ? '' : 's'} selected',
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          // Shop list
          Expanded(
            child: _filteredShops.isEmpty
                ? Center(
                    child: TextWidget(
                      text: _searchQuery.isEmpty
                          ? 'No cafes found'
                          : 'No cafes found for "$_searchQuery"',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredShops.length,
                    itemBuilder: (context, index) {
                      final shop = _filteredShops[index];
                      final shopData = shop.data();
                      if (shopData == null) return const SizedBox.shrink();
                      final shopId = shop.id;
                      final isSelected = _selectedShopIds.contains(shopId);
                      final name = (shopData['name'] ?? '') as String;
                      final address = (shopData['address'] ?? '') as String;
                      final logoUrl = (shopData['logoUrl'] ?? '') as String;
                      final tags =
                          (shopData['tags'] as List?)?.cast<String>() ?? [];

                      return ShopSelectionTile(
                        name: name,
                        address: address,
                        logoUrl: logoUrl,
                        tags: tags,
                        isSelected: isSelected,
                        onTap: () => _toggleShopSelection(shopId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ShopSelectionTile extends StatelessWidget {
  final String name;
  final String address;
  final String logoUrl;
  final List<String> tags;
  final bool isSelected;
  final VoidCallback onTap;

  const ShopSelectionTile({
    super.key,
    required this.name,
    required this.address,
    required this.logoUrl,
    required this.tags,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.2) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Shop logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[800],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.local_cafe,
                              color: Colors.white70, size: 30),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.local_cafe,
                            color: Colors.white70, size: 30),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Shop info
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
                  TextWidget(
                    text: address,
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  // Tags
                  if (tags.isNotEmpty)
                    SizedBox(
                      height: 24,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: tags.take(3).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextWidget(
                              text: tags[index],
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primary : Colors.white54,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
