import '../config/api_config.dart';

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
  final dynamic fasilitas;
  final double? latitude;
  final double? longitude;

  FieldModel({
    required this.id,
    required this.name,
    required this.type,
    this.courtCount = 1,
    this.courts = const [],
    required this.price,
    this.imageUrl,
    this.galleryImages = const [],
    this.description,
    this.fasilitas,
    required this.status,
    this.latitude,
    this.longitude,
  });

  int courtIdFor(int courtNumber) {
    if (courtNumber < 1 || courtNumber > courtCount) {
      throw RangeError.range(courtNumber, 1, courtCount, 'courtNumber');
    }
    return id * 100 + courtNumber;
  }

  CourtModel courtFor(int courtNumber) {
    courtIdFor(courtNumber);
    for (final court in courts) {
      if (court.number == courtNumber) return court;
    }

    final facilities = fasilitas is List
        ? List<String>.from(fasilitas)
        : <String>[];
    final courtImages = galleryImages.isNotEmpty
        ? galleryImages
        : imageUrl == null
        ? <String>[]
        : [imageUrl!];

    return CourtModel(
      number: courtNumber,
      imageUrl: courtImages.isEmpty
          ? null
          : courtImages[(courtNumber - 1) % courtImages.length],
      price: price,
      facilities: facilities,
      description: '$type lapangan $courtNumber di $name.',
    );
  }

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    final baseUrl = '${ApiConfig.serverBaseUrl}/';
    final photoPath = json['foto']?.toString();
    final imageUrl = photoPath != null
        ? Uri.parse(baseUrl).resolve(photoPath).toString()
        : null;

    List<String> galleryImages = [];
    final galleryData = json['gallery'] ?? json['images'] ?? json['gambars'];
    if (galleryData is List) {
      galleryImages = galleryData
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .map((item) => Uri.parse(baseUrl).resolve(item).toString())
          .toList();
    }

    if (galleryImages.isEmpty && imageUrl != null) {
      galleryImages = [imageUrl];
    }

    return FieldModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['nama'] ?? 'Tanpa Nama',
      type: json['jenis'] ?? 'Umum',
      courtCount: (json['jumlah_lapangan'] as num?)?.toInt() ?? 1,
      courts:
          (json['lapangans'] as List?)
              ?.whereType<Map>()
              .map(
                (court) => CourtModel.fromJson(
                  Map<String, dynamic>.from(court),
                  baseUrl: baseUrl,
                ),
              )
              .toList() ??
          const [],
      price: (json['harga'] as num?)?.toInt() ?? 0,
      imageUrl: imageUrl,
      galleryImages: galleryImages,
      fasilitas: json['fasilitas'],
      description: json['deskripsi'] ?? 'Tidak ada deskripsi',
      status: json['status'] ?? 'available',
      latitude: _coordinateFromJson(
        json['latitude'] ?? json['lat'] ?? json['lintang'],
      ),
      longitude: _coordinateFromJson(
        json['longitude'] ?? json['lng'] ?? json['lon'] ?? json['bujur'],
      ),
    );
  }
}

double? _coordinateFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

class CourtModel {
  final int number;
  final String? imageUrl;
  final int price;
  final List<String> facilities;
  final String description;

  const CourtModel({
    required this.number,
    required this.imageUrl,
    required this.price,
    required this.facilities,
    required this.description,
  });

  factory CourtModel.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final imagePath = json['foto']?.toString();
    final imageUrl = imagePath == null
        ? null
        : Uri.parse(baseUrl).resolve(imagePath).toString();
    final rawFacilities = json['fasilitas'];

    return CourtModel(
      number: (json['nomor'] as num?)?.toInt() ?? 1,
      imageUrl: imageUrl,
      price: (json['harga'] as num?)?.toInt() ?? 0,
      facilities: rawFacilities is List
          ? rawFacilities.map((item) => item.toString()).toList()
          : rawFacilities is String
          ? rawFacilities
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      description:
          json['deskripsi']?.toString() ?? 'Detail lapangan belum tersedia.',
    );
  }
}
