import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:penyewaan_lapangan/services/api_service.dart';
import '../utils/auth_guard.dart';
import 'app_dialog.dart';
import 'points_category_card.dart';

/// Konten poin dan reward yang bisa dipasang langsung di halaman Home.
class PointCenter extends StatefulWidget {
  const PointCenter({
    super.key,
    this.selectedCategory = 'Semua',
    this.onCategoryChanged,
  });

  final String selectedCategory;
  final ValueChanged<String>? onCategoryChanged;

  @override
  State<PointCenter> createState() => _PointCenterState();
}

class _PointCenterState extends State<PointCenter> {
  static const List<Map<String, dynamic>> _guestRewards = [
    {'id': 1, 'name': 'Voucher Booking Rp25.000', 'points': 100},
    {'id': 2, 'name': 'Diskon Booking 10%', 'points': 50},
    {'id': 3, 'name': 'Minuman Gratis', 'points': 25},
  ];

  final ApiService _apiService = ApiService();
  int _userPoints = 0;
  bool _isGuest = true;
  String? _pointsError;
  List<dynamic> _rewards = [];
  String? _rewardsError;
  bool _isLoadingRewards = true;
  bool _isProcessingRedeem = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isGuest = token == null || token.isEmpty;

    if (!mounted) return;
    if (!isGuest && prefs.getString('auth_mode') == 'local') {
      final rawUser = prefs.getString('user');
      final user = rawUser == null
          ? <String, dynamic>{}
          : jsonDecode(rawUser) as Map<String, dynamic>;
      setState(() {
        _isGuest = false;
        _userPoints = (user['points'] as num?)?.toInt() ?? 0;
        _pointsError = null;
        _rewards = _guestRewards;
        _isLoadingRewards = false;
      });
      return;
    }

    setState(() {
      _isGuest = isGuest;
      if (isGuest) {
        _pointsError = 'Login untuk melihat poin akun.';
        _rewards = _guestRewards;
        _isLoadingRewards = false;
      }
    });

