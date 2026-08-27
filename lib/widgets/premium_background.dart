import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'dart:math' as math;

class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shared foundation for Explore, Community, and Profile.
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.55, 1],
                colors: [
                  Color(0xFF0D090A),
                  Color(0xFF080707),
                  Color(0xFF0C090A),
                ],
              ),
            ),
          ),
        ),

        // Low-opacity edge lighting keeps the center calm and readable.
        Positioned(
          top: -300,
          left: -290,
          child: Container(
            width: 610,
            height: 610,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.2),
                  primary.withValues(alpha: 0.018),
                  Colors.transparent,
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -450,
          right: -400,
          child: Container(
            width: 680,
            height: 680,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.10),
                  primary.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0, 0.52, 1],
              ),
            ),
          ),
        ),

        // Noise Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.018,
              child: CustomPaint(painter: NoisePainter()),
            ),
          ),
        ),

        // Main Content
        child,
      ],
    );
  }
}

// Procedural Noise Painter
class NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random();
    final paint = Paint()..color = Colors.white;

    // Draw fewer points for performance, but enough for texture
    // A full screen noise loop can be heavy. We'll try a moderate density.
    for (int i = 0; i < 5000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      // Vary opacity slightly for depth
      paint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.5);
      canvas.drawRect(Rect.fromLTWH(x, y, 1.5, 1.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
