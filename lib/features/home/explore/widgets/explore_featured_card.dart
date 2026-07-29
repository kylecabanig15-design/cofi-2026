import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ExploreFeaturedCard extends StatelessWidget {
  final Map<String, dynamic> shopData;
  final String id;
  final String name;
  final String city;
  final String hours;
  final Widget ratingText;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  
  const ExploreFeaturedCard({
    super.key,
    required this.shopData,
    required this.id,
    required this.name,
    required this.city,
    required this.hours,
    required this.ratingText,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmark,
  });

  List<String> _getGalleryList(dynamic galleryData) {
    if (galleryData is List) {
      return galleryData.map((e) => e.toString()).toList();
    }
    return [];
  }

  Widget _buildSubmissionBadge(bool isVerified, String submissionType, {bool hasRankBadge = false, bool isFeatured = false}) {
    if (!isVerified && !isFeatured) return const SizedBox.shrink();
    
    final Color badgeColor = isFeatured 
        ? primary.withOpacity(0.9) 
        : (submissionType == 'business' 
            ? const Color(0xFF546E7A).withOpacity(0.85) 
            : const Color(0xFFF1C40F).withOpacity(0.85)); 
            
    final IconData badgeIcon = isFeatured
        ? Icons.auto_awesome 
        : (submissionType == 'business' ? Icons.verified : Icons.people);
        
    final String badgeText = isFeatured
        ? 'FEATURED SHOP'
        : (submissionType == 'business' ? 'Verified' : 'Community Added');

    return Positioned(
      top: hasRankBadge ? 46 : 12,
      left: 12,
      child: Container(
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedGallerySlider({
    required List<String> galleryImages,
    required bool isBookmarked,
    required VoidCallback onBookmark,
    bool isVerified = false,
    String submissionType = 'community',
    bool isFeatured = false,
  }) {
    if (galleryImages.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18), bottom: Radius.circular(18)),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.image, color: Colors.white38, size: 50),
            ),
            _buildSubmissionBadge(isVerified, submissionType, hasRankBadge: false, isFeatured: isFeatured),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: onBookmark,
              ),
            ),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setSliderState) {
        final currentIndex = ValueNotifier<int>(0);
        final pageController = PageController();
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18), bottom: Radius.circular(18)),
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  currentIndex.value = index;
                },
                itemCount: galleryImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18), bottom: Radius.circular(18)),
                    child: CachedNetworkImage(
                      imageUrl: galleryImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child:
                            Icon(Icons.image, color: Colors.white38, size: 50),
                      ),
                    ),
                  );
                },
              ),
              _buildSubmissionBadge(isVerified, submissionType, hasRankBadge: false, isFeatured: isFeatured),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                  onPressed: onBookmark,
                ),
              ),
              if (galleryImages.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              if (galleryImages.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              if (galleryImages.length > 1)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ValueListenableBuilder<int>(
                      valueListenable: currentIndex,
                      builder: (context, index, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            galleryImages.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == i ? 12 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    index == i ? Colors.white : Colors.white54,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = _getGalleryList(shopData['gallery']);
    final isVerified = (shopData['isVerified'] as bool?) ?? false;
    final submissionType = (shopData['submissionType'] as String?) ?? 'community';

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: _buildFeaturedGallerySlider(
            galleryImages: gallery,
            isBookmarked: isBookmarked,
            onBookmark: onBookmark,
            isVerified: isVerified,
            submissionType: submissionType,
            isFeatured: true, 
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextWidget(
                      text: hours,
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    const FaIcon(FontAwesomeIcons.solidStar,
                        color: Colors.amber, size: 16),
                     const SizedBox(width: 5),
                    ratingText,
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 280,
                  child: TextWidget(
                    text: name,
                    fontSize: 17,
                    color: Colors.white,
                    isBold: true,
                    maxLines: 1,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: Text(
                    city,
                    style: TextStyle(
                      fontSize: city.length > 30 ? 10.5 : 12,
                      color: Colors.white70,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            if (shopData['logoUrl'] != null && (shopData['logoUrl'] as String).startsWith('http'))
              CachedNetworkImage(
                imageUrl: shopData['logoUrl'],
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: 20,
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[800],
                  child: const Icon(Icons.local_cafe, color: Colors.white70, size: 20),
                ),
                errorWidget: (context, url, error) => CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[800],
                  child: const Icon(Icons.local_cafe, color: Colors.white70, size: 20),
                ),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.local_cafe,
                    color: Colors.white70, size: 20),
              ),
          ],
        ),
      ],
    );
  }
}
