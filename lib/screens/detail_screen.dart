import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/field_model.dart';
import '../models/review_model.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/photo_gallery_screen.dart';
import 'court_detail_screen.dart';

class DetailScreen extends StatefulWidget {
  final FieldModel field;

  const DetailScreen({super.key, required this.field});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final PageController _pageController;
  late FieldModel _field;
  int _currentPage = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _field = widget.field;
    _pageController = PageController();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final venue = await ApiService.instance.venueDetail(widget.field.id);
      if (!mounted) return;
      setState(() {
        _field = venue;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    }
  }

  List<String> get galleryImages => _field.allImages;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00A32A)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 46, color: Colors.red),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
              TextButton.icon(
                onPressed: _loadDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final images = galleryImages;
    final activeImageCount = images.isEmpty ? 1 : images.length;
    final courts = _field.courts;
    final courtNumbers = courts.isNotEmpty
        ? List.generate(courts.length, (index) => index + 1)
        : List.generate(_field.courtCount, (index) => index + 1);
    final firstRowCount = (courtNumbers.length + 1) ~/ 2;
    final secondRow = courtNumbers.length > firstRowCount
        ? courtNumbers.sublist(firstRowCount)
        : <int>[];

    final isOperational = _field.isOperational;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Foto Tampilan Depan Venue & Slider
              Stack(
                children: [
                  SizedBox(
                    height: 240,
                    width: double.infinity,
                    child: images.isEmpty
                        ? Container(
                            color: Colors.blueGrey[200],
                            child: Icon(
                              _field.type.toLowerCase().contains('badminton')
                                  ? Icons.sports_tennis
                                  : Icons.sports_soccer,
                              size: 50,
                              color: Colors.white70,
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _openGallery(images, index),
                              child: AppNetworkImage(
                                images[index],
                                fit: BoxFit.cover,
                                backgroundColor: Colors.blueGrey[200],
                                fallbackIcon: Icons.image,
                                fallbackIconColor: Colors.white70,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 15,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: const BackButton(color: Colors.black),
                    ),
                  ),
                  // Badge Status Operasional
                  Positioned(
                    top: 16,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOperational ? const Color(0xFF00A32A) : Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOperational ? Icons.check_circle_outline : Icons.pause_circle_outline,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _field.operationalStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_currentPage + 1}/$activeImageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (images.isNotEmpty)
                    Positioned(
                      bottom: 10,
                      left: 15,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: () => _openGallery(images, _currentPage),
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
                                  Icons.photo_library_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Lihat galeri',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Nama Venue
                    Text(
                      _field.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2A2B),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 3. Jenis Olahraga (Futsal & Badminton) & Pengelola
                    Row(
                      children: [
                        Icon(
                          _field.type.toLowerCase().contains('badminton')
                              ? Icons.sports_tennis
                              : Icons.sports_soccer,
                          color: const Color(0xFF00A32A),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_field.type} • ${_field.courtCount} Lapangan',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Informasi Pengelola (Dikelola oleh)
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Color(0xFF008C35),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dikelola oleh: ${_field.displayManager}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Informasi Perusahaan (Opsional, hanya jika tersedia)
                    if (_field.companyName != null &&
                        _field.companyName!.isNotEmpty &&
                        _field.companyName != _field.name) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Badan Usaha: ${_field.companyName!}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Alamat Venue
                    if (_field.address != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _field.address!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Jam Operasional & Hari
                    if (_field.operatingHours != null && _field.operatingHours!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jam Buka: ${_field.operatingHours!}'
                              '${_field.operatingDays.isNotEmpty ? " (${_field.operatingDays.join(', ')})" : ""}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Rating & Reviews
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final star = i + 1;
                          IconData icon;
                          if (_field.rating >= star) {
                            icon = Icons.star_rounded;
                          } else if (_field.rating >= star - 0.5) {
                            icon = Icons.star_half_rounded;
                          } else {
                            icon = Icons.star_border_rounded;
                          }
                          return Icon(
                            icon,
                            size: 18,
                            color: const Color(0xFFF59E0B),
                          );
                        }),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _field.reviewCount == 0
                                ? 'Belum ada ulasan'
                                : '${_field.rating.toStringAsFixed(1)} (${_field.reviewCount} ulasan)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // 4. Informasi / Deskripsi Venue
                    if (_field.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Informasi Venue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _field.description!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    // Fasilitas Venue
                    if (_field.fasilitas.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Fasilitas Venue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _field.fasilitas
                            .map(
                              (facility) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF7EE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  facility,
                                  style: const TextStyle(
                                    color: Color(0xFF25613C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // 5. Galeri Foto Venue (Thumbnail Slider)
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Galeri Foto Venue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openGallery(images, 0),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF00A32A),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: const Icon(Icons.open_in_full, size: 15),
                            label: Text('Lihat semua (${images.length})'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _openGallery(images, index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AppNetworkImage(
                                images[index],
                                width: 120,
                                height: 90,
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.image_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 6. Daftar Lapangan Tersedia
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pilih Lapangan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_field.price > 0)
                          Text(
                            'Mulai Rp ${_field.price}/jam',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF008C35),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (courtNumbers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Belum ada lapangan yang ditambahkan di venue ini.'),
                        ),
                      )
                    else ...[
                      _buildCourtRow(
                        courtNumbers.sublist(0, firstRowCount),
                      ),
                      if (secondRow.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildCourtRow(secondRow),
                      ],
                    ],

                    const SizedBox(height: 28),
                    _buildReviewsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourtRow(List<int> courtNumbers) {
    return SizedBox(
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        itemCount: courtNumbers.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final court = _field.courtFor(courtNumbers[index]);
          return _buildCourtCard(court);
        },
      ),
    );
  }

  Widget _buildCourtCard(CourtModel court) {
    final imageUrl = court.imageUrl ?? _field.imageUrl;
    final isOperate = court.operationalStatus.toLowerCase() == 'beroperasi';
    final canBook = court.canBeBooked;

    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE7ECE9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openCourtSchedule(court),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: AppNetworkImage(
                      imageUrl,
                      fit: BoxFit.cover,
                      fallbackIcon: _field.type.toLowerCase().contains('badminton')
                          ? Icons.sports_tennis
                          : Icons.sports_soccer,
                      fallbackIconColor: const Color(0xFF00A32A),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: !isOperate
                            ? Colors.red.shade700
                            : (canBook ? const Color(0xFF00A32A) : Colors.orange.shade700),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        !isOperate ? court.operationalStatus : (canBook ? 'Tersedia' : court.status),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (court.areaType != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          court.areaType!,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        court.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Rp ${court.minPrice > 0 ? court.minPrice : court.price} / jam',
                        style: const TextStyle(color: Color(0xFF008C35), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      if (court.floorType != null && court.floorType!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.layers_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Lantai: ${court.floorType!}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        court.description.isNotEmpty ? court.description : 'Lapangan siap digunakan.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, height: 1.3, fontSize: 11),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () => _openCourtSchedule(court),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A32A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Detail & Jadwal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = _field.reviews;
    final average = _field.averageReviewRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.forum_outlined,
              color: Color(0xFF00A32A),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ulasan & Penilaian Pemain',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Pengalaman nyata dari pemain yang pernah menyewa ${_field.name}.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF3),
            border: Border.all(color: const Color(0xFFCCE8D5)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14532D),
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStars(average, size: 15),
                  const SizedBox(height: 4),
                  Text(
                    'Berdasarkan ${reviews.length} ulasan',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7ECE9)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 38,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                Text(
                  'Belum ada ulasan untuk venue ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jadilah yang pertama memberikan penilaian setelah selesai bermain!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
          ...reviews.map(_buildReviewTile),
      ],
    );
  }

  Widget _buildReviewTile(ReviewModel review) {
    final photoUrl = ApiConfig.resolveMediaUrl(review.userPhotoUrl);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF168653),
            foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            onForegroundImageError: photoUrl == null ? null : (_, _) {},
            child: Text(
              review.initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                        review.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF163E28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      review.relativeTime,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStars(review.rating.toDouble(), size: 13),
                    const SizedBox(width: 6),
                    Text(
                      '(${review.rating}/5)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (review.message.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    review.message,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
                if (review.replyMessage != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FAF6),
                      border: const Border(
                        left: BorderSide(color: Color(0xFF168653), width: 3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tanggapan Pengelola Venue',
                          style: TextStyle(
                            color: Color(0xFF166534),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          review.replyMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        IconData icon;
        if (rating >= star) {
          icon = Icons.star_rounded;
        } else if (rating >= star - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: const Color(0xFFF59E0B));
      }),
    );
  }

  void _openGallery(List<String> images, int initialIndex) {
    PhotoGalleryScreen.open(
      context,
      images: images,
      initialIndex: initialIndex,
      title: _field.name,
    );
  }

  void _openCourtSchedule(CourtModel court) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourtDetailScreen(court: court, venue: _field),
      ),
    );
  }
}
