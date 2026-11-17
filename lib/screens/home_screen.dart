import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'detail_screen.dart';
import '../models/field_model.dart';
import '../models/notification_model.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/push_notification_service.dart';
import '../services/session_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/points_category_card.dart';
import 'nearby_venues_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  const HomeScreen({super.key, this.onProfileTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FieldModel> allFields = [];
  List<FieldModel> filteredFields = [];
  String selectedCategory = "Semua";
  String searchQuery = '';
  Position? userPosition;
  String? userLocationName;
  String? locationError;
  bool isLoadingLocation = true;
  bool isLoadingVenues = true;
  String? venuesError;
  int userPoints = 0;

  late Future<List<NotificationModel>> futureNotifications;

  @override
  void initState() {
    super.initState();
    futureNotifications = _loadNotifications();
    _loadVenues();
    _loadCurrentLocation();
    SessionService.revision.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    SessionService.revision.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) _loadPoints();
  }

  Future<void> _loadVenues() async {
    if (mounted) {
      setState(() {
        isLoadingVenues = true;
        venuesError = null;
      });
    }
    try {
      final position = userPosition;
      final venues = await ApiService.instance.venues(
        query: searchQuery,
        lat: position?.latitude,
        lng: position?.longitude,
      );
      if (!mounted) return;
      setState(() {
        allFields = venues;
        isLoadingVenues = false;
        _applyFilters();
      });
      await _loadPoints();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingVenues = false;
        venuesError = e.message;
      });
    }
  }

  Future<void> _loadPoints() async {
    final points = await SessionService.points();
    if (!mounted) return;
    setState(() => userPoints = points);
  }

  Future<List<NotificationModel>> _loadNotifications() async {
    final userId = await SessionService.userId();
    if (userId == null) return const [];
    // Aktifkan notifikasi sistem (inbox Firestore) untuk user ini.
    PushNotificationService.listenToInbox(userId);
    PushNotificationService.saveTokenForUser(userId);
    try {
      final page = await ApiService.instance.notifications(perPage: 20);
      return page.notifications;
    } on ApiException {
      return const [];
    }
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;

      // Tampilkan posisi segera; nama daerah dimuat terpisah agar indikator
      // lokasi tidak berputar menunggu proses geocoding.
      setState(() {
        userPosition = position;
        userLocationName = null;
        isLoadingLocation = false;
        _applyFilters();
      });

      unawaited(_loadVenues());
      unawaited(_resolveLocationName(position));
    } on LocationException catch (e) {
      _setLocationError(e.message);
    }
  }

  Future<void> _resolveLocationName(Position position) async {
    final name = await LocationService.describe(position);
    if (!mounted) return;
    setState(() => userLocationName = name);
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() {
      isLoadingLocation = false;
      locationError = message;
    });
  }

  double? _distanceTo(FieldModel field) {
    if (field.distanceKm != null) return field.distanceKm! * 1000;
    final position = userPosition;
    final latitude = field.latitude;
    final longitude = field.longitude;
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
    );
  }

  void _applyFilters() {
    final query = searchQuery.toLowerCase();
    final fields = allFields.where((field) {
      final sports = field.sports.map((s) => s.toLowerCase()).toList();
      final matchesCategory =
          selectedCategory == 'Semua' ||
          sports.contains(selectedCategory.toLowerCase()) ||
          field.type.toLowerCase().contains(selectedCategory.toLowerCase());
      final haystack =
          '${field.name} ${field.city ?? ''} ${field.address ?? ''}'
              .toLowerCase();
      final matchesQuery = haystack.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    if (userPosition != null || fields.any((f) => f.distanceKm != null)) {
      fields.sort((a, b) {
        final distanceA = _distanceTo(a);
        final distanceB = _distanceTo(b);
        if (distanceA == null) return distanceB == null ? 0 : 1;
        if (distanceB == null) return -1;
        return distanceA.compareTo(distanceB);
      });
    }
    filteredFields = fields;
  }

  void _openNearbyVenues() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearbyVenuesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataFields = filteredFields;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            selectedCategory = 'Semua';
            searchQuery = '';
            futureNotifications = _loadNotifications();
          });
          await Future.wait([_loadVenues(), _loadCurrentLocation()]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PointsCategoryCard(
                  points: userPoints,
                  pointsError: null,
                  selectedCategory: selectedCategory,
                  onCategoryChanged: (category) {
                    setState(() {
                      selectedCategory = category;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (isLoadingVenues)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00A32A)),
                  ),
                )
              else if (venuesError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Text(venuesError!, textAlign: TextAlign.center),
                      TextButton.icon(
                        onPressed: _loadVenues,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              else ...[
                if (dataFields.isNotEmpty) _buildFeaturedCard(dataFields.first),
                if (dataFields.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Venue tidak ditemukan.')),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userPosition == null
                                  ? 'Semua Venue'
                                  : 'Venue Terdekat',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF1E2A2B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              userPosition == null
                                  ? 'Temukan lapangan favoritmu'
                                  : 'Diurutkan dari lokasi kamu',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openNearbyVenues,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00A32A),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        icon: const Icon(Icons.near_me_outlined, size: 16),
                        label: const Text('Lihat semua'),
                      ),
                    ],
                  ),
                ),
                _buildHorizontalList(context, dataFields),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(FieldModel field) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(field: field),
              ),
            ),
            child: Stack(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: _fieldImage(
                    field,
                    width: double.infinity,
                    height: 190,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        field.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${field.type} • ${field.courtCount} lapangan • Rp ${field.price} / jam',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, List<FieldModel> fields) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: fields.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _cardVenue(context, fields[index]),
          );
        },
      ),
    );
  }

  Widget _cardVenue(BuildContext context, FieldModel field) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetailScreen(field: field)),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldImage(field, width: double.infinity, height: 108),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        field.type == 'Badminton'
                            ? Icons.sports_tennis
                            : Icons.sports_soccer,
                        size: 14,
                        color: const Color(0xFF00A32A),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          field.type,
                          style: const TextStyle(
                            color: Color(0xFF00A32A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${field.courtCount} court',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    field.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.15,
                      color: Color(0xFF1E2A2B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rp ${field.price} / jam',
                    style: const TextStyle(
                      color: Color(0xFF00A32A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (_distanceTo(field) case final distance?) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 12,
                          color: Color(0xFF00A32A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distance < 1000
                              ? '${distance.round()} m dari kamu'
                              : '${(distance / 1000).toStringAsFixed(1)} km dari kamu',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldImage(
    FieldModel field, {
    required double width,
    required double height,
  }) {
    return AppNetworkImage(
      field.imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      fallbackIcon: field.type.toLowerCase().contains('badminton')
          ? Icons.sports_tennis
          : Icons.sports_soccer,
      fallbackIconColor: const Color(0xFF00A32A),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 52, left: 20, right: 20, bottom: 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9F4B), Color(0xFF00A32A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InkWell(
                  onTap: isLoadingLocation ? null : _loadCurrentLocation,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi Kamu',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isLoadingLocation)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              userPosition == null
                                  ? (isLoadingLocation
                                        ? 'Mendeteksi lokasi...'
                                        : 'Lokasi tidak tersedia')
                                  : '📍 ${userLocationName ?? 'Koordinat ${userPosition!.latitude.toStringAsFixed(4)}°, ${userPosition!.longitude.toStringAsFixed(4)}°'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (locationError case final error?)
                        Text(
                          error,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  FutureBuilder<List<NotificationModel>>(
                    future: futureNotifications,
                    builder: (context, snapshot) {
                      final count =
                          snapshot.data?.where((n) => !n.isRead).length ?? 0;

                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  setState(() {
                                    futureNotifications = _loadNotifications();
                                  });
                                }
                              });
                            },
                          ),
                          if (count > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5C5C),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: widget.onProfileTap,
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Hai, siap main hari ini?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cari lapangan favoritmu dan booking sekarang',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.sports_soccer, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Cari venue...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
