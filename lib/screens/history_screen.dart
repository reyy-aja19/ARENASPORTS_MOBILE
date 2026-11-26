import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/match_api.dart';
import '../services/rating_api.dart';
import '../services/session_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_network_image.dart';
import '../widgets/guest_access_overlay.dart';
import '../widgets/photo_gallery_screen.dart';
import 'payment_screen.dart';
import 'ticket_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<BookingModel>> _historyFuture;
  bool _isGuest = true;
  bool _isCheckingSession = true;
  bool _isRefreshing = false;
  DateTime? _lastRefreshAt;
  Timer? _statusTicker;
  String _statusFilter = 'semua';

  @override
  void initState() {
    super.initState();
    _historyFuture = Future.value(const <BookingModel>[]);
    _loadSession();

    MatchApi.dataRevision.addListener(_onMatchDataChanged);
    SessionService.authRevision.addListener(_onSessionChanged);

    _statusTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _isGuest) return;
      setState(() {});
    });
  }

  void _onMatchDataChanged() {
    if (!mounted || _isGuest) return;
    _refreshData(force: true);
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _handleSessionChange();
  }

  Future<void> _handleSessionChange() async {
    final loggedIn = await SessionService.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      setState(() {
        _isGuest = true;
        _isCheckingSession = false;
      });
      return;
    }
    if (_isGuest) {
      setState(() {
        _isGuest = false;
        _isCheckingSession = false;
      });
    }
    _refreshData(force: true);
  }

  @override
  void dispose() {
    MatchApi.dataRevision.removeListener(_onMatchDataChanged);
    SessionService.authRevision.removeListener(_onSessionChanged);
    _statusTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final loggedIn = await SessionService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isGuest = !loggedIn;
      _isCheckingSession = false;
      if (loggedIn) _historyFuture = ApiService.instance.bookings();
    });
  }

  Future<void> _refreshData({bool force = false}) async {
    if (_isGuest || _isRefreshing) return;
    final now = DateTime.now();
    final last = _lastRefreshAt;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _isRefreshing = true;
    _lastRefreshAt = now;
    try {
      final future = ApiService.instance.bookings();
      if (mounted) {
        setState(() {
          _historyFuture = future;
        });
      }
      await future;
    } catch (_) {
      // Error ditampilkan oleh FutureBuilder. Jangan retry otomatis agar
      // tidak memperparah rate limit.
    } finally {
      _isRefreshing = false;
    }
  }

  List<BookingModel> _filteredBookings(List<BookingModel> all) {
    if (_statusFilter == 'semua') return all;
    return all.where((b) {
      final s = b.effectiveStatus.toLowerCase();
      switch (_statusFilter) {
        case 'menunggu':
          return s == 'menunggu' || s == 'dp' || s == 'pending';
        case 'lunas':
          return s == 'lunas' ||
              s == 'settlement' ||
              s == 'capture' ||
              s == 'success' ||
              s == 'paid';
        case 'selesai':
          return s == 'selesai' || s == 'completed';
        case 'dibatalkan':
          return s == 'dibatalkan' ||
              s == 'batal' ||
              s == 'expired' ||
              s == 'cancelled';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('semua', 'Semua'),
      ('menunggu', 'Menunggu'),
      ('lunas', 'Lunas'),
      ('selesai', 'Selesai'),
      ('dibatalkan', 'Dibatalkan'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Booking Saya"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _isGuest ? null : () => _refreshData(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isCheckingSession
          ? const Center(child: CircularProgressIndicator())
          : GuestAccessOverlay(
              isGuest: _isGuest,
              message: 'Login untuk melihat booking kamu.',
              child: FutureBuilder<List<BookingModel>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              error is ApiException
                                  ? error.message
                                  : 'Gagal memuat data: $error',
                              textAlign: TextAlign.center,
                            ),
                            TextButton.icon(
                              onPressed: () => _refreshData(force: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final all = snapshot.data ?? const <BookingModel>[];
                  final filtered = _filteredBookings(all);
                  return Column(
                    children: [
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (_, i) {
                            final f = filters[i];
                            final selected = _statusFilter == f.$1;
                            return ChoiceChip(
                              label: Text(f.$2),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = f.$1),
                              selectedColor: const Color(0xFF00A32A),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFF00A32A)
                                    : Colors.grey.shade300,
                              ),
                            );
                          },
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemCount: filters.length,
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  all.isEmpty
                                      ? "Belum ada data booking, booking sekarang!!"
                                      : "Tidak ada booking dengan status ini.",
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _refreshData(force: true),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) =>
                                      _historyCard(filtered[i]),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Color _statusColor(BookingModel booking) {
    switch (booking.effectiveStatus.toLowerCase()) {
      case 'menunggu':
        return Colors.orange;
      case 'dp':
        return Colors.amber;
      case 'lunas':
        return const Color(0xFF00A32A);
      case 'selesai':
        return Colors.blueGrey;
      case 'dibatalkan':
      case 'batal':
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _historyCard(BookingModel booking) {
    final statusColor = _statusColor(booking);
    final status = booking.effectiveStatus.toLowerCase();
    final canPay =
        booking.isActive &&
        booking.paymentMethod.toLowerCase() == 'midtrans' &&
        status != 'lunas';
    final canCancel =
        booking.isActive &&
        !booking.isCancelled &&
        const {'menunggu', 'dp', 'pending'}.contains(status);
    final images = booking.galleryImages;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2D22).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EE),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.stadium_outlined,
                    color: Color(0xFF00A32A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.venueName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E2A2B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.courtName,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (images.isNotEmpty) _buildBookingPhotos(booking, images),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine(
                  Icons.confirmation_number_outlined,
                  'Kode Booking',
                  '#${booking.id}',
                ),
                _infoLine(
                  Icons.calendar_month_outlined,
                  'Tanggal',
                  booking.bookingDate,
                ),
                _infoLine(
                  Icons.schedule_rounded,
                  'Waktu',
                  '${booking.timeLabel} (${booking.hours} jam)',
                ),
                _infoLine(
                  Icons.payments_outlined,
                  'Total',
                  'Rp ${booking.totalPrice}',
                ),
                _infoLine(
                  Icons.credit_card_outlined,
                  'Pembayaran',
                  booking.paymentMethod,
                ),
                if (booking.venueAddress.isNotEmpty)
                  _infoLine(
                    Icons.location_on_outlined,
                    'Venue',
                    booking.venueAddress,
                  ),
                if (booking.extensions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Perpanjangan: ${booking.extensions.map((e) => '${e.hours} jam (${e.status})').join(', ')}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (canPay) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _continuePayment(booking),
                      icon: const Icon(Icons.credit_card_rounded, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text(
                        "LANJUTKAN PEMBAYARAN",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelPayment(booking),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "BATALKAN BOOKING",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
                if (booking.isPaid) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TicketScreen(bookingId: booking.id),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00A32A),
                        side: const BorderSide(color: Color(0xFF00A32A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text(
                        "LIHAT TIKET",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                if ((booking.paymentProofUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showPaymentProof(booking.paymentProofUrl!),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1D4ED8),
                        side: const BorderSide(color: Color(0xFF1D4ED8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text(
                        "LIHAT BUKTI PEMBAYARAN",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                if (booking.openMatchId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Color(0xFF00A32A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sudah membuat Open Match',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (booking.canExtend) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _requestExtension(booking),
                      icon: const Icon(Icons.more_time_rounded, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text(
                        "PERPANJANG DURASI",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                if (booking.canReview) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _submitReview(booking),
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF59E0B),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text(
                        "BERI RATING",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                if (booking.hasReview)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sudah dirating',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingPhotos(BookingModel booking, List<String> images) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _openBookingGallery(booking, images),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  images.first,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.image_not_supported_outlined,
                  fallbackIconColor: Colors.grey,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${images.length} foto',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: () => _openBookingGallery(booking, images),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              size: 14,
                              color: Color(0xFF00A32A),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Lihat semua',
                              style: TextStyle(
                                color: Color(0xFF00A32A),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () =>
                    _openBookingGallery(booking, images, initialIndex: index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(
                    images[index],
                    width: 54,
                    height: 50,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.image_outlined,
                    fallbackIconColor: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F3E46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBookingGallery(
    BookingModel booking,
    List<String> images, {
    int initialIndex = 0,
  }) {
    PhotoGalleryScreen.open(
      context,
      images: images,
      initialIndex: initialIndex,
      title: booking.venueName,
    );
  }

  Future<void> _continuePayment(BookingModel booking) async {
    try {
      final snap = await ApiService.instance.checkoutBooking(booking.id);
      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            paymentId: snap.paymentId,
            paymentUrl: snap.redirectUrl,
            orderId: snap.orderId,
            totalPrice: booking.totalPrice.toDouble(),
            venueName: booking.courtName,
            date: booking.bookingDate,
            time: booking.timeLabel,
          ),
        ),
      );
      if (paid == true && mounted) {
        _refreshData(force: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil diverifikasi.'),
            backgroundColor: Color(0xFF00A32A),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaymentProof(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bukti Pembayaran',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: AppNetworkImage(
                  url,
                  fit: BoxFit.contain,
                  fallbackIcon: Icons.receipt_long_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelPayment(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan Booking'),
        content: Text(
          'Batalkan booking ini? Status booking akan menjadi Dibatalkan.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance.cancelBooking(booking.id);
      if (!mounted) return;
      _refreshData(force: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking di ${booking.id} dibatalkan.'),
          backgroundColor: Colors.orange,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _requestExtension(BookingModel booking) async {
    final controller = TextEditingController(text: '1');
    final hours = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Perpanjang Durasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Booking ${booking.timeLabel}. Tambah berapa jam?',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah jam (1-8)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A32A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (hours == null || hours < 1) return;

    try {
      final extension = await ApiService.instance.requestExtension(
        booking.id,
        hours: hours,
      );
      if (!mounted) return;
      final snap = await ApiService.instance.checkoutExtension(extension.id);
      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            paymentId: snap.paymentId,
            paymentUrl: snap.redirectUrl,
            orderId: snap.orderId,
            totalPrice: extension.amount.toDouble(),
            venueName: booking.courtName,
            date: booking.bookingDate,
            time: '${extension.previousEndTime} - ${extension.newEndTime}',
          ),
        ),
      );
      if (paid == true && mounted) _refreshData(force: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitReview(BookingModel booking) async {
    final result = await showAppRatingDialog(
      context,
      title: 'Beri Rating',
      message: 'Bagaimana pengalamanmu di ${booking.courtName}?',
    );
    if (result == null || !mounted) return;

    if (result.comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ulasan wajib diisi sebelum mengirim rating.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ok = await RatingApi.submit(
      fieldId: booking.court?.id ?? 0,
      bookingId: booking.id,
      rating: result.rating,
      comment: result.comment,
    );
    if (!mounted) return;
    if (ok) {
      await _refreshData(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terima kasih! Rating tersimpan.'),
          backgroundColor: Color(0xFF00A32A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating gagal disimpan.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
