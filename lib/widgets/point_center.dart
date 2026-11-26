import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../utils/auth_guard.dart';
import 'app_dialog.dart';
import 'app_network_image.dart';

/// Konten poin dan reward berbasis API Laravel.
class PointCenter extends StatefulWidget {
  const PointCenter({super.key});

  @override
  State<PointCenter> createState() => _PointCenterState();
}

class _PointCenterState extends State<PointCenter> {
  int _userPoints = 0;
  bool _isGuest = true;
  List<Map<String, dynamic>> _rewards = const [];
  List<Map<String, dynamic>> _redemptions = const [];
  String? _rewardsError;
  bool _isLoading = true;
  bool _isProcessingRedeem = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    SessionService.authRevision.addListener(_onSessionChanged);
    SessionService.dataRevision.addListener(_onSessionChanged);
    _initializeScreen();
  }

  @override
  void dispose() {
    SessionService.authRevision.removeListener(_onSessionChanged);
    SessionService.dataRevision.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      await _loadRewards();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadRewards() async {
    final isLoggedIn = await SessionService.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      setState(() {
        _isGuest = true;
        _userPoints = 0;
        _rewardsError = 'Login untuk melihat dan menukar reward.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isGuest = false;
      _rewardsError = null;
      _isLoading = true;
    });

    final cachedPoints = await SessionService.points();
    if (mounted) setState(() => _userPoints = cachedPoints);

    try {
      final data = await ApiService.instance.rewards();
      if (!mounted) return;
      setState(() {
        _userPoints = data.points;
        _rewards = data.rewards;
        _redemptions = data.redemptions;
        _rewardsError = null;
        _isLoading = false;
      });
      await SessionService.updateUser({'points': data.points});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rewardsError = e is ApiException
            ? e.message
            : 'Gagal memuat reward: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRedeem(Map<String, dynamic> reward) async {
    final isAuthenticated = await requireAuthenticatedUser(
      context,
      message: 'Login terlebih dahulu untuk menukar reward.',
    );
    if (!mounted || !isAuthenticated) return;

    final rewardId = (reward['id'] as num?)?.toInt() ?? 0;
    final rewardName = reward['title']?.toString() ?? 'Reward';
    final cost = (reward['points_required'] as num?)?.toInt() ?? 0;
    final venueName = _rewardVenue(reward);
    final redemptionInfo = venueName == null
        ? 'Hadiah ini berlaku di semua venue ArenaSports.'
        : 'Hadiah ini hanya dapat diambil dan diverifikasi di $venueName.';

    if (rewardId == 0) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Tukar Reward',
      message: 'Tukar $cost poin dengan "$rewardName"?\n\n$redemptionInfo',
      icon: Icons.card_giftcard,
      confirmLabel: 'Tukar',
      cancelLabel: 'Batal',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessingRedeem = true);
    try {
      final result = await ApiService.instance.redeemReward(rewardId);
      final redemption = result['redemption'];
      final code = redemption is Map ? redemption['qr_code']?.toString() : null;

      if (!mounted) return;
      setState(() {
        _userPoints = (result['points'] as num?)?.toInt() ?? _userPoints;
      });
      await _initializeScreen();
      if (!mounted) return;
      _showSuccessDialog(rewardName, code, venueName);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e is ApiException ? e.message : 'Gagal menukarkan poin.',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingRedeem = false);
    }
  }

  void _showSuccessDialog(String rewardName, String? code, String? venueName) {
    showAppInfoDialog(
      context,
      title: 'Penukaran Berhasil',
      message: 'Kamu berhasil menukarkan poin dengan:\n$rewardName',
      icon: Icons.check_circle_rounded,
      buttonLabel: 'Selesai',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _venueBadge(venueName, expanded: true),
          const SizedBox(height: 14),
          const Text(
            'KODE REDEEM KAMU',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFE5CB)),
            ),
            child: Text(
              code ?? '-',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF007A2A),
              ),
            ),
          ),
          if (code != null && code.isNotEmpty) ...[
            const SizedBox(height: 15),
            Image.network(
              'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=$code',
              height: 140,
              width: 140,
              errorBuilder: (c, e, s) => const Icon(Icons.qr_code, size: 100),
            ),
            const SizedBox(height: 6),
            Text(
              venueName == null
                  ? 'Tunjukkan kode atau QR ini ke Admin Venue ArenaSports.'
                  : 'Tunjukkan kode atau QR ini ke Admin $venueName.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter kategori dipindah ke Home.
        _buildPointsSummary(),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Daftar Reward',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            IconButton(
              tooltip: 'Refresh poin dan reward',
              onPressed: _initializeScreen,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00A32A)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Reward dengan label venue hanya dapat diambil dan diverifikasi di venue tersebut.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        if (_isGuest)
          _buildLoginPrompt()
        else if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF00A32A)),
            ),
          )
        else if (_rewardsError != null)
          Column(
            children: [
              Text(_rewardsError!, textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: _initializeScreen,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          )
        else if (_rewards.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Belum ada reward aktif saat ini.')),
          )
        else
          ..._rewards.map(_buildRewardCard),
        if (!_isGuest && _redemptions.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Riwayat Penukaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          ..._redemptions.map(_buildRedemptionCard),
        ],
      ],
    );
  }

  Widget _buildPointsSummary() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF00A32A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A32A).withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Color(0xFFFDE047),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo Poin Kamu',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_userPoints Poin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Dapatkan 10 poin setiap pembayaran berhasil.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 40, color: Color(0xFF00A32A)),
          const SizedBox(height: 10),
          const Text(
            'Login diperlukan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Masuk ke akun ArenaSports untuk melihat saldo poin, daftar reward, dan riwayat penukaran.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final authenticated = await requireAuthenticatedUser(
                context,
                message: 'Login untuk melihat poin dan reward kamu.',
              );
              if (authenticated && mounted) _initializeScreen();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A32A),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    final title = reward['title']?.toString() ?? 'Reward';
    final badge = reward['badge']?.toString();
    final description = reward['description']?.toString();
    final imageUrl = reward['image_url']?.toString();
    final cost = (reward['points_required'] as num?)?.toInt() ?? 0;
    final venueName = _rewardVenue(reward);
    final provider = _rewardProvider(reward, venueName);
    final canRedeem = _userPoints >= cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppNetworkImage(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorWidget: _fallbackIcon(title),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (badge != null && badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF007A2A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _venueChip(venueName),
                    if (provider != null) _providerChip(provider),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$cost Poin',
                  style: const TextStyle(
                    color: Color(0xFF00A32A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: canRedeem && !_isProcessingRedeem
                  ? () => _handleRedeem(reward)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A32A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: _isProcessingRedeem
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      canRedeem ? 'Tukar' : 'Kurang',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionCard(Map<String, dynamic> redemption) {
    final title = redemption['reward_title']?.toString() ?? 'Reward';
    final code = redemption['qr_code']?.toString() ?? '-';
    final status = redemption['status']?.toString() ?? '-';
    final redeemedAt = redemption['redeemed_at']?.toString();
    final venueName = _rewardVenue(redemption);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showRedemptionQr(title, code, venueName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF00A32A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      color: Color(0xFF007A2A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: venueName == null
                            ? const Color(0xFF3552A4)
                            : const Color(0xFF007A2A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venueName ?? 'Berlaku di semua venue ArenaSports',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (redeemedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _formatDate(redeemedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007A2A),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.qr_code_2, size: 18, color: Color(0xFF007A2A)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRedemptionQr(String title, String code, String? venueName) {
    if (code.isEmpty || code == '-') return;
    showAppInfoDialog(
      context,
      title: 'QR Penukaran',
      message: title,
      icon: Icons.qr_code_2_rounded,
      buttonLabel: 'Tutup',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _venueBadge(venueName, expanded: true),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFE5CB)),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF007A2A),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Image.network(
            'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=$code',
            height: 150,
            width: 150,
            errorBuilder: (c, e, s) => const Icon(Icons.qr_code, size: 100),
          ),
          const SizedBox(height: 6),
          Text(
            venueName == null
                ? 'Tunjukkan kode atau QR ini ke Admin Venue ArenaSports.'
                : 'Tunjukkan kode atau QR ini ke Admin $venueName.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  String? _rewardVenue(Map<String, dynamic> item) {
    final raw = item['venue_name'] ?? item['venue'];
    if (raw is Map) {
      final nested = raw['name']?.toString().trim();
      return (nested == null || nested.isEmpty) ? null : nested;
    }
    final value = raw?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _rewardProvider(Map<String, dynamic> reward, String? venueName) {
    final provider = reward['provider']?.toString().trim();
    if (provider == null || provider.isEmpty) return null;
    if (venueName != null &&
        provider.toLowerCase() == venueName.toLowerCase()) {
      return null;
    }
    return provider;
  }

  Widget _venueChip(String? venueName) {
    final isGlobal = venueName == null;
    final accent = isGlobal ? const Color(0xFF3552A4) : const Color(0xFF007A2A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isGlobal ? const Color(0xFFEEF4FF) : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 12, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isGlobal ? 'Global' : venueName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerChip(String provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 12,
            color: Color(0xFF5B6B63),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Penyedia: $provider',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6B63),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _venueBadge(String? venueName, {bool expanded = false}) {
    final isGlobal = venueName == null;
    final accent = isGlobal ? const Color(0xFF3552A4) : const Color(0xFF007A2A);
    return Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isGlobal ? const Color(0xFFEEF4FF) : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGlobal ? const Color(0xFFC7D6F5) : const Color(0xFFBFE5CB),
        ),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on_outlined, size: 15, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isGlobal
                  ? 'Berlaku di semua venue ArenaSports'
                  : 'Berlaku di $venueName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(date.day)}/${two(date.month)}/${date.year} '
          '${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return value;
    }
  }

  Widget _fallbackIcon(String title) {
    IconData icon = Icons.card_giftcard;
    final lower = title.toLowerCase();
    if (lower.contains('minuman')) {
      icon = Icons.local_drink;
    } else if (lower.contains('diskon') || lower.contains('%')) {
      icon = Icons.confirmation_number_outlined;
    } else if (lower.contains('jam') || lower.contains('sewa')) {
      icon = Icons.access_time_filled;
    } else if (lower.contains('bola') || lower.contains('lapangan')) {
      icon = Icons.sports_soccer;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F5EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: const Color(0xFF00A32A)),
    );
  }
}
