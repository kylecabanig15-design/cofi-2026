import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/widgets/text_widget.dart';

class SubmitPhotoSection extends StatelessWidget {
  final String title;
  final List<String> existingUrls;
  final List<File> newImages;
  final VoidCallback? onAdd;
  final void Function(int index) onRemoveExisting;
  final void Function(int index) onRemoveNew;

  const SubmitPhotoSection({
    super.key,
    required this.title,
    required this.existingUrls,
    required this.newImages,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: title,
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: (existingUrls.isEmpty && newImages.isEmpty)
              ? GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[700]!,
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.white54,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        TextWidget(
                          text: 'Add up to 5 photos',
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: existingUrls.length +
                      newImages.length +
                      (existingUrls.length + newImages.length < 5 ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    // Add button at the end
                    if (index == existingUrls.length + newImages.length) {
                      return GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: const Center(
                            child: Icon(Icons.add,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      );
                    }

                    // Existing Images
                    if (index < existingUrls.length) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: existingUrls[index],
                              width: 280,
                              height: 200,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 280,
                                height: 200,
                                color: Colors.grey[800],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error,
                                      color: Colors.white),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => onRemoveExisting(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // New Images
                    final newIndex = index - existingUrls.length;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            newImages[newIndex],
                            width: 280,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => onRemoveNew(newIndex),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
