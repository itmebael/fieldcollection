import 'package:flutter/material.dart';

class GlassScaffoldBackground extends StatelessWidget {
  const GlassScaffoldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF1F6FF), Color(0xFFE7F0FF), Color(0xFFF8FBFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _GlassGridPainter(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: -screenHeight * 0.15,
          left: -screenWidth * 0.22,
          child: Container(
            width: screenWidth * 0.7,
            height: screenWidth * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF66B6FF).withValues(alpha: 0.20),
            ),
          ),
        ),
        Positioned(
          bottom: -screenHeight * 0.18,
          right: -screenWidth * 0.28,
          child: Container(
            width: screenWidth * 0.8,
            height: screenWidth * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2D83EA).withValues(alpha: 0.18),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9FC0FF).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const gap = 42.0;

    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
