import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.80, size.height * 0.30);

    final extractPath = Path();
    for (final metric in path.computeMetrics()) {
      extractPath.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }
    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) => oldDelegate.progress != progress;
}

/// A circle that pops in, followed by a checkmark that "draws" itself.
/// The signature success micro-interaction used across the app —
/// deliberately restrained (no particles), per the calm/premium brief.
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color circleColor;
  final Color checkColor;

  const AnimatedCheckmark({
    super.key,
    this.size = 88,
    this.circleColor = AppColors.brandGreen,
    this.checkColor = AppColors.darkGreen,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circleScale = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack));
    final checkProgress = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = circleScale.value < 0 ? 0.0 : circleScale.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: widget.circleColor, shape: BoxShape.circle),
            child: CustomPaint(
              painter: _CheckPainter(progress: checkProgress.value.clamp(0.0, 1.0), color: widget.checkColor),
            ),
          ),
        );
      },
    );
  }
}
