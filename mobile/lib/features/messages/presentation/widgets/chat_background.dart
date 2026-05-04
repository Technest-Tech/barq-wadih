import 'dart:math';
import 'package:flutter/material.dart';

/// A static "WhatsApp-style" tiled doodle pattern painter.
///
/// Draws a small set of simple line glyphs (chat bubble, envelope, camera, car,
/// phone, key, bag, bicycle, etc.) at low opacity over a cream background. The
/// pattern is deterministic — seeded with a fixed integer — so it doesn't shift
/// between rebuilds.
class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECE5DD),
      child: CustomPaint(
        painter: _DoodlePainter(),
        size: Size.infinite,
        child: child,
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  static const _tile = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF8E9AA6).withValues(alpha: 0.18);

    // Walk a grid of tiles; each tile picks 3 glyphs from a deterministic stream.
    final cols = (size.width  / _tile).ceil() + 1;
    final rows = (size.height / _tile).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final ox = c * _tile;
        final oy = r * _tile;
        // Seed per-tile so layout is stable but varied
        final rand = Random((r * 73856093) ^ (c * 19349663));

        for (int i = 0; i < 3; i++) {
          final glyph = rand.nextInt(_glyphs.length);
          final dx = rand.nextDouble() * (_tile - 36) + 18;
          final dy = rand.nextDouble() * (_tile - 36) + 18;
          _glyphs[glyph](canvas, stroke, Offset(ox + dx, oy + dy));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  static final List<void Function(Canvas, Paint, Offset)> _glyphs = [
    _drawBubble,
    _drawEnvelope,
    _drawCamera,
    _drawCar,
    _drawHeadphones,
    _drawKey,
    _drawWatch,
    _drawHouse,
  ];

  static void _drawBubble(Canvas c, Paint p, Offset o) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx - 12, o.dy - 8, 24, 16),
      const Radius.circular(5),
    );
    c.drawRRect(r, p);
    final tail = Path()
      ..moveTo(o.dx - 6, o.dy + 8)
      ..lineTo(o.dx - 8, o.dy + 14)
      ..lineTo(o.dx - 2, o.dy + 8);
    c.drawPath(tail, p);
  }

  static void _drawEnvelope(Canvas c, Paint p, Offset o) {
    final rect = Rect.fromLTWH(o.dx - 12, o.dy - 7, 24, 14);
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), p);
    final flap = Path()
      ..moveTo(rect.left,  rect.top + 1)
      ..lineTo(o.dx,       o.dy + 4)
      ..lineTo(rect.right, rect.top + 1);
    c.drawPath(flap, p);
  }

  static void _drawCamera(Canvas c, Paint p, Offset o) {
    final body = Rect.fromLTWH(o.dx - 13, o.dy - 7, 26, 16);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)), p);
    c.drawCircle(o, 4, p);
    final hood = Path()
      ..moveTo(o.dx - 6, o.dy - 7)
      ..lineTo(o.dx - 4, o.dy - 10)
      ..lineTo(o.dx + 4, o.dy - 10)
      ..lineTo(o.dx + 6, o.dy - 7);
    c.drawPath(hood, p);
  }

  static void _drawCar(Canvas c, Paint p, Offset o) {
    final hull = Path()
      ..moveTo(o.dx - 14, o.dy + 2)
      ..lineTo(o.dx - 10, o.dy - 6)
      ..lineTo(o.dx + 10, o.dy - 6)
      ..lineTo(o.dx + 14, o.dy + 2);
    c.drawPath(hull, p);
    c.drawRect(Rect.fromLTWH(o.dx - 14, o.dy + 2, 28, 6), p);
    c.drawCircle(Offset(o.dx - 8, o.dy + 9), 2.4, p);
    c.drawCircle(Offset(o.dx + 8, o.dy + 9), 2.4, p);
  }

  static void _drawHeadphones(Canvas c, Paint p, Offset o) {
    c.drawArc(
      Rect.fromCenter(center: o, width: 26, height: 22),
      pi, pi, false, p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx - 14, o.dy - 1, 5, 9),
        const Radius.circular(2),
      ),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx + 9, o.dy - 1, 5, 9),
        const Radius.circular(2),
      ),
      p,
    );
  }

  static void _drawKey(Canvas c, Paint p, Offset o) {
    c.drawCircle(Offset(o.dx - 8, o.dy), 4, p);
    c.drawLine(Offset(o.dx - 4, o.dy), Offset(o.dx + 12, o.dy), p);
    c.drawLine(Offset(o.dx + 8,  o.dy), Offset(o.dx + 8,  o.dy + 4), p);
    c.drawLine(Offset(o.dx + 12, o.dy), Offset(o.dx + 12, o.dy + 5), p);
  }

  static void _drawWatch(Canvas c, Paint p, Offset o) {
    c.drawCircle(o, 7, p);
    c.drawCircle(o, 4, p);
    final band = Path()
      ..moveTo(o.dx - 4, o.dy - 7)
      ..lineTo(o.dx - 3, o.dy - 11)
      ..lineTo(o.dx + 3, o.dy - 11)
      ..lineTo(o.dx + 4, o.dy - 7);
    c.drawPath(band, p);
    final band2 = Path()
      ..moveTo(o.dx - 4, o.dy + 7)
      ..lineTo(o.dx - 3, o.dy + 11)
      ..lineTo(o.dx + 3, o.dy + 11)
      ..lineTo(o.dx + 4, o.dy + 7);
    c.drawPath(band2, p);
  }

  static void _drawHouse(Canvas c, Paint p, Offset o) {
    final house = Path()
      ..moveTo(o.dx - 10, o.dy + 8)
      ..lineTo(o.dx - 10, o.dy - 2)
      ..lineTo(o.dx,       o.dy - 10)
      ..lineTo(o.dx + 10,  o.dy - 2)
      ..lineTo(o.dx + 10,  o.dy + 8)
      ..close();
    c.drawPath(house, p);
    c.drawRect(Rect.fromLTWH(o.dx - 3, o.dy + 1, 6, 7), p);
  }
}
