import 'package:flutter/material.dart';

/// Areno robot logo (mirip gambar: wajah putih bulat, layar hitam,
/// mata & senyuman cyan menyala). Bisa dianimasikan (kedip + senyum).
class ArenoLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const ArenoLogo({super.key, this.size = 72, this.animate = true});

  @override
  State<ArenoLogo> createState() => _ArenoLogoState();
}

class _ArenoLogoState extends State<ArenoLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _blink;
  late final Animation<double> _smile;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Kedip mata di interval tertentu (jarang)
    _blink = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.86, 0.92, curve: Curves.easeInOut),
      ),
    );

    // Senyum buka-tutup perlahan
    _smile = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: const _ArenoLogoPainter(blink: 1.0, smile: 1.0),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ArenoLogoPainter(
              blink: _blink.value,
              smile: _smile.value,
            ),
          );
        },
      ),
    );
  }
}

class _ArenoLogoPainter extends CustomPainter {
  final double blink;
  final double smile;

  const _ArenoLogoPainter({required this.blink, required this.smile});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ---------- Telinga / antena kiri ----------
    _drawEar(canvas, size, left: true);
    // ---------- Telinga / antena kanan ----------
    _drawEar(canvas, size, left: false);

    // ---------- Badan putih (squircle) ----------
    final faceRect = Rect.fromCenter(
      center: Offset(cx, cy + size.height * 0.04),
      width: size.width * 0.72,
      height: size.height * 0.72,
    );
    final r = size.width * 0.22;

    // Bayangan badan (pinggir bawah sedikit abu)
    final faceBody = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFFFFF),
          const Color(0xFFE8E8E8),
          const Color(0xFFD8D8D8),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(faceRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, Radius.circular(r)),
      faceBody,
    );

    // Highlight putih atas (cerah)
    final highlightRect = Rect.fromCenter(
      center: Offset(cx - size.width * 0.15, cy - size.height * 0.15),
      width: size.width * 0.35,
      height: size.height * 0.08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(999)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // ---------- Layar hitam ----------
    final screenRect = Rect.fromCenter(
      center: Offset(cx, cy + size.height * 0.06),
      width: size.width * 0.54,
      height: size.height * 0.54,
    );
    final screenR = size.width * 0.13;
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, Radius.circular(screenR)),
      Paint()..color = const Color(0xFF0A0A0A),
    );

    // Ring biru tipis di layar (referensi tepi gambar)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        screenRect.deflate(1.2),
        Radius.circular(screenR),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // ---------- Mata (glowing cyan) ----------
    final eyeY = cy - size.height * 0.04;
    final eyeDX = size.width * 0.13;
    final eyeRadius = size.width * 0.07 * (1.0 - blink.clamp(0, 1));

    if (eyeRadius <= 0.8) {
      // Baris kedip
      final blinkPaint = Paint()
        ..color = const Color(0xFF22D3EE)
        ..strokeWidth = size.width * 0.045
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx - eyeDX - size.width * 0.055, eyeY),
        Offset(cx - eyeDX + size.width * 0.055, eyeY),
        blinkPaint,
      );
      canvas.drawLine(
        Offset(cx + eyeDX - size.width * 0.055, eyeY),
        Offset(cx + eyeDX + size.width * 0.055, eyeY),
        blinkPaint,
      );
    } else {
      // Mata glowing: outer glow + inner bright core
      _drawGlowCircle(canvas, Offset(cx - eyeDX, eyeY), eyeRadius);
      _drawGlowCircle(canvas, Offset(cx + eyeDX, eyeY), eyeRadius);
    }

    // ---------- Senyuman (glowing cyan U) ----------
    final mouthY = cy + size.height * 0.10;
    final mouthWidth = size.width * 0.19;
    final mouthCurve = size.height * (0.07 + 0.035 * smile.clamp(0, 1));

    final smilePath = Path()
      ..moveTo(cx - mouthWidth, mouthY)
      ..quadraticBezierTo(cx, mouthY + mouthCurve, cx + mouthWidth, mouthY);

    // Glow senyum
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = const Color(0xFF22D3EE).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.11
        ..strokeCap = StrokeCap.round,
    );

    // Senyum terang
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = const Color(0xFF22D3EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.055
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEar(Canvas canvas, Size size, {required bool left}) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dir = left ? -1 : 1;

    // Posisi base telinga
    final baseY = cy - size.height * 0.12;
    final tipY = cy - size.height * 0.46;
    final baseIn = cx + dir * size.width * 0.34;
    final tipX = cx + dir * size.width * 0.46;
    final innerNotchX = cx + dir * size.width * 0.40;
    final innerNotchY = cy - size.height * 0.02;

    final earPath = Path()
      ..moveTo(baseIn, baseY + size.height * 0.04)
      ..quadraticBezierTo(
        tipX - dir * size.width * 0.02,
        tipY + size.height * 0.06,
        tipX,
        tipY,
      )
      ..quadraticBezierTo(
        tipX + dir * size.width * 0.03,
        tipY + size.height * 0.16,
        innerNotchX,
        innerNotchY,
      )
      ..quadraticBezierTo(
        baseIn + dir * size.width * 0.06,
        innerNotchY + size.height * 0.10,
        baseIn,
        baseY + size.height * 0.04,
      )
      ..close();

    final earRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final earPaint = Paint()
      ..shader = LinearGradient(
        begin: left ? Alignment.topLeft : Alignment.topRight,
        end: left ? Alignment.bottomRight : Alignment.bottomLeft,
        colors: [
          const Color(0xFF60A5FA),
          const Color(0xFF2563EB),
          const Color(0xFF1E3A8A),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(earRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(earPath, earPaint);

    // Inner stripe (biru muda)
    final stripePath = Path()
      ..moveTo(baseIn + dir * size.width * 0.02, baseY + size.height * 0.08)
      ..quadraticBezierTo(
        tipX - dir * size.width * 0.005,
        tipY + size.height * 0.09,
        tipX + dir * size.width * 0.005,
        tipY + size.height * 0.16,
      )
      ..quadraticBezierTo(
        tipX - dir * size.width * 0.01,
        tipY + size.height * 0.20,
        innerNotchX - dir * size.width * 0.01,
        innerNotchY - size.height * 0.02,
      )
      ..quadraticBezierTo(
        baseIn + dir * size.width * 0.03,
        innerNotchY + size.height * 0.05,
        baseIn + dir * size.width * 0.02,
        baseY + size.height * 0.08,
      )
      ..close();

    canvas.drawPath(
      stripePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ).createShader(earRect)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawGlowCircle(Canvas canvas, Offset center, double radius) {
    // Glow luar (transparan cyan)
    canvas.drawCircle(
      center,
      radius * 2.1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF22D3EE).withValues(alpha: 0.65),
            const Color(0xFF22D3EE).withValues(alpha: 0.18),
            const Color(0xFF22D3EE).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.1)),
    );

    // Inti mata
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            const Color(0xFFFFFFFF),
            const Color(0xFF22D3EE),
            const Color(0xFF06B6D4),
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _ArenoLogoPainter oldDelegate) =>
      oldDelegate.blink != blink || oldDelegate.smile != smile;
}