    if (!isGuest) {
      await Future.wait([_loadUserPoints(), _fetchRewardsFromApi()]);
    }
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isLoadingRewards = true;
      _rewardsError = null;
    });
    await _initializeScreen();
  }

  // 1. Ambil poin user dari lokal data pencatatan login
  Future<void> _loadUserPoints() async {
    try {
      final result = await _apiService.getUserProfile();

      if (result == null) {
        print("User API null");
        if (mounted) {
          setState(() {
            _pointsError = 'Login dengan akun untuk melihat poin.';
          });
        }
        return;
      }

      setState(() {
        _userPoints = result['points'] ?? 0;
        _pointsError = null;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(result));
    } catch (e) {
      print("Error load user points: $e");
    }
  }

  // 2. Ambil list reward sesuai yang diinput di Web Admin
  Future<void> _fetchRewardsFromApi() async {
    try {
      final result = await _apiService.getRewards();
      if (!mounted) return;
      setState(() {
        final success = result['status'] == true;
        _rewards = success ? result['data'] ?? [] : [];
        _rewardsError = success
            ? null
            : result['message']?.toString() ?? 'Gagal memuat daftar reward.';
        _isLoadingRewards = false;
      });
    } catch (e) {
      print("Error fetch rewards: $e");
      if (!mounted) return;
      setState(() {
        _rewardsError = 'Gagal memuat reward: $e';
        _isLoadingRewards = false;
      });
    }
  }

  void _retryRewards() {
    setState(() {
      _isLoadingRewards = true;
      _rewardsError = null;
    });
    _fetchRewardsFromApi();
  }

  // 3. Proses penukaran poin & memunculkan Bukti Klaim (Kode Redeem/QR)
  Future<void> _handleRedeem(
    int rewardId,
    int pointsCost,
    String rewardName,
  ) async {
    final isAuthenticated = await requireAuthenticatedUser(
      context,
      message: 'Login terlebih dahulu untuk menukar reward.',
    );
    if (!mounted || !isAuthenticated) return;
    setState(() => _isProcessingRedeem = true);

    try {
      final result = await _apiService.redeemReward(rewardId: rewardId);

      if (result['status'] == true) {
        // Ambil data kode redeem atau link QR dari response backend Laravel
        String redeemCode = result['kode_redeem'] ?? 'KODE-REDEEM-OK';
        String? qrUrl = result['qr_url'];

        // Update SharedPreferences lokal dengan sisa poin terbaru dari server
        final prefs = await SharedPreferences.getInstance();
        final String? userRaw = prefs.getString('user');
        if (userRaw != null) {
          Map<String, dynamic> userData = jsonDecode(userRaw);
          userData['points'] =
              result['current_points'] ?? (_userPoints - pointsCost);
          await prefs.setString('user', jsonEncode(userData));
        }

        // Refresh poin di UI aplikasi
        await _loadUserPoints();

        // Tampilkan dialog sukses beserta kode klaim untuk diserahkan ke admin
        if (mounted) {
          _showSuccessDialog(rewardName, redeemCode, qrUrl);
        }
      } else {
        _showSnackBar(result['message'] ?? "Gagal menukarkan poin", Colors.red);
      }
    } catch (e) {
      print("Error redeem: $e");
      _showSnackBar("Terjadi kesalahan sistem penukaran", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessingRedeem = false);
    }
  }

  // Dialog sukses yang menampilkan Kode Redeem / QR sesuai tabel web admin
  void _showSuccessDialog(String rewardName, String code, String? qrUrl) {
    showAppInfoDialog(
      context,
      title: 'Penukaran Berhasil',
      message: 'Kamu berhasil menukarkan poin dengan:\n$rewardName',
      icon: Icons.check_circle_rounded,
      buttonLabel: 'Selesai',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "KODE REDEEM KAMU:",
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
              code,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Color(0xFF007A2A),
              ),
            ),
          ),
          if (qrUrl != null) ...[
            const SizedBox(height: 15),
            Image.network(
              qrUrl,
              height: 120,
              width: 120,
              errorBuilder: (c, e, s) => const Icon(Icons.qr_code, size: 100),
            ),
          ],
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PointsCategoryCard(
          points: _userPoints,
          pointsError: _pointsError,
          selectedCategory: widget.selectedCategory,
          onCategoryChanged: widget.onCategoryChanged ?? (_) {},
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                "Daftar Reward",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            IconButton(
              tooltip: 'Refresh poin dan reward',
              onPressed: _refreshPage,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00A32A)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Membaca data dinamis dari Admin Web Laravel
        _isLoadingRewards
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Color(0xFF00A32A)),
                ),
              )
            : _rewardsError != null
            ? Column(
                children: [
                  Text(_rewardsError!, textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: _retryRewards,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              )
            : _rewards.isEmpty
            ? const Center(child: Text("Tidak ada reward aktif saat ini."))
            : SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _rewards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _rewards[index];

                    // Pastikan penamaan key JSON sesuai dengan response API Laravel kamu
                    // Contoh: item['poin'] atau item['points_required']
                    return _rewardTile(
                      id: item['id'] ?? 0,
                      title: item['name'] ?? item['title'] ?? '',
                      costValue: item['points'] ?? item['points_required'] ?? 0,
                      imagePath:
                          item['image_url'], // jika admin mengirim url image dari public/storage
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _rewardTile({
    required int id,
    required String title,
    required int costValue,
    String? imagePath,
  }) {
    final canRedeem = _isGuest || _userPoints >= costValue;

    return SizedBox(
      width: 185,
      height: 178,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imagePath != null
                        ? Image.network(
                            imagePath,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _fallbackIcon(title),
                          )
                        : _fallbackIcon(title),
                  ),
                  const Spacer(),
                  Text(
                    "$costValue Poin",
                    style: const TextStyle(
                      color: Color(0xFF00A32A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (canRedeem && !_isProcessingRedeem)
                      ? () => _handleRedeem(id, costValue, title)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A32A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                      : const Text(
                          "Tukar",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Jika URL Gambar dari backend kosong, otomatis pakai icon penunjang berdasarkan judul di Admin
  Widget _fallbackIcon(String title) {
    IconData icon = Icons.card_giftcard;
    if (title.toLowerCase().contains('minuman')) {
      icon = Icons.local_drink;
    } else if (title.toLowerCase().contains('diskon') ||
        title.toLowerCase().contains('%')) {
      icon = Icons.confirmation_number_outlined;
    } else if (title.toLowerCase().contains('jam') ||
        title.toLowerCase().contains('sewa')) {
      icon = Icons.access_time_filled;
    }

    return Container(
      width: 50,
      height: 50,
      color: Colors.green.withOpacity(0.1),
      child: Icon(icon, color: const Color(0xFF00A32A)),
    );
  }
}
