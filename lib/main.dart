import 'package:flutter/material.dart';

// Import Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/change_pin_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/request_admin_screen.dart';
// REVISI: Import payment_screen.dart dihapus dari sini karena sudah tidak digunakan di main.dart
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/match_screen.dart';
import 'screens/point_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/success_auth_screen.dart';
import 'widgets/areno_chatbot_button.dart';
import 'widgets/app_lock_gate.dart';
import 'app_navigator.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'services/session_service.dart';
import 'package:firebase_core/firebase_core.dart';

// Catatan: ScheduleScreen dan CheckoutScreen tidak di-import di sini
// karena sudah tidak dipakai di routing statis (MaterialApp routes).

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.init();
  if (await SessionService.isLoggedIn()) {
    await PushNotificationService.registerTokenIfPossible();
  }
  runApp(const SportsFieldApp());
}

class SportsFieldApp extends StatelessWidget {
  const SportsFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARENASPORTS',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      builder: (context, child) => AppLockGate(
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00A32A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A32A),
          primary: const Color(0xFF00A32A),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2A2B),
          ),
          contentTextStyle: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Colors.grey.shade700,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainNavigation(),
        // REVISI: Route /schedule, /checkout, dan /payment dihapus dari sini
        // karena sekarang menggunakan Navigator.push manual untuk mengirim data dinamis.
        '/history': (context) => const HistoryScreen(),
        '/success_auth': (context) => const SuccessAuthScreen(),
        '/request-admin': (context) => const RequestAdminScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/change-pin': (context) => const ChangePinScreen(),
        '/terms': (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
      },
    );
  }
}

// --- Wrapper untuk Bottom Navigation ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 2; // Default ke Home (index ke-2)
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HistoryScreen(),
      const MatchScreen(),
      HomeScreen(onProfileTap: _goToProfile),
      const PointScreen(),
      const ProfileScreen(),
    ];
  }

  void _goToProfile() {
    if (!mounted) return;
    setState(() => _index = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
          Positioned(
            bottom:
                kBottomNavigationBarHeight +
                MediaQuery.of(context).padding.bottom +
                4,
            right: 12,
            child: const ArenoChatbotButton(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Booking'),
                _buildNavItem(1, Icons.groups_outlined, Icons.groups_rounded, 'Match'),
                _buildNavItem(2, Icons.home_outlined, Icons.home_rounded, 'Home', isCenter: true),
                _buildNavItem(3, Icons.stars_outlined, Icons.stars_rounded, 'Poin'),
                _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {bool isCenter = false}) {
    final isSelected = _index == index;
    if (isCenter) {
      return GestureDetector(
        onTap: () => setState(() => _index = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF00A32A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A32A).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF00A32A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F8ED) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? const Color(0xFF00A32A) : const Color(0xFF94A3B8),
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF00A32A) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
