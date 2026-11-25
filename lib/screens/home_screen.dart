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
  static const List<String> _homeCarouselAssets = [
    'assets/images/carousel/venue1.jpg',
    'assets/images/carousel/venue2.jpg',
    'assets/images/carousel/venue3.jpg',
  ];

  List<FieldModel> allFields = [];
  List<FieldModel> filteredFields = [];
  String selectedCategory = "Semua";
  String searchQuery = '';
  String _sortBy = 'nearest';
  Timer? _searchDebounce;
  final PageController _carouselController = PageController(viewportFraction: 0.92);
  int _carouselIndex = 0;
  Timer? _carouselTimer;
  Position? userPosition;
  String? userLocationName;
  String? locationError;
  bool isLoadingLocation = true;
  bool isLoadingVenues = true;
  String? venuesError;
  int userPoints = 0;
  String _userName = '';

  late Future<List<NotificationModel>> futureNotifications;

  @override
  void initState() {
    super.initState();
    futureNotifications = _loadNotifications();
    _loadUserName();
    _loadVenues();
    _loadCurrentLocation();
    SessionService.dataRevision.addListener(_onSessionChanged);
    _startCarouselAutoPlay();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _carouselTimer?.cancel();
    _carouselController.dispose();
    SessionService.dataRevision.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      _loadPoints();
      _loadUserName();
    }
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
        _carouselIndex = 0;
        _applyFilters();
      });
      _startCarouselAutoPlay();
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

  Future<void> _loadUserName() async {
    final user = await SessionService.currentUser();
    if (!mounted) return;
    final name = (user?['name'] ?? '').toString().trim();
    setState(() => _userName = name);
  }

  Future<List<NotificationModel>> _loadNotifications() async {
    final userId = await SessionService.userId();
    if (userId == null) return const [];
    // Pastikan token FCM perangkat ini terdaftar ke backend.
    await PushNotificationService.registerTokenIfPossible();
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

  int _priceValue(FieldModel field) => field.price;

  void _applyFilters() {
    final query = searchQuery.toLowerCase().trim();
    final fields = allFields.where((field) {
      final sports = field.sports.map((s) => s.toLowerCase()).toList();
      final matchesCategory =
          selectedCategory == 'Semua' ||
          sports.contains(selectedCategory.toLowerCase()) ||
          field.type.toLowerCase().contains(selectedCategory.toLowerCase());
      final haystack =
          '${field.name} ${field.city ?? ''} ${field.address ?? ''}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    final effectiveSort =
        (_sortBy == 'nearest' && userPosition == null) ? 'cheapest' : _sortBy;

    fields.sort((a, b) {
      int compareDistance() {
        final da = _distanceTo(a);
        final db = _distanceTo(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }

      switch (effectiveSort) {
        case 'cheapest':
          final cmp = _priceValue(a).compareTo(_priceValue(b));
          return cmp != 0 ? cmp : compareDistance();
        case 'expensive':
          final cmp = _priceValue(b).compareTo(_priceValue(a));
          return cmp != 0 ? cmp : compareDistance();
        case 'name':
          final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return cmp != 0 ? cmp : compareDistance();
        case 'nearest':
        default:
          final cmp = compareDistance();
          if (cmp != 0) return cmp;
          return _priceValue(a).compareTo(_priceValue(b));
      }
    });

    filteredFields = fields;
  }

  void _openNearbyVenues() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearbyVenuesScreen()),
    );
  }

  void _startCarouselAutoPlay() {
    _carouselTimer?.cancel();
    if (!mounted || _homeCarouselAssets.length < 2) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_carouselController.hasClients) return;
      final next = (_carouselIndex + 1) % _homeCarouselAssets.length;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  String _sortLabel() {
    switch (_sortBy) {
      case 'cheapest':
        return 'Venue Termurah';
      case 'expensive':
        return 'Venue Termahal';
      case 'name':
        return 'Venue A-Z';
      case 'nearest':
      default:
        return userPosition == null ? 'Semua Venue' : 'Venue Terdekat';
    }
  }

  String _sortSubtitle() {
    switch (_sortBy) {
      case 'cheapest':
        return 'Diurutkan dari harga terendah';
      case 'expensive':
        return 'Diurutkan dari harga tertinggi';
      case 'name':
        return 'Diurutkan berdasarkan nama';
      case 'nearest':
      default:
        return userPosition == null
            ? 'Temukan lapangan favoritmu'
            : 'Diurutkan dari lokasi kamu';
    }
  }

  Widget _buildVenueCarousel() {
    final items = _homeCarouselAssets;
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: items.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _carouselIndex = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        items[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF9CA3AF),
                            size: 40,
                          ),
                        ),
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
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final active = index == _carouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? const Color(0xFF00A32A) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
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
                      _carouselIndex = 0;
                      _applyFilters();
                    });
                    if (_carouselController.hasClients) {
                      _carouselController.jumpToPage(0);
                    }
                    _startCarouselAutoPlay();
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
                _buildVenueCarousel(),
                const SizedBox(height: 20),
                if (dataFields.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Venue tidak ditemukan.')),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                                              Text(
                                  _sortLabel(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF1E2A2B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _sortSubtitle(),
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
                  _buildVenueList(context, dataFields),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVenueList(BuildContext context, List<FieldModel> fields) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final field in fields) ...[
            _venueCard(context, field),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _venueCard(BuildContext context, FieldModel field) {
    final distance = _distanceTo(field);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetailScreen(field: field)),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _fieldImage(field, width: double.infinity, height: 170),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          field.type.toLowerCase().contains('badminton')
                              ? Icons.sports_tennis
                              : Icons.sports_soccer,
                          size: 14,
                          color: const Color(0xFF00A32A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          field.type,
                          style: const TextStyle(
                            color: Color(0xFF1E2A2B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${field.courtCount} court',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.2,
                      color: Color(0xFF1E2A2B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if ((field.address ?? field.city ?? '').isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            field.address ?? field.city ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Rp ${field.price} / jam',
                          style: const TextStyle(
                            color: Color(0xFF00A32A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (distance != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                size: 13,
                                color: Color(0xFF00A32A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distance < 1000
                                    ? '${distance.round()} m'
                                    : '${(distance / 1000).toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  color: Color(0xFF25613C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                    children: [
                      Text(
                        _userName.isNotEmpty
                            ? 'Hai, $_userName! Siap main hari ini?'
                            : 'Hai, siap main hari ini?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
                      if (mounted) _loadVenues();
                    });
                  },
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    _searchDebounce?.cancel();
                    _loadVenues();
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
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                tooltip: 'Urutkan',
                initialValue: _sortBy,
                onSelected: (value) {
                  setState(() {
                    _sortBy = value;
                    _applyFilters();
                  });
                },
                itemBuilder: (context) => [
                  for (final option in const [
                    ('nearest', 'Terdekat'),
                    ('cheapest', 'Termurah'),
                    ('expensive', 'Termahal'),
                    ('name', 'Nama A-Z'),
                  ])
                    PopupMenuItem<String>(
                      value: option.$1,
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == option.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18,
                            color: _sortBy == option.$1 ? const Color(0xFF00A32A) : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Text(option.$2),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF00A32A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
