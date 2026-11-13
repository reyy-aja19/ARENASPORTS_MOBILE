import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'detail_screen.dart';
import 'package:penyewaan_lapangan/models/field_model.dart';
import '../models/notification_model.dart';
import '../services/local_app_data_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/point_center.dart';
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
  List<FieldModel> favoriteFields = [];
  String selectedCategory = "Semua";
  String searchQuery = '';
  Position? userPosition;
  String? userLocationName;
  String? locationError;
  bool isLoadingLocation = true;

  late Future<List<NotificationModel>> futureNotifications;

  @override
  void initState() {
    super.initState();
    allFields = List<FieldModel>.from(LocalAppDataService.fields);
    filteredFields = List<FieldModel>.from(LocalAppDataService.fields);
    futureNotifications = _loadNotifications();
    _loadFavorites();
    _loadCurrentLocation();
  }

  Future<List<NotificationModel>> _loadNotifications() async {
    final uid = await LocalAppDataService.currentUserId();
    if (uid == null) return LocalAppDataService.notifications;
    // Aktifkan notifikasi sistem (inbox Firestore) untuk user ini.
    PushNotificationService.listenToInbox(uid);
    PushNotificationService.saveTokenForUser(uid);
    return LocalAppDataService.getNotifications(uid);
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationError(
          'Aktifkan layanan lokasi perangkat untuk mencari venue terdekat.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationError(
          'Izin lokasi ditolak. Ketuk di sini untuk mencoba lagi.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationError(
          'Izin lokasi ditolak permanen. Aktifkan izin lokasi di Pengaturan.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      String? locationName;
      try {
        final placemarks = await Geocoding(
          locale: const Locale('id', 'ID'),
        ).placemarkFromCoordinates(position.latitude, position.longitude);
        for (final placemark in placemarks) {
          locationName = _formatLocationName(placemark);
          if (locationName != null) break;
        }
      } on PlatformException {
        locationName = null;
      }
      locationName ??= await _lookupLocationName(position);
      if (!mounted) return;

      setState(() {
        userPosition = position;
        userLocationName = locationName;
        isLoadingLocation = false;
        locationError = locationName == null
            ? 'Nama daerah tidak dapat ditemukan.'
            : null;
        _applyFilters();
      });
    } on TimeoutException {
      _setLocationError(
        'Waktu mendapatkan lokasi habis. Ketuk di sini untuk mencoba lagi.',
      );
    } on LocationServiceDisabledException {
      _setLocationError(
        'Aktifkan layanan lokasi perangkat untuk mencari venue terdekat.',
      );
    } on PermissionDeniedException {
      _setLocationError('Izin lokasi diperlukan untuk mencari venue terdekat.');
    } on PlatformException {
      _setLocationError(
        'Lokasi perangkat gagal didapatkan. Ketuk di sini untuk mencoba lagi.',
      );
    } on MissingPluginException {
      _setLocationError('Fitur lokasi tidak tersedia pada perangkat ini.');
    }
  }

  String? _formatLocationName(Placemark placemark) {
    final area =
        [
              placemark.subLocality,
              placemark.locality,
              placemark.subAdministrativeArea,
              placemark.administrativeArea,
            ]
            .map((value) => value?.trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => null,
            );
    if (area == null || area.isEmpty) return null;

    final detail =
        [
              placemark.locality,
              placemark.subAdministrativeArea,
              placemark.administrativeArea,
            ]
            .map((value) => value?.trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty && value != area,
              orElse: () => null,
            );
    return detail == null ? area : '$area, $detail';
  }

  Future<String?> _lookupLocationName(Position position) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
      'zoom': '16',
      'addressdetails': '1',
    });

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Accept-Language': 'id',
              'User-Agent': 'ARENASPORTS/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>) return null;
      final address = result['address'];
      if (address is! Map<String, dynamic>) return null;

      final area = _firstAddressValue(address, [
        'village',
        'hamlet',
        'suburb',
        'neighbourhood',
        'quarter',
        'residential',
        'subdistrict',
        'district',
        'city_district',
        'town',
        'municipality',
        'city',
        'county',
        'state_district',
      ]);
      if (area == null) return null;

      final region = _firstAddressValue(address, [
        'city',
        'town',
        'county',
        'state_district',
        'state',
      ]);
      return region == null || region == area ? area : '$area, $region';
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  String? _firstAddressValue(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() {
      isLoadingLocation = false;
      locationError = message;
    });
  }

  double? _distanceTo(FieldModel field) {
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
      final matchesCategory =
          selectedCategory == 'Semua' || field.type == selectedCategory;
      final matchesQuery = field.name.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    if (userPosition != null) {
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

  Future<void> _loadFavorites() async {
    final favs = await LocalAppDataService.getFavoriteFields();
    if (!mounted) return;
    setState(() => favoriteFields = favs);
  }

  @override
  Widget build(BuildContext context) {
    final dataFields = filteredFields;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            allFields = List<FieldModel>.from(LocalAppDataService.fields);
            selectedCategory = 'Semua';
            searchQuery = '';
            _applyFilters();
            futureNotifications = _loadNotifications();
          });
          await Future.wait([_loadFavorites(), _loadCurrentLocation()]);
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
                child: PointCenter(
                  selectedCategory: selectedCategory,
                  onCategoryChanged: (category) {
                    setState(() {
                      selectedCategory = category;
                      _applyFilters();
                    });
                  },
                ),
              ),
              if (favoriteFields.isNotEmpty) ...[
                _sectionHeader("Sering Dibooking", Icons.favorite_rounded),
                _buildHorizontalList(context, favoriteFields),
                const SizedBox(height: 8),
              ],
              if (dataFields.isNotEmpty) _buildFeaturedCard(dataFields.first),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      userPosition == null ? 'Semua Venue' : 'Venue Terdekat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF1E2A2B),
                      ),
                    ),
                    Text(
                      userPosition == null
                          ? 'Geser ke samping'
                          : 'Diurutkan dari lokasi kamu',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHorizontalList(context, dataFields),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF00A32A)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1E2A2B),
            ),
          ),
        ],
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
    final imageUrl = field.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.sports_soccer, color: Colors.grey, size: 36),
      );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.sports_soccer, color: Colors.grey, size: 36),
      ),
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
                                  : '📍 ${userLocationName ?? 'Nama daerah tidak ditemukan'}',
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
