import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../models/field_model.dart';
import '../models/review_model.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../utils/auth_guard.dart';
import '../widgets/app_network_image.dart';
import '../widgets/photo_gallery_screen.dart';
import 'checkout_screen.dart';

/// Detail satu lapangan sebelum booking, mengikuti halaman `court-detail`
/// pada web: galeri, informasi lapangan, fasilitas, ulasan, lalu pilihan
/// tanggal serta jam mulai sampai jam selesai.
class CourtDetailScreen extends StatefulWidget {
  final CourtModel court;
  final FieldModel venue;

  const CourtDetailScreen({
    super.key,
    required this.court,
    required this.venue,
  });

  @override
  State<CourtDetailScreen> createState() => _CourtDetailScreenState();
}

class _CourtDetailScreenState extends State<CourtDetailScreen> {
  static const int _maxHours = 8;
  static const Color _green = Color(0xFF00A32A);
  static const Color _dark = Color(0xFF1E2A2B);
  static const Color _background = Color(0xFFF5F7FA);

  late final CourtModel _court = widget.court;
  late final FieldModel _venue = widget.venue;
  final PageController _pageController = PageController();

  DateTime _selectedDate = DateTime.now();
  int _photoIndex = 0;

  AvailabilityData? _availability;
  bool _loadingSlots = true;
  String? _slotsError;

  String? _startTime;
  int _selectedHours = 1;

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _images {
    final images = _court.allImages;
    return images.isEmpty ? _venue.allImages : images;
  }

  List<AvailabilitySlot> get _slots => _availability?.slots ?? const [];

  String get _closing => _availability?.closing ?? '23:00';

  int get _pricePerHour {
    final price = _availability?.price ?? 0;
    return price > 0 ? price : _court.price;
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatRupiah(int value) =>
      'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';

  bool _isPastSlot(String startTime) {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    if (!isToday) return false;

    final minutes = _toMinutes(startTime);
    final slotTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).add(Duration(minutes: minutes));
    return !slotTime.isAfter(now);
  }

  /// Durasi yang mungkin dari jam mulai terpilih: harus melewati slot-slot
  /// yang masih kosong secara berurutan dan tidak melewati jam tutup.
  List<int> _endHourOptionsFor(String startTime) {
    final slots = _slots;
    final startIndex = slots.indexWhere((slot) => slot.startTime == startTime);
    if (startIndex < 0) return const [];

    final closing = _toMinutes(_closing);
    final options = <int>[];

    for (var hours = 1; hours <= _maxHours; hours++) {
      final endIndex = startIndex + hours - 1;
      if (endIndex >= slots.length) break;

      final slot = slots[endIndex];
      if (!slot.available || _isPastSlot(slot.startTime)) break;

      final endMinutes = _toMinutes(slot.endTime);
      if (endMinutes > closing) break;

      options.add(hours);
    }

    return options;
  }

  int? get _effectiveHours {
    final start = _startTime;
    if (start == null) return null;
    final options = _endHourOptionsFor(start);
    if (options.isEmpty) return null;
    if (options.contains(_selectedHours)) return _selectedHours;
    return options.first;
  }

  String? get _endTime {
    final start = _startTime;
    final hours = _effectiveHours;
    if (start == null || hours == null) return null;
    return _formatMinutes(_toMinutes(start) + hours * 60);
  }

