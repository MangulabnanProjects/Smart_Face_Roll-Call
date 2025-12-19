import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConfidenceIndicator extends StatefulWidget {
  final double confidence;
  final double size;
  final Color primaryColor;
  final Color backgroundColor;
  
  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.size = 120,
    this.primaryColor = const Color(0xFF00D9C9), // Default cyan for dark theme
    this.backgroundColor = const Color(0xFF2A2F3A), // Default dark grey
  });

  @override
  State<ConfidenceIndicator> createState() => _ConfidenceIndicatorState();
}

class _ConfidenceIndicatorState extends State<ConfidenceIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.confidence).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            
            // Progress circle
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: _animation.value,
                  color: widget.primaryColor,
                  backgroundColor: widget.backgroundColor.withOpacity(0.3),
                  strokeWidth: 8,
                ),
              ),
            ),
            
            // Percentage text
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(_animation.value * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.size * 0.22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Confidence',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: widget.size * 0.10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
