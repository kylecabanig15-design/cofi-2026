import 'package:cofi/models/promotion_model.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PromotionCard extends StatelessWidget {
  const PromotionCard({super.key, required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return _buildCard(context,
        imageUrl: promotion.imageUrl, logoUrl: promotion.logoUrl);
  }

  Widget _buildCard(BuildContext context,
      {required String imageUrl, required String logoUrl}) {
    final expiry = promotion.endDate == null
        ? ''
        : 'Ends ${DateFormat('MMM d').format(promotion.endDate!)}';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showDetails(context),
      child: Ink(
        width: MediaQuery.sizeOf(context).width - 38,
        decoration: BoxDecoration(
          color: const Color(0xFF241D19),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isEmpty
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4B3428), Color(0xFF191513)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFF2A211C)),
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFF2A211C)),
                      ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x73000000), Color(0xF4090807)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(promotion.offer.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .58),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(expiry,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(promotion.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            shadows: [Shadow(blurRadius: 8)])),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                            image: logoUrl.isEmpty
                                ? null
                                : DecorationImage(
                                    image: CachedNetworkImageProvider(logoUrl),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: logoUrl.isEmpty
                              ? const Icon(Icons.local_cafe,
                                  color: primary, size: 17)
                              : null,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(promotion.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            color: primary, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (_) => _PromotionDetailsSheet(promotion: promotion),
    );
  }
}

class _PromotionDetailsSheet extends StatelessWidget {
  const _PromotionDetailsSheet({required this.promotion});

  static const _canvas = Color(0xFF100E0D);
  static const _surface = Color(0xFF1A1715);
  static const _surfaceRaised = Color(0xFF211D1A);
  static const _line = Color(0xFF37312D);
  static const _muted = Color(0xFFB2ABA5);
  static const _warm = primary;

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.46,
      maxChildSize: 0.96,
      expand: false,
      snap: true,
      shouldCloseOnMinExtent: true,
      snapSizes: const [0.46, 0.72, 0.92],
      builder: (context, scrollController) => DecoratedBox(
        decoration: const BoxDecoration(
          color: _canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: _line)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero(context)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      sliver: SliverList.list(
                        children: [
                          _buildCafeIdentity(),
                          const SizedBox(height: 22),
                          _buildValidityCard(),
                          if (promotion.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 25),
                            _sectionLabel('About this offer'),
                            const SizedBox(height: 9),
                            Text(
                              promotion.description.trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (promotion.terms.trim().isNotEmpty) ...[
                            const SizedBox(height: 25),
                            _sectionLabel('Before you go'),
                            const SizedBox(height: 9),
                            _buildTermsCard(),
                          ],
                          const SizedBox(height: 18),
                          _buildRedemptionNote(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final imageUrl = promotion.imageUrl.trim();
    final offer = promotion.offer.trim().isEmpty
        ? 'SPECIAL OFFER'
        : promotion.offer.trim().toUpperCase();

    return SizedBox(
      height: 292,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: _surfaceRaised),
              errorWidget: (_, __, ___) => _imageFallback(),
            )
          else
            _imageFallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x52000000),
                  Color(0x1A000000),
                  Color(0xF2100E0D),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 22,
            right: 16,
            child: Material(
              color: Colors.black.withValues(alpha: 0.52),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.close_rounded, color: primary, size: 21),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    offer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.55,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  promotion.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3327), Color(0xFF1B1512)],
        ),
      ),
      child: Center(
        child: Icon(Icons.local_offer_outlined, color: primary, size: 54),
      ),
    );
  }

  Widget _buildCafeIdentity() {
    final logoUrl = promotion.logoUrl.trim();
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 46,
            height: 46,
            child: logoUrl.isEmpty
                ? const ColoredBox(
                    color: _surfaceRaised,
                    child:
                        Icon(Icons.local_cafe_outlined, color: _warm, size: 21),
                  )
                : CachedNetworkImage(
                    imageUrl: logoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: _surfaceRaised),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: _surfaceRaised,
                      child: Icon(Icons.local_cafe_outlined,
                          color: _warm, size: 21),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Offered by',
                style: TextStyle(color: _muted, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              Text(
                promotion.shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF26372C),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'Available',
            style: TextStyle(
              color: Color(0xFFB8DFC2),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValidityCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: _warm, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offer period',
                  style: TextStyle(color: _muted, fontSize: 11.5),
                ),
                const SizedBox(height: 3),
                Text(
                  _validityText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _validityText() {
    final start = promotion.startDate;
    final end = promotion.endDate;
    if (start != null && end != null) {
      final sameYear = start.year == end.year;
      final startText =
          DateFormat(sameYear ? 'MMM d' : 'MMM d, y').format(start);
      final endText = DateFormat('MMM d, y').format(end);
      return '$startText – $endText';
    }
    if (end != null) return 'Until ${DateFormat('MMM d, y').format(end)}';
    if (start != null) return 'From ${DateFormat('MMM d, y').format(start)}';
    return 'Ask the café for availability';
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildTermsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: primary, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              promotion.terms.trim(),
              style: const TextStyle(
                color: Color(0xFFD1CBC6),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF251B17),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF4B352A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.confirmation_number_outlined, color: _warm, size: 21),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use this offer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Show this screen to the café staff before ordering. The café handles redemption.',
                  style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _canvas,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded, size: 19),
            label: const Text('Got it'),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
