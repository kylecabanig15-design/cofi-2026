import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ExploreShopCard extends StatelessWidget {
  final String id;
  final String name;
  final String city;
  final String hours;
  final Widget ratingText;
  final bool isBookmarked;
  final IconData icon;
  final VoidCallback onBookmark;
  final String logo;
  final List<String>? galleryImages;
  final int? rank;
  final bool isVerified;
  final String submissionType;

  const ExploreShopCard({
    super.key,
    required this.id,
    required this.name,
    required this.city,
    required this.hours,
    required this.ratingText,
    required this.isBookmarked,
    required this.icon,
    required this.onBookmark,
    required this.logo,
    this.galleryImages,
    this.rank,
    this.isVerified = false,
    this.submissionType = 'community',
  });

  static Widget _buildSubmissionBadge(bool isVerified, String submissionType, {bool hasRankBadge = false, bool isFeatured = false}) {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(
              badgeText,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySlider({
    required List<String> galleryImages,
    required bool isBookmarked,
    required VoidCallback onBookmark,
    bool isVerified = false,
    String submissionType = 'community',
    bool hasRankBadge = false,
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
            _buildSubmissionBadge(isVerified, submissionType, hasRankBadge: false),
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

    // Owned by _ShopCardGallery (StatefulWidget) so the PageController and
    // page index survive parent rebuilds instead of being recreated — and
    // leaked — on every bookmark toggle.
    return _ShopCardGallery(
      galleryImages: galleryImages,
      isBookmarked: isBookmarked,
      onBookmark: onBookmark,
      isVerified: isVerified,
      submissionType: submissionType,
      hasRankBadge: hasRankBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Stack(
            children: [
              _buildGallerySlider(
                galleryImages: galleryImages ?? [],
                isBookmarked: isBookmarked,
                onBookmark: onBookmark,
                isVerified: false, 
                submissionType: submissionType,
                hasRankBadge: false, 
              ),
              if (isVerified)
                _buildSubmissionBadge(isVerified, submissionType, hasRankBadge: rank == 1),
              if (rank == 1)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.crown, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          '#$rank Recommended',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
                      const Icon(Icons.star,
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
              if (logo.startsWith('http'))
                CachedNetworkImage(
                  imageUrl: logo,
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
      ),
    );
  }
}

/// Gallery slider for [ExploreShopCard]. Owns its PageController and page
/// index so gallery position survives parent rebuilds (bookmark toggles)
/// instead of resetting to image 0 and leaking controllers.
class _ShopCardGallery extends StatefulWidget {
  final List<String> galleryImages;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final bool isVerified;
  final String submissionType;
  final bool hasRankBadge;

  const _ShopCardGallery({
    required this.galleryImages,
    required this.isBookmarked,
    required this.onBookmark,
    this.isVerified = false,
    this.submissionType = 'community',
    this.hasRankBadge = false,
  });

  @override
  State<_ShopCardGallery> createState() => _ShopCardGalleryState();
}

class _ShopCardGalleryState extends State<_ShopCardGallery> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

  @override
  void dispose() {
    _pageController.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryImages = widget.galleryImages;
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
            ExploreShopCard._buildSubmissionBadge(
                widget.isVerified, widget.submissionType,
                hasRankBadge: false),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: widget.onBookmark,
              ),
            ),
          ],
        ),
      );
    }

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
            controller: _pageController,
            onPageChanged: (index) {
              _currentIndex.value = index;
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
                    child: Icon(Icons.image, color: Colors.white38, size: 50),
                  ),
                ),
              );
            },
          ),
          ExploreShopCard._buildSubmissionBadge(
              widget.isVerified, widget.submissionType,
              hasRankBadge: false),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(
                widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.white,
              ),
              onPressed: widget.onBookmark,
            ),
          ),
          if (galleryImages.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    decoration: const BoxDecoration(
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
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    decoration: const BoxDecoration(
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
                  valueListenable: _currentIndex,
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
  }
}
