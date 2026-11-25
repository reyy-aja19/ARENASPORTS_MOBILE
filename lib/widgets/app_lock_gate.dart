import 'package:flutter/material.dart';

import '../screens/app_lock_screen.dart';
import '../services/app_lock_service.dart';
import '../services/session_service.dart';

/// Menutup seluruh isi aplikasi dengan layar kunci bila PIN/biometrik aktif.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final AppLockService _lock = AppLockService.instance;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SessionService.authRevision.addListener(_onSessionChanged);
    _lock.initialize().whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionService.authRevision.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    _lock.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _lock.handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _lock.handleAppResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(color: Color(0xFF073B31));
    }

    return AnimatedBuilder(
      animation: _lock,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            TickerMode(
              enabled: !_lock.isLocked,
              child: ExcludeSemantics(
                excluding: _lock.isLocked,
                child: IgnorePointer(
                  ignoring: _lock.isLocked,
                  child: widget.child,
                ),
              ),
            ),
            if (_lock.isLocked) const AppLockScreen(),
          ],
        );
      },
    );
  }
}
