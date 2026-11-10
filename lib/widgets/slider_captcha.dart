import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SliderCaptcha extends StatefulWidget {
  final ValueChanged<bool> onVerificationChanged;

  const SliderCaptcha({super.key, required this.onVerificationChanged});

  @override
  State<SliderCaptcha> createState() => _SliderCaptchaState();
}

class _SliderCaptchaState extends State<SliderCaptcha> {
  static const double _thumbWidth = 48;
  static const String _failedAttemptsKey = 'register_captcha_failed_attempts';
  static const String _lockedUntilKey = 'register_captcha_locked_until';
  final Random _random = Random.secure();
  double _targetProgress = 0.48 + Random.secure().nextDouble() * 0.3;
  double _progress = 0;
  bool _verified = false;
  bool _attemptStateLoaded = true;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;
  String? _message;

  @override
  void initState() {
    super.initState();
    _restoreAttemptState();
  }

  Future<void> _restoreAttemptState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final failedAttempts = preferences.getInt(_failedAttemptsKey) ?? 0;
      final lockedUntilMillis = preferences.getInt(_lockedUntilKey);
      final lockedUntil = lockedUntilMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lockedUntilMillis);
      final activeLock = lockedUntil != null && lockedUntil.isAfter(DateTime.now())
          ? lockedUntil
          : null;

      if (activeLock == null && lockedUntilMillis != null) {
        await preferences.remove(_lockedUntilKey);
      }
      if (!mounted) return;

      setState(() {
        _failedAttempts = failedAttempts;
        _lockedUntil = activeLock;
        _attemptStateLoaded = true;
      });
      if (activeLock != null) _startLockTimer(activeLock);
    } catch (_) {
      if (!mounted) return;
      setState(() => _attemptStateLoaded = true);
    }
  }

  void _createChallenge({bool notify = false}) {
    if (_isLocked) return;
    setState(() {
      _targetProgress = 0.48 + _random.nextDouble() * 0.3;
      _progress = 0;
      _verified = false;
      _message = null;
    });
    if (notify) widget.onVerificationChanged(false);
  }

  void _updateProgress(double delta, double availableWidth) {
    if (_verified || _isLocked || !_attemptStateLoaded || availableWidth <= 0) {
      return;
    }
    setState(() {
      _progress = (_progress + delta / availableWidth).clamp(0.0, 1.0);
      _message = null;
    });
  }

  bool get _isLocked =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  Future<void> _finishDrag() async {
    if (_verified || _isLocked || !_attemptStateLoaded) return;
    if ((_progress - _targetProgress).abs() <= 0.035) {
      setState(() {
        _progress = _targetProgress;
        _verified = true;
        _message = null;
        _failedAttempts = 0;
      });
      widget.onVerificationChanged(true);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_failedAttemptsKey);
      await preferences.remove(_lockedUntilKey);
    } else {
      setState(() {
        _failedAttempts++;
        _progress = 0;
        final lockMinutes = _failedAttempts ~/ 5;
        if (lockMinutes > 0) {
          _lockedUntil = DateTime.now().add(Duration(minutes: lockMinutes));
          _message =
              'Terlalu banyak percobaan. Coba lagi dalam $lockMinutes menit.';
        } else {
          _message = 'Belum pas. Coba geser lagi.';
        }
      });
      _saveAttemptState();
      if (_lockedUntil case final lockedUntil?) {
        _startLockTimer(lockedUntil);
      }
    }
  }

  Future<void> _saveAttemptState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_failedAttemptsKey, _failedAttempts);
      final lockedUntil = _lockedUntil;
      if (lockedUntil == null) {
        await preferences.remove(_lockedUntilKey);
      } else {
        await preferences.setInt(
          _lockedUntilKey,
          lockedUntil.millisecondsSinceEpoch,
        );
      }
    } catch (_) {}
  }

  void _startLockTimer(DateTime lockedUntil) {
    _lockTimer?.cancel();
    final remaining = lockedUntil.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _unlock();
      return;
    }
    _lockTimer = Timer(remaining, _unlock);
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    setState(() {
      _lockedUntil = null;
      _progress = 0;
      _message = null;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_lockedUntilKey);
  }

  @override
  Widget build(BuildContext context) {
    final lockedMinutes = _lockedUntil == null
        ? 0
        : max(1, (_lockedUntil!.difference(DateTime.now()).inSeconds / 60).ceil());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _verified ? Colors.green : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _verified
                      ? 'Verifikasi berhasil'
                      : _isLocked
                      ? 'Verifikasi dikunci'
                      : 'Drag To Verify',
                  style: TextStyle(
                    color: _verified
                        ? Colors.green.shade700
                        : _isLocked
                        ? Colors.red.shade700
                        : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLocked || !_attemptStateLoaded
                    ? null
                    : () => _createChallenge(notify: true),
                icon: const Icon(Icons.refresh, color: Colors.grey),
                tooltip: 'Muat puzzle baru',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = width * 0.5;
              final pieceSize = min(width * 0.16, 62.0);
              final sideInset = width * 0.04;
              final travel = width - pieceSize * 1.3 - sideInset * 2;
              final pieceLeft = sideInset + travel * _progress;
              final targetLeft = sideInset + travel * _targetProgress;
              final pieceTop = height * 0.48;

              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    key: const Key('slider-captcha-image'),
                    painter: _CaptchaScenePainter(
                      targetLeft: targetLeft,
                      pieceLeft: pieceLeft,
                      pieceTop: pieceTop,
                      pieceSize: pieceSize,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final travel = width - _thumbWidth;
              return GestureDetector(
                key: const Key('slider-captcha-track'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _verified || _isLocked || !_attemptStateLoaded
                    ? null
                    : (details) => _updateProgress(details.delta.dx, travel),
                onHorizontalDragEnd:
                    _verified || _isLocked || !_attemptStateLoaded
                    ? null
                    : (_) => _finishDrag(),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 4,
                        bottom: 4,
                        width: _thumbWidth + travel * _progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _verified
                                ? Colors.green.shade100
                                : const Color(0xFFD8EEFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: travel * _progress,
                        top: 4,
                        bottom: 4,
                        width: _thumbWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _verified
                                ? Colors.green
                                : const Color(0xFF1689E8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _verified ? Icons.check : Icons.arrow_forward,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _verified
                  ? 'Puzzle berhasil dicocokkan'
                  : !_attemptStateLoaded
                  ? 'Memuat verifikasi...'
                  : _isLocked
                  ? 'Coba lagi dalam $lockedMinutes menit'
                  : 'Geser sampai potongan puzzle pas',
              style: TextStyle(
                color: _verified ? Colors.green.shade700 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 6),
            Text(
              _message!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }
}

class _CaptchaScenePainter extends CustomPainter {
  final double targetLeft;
  final double pieceLeft;
  final double pieceTop;
  final double pieceSize;

  const _CaptchaScenePainter({
    required this.targetLeft,
    required this.pieceLeft,
    required this.pieceTop,
    required this.pieceSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 400;
    canvas.save();
    canvas.scale(scale, scale);
    _drawScene(canvas);

    final targetX = targetLeft / scale;
    final movingX = pieceLeft / scale;
    final top = pieceTop / scale;
    final side = pieceSize / scale;
    final target = _piecePath(targetX, top, side);
    canvas.drawPath(target, Paint()..color = const Color(0xAA102A22));
    canvas.drawPath(
      target,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.save();
    canvas.clipPath(_piecePath(movingX, top, side));
    canvas.translate(movingX - targetX, 0);
    _drawScene(canvas);
    canvas.restore();
    canvas.drawPath(
      _piecePath(movingX, top, side),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  Path _piecePath(double left, double top, double side) {
    final path = Path()
      ..moveTo(left, top)
      ..lineTo(left + side * 0.32, top)
      ..cubicTo(
        left + side * 0.25,
        top - side * 0.3,
        left + side * 0.75,
        top - side * 0.3,
        left + side * 0.68,
        top,
      )
      ..lineTo(left + side, top)
      ..lineTo(left + side, top + side * 0.32)
      ..cubicTo(
        left + side * 1.3,
        top + side * 0.25,
        left + side * 1.3,
        top + side * 0.75,
        left + side,
        top + side * 0.68,
      )
      ..lineTo(left + side, top + side)
      ..lineTo(left, top + side)
      ..close();
    return path;
  }

  void _drawScene(Canvas canvas) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF77C8E8), Color(0xFFD8EDDB)],
      ).createShader(const Rect.fromLTWH(0, 0, 400, 200));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 200), sky);

    canvas.drawCircle(
      const Offset(326, 35),
      17,
      Paint()..color = const Color(0xFFFFE49A),
    );
    _drawCloud(canvas, const Offset(75, 38), 0.8);
    _drawCloud(canvas, const Offset(205, 25), 0.55);

    final distantHill = Path()
      ..moveTo(0, 102)
      ..quadraticBezierTo(80, 57, 153, 99)
      ..quadraticBezierTo(253, 47, 400, 93)
      ..lineTo(400, 200)
      ..lineTo(0, 200)
      ..close();
    canvas.drawPath(distantHill, Paint()..color = const Color(0xFF648A61));

    final grass = Path()
      ..moveTo(0, 117)
      ..quadraticBezierTo(96, 95, 173, 125)
      ..quadraticBezierTo(276, 90, 400, 117)
      ..lineTo(400, 200)
      ..lineTo(0, 200)
      ..close();
    canvas.drawPath(grass, Paint()..color = const Color(0xFF57934F));

    final path = Path()
      ..moveTo(160, 200)
      ..quadraticBezierTo(186, 168, 180, 145)
      ..quadraticBezierTo(164, 121, 194, 99)
      ..lineTo(221, 99)
      ..quadraticBezierTo(194, 129, 210, 149)
      ..quadraticBezierTo(228, 174, 237, 200)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFCFBE9A));

    for (final offset in const [
      Offset(18, 117),
      Offset(61, 108),
      Offset(344, 110),
      Offset(382, 120),
    ]) {
      _drawTree(canvas, offset);
    }

    final foreground = Paint()
      ..color = const Color(0xFF4A8548)
      ..strokeWidth = 1.5;
    for (var x = 8.0; x < 400; x += 13) {
      final y = 188 + (x % 4) * 2;
      canvas.drawLine(Offset(x, y), Offset(x + 2, y - 5), foreground);
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double scale) {
    final paint = Paint()..color = const Color(0xEFFFFFFF);
    canvas.drawCircle(center, 12 * scale, paint);
    canvas.drawCircle(
      center + Offset(12 * scale, -4 * scale),
      15 * scale,
      paint,
    );
    canvas.drawCircle(
      center + Offset(27 * scale, 1 * scale),
      11 * scale,
      paint,
    );
  }

  void _drawTree(Canvas canvas, Offset base) {
    final trunk = Paint()..color = const Color(0xFF674D38);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - 17),
        width: 5,
        height: 27,
      ),
      trunk,
    );
    final leaves = Paint()..color = const Color(0xFF315F3D);
    canvas.drawCircle(Offset(base.dx, base.dy - 39), 19, leaves);
    canvas.drawCircle(Offset(base.dx - 12, base.dy - 29), 14, leaves);
    canvas.drawCircle(Offset(base.dx + 12, base.dy - 29), 14, leaves);
    canvas.drawCircle(
      Offset(base.dx - 5, base.dy - 44),
      6,
      Paint()..color = const Color(0xFF4D7947),
    );
  }

  @override
  bool shouldRepaint(_CaptchaScenePainter oldDelegate) =>
      targetLeft != oldDelegate.targetLeft ||
      pieceLeft != oldDelegate.pieceLeft ||
      pieceTop != oldDelegate.pieceTop ||
      pieceSize != oldDelegate.pieceSize;
}
