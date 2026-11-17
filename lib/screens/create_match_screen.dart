import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import '../services/api_client.dart';
import '../services/match_api.dart';
import '../widgets/app_dialog.dart';

class CreateMatchScreen extends StatefulWidget {
  final BookingModel? booking;

  const CreateMatchScreen({super.key, this.booking});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _jmlPemainController = TextEditingController(text: '10');
  final _descController = TextEditingController();

  BookingModel? _selectedBooking;
  List<BookingModel> _eligibleBookings = const [];
  bool _isLoadingBookings = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedBooking = widget.booking;
    if (_selectedBooking == null) {
      _loadEligibleBookings();
    }
  }

  Future<void> _loadEligibleBookings() async {
    setState(() {
      _isLoadingBookings = true;
      _loadError = null;
    });
    try {
      final bookings = await MatchApi.fetchEligibleBookings();
      if (!mounted) return;
      setState(() {
        _eligibleBookings = bookings;
        _selectedBooking = bookings.isNotEmpty ? bookings.first : null;
        _isLoadingBookings = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBookings = false;
        _loadError = e.message;
      });
    }
  }

  IconData _sportIcon(String type) {
    final value = type.toLowerCase();
    if (value.contains('badminton') || value.contains('tenis')) {
      return Icons.sports_tennis;
    }
    if (value.contains('basket')) return Icons.sports_basketball;
    if (value.contains('voli')) return Icons.sports_volleyball;
    return Icons.sports_soccer;
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    bool enabled = true,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: enabled ? Colors.green : Colors.grey),
    fillColor: enabled ? Colors.white : Colors.grey.shade100,
    filled: !enabled,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: enabled ? Colors.green : Colors.grey,
        width: 2,
      ),
    ),
  );

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    final booking = _selectedBooking;
    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih booking yang akan dijadikan Open Match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showAppLoadingDialog(context, message: 'Membuat open match...');

    try {
      await MatchApi.createMatch(
        bookingId: booking.id,
        title: _titleController.text.trim(),
        jumlahPemain: int.parse(_jmlPemainController.text.trim()),
        deskripsi: _descController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // tutup loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Match Berhasil Dibuat!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat match: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _selectedBooking;
    final jenis = booking?.court?.type ?? 'Futsal';
    final date = booking?.bookingDate ?? '-';
    final start = booking?.startTime ?? '-';
    final end = booking?.endTime ?? '-';
    final venue = booking == null
        ? 'Pilih booking terlebih dahulu'
        : '${booking.venueName} • ${booking.courtName}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Buat Match Baru",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: (_isLoadingBookings && widget.booking == null)
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A32A)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Detail Pertandingan",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Muat ulang booking',
                          onPressed: widget.booking == null
                              ? _loadEligibleBookings
                              : null,
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFF00A32A),
                          ),
                        ),
                      ],
                    ),
                    if (widget.booking == null) ...[
                      const SizedBox(height: 10),
                      if (_loadError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_loadError!),
                            TextButton.icon(
                              onPressed: _loadEligibleBookings,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                            ),
                          ],
                        )
                      else if (_eligibleBookings.isEmpty)
                        const Text(
                          'Tidak ada booking aktif yang bisa dijadikan Open Match. '
                          'Pastikan booking sudah DP/Lunas dan belum dimulai.',
                        )
                      else
                        DropdownButtonFormField<BookingModel>(
                          initialValue: _selectedBooking,
                          decoration: _inputDecoration(
                            "Pilih Booking",
                            Icons.event_available_outlined,
                          ),
                          items: _eligibleBookings
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    '${item.courtName} • ${item.bookingDate} '
                                    '${item.startTime}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBooking = value;
                            });
                          },
                          validator: (value) => value == null
                              ? 'Pilih booking terlebih dahulu'
                              : null,
                        ),
                      const SizedBox(height: 15),
                    ],
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration("Judul Match", Icons.title),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Isi judul match terlebih dahulu"
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      key: ValueKey(venue),
                      initialValue: venue,
                      readOnly: true,
                      decoration: _inputDecoration(
                        "Lapangan",
                        Icons.stadium_outlined,
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      key: ValueKey(jenis),
                      initialValue: jenis,
                      readOnly: true,
                      decoration: _inputDecoration(
                        "Jenis Olahraga",
                        _sportIcon(jenis),
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _jmlPemainController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        "Maksimal Pemain (2-99)",
                        Icons.groups,
                      ),
                      validator: (v) {
                        final value = int.tryParse(v?.trim() ?? '');
                        if (value == null) return "Masukkan angka yang valid";
                        if (value < 2 || value > 99) {
                          return "Jumlah pemain harus 2 sampai 99";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        "Deskripsi Tambahan / Catatan",
                        Icons.description,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      key: ValueKey('tanggal_$date'),
                      initialValue: "Tanggal Main: $date",
                      readOnly: true,
                      decoration: _inputDecoration(
                        "Tanggal",
                        Icons.calendar_today,
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('start_$start'),
                            initialValue: start,
                            readOnly: true,
                            decoration: _inputDecoration(
                              "Mulai",
                              Icons.access_time,
                              enabled: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('end_$end'),
                            initialValue: end,
                            readOnly: true,
                            decoration: _inputDecoration(
                              "Selesai",
                              Icons.access_time,
                              enabled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _submitData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          "SIMPAN MATCH",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _jmlPemainController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
