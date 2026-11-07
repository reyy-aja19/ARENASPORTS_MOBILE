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
    if (images.isEmpty &&
        widget.field.imageUrl != null &&
        widget.field.imageUrl!.trim().isNotEmpty) {
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
    final firstRowCount = (widget.field.courtCount + 1) ~/ 2;
    final bottomRowStart = firstRowCount + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: images.isEmpty
                        ? Container(
                            color: Colors.blueGrey[200],
                            child: Icon(
                              widget.field.type == 'Badminton'
                                  ? Icons.sports_tennis
                                  : Icons.sports_soccer,
                              size: 50,
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemBuilder: (context, index) => Image.network(
                              images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.blueGrey[200],
                                    child: const Icon(Icons.image, size: 50),
                                  ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 15,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: const BackButton(color: Colors.black),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      right: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_currentPage + 1}/$activeImageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
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
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          widget.field.type == 'Badminton'
                              ? Icons.sports_tennis
                              : Icons.sports_soccer,
                          color: const Color(0xFF00A32A),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.field.type} • ${widget.field.courtCount} lapangan',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (widget.field.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.field.description!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    const Text(
                      'Pilih lapangan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCourtRow(
                      List.generate(firstRowCount, (index) => index + 1),
                    ),
                    if (bottomRowStart <= widget.field.courtCount) ...[
                      const SizedBox(height: 12),
                      _buildCourtRow(
                        List.generate(
                          widget.field.courtCount - bottomRowStart + 1,
                          (index) => bottomRowStart + index,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourtRow(List<int> courtNumbers) {
    return SizedBox(
      height: 310,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 4),
        itemCount: courtNumbers.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _buildCourtCard(widget.field.courtFor(courtNumbers[index])),
      ),
    );
  }

  Widget _buildCourtCard(CourtModel court) {
    final imageUrl = court.imageUrl ?? widget.field.imageUrl;
    return SizedBox(
      width: 220,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7ECE9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 90,
              width: double.infinity,
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFEAF2ED),
                      child: Icon(
                        widget.field.type == 'Badminton'
                            ? Icons.sports_tennis
                            : Icons.sports_soccer,
                        size: 42,
                        color: const Color(0xFF00A32A),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFEAF2ED),
                        child: const Icon(Icons.image_outlined, size: 42),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lapangan ${court.number}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Rp ${court.price} / jam',
                        style: const TextStyle(
                          color: Color(0xFF008C35),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    court.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.3,
                      fontSize: 12,
                    ),
                  ),
                  if (court.facilities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Fasilitas',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: court.facilities
                          .map(
                            (facility) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                facility,
                                style: const TextStyle(
                                  color: Color(0xFF25613C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () => _openCourtSchedule(court),
                      icon: const Icon(Icons.sports_soccer_outlined, size: 18),
                      label: const Text('Booking'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF008C35),
                        side: const BorderSide(color: Color(0xFF00A32A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCourtSchedule(CourtModel court) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleScreen(
          id: widget.field.courtIdFor(court.number),
          namaLapangan: '${widget.field.name} • Lapangan ${court.number}',
          hargaLapangan: 'Rp ${court.price}',
        ),
      ),
    );
  }
}
