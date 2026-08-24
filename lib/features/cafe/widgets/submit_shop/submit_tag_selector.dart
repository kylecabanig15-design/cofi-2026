import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class SubmitTagSelector extends StatelessWidget {
  final Map<String, bool> selectedTags;
  final Map<String, List<String>> tagCategories;
  final void Function(String tag) onTagTap;

  const SubmitTagSelector({
    super.key,
    required this.selectedTags,
    required this.tagCategories,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Select Tags',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 16),

        // Tags Sections (Categorized)
        ...tagCategories.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: TextWidget(
                  text: entry.key,
                  fontSize: 14,
                  color: Colors.white70,
                  isBold: true,
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: entry.value.map((tag) {
                  // Ensure tag exists in state, default to false if not
                  final isSelected = selectedTags[tag] ?? false;
                  return _buildTag(tag, isSelected);
                }).toList(),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTag(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => onTagTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextWidget(
          text: text,
          fontSize: 14,
          color: Colors.white,
          isBold: false,
        ),
      ),
    );
  }
}