  Future<void> _fetchSlots() async {
    if (!mounted) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
      _startTime = null;
      _selectedHours = 1;
    });

    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await ApiService.instance.availability(_court.id, date);
      if (!mounted) return;
      setState(() {
        _availability = data;
        _loadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _slotsError = e.message;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _fetchSlots();
  }

  void _selectStart(int index) {
    final slot = _slots[index];
    if (!slot.available || _isPastSlot(slot.startTime)) return;

    setState(() {
      _startTime = slot.startTime;
      final options = _endHourOptionsFor(slot.startTime);
      _selectedHours = options.isEmpty
          ? 1
          : (options.contains(_selectedHours) ? _selectedHours : options.first);
    });
  }

  Future<void> _continueToCheckout() async {
    final start = _startTime;
    final hours = _effectiveHours;
    final end = _endTime;

    if (start == null || hours == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih jam mulai dan jam selesai terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!await requireAuthenticatedUser(context) || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          lapanganId: _court.id,
          namaLapangan: '${_venue.name} • ${_court.displayName}',
          tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
          jam: '$start - $end',
          jamMulai: start,
          durasiJam: hours,
          harga: _formatRupiah(_pricePerHour * hours),
        ),
      ),
    );
  }

  void _openGallery(int index) {
    final images = _images;
    if (images.isEmpty) return;
    PhotoGalleryScreen.open(
      context,
      images: images,
      initialIndex: index,
      title: _court.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Detail Lapangan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            tooltip: 'Muat ulang jadwal',
            onPressed: _loadingSlots ? null : _fetchSlots,
            icon: const Icon(Icons.refresh, color: _green),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _buildGallery(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildFacilitiesCard(),
                const SizedBox(height: 16),
                _buildBookingCard(),
                const SizedBox(height: 16),
                _buildReviewsCard(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildGallery() {
    final images = _images;
    if (images.isEmpty) {
      return Container(
        height: 220,
        color: const Color(0xFFEAF2ED),
        alignment: Alignment.center,
        child: Icon(
          _isBadminton ? Icons.sports_tennis_rounded : Icons.sports_soccer_rounded,
          size: 64,
          color: _green,
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _photoIndex = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openGallery(index),
                child: AppNetworkImage(
                  images[index],
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.stadium_outlined,
                ),
              );
            },
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_photoIndex + 1}/${images.length} foto',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => _openGallery(_photoIndex),
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen_rounded,
                        size: 15,
                        color: Color(0xFF25613C),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Lihat semua',
                        style: TextStyle(
                          color: Color(0xFF25613C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final active = index == _photoIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  bool get _isBadminton =>
      '${_court.type} ${_venue.type}'.toLowerCase().contains('badminton');

  Widget _buildInfoCard() {
    final rating = _court.rating > 0 ? _court.rating : _venue.rating;
    final reviewCount = _court.reviewCount > 0
        ? _court.reviewCount
        : _venue.reviewCount;
    final venueName = _court.venueName ?? _venue.name;
    final venueAddress = _court.venueAddress ?? _venue.address;
    final hasVenue = venueName.trim().isNotEmpty;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip(_court.type, background: const Color(0xFFEAF7EE)),
              const SizedBox(width: 8),
              _chip(
                _court.status,
                background: _court.status.toLowerCase() == 'tersedia'
                    ? const Color(0xFFEAF7EE)
                    : const Color(0xFFFFF4E5),
                foreground: _court.status.toLowerCase() == 'tersedia'
                    ? const Color(0xFF008C35)
                    : const Color(0xFFB45309),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 4),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : '-',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              if (reviewCount > 0)
                Text(
                  ' ($reviewCount)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _court.displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(_pricePerHour),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _green,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ jam',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          if (hasVenue) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCE8D5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.stadium_outlined,
                    size: 18,
                    color: Color(0xFF14532D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venueName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        if (venueAddress != null &&
                            venueAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            venueAddress,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _court.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesCard() {
    if (_court.facilities.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Fasilitas Lapangan', Icons.checklist_rounded),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _court.facilities
                .map(
                  (facility) => _chip(
                    facility,
                    background: const Color(0xFFF0FAF3),
                    foreground: const Color(0xFF14532D),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Pilih Jadwal Bermain', Icons.event_available_rounded),
          const SizedBox(height: 4),
          Text(
            'Pilih tanggal, lalu jam mulai dan jam selesai bermain.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _loadingSlots ? null : _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCE8D5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 17, color: _green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF14532D),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Jam Mulai',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildSlotGrid(),
          const SizedBox(height: 16),
          const Text(
            'Jam Selesai',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildEndTimePicker(),
          if (_startTime != null && _effectiveHours != null) ...[
            const SizedBox(height: 16),
            _buildSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: _green),
          ),
        ),
      );
    }

    if (_slotsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _slotsError!,
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
          TextButton.icon(
            onPressed: _fetchSlots,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba lagi'),
          ),
        ],
      );
    }

    if (_slots.isEmpty) {
      return Text(
        'Tidak ada jadwal pada tanggal ini. Coba pilih tanggal lain.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      );
    }

    final startIndex = _startTime == null
        ? -1
        : _slots.indexWhere((slot) => slot.startTime == _startTime);
    final hours = _effectiveHours ?? 0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2.05,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final slot = _slots[index];
        final booked = !slot.available;
        final past = _isPastSlot(slot.startTime);
        final selected = index == startIndex;
        final inRange =
            startIndex >= 0 && hours > 0 && index > startIndex && index < startIndex + hours;

        Color border;
        Color background;
        Color foreground;

        if (booked) {
          border = const Color(0xFFDC2626);
          background = const Color(0xFFFEE2E2);
          foreground = const Color(0xFF991B1B);
        } else if (past) {
          border = const Color(0xFFD1D5DB);
          background = const Color(0xFFF3F4F6);
          foreground = const Color(0xFF9CA3AF);
        } else if (selected || inRange) {
          border = const Color(0xFF15803D);
          background = const Color(0xFFBBF7D0);
          foreground = const Color(0xFF14532D);
        } else {
          border = const Color(0xFF16A34A);
          background = const Color(0xFFDCFCE7);
          foreground = const Color(0xFF166534);
        }

        return Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: border,
              width: selected ? 2.2 : 1,
            ),
          ),
          child: InkWell(
            onTap: booked || past ? null : () => _selectStart(index),
            borderRadius: BorderRadius.circular(9),
            child: Center(
              child: Text(
                slot.startTime,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEndTimePicker() {
    final start = _startTime;
    if (start == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7ECE9)),
        ),
        child: Text(
          'Pilih jam mulai terlebih dahulu.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }

    final options = _endHourOptionsFor(start);
    if (options.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5D9AE)),
        ),
        child: Text(
          'Tidak ada jam selesai yang tersedia dari jam mulai ini.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
        ),
      );
    }

    final value = _effectiveHours;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF14532D),
          ),
          items: options.map((hours) {
            final endTime = _formatMinutes(_toMinutes(start) + hours * 60);
            return DropdownMenuItem<int>(
              value: hours,
              child: Text(
                '$endTime ($hours jam)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (hours) {
            if (hours == null) return;
            setState(() => _selectedHours = hours);
          },
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final hours = _effectiveHours ?? 1;
    final total = _pricePerHour * hours;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FAF3), Color(0xFFE4F6EA)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCE8D5)),
      ),
      child: Column(
        children: [
          _summaryRow(
            'Jam bermain',
            '$_startTime - $_endTime ($hours jam)',
          ),
          const SizedBox(height: 8),
          _summaryRow(
            'Total',
            _formatRupiah(total),
            valueColor: _green,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: bold ? 15 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? _dark,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsCard() {
    final reviews = _court.reviews;
    final average = _court.rating > 0
        ? _court.rating
        : (reviews.isEmpty
              ? 0.0
              : reviews.fold<int>(0, (sum, item) => sum + item.rating) /
                    reviews.length);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Ulasan Pemain', Icons.forum_outlined),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            Text(
              'Belum ada ulasan untuk lapangan ini.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            )
          else ...[
            Row(
              children: [
                Text(
                  average.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14532D),
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStars(average, size: 14),
                    const SizedBox(height: 3),
                    Text(
                      '${reviews.length} ulasan pemain',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...reviews.take(4).map(_buildReviewTile),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewTile(ReviewModel review) {
    final photoUrl = ApiConfig.resolveMediaUrl(review.userPhotoUrl);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFF168653),
                foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
                onForegroundImageError: photoUrl == null ? null : (_, _) {},
                child: Text(
                  review.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  review.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
              Text(
                review.relativeTime,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _buildStars(review.rating.toDouble(), size: 12),
          if (review.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.message,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.grey.shade800,
              ),
            ),
          ],
          if (review.replyMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF3),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'Balasan pengelola: ${review.replyMessage}',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStars(double value, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final IconData icon;
        if (value >= star) {
          icon = Icons.star_rounded;
        } else if (value >= star - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: const Color(0xFFF59E0B));
      }),
    );
  }

  Widget _buildBottomBar() {
    final ready = _startTime != null && _effectiveHours != null;
    final total = _pricePerHour * (_effectiveHours ?? 1);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ready ? 'Total ${_effectiveHours!} jam' : 'Belum ada jadwal',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready ? _formatRupiah(total) : _formatRupiah(0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: ready ? _continueToCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5D0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 0,
                ),
                child: const Text(
                  'Lanjut Booking',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(
    String text, {
    Color background = const Color(0xFFEAF7EE),
    Color foreground = const Color(0xFF008C35),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
