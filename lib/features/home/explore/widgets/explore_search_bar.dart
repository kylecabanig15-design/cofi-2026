import 'package:flutter/material.dart';

class ExploreSearchBar extends StatelessWidget {
  final GlobalKey? searchKey;
  final GlobalKey? filterKey;
  final TextEditingController searchCtrl;
  final String query;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onSubmitted;

  const ExploreSearchBar({
    super.key,
    this.searchKey,
    this.filterKey,
    required this.searchCtrl,
    required this.query,
    required this.onClear,
    required this.onFilterTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: searchKey,
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
              controller: searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Find Cafes',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
            ),
          ),
          IconButton(
            key: filterKey,
            icon: const Icon(Icons.tune, color: Colors.white54),
            onPressed: onFilterTap,
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white54),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}
