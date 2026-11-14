import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Impeller GPU-accelerated custom vector renderer of `c:\GIT\MusicBotUI\src\assets\logo_icon.svg`
/// (Equalizer bars + floating musical notes + stitched dark pocket with neon emerald rivets)
/// plus the `MusicBỏTúi` brand wordmark.
class MusicBotLogoIcon extends StatelessWidget {
  final double size;

  const MusicBotLogoIcon({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(
          painter: MusicBotLogoPainter(),
        ),
      ),
    );
  }
}

/// Brand Wordmark matching `MusicBotUI`:
/// `[LogoIcon] MusicBỏTúi` (`Music` in white, `BỏTúi` in vibrant emerald `#00E676`).
class MusicBotBrandWordmark extends StatelessWidget {
  final double iconSize;
  final double fontSize;

  const MusicBotBrandWordmark({
    super.key,
    this.iconSize = 32,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x4000E676),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: MusicBotLogoIcon(size: iconSize),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.0,
            ),
            children: const [
              TextSpan(
                text: 'Music',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'BỏTúi',
                style: TextStyle(color: Color(0xFF00E676)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MusicBotLogoPainter extends CustomPainter {
  final bool withAppIconBackground;

  const MusicBotLogoPainter({
    this.withAppIconBackground = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    if (withAppIconBackground) {
      final bgRect = Offset.zero & size;
      final bgRRect = RRect.fromRectAndRadius(
        bgRect,
        Radius.circular(size.width * 0.22),
      );
      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(size.width, size.height),
          const [
            Color(0xFF141D24),
            Color(0xFF0B1014),
          ],
        );
      canvas.drawRRect(bgRRect, bgPaint);

      // Subtle emerald radial glow in center
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.width * 0.45,
          const [
            Color(0x3300E676),
            Color(0x0000E676),
          ],
        );
      canvas.drawRRect(bgRRect, glowPaint);
    }

    // Coordinate system from logo_icon.svg: viewBox="0 0 800 800"
    final scaleX = size.width / 800.0;
    final scaleY = size.height / 800.0;
    canvas.scale(scaleX, scaleY);

    // 1. Equalizer Bars Gradient (#00D26A -> #1ED760 -> #55FF9E bottom-to-top)
    final eqShader = ui.Gradient.linear(
      const Offset(400, 420),
      const Offset(400, 115),
      const [
        Color(0xFF00D26A),
        Color(0xFF1ED760),
        Color(0xFF55FF9E),
      ],
      const [0.0, 0.6, 1.0],
    );

    final eqGlowPaint = Paint()
      ..shader = eqShader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final eqPaint = Paint()..shader = eqShader;

    const bars = <List<double>>[
      [250, 270, 34, 150],
      [300, 225, 34, 195],
      [350, 180, 34, 240],
      [400, 115, 34, 305],
      [450, 180, 34, 240],
      [500, 225, 34, 195],
      [550, 270, 34, 150],
    ];

    for (final b in bars) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(b[0], b[1], b[2], b[3]),
        const Radius.circular(17),
      );
      canvas.drawRRect(rrect, eqGlowPaint);
      canvas.drawRRect(rrect, eqPaint);
    }

    // 2. Floating Musical Notes (Left & Right)
    _drawMusicalNote(canvas, dx: 155, dy: 205, angleDeg: -16);
    _drawMusicalNote(canvas, dx: 615, dy: 195, angleDeg: 14);

    // 3. Main Pocket Body Path
    final pocketBodyPath = Path()
      ..moveTo(205, 350)
      ..cubicTo(320, 375, 480, 375, 595, 350)
      ..lineTo(570, 590)
      ..cubicTo(565, 640, 520, 675, 470, 695)
      ..lineTo(415, 715)
      ..cubicTo(405, 718, 395, 718, 385, 715)
      ..lineTo(330, 695)
      ..cubicTo(280, 675, 235, 640, 230, 590)
      ..close();

    // Pocket drop shadow
    canvas.save();
    canvas.translate(0, 14);
    canvas.drawPath(
      pocketBodyPath,
      Paint()
        ..color = const Color(0x73000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.restore();

    final pocketBodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(400, 350),
        const Offset(400, 718),
        const [
          Color(0xFF283238),
          Color(0xFF1E262B),
          Color(0xFF12181C),
        ],
        const [0.0, 0.35, 1.0],
      );
    canvas.drawPath(pocketBodyPath, pocketBodyPaint);

    // 4. Top Rim / Lip of Pocket
    final pocketRimPath = Path()
      ..moveTo(205, 350)
      ..cubicTo(320, 375, 480, 375, 595, 350)
      ..lineTo(592, 375)
      ..cubicTo(480, 400, 320, 400, 208, 375)
      ..close();

    final pocketRimPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(400, 350),
        const Offset(400, 400),
        const [
          Color(0xFF3A464D),
          Color(0xFF222B30),
        ],
      );
    canvas.drawPath(pocketRimPath, pocketRimPaint);

    // 5. Stitched Seam Border (Dashed #00E676)
    final seamPath = Path()
      ..moveTo(235, 395)
      ..cubicTo(330, 415, 470, 415, 565, 395)
      ..lineTo(545, 580)
      ..cubicTo(540, 620, 500, 650, 460, 668)
      ..lineTo(410, 686)
      ..cubicTo(403, 689, 397, 689, 390, 686)
      ..lineTo(340, 668)
      ..cubicTo(300, 650, 260, 620, 255, 580)
      ..close();

    final seamPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    _drawDashedPath(canvas, seamPath, seamPaint, dashWidth: 13, dashSpace: 10);

    // 6. Corner Rivets
    _drawRivet(canvas, const Offset(230, 385));
    _drawRivet(canvas, const Offset(570, 385));

    canvas.restore();
  }

  void _drawMusicalNote(
    Canvas canvas, {
    required double dx,
    required double dy,
    required double angleDeg,
  }) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.rotate(angleDeg * math.pi / 180.0);

    final notePaint = Paint()..color = const Color(0xFF1ED760);
    final glowPaint = Paint()
      ..color = const Color(0x881ED760)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Rotated ellipse head
    canvas.save();
    canvas.translate(25, 55);
    canvas.rotate(-20 * math.pi / 180.0);
    final ovalRect = Rect.fromCenter(
      center: Offset.zero,
      width: 38,
      height: 28,
    );
    canvas.drawOval(ovalRect, glowPaint);
    canvas.drawOval(ovalRect, notePaint);
    canvas.restore();

    // Stem
    final stemRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(36, 8, 8, 48),
      const Radius.circular(4),
    );
    canvas.drawRRect(stemRRect, glowPaint);
    canvas.drawRRect(stemRRect, notePaint);

    // Flag
    final flagPath = Path()
      ..moveTo(44, 8)
      ..cubicTo(58, 10, 68, 22, 66, 38)
      ..cubicTo(64, 34, 56, 22, 44, 20)
      ..close();
    canvas.drawPath(flagPath, glowPaint);
    canvas.drawPath(flagPath, notePaint);

    canvas.restore();
  }

  void _drawRivet(Canvas canvas, Offset center) {
    final rivetPaint = Paint()
      ..shader = ui.Gradient.linear(
        center - const Offset(10, 10),
        center + const Offset(10, 10),
        const [
          Color(0xFF69F0AE),
          Color(0xFF00C853),
          Color(0xFF007E33),
        ],
        const [0.0, 0.5, 1.0],
      );
    final borderPaint = Paint()
      ..color = const Color(0xFF11181C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, 10, rivetPaint);
    canvas.drawCircle(center, 10, borderPaint);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint, {
    required double dashWidth,
    required double dashSpace,
  }) {
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant MusicBotLogoPainter oldDelegate) =>
      oldDelegate.withAppIconBackground != withAppIconBackground;
}
