import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:penyewaan_lapangan/services/api_service.dart';
import 'package:penyewaan_lapangan/screens/payment_screen.dart';
import 'package:penyewaan_lapangan/services/midtrans_payment_service.dart';
import '../utils/auth_guard.dart';

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

  String paymentMethod = 'Midtrans Sandbox';

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

      if (paymentMethod == 'Midtrans Sandbox') {
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
        paymentMethod: paymentMethod,
        date: widget.tanggal,
        startTime: jamMulai,
        endTime: jamSelesai,
        totalPrice: cleanPrice,
        hours: listJam.length,
      );
      if (!mounted) return;

      if (result['status'] == true) {
        if (result['local_demo'] == true) {
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
      backgroundColor: const Color(0xFFF8F9FA),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ringkasan Pesanan",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _rowInfo("Lapangan", widget.namaLapangan),
                  const Divider(),
                  _rowInfo("Tanggal", widget.tanggal),
                  const Divider(),
                  _rowInfo("Jam", widget.jam),
                  const Divider(),
                  _rowInfo("Total", widget.harga, isPrice: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Pilih Metode Pembayaran",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            RadioGroup<String>(
              groupValue: paymentMethod,
              onChanged: (value) {
                if (value != null) setState(() => paymentMethod = value);
              },
              child: Column(
                children: [
                  const RadioListTile<String>(
                    value: 'Midtrans Sandbox',
                    title: Text('Midtrans Sandbox'),
                    subtitle: Text('Mode uji coba, tidak ada pembayaran nyata'),
                  ),
                  const RadioListTile<String>(
                    value: 'Cash',
                    title: Text('Bayar di Tempat'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handlePayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A32A),
            minimumSize: const Size(double.infinity, 55),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  paymentMethod == 'Midtrans Sandbox'
                      ? 'Lanjut ke Sandbox'
                      : 'Konfirmasi Booking',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _rowInfo(String label, String value, {bool isPrice = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPrice ? Colors.green : Colors.black,
          ),
        ),
      ],
    );
  }
}
