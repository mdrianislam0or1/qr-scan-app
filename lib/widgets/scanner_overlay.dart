import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  final Rect scanWindow;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;

  const ScannerOverlay({
    super.key,
    required this.scanWindow,
    this.borderRadius = 16.0,
    this.borderColor = const Color(0xFF00E676),
    this.borderWidth = 3.5,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScannerOverlayPainter(
            scanWindow: widget.scanWindow,
            progress: _animation.value,
            borderRadius: widget.borderRadius,
            borderColor: widget.borderColor,
            borderWidth: widget.borderWidth,
          ),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double progress;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;

  _ScannerOverlayPainter({
    required this.scanWindow,
    required this.progress,
    required this.borderRadius,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        scanWindow,
        Radius.circular(borderRadius),
      ));

    final finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(finalPath, backgroundPaint);

    // Draw the 4 stylish corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final cornerLength = scanWindow.width * 0.12;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.left, scanWindow.top + cornerLength)
        ..lineTo(scanWindow.left, scanWindow.top + borderRadius)
        ..quadraticBezierTo(scanWindow.left, scanWindow.top,
            scanWindow.left + borderRadius, scanWindow.top)
        ..lineTo(scanWindow.left + cornerLength, scanWindow.top),
      cornerPaint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.right - cornerLength, scanWindow.top)
        ..lineTo(scanWindow.right - borderRadius, scanWindow.top)
        ..quadraticBezierTo(scanWindow.right, scanWindow.top,
            scanWindow.right, scanWindow.top + borderRadius)
        ..lineTo(scanWindow.right, scanWindow.top + cornerLength),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.left, scanWindow.bottom - cornerLength)
        ..lineTo(scanWindow.left, scanWindow.bottom - borderRadius)
        ..quadraticBezierTo(scanWindow.left, scanWindow.bottom,
            scanWindow.left + borderRadius, scanWindow.bottom)
        ..lineTo(scanWindow.left + cornerLength, scanWindow.bottom),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(scanWindow.right - cornerLength, scanWindow.bottom)
        ..lineTo(scanWindow.right - borderRadius, scanWindow.bottom)
        ..quadraticBezierTo(scanWindow.right, scanWindow.bottom,
            scanWindow.right, scanWindow.bottom - borderRadius)
        ..lineTo(scanWindow.right, scanWindow.bottom - cornerLength),
      cornerPaint,
    );

    // Animated Laser Beam
    final laserY = scanWindow.top + (scanWindow.height * progress);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          borderColor.withValues(alpha: 0.0),
          borderColor.withValues(alpha: 0.85),
          borderColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(scanWindow.left, laserY - 1, scanWindow.width, 2))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(scanWindow.left + 8, laserY),
      Offset(scanWindow.right - 8, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.scanWindow != scanWindow;
  }
}

