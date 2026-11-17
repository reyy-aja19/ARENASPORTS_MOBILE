import 'package:flutter/material.dart';

import 'app_network_image.dart';

/// Galeri foto layar penuh untuk venue, lapangan, maupun booking.
///
/// Pemain dapat menggeser antar foto, melakukan pinch-to-zoom, dan memilih
/// foto lewat thumbnail di bagian bawah.
class PhotoGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;

  const PhotoGalleryScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title = 'Galeri Foto',
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String title = 'Galeri Foto',
  }) {
    final photos = images
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (photos.isEmpty) return Future.value();

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoGalleryScreen(
          images: photos,
          initialIndex: initialIndex.clamp(0, photos.length - 1),
          title: title,
        ),
      ),
    );
  }

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_currentIndex + 1} dari $total foto',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: total,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: AppNetworkImage(
                      widget.images[index],
                      fit: BoxFit.contain,
                      width: double.infinity,
                      backgroundColor: Colors.black,
                      placeholder: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 54,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Foto tidak dapat dimuat',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (total > 1)
            SafeArea(
              top: false,
              child: SizedBox(
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: total,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF00A32A)
                                : Colors.white24,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AppNetworkImage(
                          widget.images[index],
                          fit: BoxFit.cover,
                          backgroundColor: Colors.white12,
                          fallbackIcon: Icons.image_not_supported_outlined,
                          fallbackIconColor: Colors.white38,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
