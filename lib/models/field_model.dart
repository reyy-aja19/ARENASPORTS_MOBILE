import 'review_model.dart';

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
    this.fasilitas = const [],
    this.status = 'Aktif',
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
    this.googleMapsUrl,
    this.slug,
  });

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
        : (courts.isNotEmpty ? courts.first.type : 'Umum');

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
  final List<String> facilities;
  final String description;
  final String status;
  final double rating;
  final int reviewCount;
  final int? venueId;
  final String? venueName;
  final String? venueAddress;
  final List<ReviewModel> reviews;

  const CourtModel({
    required this.id,
    required this.number,
    this.name = '',
    this.type = 'Umum',
    required this.imageUrl,
    this.galleryImages = const [],
    required this.price,
    required this.facilities,
    required this.description,
    this.status = 'Tersedia',
    this.rating = 0,
    this.reviewCount = 0,
    this.venueId,
    this.venueName,
    this.venueAddress,
    this.reviews = const [],
  });

  String get displayName => name.isNotEmpty ? name : 'Lapangan $number';

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
    final gallery = _stringList(json['gallery_images']);
    final image = _string(json['image_url']);
    final reviews = (json['reviews'] as List? ?? [])
        .whereType<Map>()
        .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return CourtModel(
      id: _int(json['id']),
      number: fallbackNumber,
      name: _string(json['name']) ?? 'Lapangan $fallbackNumber',
      type: _string(json['type']) ?? 'Umum',
      imageUrl: image ?? (gallery.isNotEmpty ? gallery.first : null),
      galleryImages: gallery,
      price: _int(json['price']),
      facilities: facilities,
      description:
          _string(json['description']) ?? 'Detail lapangan belum tersedia.',
      status: _string(json['status']) ?? 'Tersedia',
      rating: _double(json['rating_average'] ?? json['rating']) ?? 0,
      reviewCount: _int(json['review_count']),
      venueId: json['venue_id'] == null ? null : _int(json['venue_id']),
      venueName: _string(json['venue_name']),
      venueAddress: _string(json['venue_address']),
      reviews: reviews,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'price': price,
    'rating': rating,
    'review_count': reviewCount,
    'status': status,
    'description': description,
    'image_url': imageUrl,
    'gallery_images': galleryImages,
    'facilities': facilities,
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
