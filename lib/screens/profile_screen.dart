import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import '../services/auth_api.dart';
import '../services/pin_service.dart';
import '../services/session_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/photo_gallery_screen.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isGuest = true;
  bool _isFetching = false;
  bool _biometricsEnabled = false;
  bool _lockEnabled = false;
  bool _hasPin = false;
  int _lockTimeoutSeconds = PinService.defaultLockTimeoutSeconds;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    SessionService.authRevision.addListener(_fetchUserProfile);
    _fetchUserProfile();
  }

  @override
  void dispose() {
    SessionService.authRevision.removeListener(_fetchUserProfile);
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      await _loadProfile().timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _loadError ??= 'Gagal memuat profil. Tarik untuk mencoba lagi.';
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _loadProfile() async {
    if (!await SessionService.isLoggedIn()) {
      if (!mounted) return;
      setState(() {
        userData = null;
        _stats = null;
        _isGuest = true;
        _isLoading = false;
        _loadError = null;
        _biometricsEnabled = false;
        _lockEnabled = false;
        _hasPin = false;
      });
      return;
    }

    final cached = await SessionService.currentUser();
    bool bioEnabled = false;
    bool lockEnabled = false;
    bool hasPin = false;
    int lockTimeout = PinService.defaultLockTimeoutSeconds;
    try {
      bioEnabled = await PinService.instance
          .isBiometricEnabled()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      lockEnabled = await PinService.instance
          .isLockEnabled()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      hasPin = await PinService.instance
          .hasPin()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      lockTimeout = await PinService.instance
          .lockTimeoutSeconds()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => PinService.defaultLockTimeoutSeconds,
          );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (cached != null) userData = cached;
      _isGuest = false;
      _biometricsEnabled = bioEnabled;
      _lockEnabled = lockEnabled;
      _hasPin = hasPin;
      _lockTimeoutSeconds = lockTimeout;
      // Data cache langsung ditampilkan supaya halaman tidak berkedip kosong.
      _isLoading = false;
    });

    try {
      final data = await ApiService.instance.profile();
      if (!mounted) return;
      setState(() {
        userData = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : cached;
        _stats = data['stats'] is Map
            ? Map<String, dynamic>.from(data['stats'] as Map)
            : null;
        _isLoading = false;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.isUnauthorized) {
        setState(() {
          userData = null;
          _stats = null;
          _isGuest = true;
          _isLoading = false;
          _loadError = null;
        });
        _showSnackBar(
          'Sesi login berakhir. Silakan login kembali.',
          const Color(0xFFF59E0B),
        );
        return;
      }

      setState(() {
        _isLoading = false;
        if (userData == null) _loadError = e.message;
      });
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (userData == null) {
          _loadError = 'Gagal memuat profil: $e';
        }
      });
      _showSnackBar('Gagal memuat profil: $e', Colors.red);
    }
  }

  String get _lockTimeoutLabel {
    switch (_lockTimeoutSeconds) {
      case 0:
        return 'Langsung saat aplikasi ditinggalkan';
      case 60:
        return 'Setelah 1 menit';
      case 300:
        return 'Setelah 5 menit';
      case 900:
        return 'Setelah 15 menit';
      default:
        return 'Setelah $_lockTimeoutSeconds detik';
    }
  }

  Future<void> _refreshSecurityState() async {
    final hasPin = await PinService.instance.hasPin();
    final lockEnabled = await PinService.instance.isLockEnabled();
    final bioEnabled = await PinService.instance.isBiometricEnabled();
    final timeout = await PinService.instance.lockTimeoutSeconds();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _lockEnabled = lockEnabled;
      _biometricsEnabled = bioEnabled;
      _lockTimeoutSeconds = timeout;
    });
  }

  Future<bool> _confirmWithPinOrBiometric() async {
    if (_biometricsEnabled && await PinService.instance.canUseBiometrics()) {
      final ok = await AppLockService.instance.authenticateBiometric(
        reason: 'Verifikasi untuk mengubah keamanan aplikasi',
      );
      if (ok) return true;
    }

    if (!mounted) return false;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verifikasi PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Masukkan PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.isEmpty) return false;

    final result = await PinService.instance.verifyPin(pin.trim());
    switch (result.status) {
      case PinVerifyStatus.success:
        return true;
      case PinVerifyStatus.lockedOut:
        _showSnackBar(
          'Terlalu banyak percobaan. Tunggu ${result.retryAfter.inSeconds} detik.',
          Colors.red,
        );
        return false;
      case PinVerifyStatus.incorrect:
        _showSnackBar(
          result.attemptsLeft > 0
              ? 'PIN salah. Sisa ${result.attemptsLeft} percobaan.'
              : 'PIN salah.',
          Colors.red,
        );
        return false;
      case PinVerifyStatus.notSet:
        _showSnackBar('PIN belum dibuat.', Colors.orange);
        return false;
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      if (!_hasPin) {
        final created = await Navigator.pushNamed(context, '/change-pin');
        if (created != true || !mounted) return;
      }
      await PinService.instance.setLockEnabled(true);
      await AppLockService.instance.refresh();
      await _refreshSecurityState();
      if (!mounted) return;
      _showSnackBar(
        'Kunci aplikasi diaktifkan.',
        const Color(0xFF00A32A),
      );
      return;
    }

    final verified = await _confirmWithPinOrBiometric();
    if (!verified) return;
    await PinService.instance.setLockEnabled(false);
    await AppLockService.instance.refresh();
    await _refreshSecurityState();
    if (!mounted) return;
    _showSnackBar(
      'Kunci aplikasi dinonaktifkan.',
      const Color(0xFF00A32A),
    );
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      if (!_lockEnabled || !_hasPin) {
        _showSnackBar(
          'Aktifkan kunci aplikasi dengan PIN terlebih dahulu.',
          Colors.orange,
        );
        return;
      }
      final canUse = await PinService.instance.canUseBiometrics();
      if (!canUse) {
        _showSnackBar(
          'Biometrik belum tersedia atau belum didaftarkan di perangkat ini.',
          Colors.orange,
        );
        return;
      }
      final ok = await AppLockService.instance.authenticateBiometric(
        reason: 'Verifikasi untuk mengaktifkan biometrik',
      );
      if (!ok) {
        _showSnackBar('Verifikasi biometrik gagal.', Colors.red);
        return;
      }
      await PinService.instance.setBiometricEnabled(true);
      await _refreshSecurityState();
      if (!mounted) return;
      _showSnackBar(
        'Biometrik diaktifkan. Data biometrik tetap di perangkat Anda.',
        const Color(0xFF00A32A),
      );
      return;
    }

    await PinService.instance.setBiometricEnabled(false);
    await _refreshSecurityState();
    if (!mounted) return;
    _showSnackBar('Biometrik dinonaktifkan.', const Color(0xFF00A32A));
  }

  Future<void> _selectLockTimeout() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Kunci aplikasi setelah',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            for (final option in const [0, 60, 300, 900])
              RadioListTile<int>(
                value: option,
                groupValue: _lockTimeoutSeconds,
                activeColor: const Color(0xFF00A32A),
                title: Text(_timeoutLabelFor(option)),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null) return;
    await PinService.instance.setLockTimeoutSeconds(selected);
    if (!mounted) return;
    setState(() => _lockTimeoutSeconds = selected);
  }

  String _timeoutLabelFor(int seconds) {
    switch (seconds) {
      case 0:
        return 'Langsung saat aplikasi ditinggalkan';
      case 60:
        return 'Setelah 1 menit';
      case 300:
        return 'Setelah 5 menit';
      case 900:
        return 'Setelah 15 menit';
      default:
        return '$seconds detik';
    }
  }

  String? _avatarUrl() {
    final avatar = userData?['profile_photo_url'] ?? userData?['avatar'];
    final text = avatar?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _openAvatarPhoto(String? url) async {
    if (url == null || url.isEmpty) return;
    await PhotoGalleryScreen.open(context, images: [url], title: 'Foto Profil');
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _handleLogout() async {
    await AuthApi.logout();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutDialog() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Konfirmasi Keluar',
      message: 'Apakah Anda yakin ingin keluar dari akun ini?',
      icon: Icons.logout_rounded,
      confirmLabel: 'Keluar',
      destructive: true,
    );

    if (confirmed && mounted) _handleLogout();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final userName = userData?['name']?.toString() ?? 'User';
    final userEmail = userData?['email']?.toString() ?? 'user@example.com';
    final userPhone = userData?['phone']?.toString().trim() ?? '';
    final userPoints = _asInt(userData?['points'] ?? _stats?['points']);
    final bookingCount = _asInt(_stats?['booking_count']);
    final avatarUrl = _avatarUrl();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A32A)),
              )
            : _isGuest
            ? _buildGuestProfile()
            : userData == null && _loadError != null
            ? _buildLoadError()
            : RefreshIndicator(
                onRefresh: _loadProfile,
                color: const Color(0xFF00A32A),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header Title & Logout Icon ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Profile Saya',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          IconButton(
                            onPressed: _showLogoutDialog,
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFEF4444),
                              size: 24,
                            ),
                            splashRadius: 22,
                            tooltip: 'Keluar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- User Card ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/settings',
                            );
                            if (result == true) _fetchUserProfile();
                          },
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  UserAvatar(
                                    url: avatarUrl,
                                    radius: 30,
                                    initials: _getInitials(userName),
                                    onTap: avatarUrl == null
                                        ? null
                                        : () => _openAvatarPhoto(avatarUrl),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userEmail,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (userPhone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        userPhone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // --- Stats Summary (Poin & Booking) ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactStatCard(
                              title: 'Poin Tersedia',
                              value: '$userPoints',
                              icon: Icons.stars_rounded,
                              iconColor: const Color(0xFFEAB308),
                              iconBg: const Color(0xFFFEFCE8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactStatCard(
                              title: 'Total Booking',
                              value: '$bookingCount',
                              icon: Icons.sports_tennis_rounded,
                              iconColor: const Color(0xFF00A32A),
                              iconBg: const Color(0xFFE8F8ED),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- Section: ADDRESS & SECURITY ---
                      _buildSectionHeader('ADDRESS & SECURITY'),
                      const SizedBox(height: 10),
                      _buildCardContainer([
                        _buildListTileItem(
                          icon: Icons.account_box_outlined,
                          title: 'Foto Profil',
                          subtitle: avatarUrl == null
                              ? 'Belum ada foto. Ketuk untuk menambahkan.'
                              : 'Ketuk untuk melihat foto ukuran penuh',
                          onTap: () async {
                            if (avatarUrl == null) {
                              final result = await Navigator.pushNamed(
                                context,
                                '/settings',
                              );
                              if (result == true) _fetchUserProfile();
                              return;
                            }
                            await _openAvatarPhoto(avatarUrl);
                          },
                        ),
                        _buildDivider(),
                        _buildListTileItem(
                          icon: Icons.location_on_outlined,
                          title: 'Tambah Venue / Sewa',
                          subtitle: 'Daftarkan venue olahraga Anda',
                          onTap: () {
                            Navigator.pushNamed(context, '/request-admin');
                          },
                        ),
                        _buildDivider(),
                        _buildListTileItem(
                          icon: Icons.badge_outlined,
                          title: 'Change Password',
                          onTap: () {
                            Navigator.pushNamed(context, '/change-password');
                          },
                        ),
                        _buildDivider(),
                        _buildListTileSwitch(
                          icon: Icons.lock_outline_rounded,
                          title: 'Kunci Aplikasi (PIN)',
                          subtitle: _lockEnabled
                              ? 'Aktif - PIN diminta saat aplikasi dibuka kembali'
                              : 'Opsional. Aktifkan untuk mengunci aplikasi.',
                          value: _lockEnabled,
                          onChanged: _toggleAppLock,
                        ),
                        _buildDivider(),
                        _buildListTileItem(
                          icon: Icons.pin_outlined,
                          title: _hasPin ? 'Ubah PIN' : 'Buat PIN',
                          subtitle: _hasPin
                              ? 'PIN disimpan sebagai hash terenkripsi di perangkat'
                              : 'Buat PIN 4-6 digit untuk kunci aplikasi',
                          onTap: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/change-pin',
                            );
                            if (result == true) await _refreshSecurityState();
                          },
                        ),
                        _buildDivider(),
                        _buildListTileSwitch(
                          icon: Icons.fingerprint_rounded,
                          title: 'Buka dengan Biometrik',
                          subtitle: _biometricsEnabled
                              ? 'Verifikasi dilakukan oleh sistem perangkat'
                              : 'Butuh PIN aktif sebagai cadangan',
                          value: _biometricsEnabled,
                          onChanged: _toggleBiometrics,
                        ),
                        if (_lockEnabled) ...[
                          _buildDivider(),
                          _buildListTileItem(
                            icon: Icons.timer_outlined,
                            title: 'Kunci Setelah',
                            subtitle: _lockTimeoutLabel,
                            onTap: _selectLockTimeout,
                          ),
                        ],
                      ]),

                      const SizedBox(height: 24),

                      // --- Section: ACTIVITY & PREFERENCES ---
                      _buildSectionHeader('MORE'),
                      const SizedBox(height: 10),
                      _buildCardContainer([
                        _buildListTileItem(
                          icon: Icons.receipt_long_outlined,
                          title: 'Riwayat Booking',
                          onTap: () {
                            Navigator.pushNamed(context, '/history');
                          },
                        ),
                        _buildDivider(),
                        _buildListTileItem(
                          icon: Icons.description_outlined,
                          title: 'Syarat dan Ketentuan',
                          onTap: () {
                            Navigator.pushNamed(context, '/terms');
                          },
                        ),
                        _buildDivider(),
                        _buildListTileItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () {
                            Navigator.pushNamed(context, '/privacy');
                          },
                        ),
                        _buildDivider(),
                        _buildListTileItem(
                          icon: Icons.headset_mic_outlined,
                          title: 'Help and Support',
                          onTap: () {
                            Navigator.pushNamed(context, '/chatbot');
                          },
                        ),
                      ]),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }

  Widget _buildListTileItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF64748B)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTileSwitch({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF64748B)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF00A32A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: const Color(0xFF00A32A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 72),
          const Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          const Text(
            'Profil belum bisa dimuat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? 'Periksa koneksi internet lalu coba lagi.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A32A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 72,
              color: Color(0xFF00A32A),
            ),
            const SizedBox(height: 18),
            const Text(
              'Kamu belum login',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Login atau daftar untuk mengakses profil akun dan semua fitur booking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.login),
                label: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A32A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Daftar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00A32A),
                  side: const BorderSide(color: Color(0xFF00A32A)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
