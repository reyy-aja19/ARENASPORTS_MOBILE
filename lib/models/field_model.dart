import '../config/api_config.dart';

class FieldModel {
  final int id;
  final String name;
  final String type;
  final int price;
  final String? imageUrl;
  final List<String> galleryImages;
  final String? description;
  final String status;
  final dynamic fasilitas;

  FieldModel({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.imageUrl,
    this.galleryImages = const [],
    this.description,
    this.fasilitas,
    required this.status,
  });

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
      price: (json['harga'] as num?)?.toInt() ?? 0,
      imageUrl: imageUrl,
      galleryImages: galleryImages,
      fasilitas: json['fasilitas'],
      description: json['deskripsi'] ?? 'Tidak ada deskripsi',
      status: json['status'] ?? 'available',
    );
  }
}
