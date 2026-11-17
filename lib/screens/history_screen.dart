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
import 'create_match_screen.dart';
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
  Timer? _statusTicker;

  @override
  void initState() {
    super.initState();
    _historyFuture = Future.value(const <BookingModel>[]);
    _loadSession();

    MatchApi.dataRevision.addListener(_onMatchDataChanged);
    SessionService.revision.addListener(_onSessionChanged);

    _statusTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isGuest) return;
      setState(() {});
    });
  }

  void _onMatchDataChanged() {
    if (!mounted || _isGuest) return;
    _refreshData();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _loadSession();
  }

  @override
  void dispose() {
    MatchApi.dataRevision.removeListener(_onMatchDataChanged);
    SessionService.revision.removeListener(_onSessionChanged);
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

  Future<void> _refreshData() async {
    if (_isGuest) return;
    setState(() {
      _historyFuture = ApiService.instance.bookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Riwayat Sewa"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              onPressed: _isGuest ? null : _refreshData,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Aktif"),
              Tab(text: "Selesai"),
            ],
          ),
        ),
        body: _isCheckingSession
            ? const Center(child: CircularProgressIndicator())
            : GuestAccessOverlay(
                isGuest: _isGuest,
                message: 'Login untuk melihat riwayat sewa.',
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
                                onPressed: _refreshData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final all = snapshot.data ?? const <BookingModel>[];
                    if (all.isEmpty) {
                      return const Center(
                        child: Text(
                          "Belum ada data booking, booking sekarang!!",
                        ),
                      );
                    }

                    final active = all.where((b) => b.isActive).toList();
                    final done = all.where((b) => !b.isActive).toList();

                    return TabBarView(
                      children: [_buildList(active), _buildList(done)],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildList(List<BookingModel> bookings) {
    if (bookings.isEmpty) {
      return const Center(child: Text("Tidak ada transaksi di kategori ini."));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, i) => _historyCard(bookings[i]),
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
        return Colors.green;
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
    final canPay = booking.isActive &&
        booking.paymentMethod.toLowerCase() == 'midtrans' &&
        booking.effectiveStatus.toLowerCase() != 'lunas';
    final images = booking.galleryImages;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                if (canPay)
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
                if (booking.canCreateMatch) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateMatchScreen(booking: booking),
                          ),
                        );
                        if (created == true && mounted) _refreshData();
                      },
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A32A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text(
                        "BUAT OPEN MATCH",
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
                              color: Color(0xFF25613C),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Lihat semua',
                              style: TextStyle(
                                color: Color(0xFF25613C),
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
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil diverifikasi.'),
            backgroundColor: Colors.green,
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
      if (paid == true && mounted) _refreshData();
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
      await _refreshData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terima kasih! Rating tersimpan.'),
          backgroundColor: Colors.green,
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
