import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/midtrans_payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final double totalPrice;
  final String venueName;
  final String date;
  final String time;

  const PaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    required this.totalPrice,
    required this.venueName,
    required this.date,
    required this.time,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _isFetchingStatus = false;
  bool _paymentCompleted = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            // Begitu halaman Snap selesai dimuat (termasuk halaman sukses),
            // cek status tanpa menunggu user menekan tombol apa pun.
            _checkPaymentStatus(silent: true);
          },
          onUrlChange: (change) {
            final url = change.url?.toLowerCase() ?? '';
            final looksPaid =
                url.contains('status_code=200') ||
                url.contains('transaction_status=settlement') ||
                url.contains('transaction_status=capture') ||
                url.contains('/finish');
            if (looksPaid) _checkPaymentStatus(silent: true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));

    // Jaring pengaman: kalau halaman sukses tidak memicu navigasi apa pun,
    // status tetap dicek otomatis setiap 3 detik sampai pembayaran terdeteksi.
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkPaymentStatus(silent: true);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_paymentCompleted || _isFetchingStatus) return;

    _isFetchingStatus = true;
    if (!silent) setState(() => _isCheckingStatus = true);

    try {
      final status = await MidtransPaymentService().checkStatus(widget.orderId);
      if (!mounted || _paymentCompleted) return;

      if (status.isPaid) {
        _paymentCompleted = true;
        _statusTimer?.cancel();
        // Langsung kembali ke checkout; checkout akan menyimpan booking lalu
        // menampilkan layar "Pembayaran Berhasil" secara otomatis.
        Navigator.pop(context, true);
        return;
      }

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pembayaran belum selesai (${status.transactionStatus}). '
              'Selesaikan pembayaran lalu tunggu sebentar.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa pembayaran: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isFetchingStatus = false;
      if (mounted && !silent) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pembayaran Midtrans',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A32A)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.venueName} • ${widget.date} • ${widget.time}\n'
                '${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(widget.totalPrice)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00A32A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Status pembayaran dicek otomatis. '
                      'Notifikasi berhasil akan muncul sendiri.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isCheckingStatus
                      ? null
                      : () => _checkPaymentStatus(),
                  icon: _isCheckingStatus
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isCheckingStatus
                        ? 'Memeriksa status...'
                        : 'Cek Ulang Status',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A32A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.venueName,
    required this.date,
    required this.time,
    required this.totalPrice,
  });

  final String venueName;
  final String date;
  final String time;
  final double totalPrice;

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 1, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(widget.totalPrice);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = Curves.easeOutBack.transform(
                    _controller.value.clamp(0, 1),
                  );
                  return Transform.scale(scale: progress, child: child);
                },
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A32A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A32A).withValues(alpha: 0.2),
                        blurRadius: 28,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: _SuccessCheckPainter(
                        progress: Curves.easeInOutCubic.transform(
                          ((_controller.value - 0.2) / 0.55).clamp(0, 1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 38),
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(
                    children: [
                      const Text(
                        'Pembayaran Berhasil!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF163B29),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pembayaran sudah terverifikasi dan booking kamu selesai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        widget.venueName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.date} • ${widget.time}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        amount,
                        style: const TextStyle(
                          color: Color(0xFF00A32A),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Kembali ke Beranda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A32A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final checkPath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.7)
      ..lineTo(size.width * 0.76, size.height * 0.34);
    final metrics = checkPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final animatedPath = metrics.first.extractPath(
      0,
      metrics.first.length * progress,
    );
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(animatedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
