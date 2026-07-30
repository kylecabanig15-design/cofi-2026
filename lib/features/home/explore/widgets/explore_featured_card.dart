import 'dart:ui';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExploreFeaturedCard extends StatefulWidget {
  final Map<String, dynamic> shopData;
  final String id;
  final String name;
  final String city;
  final String hours;
  final Widget ratingText;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  final double width;
  final double height;

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
    this.width = double.infinity,
    this.height = 260,
  });

  @override
  State<ExploreFeaturedCard> createState() => _ExploreFeaturedCardState();
}

class _ExploreFeaturedCardState extends State<ExploreFeaturedCard> {
  late PageController _pageController;
  int _currentPage = 0;

  List<String> get _gallery {
    final g = widget.shopData['gallery'];
    if (g is List) return g.map((e) => e.toString()).where((s) => s.startsWith('http')).toList();
    final logo = widget.shopData['logoUrl']?.toString() ?? '';
    if (logo.startsWith('http')) return [logo];
    return [];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = _gallery;
    final isVerified = (widget.shopData['isVerified'] as bool?) ?? false;
    final submissionType = (widget.shopData['submissionType'] as String?) ?? 'community';
    final logoUrl = widget.shopData['logoUrl']?.toString() ?? '';

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background image / gallery ──────────────────────────
                if (gallery.isNotEmpty)
                  PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: gallery.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: gallery[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFF1E1E1E)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(Icons.local_cafe, color: Colors.white24, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Center(
                      child: Icon(Icons.local_cafe, color: Colors.white24, size: 64),
                    ),
                  ),

                // ── Gradient overlay ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),

                // ── Top row: Featured badge + bookmark ──────────────────
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Featured badge
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                                SizedBox(width: 5),
                                Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bookmark
                      GestureDetector(
                        onTap: widget.onBookmark,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
                              ),
                              child: Icon(
                                widget.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: widget.isBookmarked ? Colors.amber : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Removed top dots ───────────────────────────────────

                // ── Bottom content ──────────────────────────────────────
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Hours pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 11),
                                  const SizedBox(width: 4),
                                  TextWidget(
                                    text: widget.hours,
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Name
                            TextWidget(
                              text: widget.name,
                              fontSize: 19,
                              color: Colors.white,
                              isBold: true,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            // City
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: Colors.white54, size: 12),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: TextWidget(
                                    text: widget.city,
                                    fontSize: 12,
                                    color: Colors.white70,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Rating
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                widget.ratingText,
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Right column: Gallery controls & Logo avatar
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (gallery.length > 1)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_pageController.page! > 0) {
                                        _pageController.previousPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    },
                                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_currentPage + 1}/${gallery.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      if (_pageController.page! < gallery.length - 1) {
                                        _pageController.nextPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    },
                                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: logoUrl.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: logoUrl,
                                    imageBuilder: (_, img) => CircleAvatar(
                                      radius: 24,
                                      backgroundImage: img,
                                    ),
                                    placeholder: (_, __) => CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[800],
                                      child: const Icon(Icons.local_cafe, color: Colors.white70, size: 20),
                                    ),
                                    errorWidget: (_, __, ___) => CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[800],
                                      child: const Icon(Icons.local_cafe, color: Colors.white70, size: 20),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey[800],
                                    child: const Icon(Icons.local_cafe, color: Colors.white70, size: 20),
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
      ),
    );
  }
}
