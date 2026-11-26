import 'review_model.dart';

/// Informasi perusahaan atau pemilik venue (opsional / fleksibel).
class VenueCompanyModel {
  final String? name;
  final String? type;
  final String? nib;
  final String? address;
  final String? phone;
  final String? description;

  const VenueCompanyModel({
    this.name,
    this.type,
    this.nib,
    this.address,
    this.phone,
    this.description,
  });

  factory VenueCompanyModel.fromJson(Map<String, dynamic> json) {
    return VenueCompanyModel(
      name: _string(json['name']),
      type: _string(json['type']),
      nib: _string(json['nib']),
      address: _string(json['address']),
      phone: _string(json['phone']),
      description: _string(json['description']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'nib': nib,
    'address': address,
    'phone': phone,
    'description': description,
  };
}

/// Aturan harga bertingkat berdasarkan hari dan jam (Court Price Rule).
class CourtPriceRuleModel {
  final String label;
  final String dayType;
  final List<String> days;
  final String startTime;
  final String endTime;
  final int price;

  const CourtPriceRuleModel({
    required this.label,
    required this.dayType,
    this.days = const [],
    required this.startTime,
    required this.endTime,
    required this.price,
  });

  factory CourtPriceRuleModel.fromJson(Map<String, dynamic> json) {
    return CourtPriceRuleModel(
      label: _string(json['label']) ?? 'Aturan Tarif',
      dayType: _string(json['day_type']) ?? 'all',
      days: _stringList(json['days']),
      startTime: _string(json['start_time']) ?? '00:00',
      endTime: _string(json['end_time']) ?? '23:59',
      price: _int(json['price']),
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'day_type': dayType,
    'days': days,
    'start_time': startTime,
    'end_time': endTime,
    'price': price,
  };
}

/// Venue beserta lapangan-lapangan yang tersedia di dalamnya.
///
/// Model ini dipetakan langsung dari payload `venue` pada API Laravel.
class FieldModel {
  final int id;
  final String name;
  final String type;
  final int courtCount;
  final List<CourtModel> courts;
  final int price;
  final String? imageUrl;
  final List<String> galleryImages;
  final String? description;
  final String status;
  final String operationalStatus;
  final String? managedBy;
  final String? companyName;
  final String? entityType;
  final VenueCompanyModel? company;
  final List<String> fasilitas;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? address;
  final String? city;
  final String? province;
  final List<String> sports;
  final double rating;
  final int reviewCount;
  final String? operatingHours;
  final List<String> operatingDays;
  final String? googleMapsUrl;
  final String? slug;

  const FieldModel({
    required this.id,
    required this.name,
    required this.type,
    this.courtCount = 1,
    this.courts = const [],
    required this.price,
    this.imageUrl,
    this.galleryImages = const [],
    this.description,
    this.status = 'Aktif',
    this.operationalStatus = 'Beroperasi',
    this.managedBy,
    this.companyName,
    this.entityType,
    this.company,
    this.fasilitas = const [],
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.address,
    this.city,
    this.province,
    this.sports = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.operatingHours,
    this.operatingDays = const [],
    this.googleMapsUrl,
    this.slug,
  });

  /// True jika venue beroperasi secara normal.
  bool get isOperational => operationalStatus.toLowerCase() == 'beroperasi';

  /// Menampilkan pengelola jika tersedia.
  String get displayManager => managedBy?.trim().isNotEmpty == true
      ? managedBy!.trim()
      : (companyName?.trim().isNotEmpty == true ? companyName!.trim() : 'Pengelola Venue');

  /// Semua foto venue: foto utama lalu seluruh foto galeri tanpa duplikat.
  List<String> get allImages {
    final images = <String>[];
    void add(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty || images.contains(text)) return;
      images.add(text);
    }

    add(imageUrl);
    for (final image in galleryImages) {
      add(image);
    }
    return images;
  }

  /// Seluruh ulasan dari semua lapangan di venue, terbaru lebih dahulu.
  List<ReviewModel> get reviews {
    final all = <ReviewModel>[];
    for (final court in courts) {
      all.addAll(court.reviews);
    }
    all.sort((a, b) {
      final dateA = a.createdAt;
      final dateB = b.createdAt;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return all;
  }

  /// Rata-rata rating dari ulasan nyata, fallback ke rating lapangan.
  double get averageReviewRating {
    final list = reviews;
    if (list.isEmpty) return rating;
    final total = list.fold<int>(0, (sum, item) => sum + item.rating);
    return total / list.length;
  }

  int courtIdFor(int courtNumber) {
    if (courtNumber < 1 || courtNumber > courtCount) {
      throw RangeError.range(courtNumber, 1, courtCount, 'courtNumber');
    }
    return courtFor(courtNumber).id;
  }

  CourtModel courtFor(int courtNumber) {
    if (courtNumber < 1) {
      throw RangeError.range(courtNumber, 1, courtCount, 'courtNumber');
    }

    for (final court in courts) {
      if (court.number == courtNumber) return court;
    }
    if (courts.length >= courtNumber) return courts[courtNumber - 1];

    return CourtModel(
      id: id * 100 + courtNumber,
      number: courtNumber,
      name: 'Lapangan $courtNumber',
      imageUrl: imageUrl,
      price: price,
      facilities: fasilitas,
      description: '$type lapangan $courtNumber di $name.',
    );
  }

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    final sports = _stringList(json['sports']);
    final facilities = _stringList(json['facilities']);
    final operatingDays = _stringList(json['operating_days']);
    final gallery = _stringList(json['gallery']);
    final photo = _string(json['photo_url']);
    final courts = (json['courts'] as List? ?? [])
        .whereType<Map>()
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => CourtModel.fromJson(
            Map<String, dynamic>.from(entry.value),
            fallbackNumber: entry.key + 1,
          ),
        )
        .toList();

    final type = sports.isNotEmpty
        ? sports.join(' • ')
        : (courts.isNotEmpty ? courts.first.type : 'Futsal & Badminton');

    final companyData = json['company'] is Map ? VenueCompanyModel.fromJson(Map<String, dynamic>.from(json['company'])) : null;

    return FieldModel(
      id: _int(json['id']),
      name: _string(json['name']) ?? 'Venue ArenaSports',
      type: type,
      courtCount: _int(json['courts_count'] ?? courts.length),
      courts: courts,
      price: _int(json['min_price'] ?? json['price']),
      imageUrl: photo ?? (gallery.isNotEmpty ? gallery.first : null),
      galleryImages: gallery.isNotEmpty
          ? gallery
          : (photo == null ? const [] : [photo]),
      description: _string(json['description']),
      status: _string(json['status']) ?? 'Aktif',
      operationalStatus: _string(json['operational_status']) ?? 'Beroperasi',
      managedBy: _string(json['managed_by']),
      companyName: _string(json['company_name']),
      entityType: _string(json['entity_type']),
      company: companyData,
      fasilitas: facilities,
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      distanceKm: _double(json['distance_km']),
      address: _string(json['address']),
      city: _string(json['city']),
      province: _string(json['province']),
      sports: sports,
      rating: _double(json['rating']) ?? 0,
      reviewCount: _int(json['review_count']),
      operatingHours: _string(json['operating_hours']),
      operatingDays: operatingDays,
      googleMapsUrl: _string(json['google_maps_url']),
      slug: _string(json['slug']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'courts_count': courtCount,
    'courts': courts.map((court) => court.toJson()).toList(),
    'min_price': price,
    'photo_url': imageUrl,
    'gallery': galleryImages,
    'description': description,
    'status': status,
    'operational_status': operationalStatus,
    'managed_by': managedBy,
    'company_name': companyName,
    'entity_type': entityType,
    'company': company?.toJson(),
    'facilities': fasilitas,
    'latitude': latitude,
    'longitude': longitude,
    'distance_km': distanceKm,
    'address': address,
    'city': city,
    'province': province,
    'sports': sports,
    'rating': rating,
    'review_count': reviewCount,
    'operating_hours': operatingHours,
    'operating_days': operatingDays,
    'google_maps_url': googleMapsUrl,
    'slug': slug,
  };
}

class CourtModel {
  final int id;
  final int number;
  final String name;
  final String type;
  final String? imageUrl;
  final List<String> galleryImages;
  final int price;
  final int minPrice;
  final List<String> facilities;
  final List<String> courtFacilities;
  final String? areaType;
  final String? floorType;
  final String description;
  final String status;
  final String operationalStatus;
  final bool isBookable;
  final double rating;
  final int reviewCount;
  final int? venueId;
  final String? venueName;
  final String? venueAddress;
  final List<CourtPriceRuleModel> priceRules;
  final List<ReviewModel> reviews;

  const CourtModel({
    required this.id,
    required this.number,
    this.name = '',
    this.type = 'Umum',
    required this.imageUrl,
    this.galleryImages = const [],
    required this.price,
    this.minPrice = 0,
    required this.facilities,
    this.courtFacilities = const [],
    this.areaType,
    this.floorType,
    required this.description,
    this.status = 'Tersedia',
    this.operationalStatus = 'Beroperasi',
    this.isBookable = true,
    this.rating = 0,
    this.reviewCount = 0,
    this.venueId,
    this.venueName,
    this.venueAddress,
    this.priceRules = const [],
    this.reviews = const [],
  });

  String get displayName => name.isNotEmpty ? name : 'Lapangan $number';

  /// True jika beroperasi dan jadwal tersedia
  bool get canBeBooked => isBookable && operationalStatus.toLowerCase() == 'beroperasi' && status.toLowerCase() == 'tersedia';

  /// Semua foto lapangan: foto utama lalu seluruh foto galeri tanpa duplikat.
  List<String> get allImages {
    final images = <String>[];
    void add(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty || images.contains(text)) return;
      images.add(text);
    }

    add(imageUrl);
    for (final image in galleryImages) {
      add(image);
    }
    return images;
  }

  factory CourtModel.fromJson(
    Map<String, dynamic> json, {
    int fallbackNumber = 1,
  }) {
    final facilities = _stringList(json['facilities']);
    final courtFacilities = _stringList(json['court_facilities']);
    final gallery = _stringList(json['gallery_images']);
    final image = _string(json['image_url']);
    final reviews = (json['reviews'] as List? ?? [])
        .whereType<Map>()
        .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final priceRules = (json['price_rules'] as List? ?? [])
        .whereType<Map>()
        .map((item) => CourtPriceRuleModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final isBookableVal = json['is_bookable'] is bool
        ? json['is_bookable'] as bool
        : (json['status']?.toString().toLowerCase() == 'tersedia');

    return CourtModel(
      id: _int(json['id']),
      number: fallbackNumber,
      name: _string(json['name']) ?? 'Lapangan $fallbackNumber',
      type: _string(json['type']) ?? 'Umum',
      imageUrl: image ?? (gallery.isNotEmpty ? gallery.first : null),
      galleryImages: gallery,
      price: _int(json['price']),
      minPrice: _int(json['min_price'] ?? json['price']),
      facilities: facilities,
      courtFacilities: courtFacilities,
      areaType: _string(json['area_type']),
      floorType: _string(json['floor_type']),
      description:
          _string(json['description']) ?? 'Detail lapangan belum tersedia.',
      status: _string(json['status']) ?? 'Tersedia',
      operationalStatus: _string(json['operational_status']) ?? 'Beroperasi',
      isBookable: isBookableVal,
      rating: _double(json['rating_average'] ?? json['rating']) ?? 0,
      reviewCount: _int(json['review_count']),
      venueId: json['venue_id'] == null ? null : _int(json['venue_id']),
      venueName: _string(json['venue_name']),
      venueAddress: _string(json['venue_address'] ?? json['location']),
      priceRules: priceRules,
      reviews: reviews,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'price': price,
    'min_price': minPrice,
    'rating': rating,
    'review_count': reviewCount,
    'status': status,
    'operational_status': operationalStatus,
    'is_bookable': isBookable,
    'description': description,
    'image_url': imageUrl,
    'gallery_images': galleryImages,
    'facilities': facilities,
    'court_facilities': courtFacilities,
    'area_type': areaType,
    'floor_type': floorType,
    'price_rules': priceRules.map((e) => e.toJson()).toList(),
    'venue_id': venueId,
    'venue_name': venueName,
    'venue_address': venueAddress,
  };
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _string(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
