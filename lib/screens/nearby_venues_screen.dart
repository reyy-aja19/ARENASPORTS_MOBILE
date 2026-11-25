import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/field_model.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/photo_gallery_screen.dart';
import 'detail_screen.dart';

/// Daftar venue di sekitar pengguna, diurutkan berdasarkan jarak GPS.
class NearbyVenuesScreen extends StatefulWidget {
  const NearbyVenuesScreen({super.key});

  @override
  State<NearbyVenuesScreen> createState() => _NearbyVenuesScreenState();
}

class _NearbyVenuesScreenState extends State<NearbyVenuesScreen> {
  static const Color _green = Color(0xFF00A32A);
  static const Color _dark = Color(0xFF1E2A2B);
  static const Color _background = Color(0xFFF5F7FA);

  Position? _position;
  String? _locationName;
  String? _locationError;
  bool _loadingLocation = true;

  List<FieldModel> _venues = const [];
  bool _loadingVenues = false;
  String? _venuesError;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;

      // Tampilkan posisi secepatnya supaya indikator lokasi berhenti.
      // Nama daerah diresolusi terpisah karena geocoding bisa lambat.
      setState(() {
        _position = position;
        _locationName = null;
        _loadingLocation = false;
      });

      unawaited(_loadVenues());
      unawaited(_resolveLocationName(position));
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError = e.message;
      });
    }
  }

  Future<void> _resolveLocationName(Position position) async {
    final name = await LocationService.describe(position);
    if (!mounted) return;
    setState(() => _locationName = name);
  }

  Future<void> _loadVenues() async {
    setState(() {
      _loadingVenues = true;
      _venuesError = null;
    });

    try {
      final venues = List<FieldModel>.from(
        await ApiService.instance.venues(
          lat: _position?.latitude,
          lng: _position?.longitude,
        ),
      );
      if (!mounted) return;

      venues.sort((a, b) {
        final distanceA = _distanceTo(a);
        final distanceB = _distanceTo(b);
        if (distanceA == null) return distanceB == null ? 0 : 1;
        if (distanceB == null) return -1;
        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _venues = venues;
        _loadingVenues = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVenues = false;
        _venuesError = e.message;
      });
    }
  }

  double? _distanceTo(FieldModel venue) {
    if (venue.distanceKm != null) return venue.distanceKm;
    final position = _position;
    final latitude = venue.latitude;
    final longitude = venue.longitude;
    if (position == null ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite) {
      return null;
    }
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        ) /
        1000;
  }

  String _distanceLabel(FieldModel venue) {
    final distance = _distanceTo(venue);
    if (distance == null) return 'Jarak belum tersedia';
    if (distance < 1) return '${(distance * 1000).round()} m dari kamu';
    return '${distance.toStringAsFixed(1)} km dari kamu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Venue Terdekat'),
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        actions: [
          IconButton(
            tooltip: 'Perbarui lokasi',
            onPressed: _loadingLocation ? null : _detectLocation,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _green,
          onRefresh: _detectLocation,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildLocationCard(),
              const SizedBox(height: 18),
              if (_loadingLocation)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: _green),
                  ),
                )
              else if (_locationError != null)
                _buildLocationError()
              else ...[
                _buildSectionHeader(),
                const SizedBox(height: 12),
                if (_loadingVenues)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: _green),
                    ),
                  )
                else if (_venuesError != null)
                  _buildVenuesError()
                else if (_venues.isEmpty)
                  _buildEmptyVenues()
                else
                  ..._venues.map(_buildVenueCard),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final position = _position;
    final subtitle = _loadingLocation
        ? 'Mendeteksi lokasi kamu...'
        : _locationError ??
              (_locationName ?? 'Lokasi ditemukan, nama daerah tidak tersedia');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF7EE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _locationError == null
                  ? Icons.near_me_rounded
                  : Icons.location_off_outlined,
              color: _locationError == null ? _green : Colors.orange,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lokasi Kamu',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _locationError == null
                        ? Colors.grey.shade700
                        : Colors.orange.shade800,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (position != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${position.latitude.toStringAsFixed(5)}, '
                    '${position.longitude.toStringAsFixed(5)}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (_loadingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _green),
            )
          else
            TextButton(
              onPressed: _detectLocation,
              child: const Text('Perbarui'),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationError() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 48,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          Text(
            _locationError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _detectLocation,
            style: FilledButton.styleFrom(backgroundColor: _green),
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Aktifkan Lokasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Venue di Sekitar Kamu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Diurutkan dari lokasi kamu saat ini',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7EE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_venues.length} venue',
            style: const TextStyle(
              color: Color(0xFF25613C),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVenuesError() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 46, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            _venuesError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loadVenues,
            style: FilledButton.styleFrom(backgroundColor: _green),
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVenues() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            'Belum ada venue aktif di sekitar kamu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(FieldModel venue) {
    final images = venue.allImages;
    final distance = _distanceTo(venue);
    final isNear = distance != null && distance <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
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
                  child: Icon(
                    venue.type.toLowerCase().contains('badminton')
                        ? Icons.sports_tennis_rounded
                        : Icons.sports_soccer_rounded,
                    color: _green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        venue.address ?? venue.city ?? 'Alamat belum tersedia',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          height: 1.35,
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
                    color: isNear
                        ? const Color(0xFFEAF7EE)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 12,
                        color: isNear ? _green : Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance == null
                            ? '-'
                            : distance < 1
                            ? '${(distance * 1000).round()} m'
                            : '${distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: isNear
                              ? const Color(0xFF25613C)
                              : Colors.blueGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildPhotoHeader(venue, images),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _distanceLabel(venue),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      Icons.stadium_outlined,
                      '${venue.courtCount} lapangan',
                    ),
                    _infoChip(
                      Icons.star_rounded,
                      venue.reviewCount > 0
                          ? '${venue.averageReviewRating.toStringAsFixed(1)} '
                                '(${venue.reviewCount} ulasan)'
                          : 'Belum ada ulasan',
                      color: const Color(0xFFF59E0B),
                    ),
                    _infoChip(
                      Icons.payments_outlined,
                      'Rp ${venue.price} / jam',
                    ),
                  ],
                ),
                if (venue.sports.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cabang Olahraga',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: venue.sports
                        .map(
                          (sport) => _tag(
                            sport,
                            background: const Color(0xFFEAF7EE),
                            foreground: const Color(0xFF25613C),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (venue.fasilitas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Fasilitas',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: venue.fasilitas
                        .take(6)
                        .map(
                          (item) => _tag(
                            item,
                            background: const Color(0xFFF1F5F9),
                            foreground: Colors.blueGrey.shade700,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openDetail(venue),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Lihat Detail'),
                      ),
                    ),
                    if (images.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openGallery(venue, images),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25613C),
                          side: const BorderSide(color: Color(0xFFCFE7D8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text('${images.length} Foto'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoHeader(FieldModel venue, List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        color: const Color(0xFFEAF2ED),
        child: Icon(
          venue.type.toLowerCase().contains('badminton')
              ? Icons.sports_tennis_rounded
              : Icons.sports_soccer_rounded,
          size: 54,
          color: _green,
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 175,
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
              Positioned.fill(
                child: DecoratedBox(
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
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
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
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${images.length} foto',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () => _openGallery(venue, images),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
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
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: () => _openGallery(venue, images)),
                ),
              ),
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openGallery(venue, images, initialIndex: index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(
                    images[index],
                    width: 58,
                    height: 54,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.image_outlined,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, {Color? color}) {
    final foreground = color ?? const Color(0xFF25613C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(
    String text, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _openGallery(
    FieldModel venue,
    List<String> images, {
    int initialIndex = 0,
  }) {
    PhotoGalleryScreen.open(
      context,
      images: images,
      initialIndex: initialIndex,
      title: venue.name,
    );
  }

  void _openDetail(FieldModel venue) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(field: venue)),
    );
  }
}
