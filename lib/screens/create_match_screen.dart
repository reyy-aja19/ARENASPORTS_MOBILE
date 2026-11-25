import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final _biayaController = TextEditingController();
  final _contactController = TextEditingController();
  final _descController = TextEditingController();
  final _hostTeamNameController = TextEditingController();
  final _hostMemberCountController = TextEditingController(text: '1');

  BookingModel? _selectedBooking;
  List<BookingModel> _eligibleBookings = const [];
  bool _isLoadingBookings = false;
  bool _isSubmitting = false;
  String? _loadError;
  String _biayaMode = 'Gratis';
  String _level = 'Santai';
  String _registrationType = 'Individu';

  final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _selectedBooking = widget.booking;
    _jmlPemainController.addListener(_syncSuggestedCost);
    if (_selectedBooking == null) {
      _loadEligibleBookings();
    } else {
      _syncSuggestedCost();
    }
  }

  @override
  void dispose() {
    _jmlPemainController.removeListener(_syncSuggestedCost);
    _titleController.dispose();
    _jmlPemainController.dispose();
    _biayaController.dispose();
    _contactController.dispose();
    _descController.dispose();
    _hostTeamNameController.dispose();
    _hostMemberCountController.dispose();
    super.dispose();
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
      _syncSuggestedCost();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBookings = false;
        _loadError = e.message;
      });
    }
  }

  int get _suggestedCost {
    final booking = _selectedBooking;
    final players = int.tryParse(_jmlPemainController.text.trim()) ?? 0;
    if (booking == null || players <= 0) return 0;
    final total = booking.totalPrice;
    if (total <= 0) return 0;
    return (total / players).ceil();
  }

  void _syncSuggestedCost() {
    if (_biayaMode != 'Patungan') return;
    final suggestion = _suggestedCost;
    if (suggestion > 0 && _biayaController.text.trim().isEmpty) {
      _biayaController.text = suggestion.toString();
    }
    if (mounted) setState(() {});
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    bool enabled = true,
    String? hint,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: enabled ? Colors.green : Colors.grey),
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      );

  Future<void> _submitData() async {
    if (_isSubmitting) return;
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

    final biaya = _biayaMode == 'Patungan'
        ? int.tryParse(_biayaController.text.trim())
        : null;
    if (_biayaMode == 'Patungan' && (biaya == null || biaya <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan biaya patungan per pemain.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isGroup = _registrationType == 'Kelompok';
    if (isGroup && _hostTeamNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama kelompok/tim host wajib diisi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final hostMemberCount = int.tryParse(_hostMemberCountController.text.trim());
    if (isGroup && (hostMemberCount == null || hostMemberCount < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah anggota kelompok host tidak valid.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    showAppLoadingDialog(context, message: 'Membuat open match...');

    try {
      await MatchApi.createMatch(
        bookingId: booking.id,
        title: _titleController.text.trim(),
        jumlahPemain: int.parse(_jmlPemainController.text.trim()),
        deskripsi: _descController.text.trim(),
        biayaMode: _biayaMode,
        biayaPerPemain: biaya,
        level: _level,
        contactPhone: _contactController.text.trim(),
        registrationType: _registrationType,
        hostTeamName: isGroup ? _hostTeamNameController.text.trim() : null,
        hostMemberCount: isGroup ? hostMemberCount : null,
      );

      if (!mounted) return;
      Navigator.pop(context); // loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match Berhasil Dibuat!'),
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _bookingPreview(BookingModel booking) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEBE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Booking',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
          ),
          const SizedBox(height: 10),
          _previewRow(Icons.storefront, booking.venueName),
          _previewRow(Icons.sports_soccer, '${booking.courtName} • ${booking.court?.type ?? '-'}'),
          _previewRow(Icons.location_on_outlined, booking.venueAddress.isNotEmpty ? booking.venueAddress : 'Alamat venue belum tersedia'),
          _previewRow(Icons.calendar_today, '${booking.bookingDate} • ${booking.startTime}-${booking.endTime}'),
          _previewRow(Icons.payments_outlined, 'Total booking: ${_idr.format(booking.totalPrice)}'),
          if (_biayaMode == 'Patungan' && _suggestedCost > 0)
            _previewRow(Icons.groups_outlined, 'Saran patungan: ${_idr.format(_suggestedCost)} / pemain'),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF168653)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4D6658), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = _selectedBooking;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Buat Match Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: (_isLoadingBookings && widget.booking == null)
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A32A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Open Match',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 12),

                    if (widget.booking == null) ...[
                      if (_loadError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_loadError!, style: const TextStyle(color: Colors.red)),
                            TextButton.icon(
                              onPressed: _loadEligibleBookings,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                            ),
                          ],
                        )
                      else if (_eligibleBookings.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF2DFB3)),
                          ),
                          child: const Text(
                            'Tidak ada booking aktif yang bisa dijadikan Open Match. Pastikan booking sudah DP/Lunas dan belum dimulai.',
                            style: TextStyle(color: Color(0xFF805A12)),
                          ),
                        )
                      else
                        DropdownButtonFormField<BookingModel>(
                          value: _selectedBooking,
                          isExpanded: true,
                          decoration: _inputDecoration('Pilih Booking', Icons.event_available_outlined),
                          items: _eligibleBookings
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    '${item.courtName} • ${item.bookingDate} ${item.startTime}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBooking = value;
                              _biayaController.clear();
                            });
                            _syncSuggestedCost();
                          },
                          validator: (value) => value == null ? 'Pilih booking terlebih dahulu' : null,
                        ),
                      const SizedBox(height: 15),
                    ],

                    if (booking != null) _bookingPreview(booking),

                    const Text('Jenis Pendaftaran', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'Individu',
                            groupValue: _registrationType,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Individu / Cari Pemain'),
                            onChanged: (value) => setState(() => _registrationType = value ?? 'Individu'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'Kelompok',
                            groupValue: _registrationType,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Kelompok / Cari Lawan'),
                            onChanged: (value) => setState(() => _registrationType = value ?? 'Kelompok'),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _registrationType == 'Kelompok'
                          ? '1 kelompok = 1 slot. Cocok untuk mencari lawan tim.'
                          : '1 orang = 1 slot. Cocok untuk mencari pemain tambahan.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),

                    if (_registrationType == 'Kelompok') ...[
                      TextFormField(
                        controller: _hostTeamNameController,
                        decoration: _inputDecoration('Nama Tim/ Kelompok Host', Icons.flag_outlined),
                        validator: (v) => _registrationType == 'Kelompok' && (v == null || v.trim().isEmpty)
                            ? 'Nama kelompok host wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _hostMemberCountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Jumlah Anggota Tim Host', Icons.groups_2_outlined),
                        validator: (v) {
                          if (_registrationType != 'Kelompok') return null;
                          final value = int.tryParse(v?.trim() ?? '');
                          if (value == null || value < 1) return 'Masukkan jumlah anggota yang valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                    ],

                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        'Judul Match',
                        Icons.title,
                        hint: _registrationType == 'Kelompok'
                            ? 'Contoh: Cari lawan futsal malam ini'
                            : 'Contoh: Cari pemain futsal malam ini',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Isi judul match terlebih dahulu' : null,
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      controller: _jmlPemainController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        _registrationType == 'Kelompok'
                            ? 'Target Total Slot Kelompok (termasuk host)'
                            : 'Target Total Pemain (termasuk host)',
                        Icons.groups,
                      ),
                      validator: (v) {
                        final value = int.tryParse(v?.trim() ?? '');
                        if (value == null) return 'Masukkan angka yang valid';
                        if (value < 2 || value > 99) return 'Jumlah slot harus 2 sampai 99';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: _level,
                      decoration: _inputDecoration('Level Permainan', Icons.signal_cellular_alt),
                      items: const ['Santai', 'Pemula', 'Menengah', 'Mahir', 'Kompetitif']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) => setState(() => _level = value ?? 'Santai'),
                    ),
                    const SizedBox(height: 15),

                    const Text('Biaya Bermain', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'Gratis',
                            groupValue: _biayaMode,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Gratis'),
                            onChanged: (value) => setState(() {
                              _biayaMode = value ?? 'Gratis';
                              _biayaController.clear();
                            }),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'Patungan',
                            groupValue: _biayaMode,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Patungan'),
                            onChanged: (value) => setState(() {
                              _biayaMode = value ?? 'Patungan';
                              _syncSuggestedCost();
                            }),
                          ),
                        ),
                      ],
                    ),

                    if (_biayaMode == 'Patungan') ...[
                      TextFormField(
                        controller: _biayaController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          'Biaya per Pemain',
                          Icons.payments_outlined,
                          hint: _suggestedCost > 0 ? _suggestedCost.toString() : 'Contoh: 50000',
                        ),
                        validator: (v) {
                          if (_biayaMode != 'Patungan') return null;
                          final value = int.tryParse(v?.trim() ?? '');
                          if (value == null || value <= 0) return 'Masukkan nominal patungan';
                          return null;
                        },
                      ),
                      if (_suggestedCost > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Saran otomatis: ${_idr.format(_suggestedCost)} / pemain dari total booking.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      const SizedBox(height: 15),
                    ] else
                      const SizedBox(height: 8),

                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('WhatsApp Host (opsional)', Icons.phone_outlined, hint: '08xxxxxxxxxx'),
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Deskripsi / Aturan',
                        Icons.description_outlined,
                        hint: 'Level, aturan, biaya bayar di venue, datang 15 menit lebih awal...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                        child: Text(
                          _isSubmitting ? 'MENYIMPAN...' : 'SIMPAN MATCH',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
