import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import '../services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ballController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, 0.42, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0, 0.72, curve: Curves.elasticOut),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.35, 0.72, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.35, 0.78, curve: Curves.easeOutCubic),
          ),
        );
    _taglineFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.62, 1, curve: Curves.easeOut),
    );

    _introController.forward();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefsFuture = SharedPreferences.getInstance();
    final startupResults = await Future.wait<dynamic>([
      prefsFuture,
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      Future<void>.delayed(const Duration(milliseconds: 2400)),
    ]);
    if (!mounted) return;

    final prefs = startupResults.first as SharedPreferences;
    await PushNotificationService.init();
    final token = prefs.getString('token');
    Navigator.pushReplacementNamed(
      context,
      token != null && token.isNotEmpty ? '/home' : '/login',
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _ballController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF073B31),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CourtLinesPainter()),
          AnimatedBuilder(
            animation: _ballController,
            builder: (context, child) {
              final progress = Curves.easeInOut.transform(
                _ballController.value,
              );
              return Align(
                alignment: Alignment(-0.78 + (progress * 1.56), 0.58),
                child: Transform.rotate(
                  angle: progress * math.pi * 2,
                  child: child,
                ),
              );
            },
            child: const Icon(
              Icons.sports_soccer,
              color: Color(0xFF54E28C),
              size: 30,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/images/arenasports_icon.png',
                      width: 164,
                      height: 164,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: const Text(
                      'ARENASPORTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'SAATNYA MASUK LAPANGAN',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 42),
                  child: SizedBox(
                    width: 92,
                    child: AnimatedBuilder(
                      animation: _introController,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _introController.value,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF54E28C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtLinesPainter extends CustomPainter {
  const _CourtLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final court = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.82,
      height: size.height * 0.62,
    );

    canvas.drawRect(court, line);
    canvas.drawLine(
      Offset(court.center.dx, court.top),
      Offset(court.center.dx, court.bottom),
      line,
    );
    canvas.drawCircle(court.center, court.width * 0.13, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(court.left + court.width * 0.1, court.center.dy),
        width: court.width * 0.2,
        height: court.height * 0.46,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(court.right - court.width * 0.1, court.center.dy),
        width: court.width * 0.2,
        height: court.height * 0.46,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
