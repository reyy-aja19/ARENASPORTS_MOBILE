import 'package:flutter/material.dart';

// Import Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/request_admin_screen.dart';
// REVISI: Import payment_screen.dart dihapus dari sini karena sudah tidak digunakan di main.dart
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/point_screen.dart';
import 'screens/match_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/success_auth_screen.dart';
import 'widgets/areno_chatbot_button.dart';

// Catatan: ScheduleScreen dan CheckoutScreen tidak di-import di sini
// karena sudah tidak dipakai di routing statis (MaterialApp routes).

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SportsFieldApp());
}

class SportsFieldApp extends StatelessWidget {
  const SportsFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARENASPORTS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00A32A),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
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

  @override
  Widget build(BuildContext context) {
    // List halaman untuk navigasi bawah
    final List<Widget> _pages = [
      const HistoryScreen(),
      const PointScreen(),
      HomeScreen(
        onProfileTap: () {
          setState(() {
            _index = 5; // Berpindah ke tab Profil
          });
        },
      ),
      const MatchScreen(),
      const FriendsScreen(),
      const ProfileScreen(),
    ];

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (val) {
          setState(() {
            _index = val;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF00A32A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Booking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_outlined),
            activeIcon: Icon(Icons.monetization_on),
            label: 'Poin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Event',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
