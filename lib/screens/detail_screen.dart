import 'package:flutter/material.dart';
import 'package:penyewaan_lapangan/models/field_model.dart';
import 'schedule_screen.dart';

class DetailScreen extends StatefulWidget {
  final FieldModel field;

  const DetailScreen({super.key, required this.field});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<String> get galleryImages {
    final images = <String>[];
    for (final item in widget.field.galleryImages) {
      if (item.trim().isNotEmpty) images.add(item);
    }
    if (images.isEmpty && widget.field.imageUrl != null && widget.field.imageUrl!.trim().isNotEmpty) {
      images.add(widget.field.imageUrl!);
    }
    return images;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = galleryImages;
    final activeImageCount = images.isEmpty ? 1 : images.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 250,
                width: double.infinity,
                child: images.isEmpty
                    ? Container(
                        color: Colors.blueGrey[200],
                        child: const Icon(Icons.sports_soccer, size: 50),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.blueGrey[200],
                              child: const Icon(Icons.image, size: 50),
                            ),
                          );
                        },
                      ),
              ),
              Positioned(
                top: 40,
                left: 15,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: const BackButton(color: Colors.black),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentPage + 1}/$activeImageCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.field.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: const [
                    Icon(Icons.star, color: Colors.amber, size: 20),
                    Text(' 4.5 Rating • Kab. Indramayu'),
                  ],
                ),
                const Divider(height: 30),
                const Text(
                  'Fasilitas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildDynamicFacilities(),
                const SizedBox(height: 20),
                const Text(
                  'Deskripsi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.field.description ?? 'Tidak ada deskripsi untuk lapangan ini.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mulai dari',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Rp ${widget.field.price}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF00A32A),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleScreen(
                          id: widget.field.id,
                          namaLapangan: widget.field.name,
                          hargaLapangan: 'Rp ${widget.field.price}',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Pilih Jadwal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFacilities() {
    if (widget.field.fasilitas == null || widget.field.fasilitas.toString().trim().isEmpty) {
      return const Text(
        'Standard Court',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    final List<String> facilityList = [];

    if (widget.field.fasilitas is List) {
      facilityList.addAll(List<String>.from(widget.field.fasilitas));
    } else if (widget.field.fasilitas is String) {
      facilityList.addAll(
        widget.field.fasilitas
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: facilityList.map((item) {
        return Chip(
          backgroundColor: const Color(0xFFF1F3F5),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
          avatar: Icon(_getIconForFacility(item), size: 16, color: Colors.green),
          label: Text(
            item,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForFacility(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('parkir')) return Icons.local_parking;
    if (lower.contains('toilet') || lower.contains('wc')) return Icons.wc;
    if (lower.contains('minum') || lower.contains('kantin')) return Icons.local_drink;
    if (lower.contains('makan')) return Icons.restaurant;
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('mushola') || lower.contains('masjid')) return Icons.mosque;
    return Icons.check_circle_outline;
  }
}