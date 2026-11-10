import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:penyewaan_lapangan/services/api_service.dart';
import 'package:penyewaan_lapangan/screens/payment_screen.dart';
import 'package:penyewaan_lapangan/services/midtrans_payment_service.dart';
import '../services/push_notification_service.dart';
import '../utils/auth_guard.dart';
import '../widgets/top_banner.dart';

class CheckoutScreen extends StatefulWidget {
  final int lapanganId;
  final String namaLapangan;
  final String tanggal;
  final String jam;
  final String harga;

  const CheckoutScreen({
    super.key,
    required this.lapanganId,
    required this.namaLapangan,
    required this.tanggal,
    required this.jam,
    required this.harga,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;

  // 'Midtrans' = pembayaran online via Midtrans, 'Cash' = bayar di tempat.
  String paymentMethod = 'Midtrans';

  String get _jamTampil => widget.jam
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .join('  •  ');

  int get _durasiJam => widget.jam
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .length;

  Future<void> _handlePayment() async {
    if (!await requireAuthenticatedUser(context) || !mounted) return;
    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final userRaw = prefs.getString('user');
      final currentUser = userRaw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(userRaw));
      final userId = currentUser['id'] as int? ?? 0;
      final cleanPrice =
          double.tryParse(widget.harga.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final listJam = widget.jam
          .split(',')
          .map((time) => time.trim())
          .where((time) => time.isNotEmpty)
          .toList();

      if (listJam.isEmpty) throw Exception('Jam tidak valid');

      final jamMulai = listJam.first;
      final jamTerakhir = listJam.last;
      final hourEnd = int.parse(jamTerakhir.split(':').first);
      final jamSelesai = '${(hourEnd + 1).toString().padLeft(2, '0')}:00';

      if (paymentMethod == 'Midtrans') {
        final transaction = await MidtransPaymentService().createTransaction(
          amount: cleanPrice.round(),
          itemName: widget.namaLapangan,
          customerName: currentUser['name']?.toString() ?? 'Pelanggan',
          customerEmail: currentUser['email']?.toString() ?? '',
        );
        if (!mounted) return;

        final paymentResult = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              paymentUrl: transaction.redirectUrl,
              orderId: transaction.orderId,
              totalPrice: cleanPrice,
              venueName: widget.namaLapangan,
              date: widget.tanggal,
              time: widget.jam,
            ),
          ),
        );

        if (paymentResult != true || !mounted) return;
      }

      final result = await apiService.postBooking(
        userId: userId,
        lapanganId: widget.lapanganId,
        fieldName: widget.namaLapangan,
        paymentMethod: paymentMethod,
        date: widget.tanggal,
        startTime: jamMulai,
        endTime: jamSelesai,
        totalPrice: cleanPrice,
        hours: listJam.length,
      );
      if (!mounted) return;

      if (result['status'] == true) {
        if (paymentMethod == 'Midtrans') {
          showTopBanner(
            context,
            title: 'Pembayaran Berhasil',
            message:
                '${widget.namaLapangan} • ${widget.tanggal} • ${widget.jam}',
            icon: Icons.check_circle_rounded,
          );
          PushNotificationService.showLocalNotification(
            title: 'Pembayaran Berhasil',
            body: '${widget.namaLapangan} • ${widget.tanggal} • ${widget.jam}',
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                venueName: widget.namaLapangan,
                date: widget.tanggal,
                time: widget.jam,
                totalPrice: cleanPrice,
              ),
            ),
            (route) => false,
          );
          return;
        }

        if (result['local_demo'] == true) {
          showTopBanner(
            context,
            title: 'Booking Berhasil',
            message:
                '${widget.namaLapangan} • ${widget.tanggal} • ${widget.jam}',
            icon: Icons.check_circle_rounded,
          );
          PushNotificationService.showLocalNotification(
            title: 'Booking Berhasil',
            body: '${widget.namaLapangan} • ${widget.tanggal} • ${widget.jam}',
          );
          _showSnackBar(
            '${result['message']} +${result['current_points']} poin.',
            Colors.green,
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/history',
            (route) => route.isFirst,
          );
          return;
        }

        showTopBanner(
          context,
          title: 'Booking Berhasil',
          message: '${widget.namaLapangan} • ${widget.tanggal} • ${widget.jam}',
          icon: Icons.check_circle_rounded,
        );
        PushNotificationService.showLocalNotification(
          title: 'Booking Berhasil',
          body: '${widget.namaLapangan} • ${widget.tanggal} • ${widget.jam}',
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/history',
          (route) => route.isFirst,
        );
      } else {
        _showSnackBar("Gagal: ${result['message']}", Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Pembayaran atau booking gagal: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Konfirmasi Pesanan",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Ringkasan Pesanan ---
            _sectionTitle("Ringkasan Pesanan", Icons.receipt_long_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _summaryRow(
                    Icons.sports_soccer_outlined,
                    "Lapangan",
                    widget.namaLapangan,
                  ),
                  _divider(),
                  _summaryRow(
                    Icons.calendar_today_outlined,
                    "Tanggal",
                    widget.tanggal,
                  ),
                  _divider(),
                  _summaryRow(Icons.access_time_outlined, "Jam", _jamTampil),
                  _divider(),
                  _summaryRow(
                    Icons.timelapse_outlined,
                    "Durasi",
                    "$_durasiJam jam",
                  ),
                  _divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            size: 16,
                            color: Color(0xFF00A32A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Total Pembayaran",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E2A2B),
                            ),
                          ),
                        ),
                        Text(
                          widget.harga,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A32A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Metode Pembayaran ---
            _sectionTitle(
              "Metode Pembayaran",
              Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 12),
            _paymentOption(
              value: 'Midtrans',
              title: 'Midtrans',
              subtitle: 'Pembayaran online (QRIS, transfer, e-wallet)',
              icon: Icons.credit_card_rounded,
              accent: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 10),
            _paymentOption(
              value: 'Cash',
              title: 'Bayar di Tempat',
              subtitle: 'Bayar langsung saat datang ke venue',
              icon: Icons.storefront_outlined,
              accent: const Color(0xFF00A32A),
            ),

            const SizedBox(height: 16),

            // --- Catatan keamanan ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Color(0xFF00A32A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Transaksi aman dan terenkripsi. Pilih metode pembayaran yang kamu inginkan.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handlePayment,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      paymentMethod == 'Midtrans'
                          ? Icons.credit_card_rounded
                          : Icons.storefront_outlined,
                      size: 20,
                    ),
              label: Text(
                _isLoading
                    ? 'Memproses...'
                    : (paymentMethod == 'Midtrans'
                          ? 'Lanjut ke Pembayaran'
                          : 'Konfirmasi Booking'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A32A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00A32A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1E2A2B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFEEF2EF));

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF00A32A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2A2B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final selected = paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => paymentMethod = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade200,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E2A2B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Indikator pilihan (custom, tidak pakai Radio widget yang deprecated).
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
