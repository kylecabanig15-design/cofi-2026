import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'dart:math' as math;

class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Solid base color
        Positioned.fill(
          child: Container(color: Colors.black),
        ),
        // ambient background - Top Left
        Positioned(
          top: -500,
          left: -500,
          child: Container(
            width: 1000,
            height: 1000,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withOpacity(0.18),
                  Colors.black.withOpacity(0.0),
                ],
                radius: 0.8,
              ),
            ),
          ),
        ),
        // ambient background - Bottom Right
        Positioned(
          bottom: -480,
          right: -480,
          child: Container(
            width: 1000,
            height: 1000,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withOpacity(0.12),
                  Colors.black.withOpacity(0.0),
                ],
                radius: 0.8,
              ),
            ),
          ),
        ),
        
        // Noise Overlay
        Positioned.fill(
           child: Opacity(
              opacity: 0.05, // Very subtle noise
              child: CustomPaint(
                  painter: NoisePainter(),
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
        paint.color = Colors.white.withOpacity(random.nextDouble() * 0.5);
        canvas.drawRect(Rect.fromLTWH(x, y, 1.5, 1.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
