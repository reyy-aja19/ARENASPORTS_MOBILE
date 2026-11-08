import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../services/match_api.dart';
import '../widgets/app_dialog.dart';

class CreateMatchScreen extends StatefulWidget {
  // Menerima data booking dari HistoryScreen
  final dynamic bookingData;

  const CreateMatchScreen({super.key, this.bookingData});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _jmlPemainController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedJenis = 'Futsal';
  String _bookingDateString = '';
  String _startTimeString = '';
  String _endTimeString = '';
  int _bookingId = 0;

  @override
  void initState() {
    super.initState();

    // Validasi & Ekstraksi Data dari JSON Laravel Booking
    if (widget.bookingData != null) {
      // 1. Ambil ID Booking Asli (Penting untuk mencocokkan relasi di API Match)
      _bookingId = widget.bookingData['id'] ?? 0;

      // 2. Ekstraksi Nama Lapangan dari Objek Relasi Lapangan Laravel
      final lapanganData = widget.bookingData['lapangan'];
      String namaLapangan = "";

      if (lapanganData != null) {
        namaLapangan =
            (lapanganData['nama_lapangan'] ??
                    lapanganData['nama'] ??
                    lapanganData['nama_venue'] ??
                    "")
                .toString()
                .toLowerCase();
      } else {
        namaLapangan =
            (widget.bookingData['nama_lapangan'] ??
                    widget.bookingData['lapangan_nama'] ??
                    "")
                .toString()
                .toLowerCase();
      }

      // 3. Deteksi Pintar Jenis Olahraga Berdasarkan Nama Lapangan
      if (namaLapangan.contains('futsal') || namaLapangan.contains('bola')) {
        _selectedJenis = 'Futsal';
      } else if (namaLapangan.contains('badminton') ||
          namaLapangan.contains('bulutangkis') ||
          namaLapangan.contains('badmin')) {
        _selectedJenis = 'Badminton';
      } else if (namaLapangan.contains('basket') ||
          namaLapangan.contains('basketball')) {
        _selectedJenis = 'Basket';
      } else if (namaLapangan.contains('voli') ||
          namaLapangan.contains('volleyball')) {
        _selectedJenis = 'Voli';
      } else if (namaLapangan.contains('tenis') ||
          namaLapangan.contains('tennis')) {
        _selectedJenis = 'Tenis';
      } else {
        // Jika tidak ketemu kata kunci, ambil dari database field 'jenis' jika ada
        String fallbackJenis = "";
        if (lapanganData != null) {
          fallbackJenis =
              lapanganData['jenis'] ?? widget.bookingData['jenis'] ?? 'Futsal';
        } else {
          fallbackJenis = widget.bookingData['jenis'] ?? 'Futsal';
        }

        _selectedJenis = fallbackJenis.isNotEmpty
            ? '${fallbackJenis[0].toUpperCase()}${fallbackJenis.substring(1).toLowerCase()}'
            : 'Futsal';
      }

      // 4. Parsing Tanggal Main (Mengamankan format YYYY-MM-DD)
      String rawDate =
          widget.bookingData['booking_date'] ??
          widget.bookingData['tanggal'] ??
          '';
      _bookingDateString = rawDate.length >= 10
          ? rawDate.substring(0, 10)
          : rawDate;

      // 5. Parsing Jam Mulai dan Selesai (Menghilangkan format detik jika ada)
      String rawStart =
          widget.bookingData['start_time'] ??
          widget.bookingData['waktu_mulai'] ??
          '';
      String rawEnd =
          widget.bookingData['end_time'] ??
          widget.bookingData['waktu_selesai'] ??
          '';

      _startTimeString = rawStart.length >= 5
          ? rawStart.substring(0, 5)
          : rawStart;
      _endTimeString = rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd;
    } else {
      // Data Fallback jika data kosong
      _bookingDateString = "${DateTime.now().toLocal()}".split(' ')[0];
      _startTimeString = '08:00';
      _endTimeString = '09:00';
    }
  }

  // Menentukan icon input secara dinamis sesuai olahraga yang terdeteksi
  IconData _getSportIcon(String jenis) {
    switch (jenis.toLowerCase()) {
      case 'futsal':
        return Icons.sports_soccer;
      case 'badminton':
        return Icons.sports_tennis;
      case 'basket':
        return Icons.sports_basketball;
      case 'voli':
        return Icons.sports_volleyball;
      case 'tenis':
        return Icons.sports_mma;
      default:
        return Icons.sports_handball;
    }
  }

  // Desain Input Field dekorasi bergaya Clean
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

  void _submitData() async {
    if (_formKey.currentState!.validate()) {
      if (_bookingId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: ID Booking tidak terbaca dari riwayat."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Membungkus data ke dalam Model Match untuk dikirim ke API Laravel
      final newMatch = MatchModel(
        id: _bookingId, // Mengirimkan ID booking asli ke server
        title: _titleController.text,
        jenis: _selectedJenis,
        tanggal: _bookingDateString,
        startTime: _startTimeString,
        endTime: _endTimeString,
        jumlahPemain: int.parse(_jmlPemainController.text),
        jumlahBergabung: 1,
        status: 'Open',
        deskripsi: _descController.text,
      );

      // Tampilkan indikator loading sederhana saat memproses jaringan
      showAppLoadingDialog(context, message: 'Membuat open match...');

      bool success = await MatchApi.createMatch(newMatch);

      if (mounted) Navigator.pop(context); // Tutup loading dialog

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Match Berhasil Dibuat!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
            true,
          ); // Kembali ke halaman riwayat sewa dan refresh data
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Gagal membuat match. Server menolak permintaan atau status belum Lunas.",
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Detail Pertandingan (Otomatis Terisi)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),

              // Input Judul Match
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration("Judul Match", Icons.title),
                validator: (v) =>
                    v!.isEmpty ? "Isi judul match terlebih dahulu" : null,
              ),
              const SizedBox(height: 15),

              // Input Jenis Olahraga (ReadOnly & Mengikuti Deteksi Berhasil)
              TextFormField(
                key: Key("jenis_$_selectedJenis"),
                initialValue: _selectedJenis,
                readOnly: true,
                decoration: _inputDecoration(
                  "Jenis Olahraga",
                  _getSportIcon(_selectedJenis),
                  enabled: false,
                ),
              ),
              const SizedBox(height: 15),

              // Input Kebutuhan Jumlah Pemain
              TextFormField(
                controller: _jmlPemainController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  "Maksimal Pemain (Kebutuhan)",
                  Icons.groups,
                ),
                validator: (v) {
                  if (v!.isEmpty) return "Isi jumlah kebutuhan pemain";
                  if (int.tryParse(v) == null || int.parse(v) <= 0)
                    return "Masukkan angka yang valid";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Input Catatan / Deskripsi Tambahan
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputDecoration(
                  "Deskripsi Tambahan / Catatan",
                  Icons.description,
                ),
              ),
              const SizedBox(height: 15),

              // Input Tanggal Pengambilan otomatis
              TextFormField(
                key: Key("tanggal_$_bookingDateString"),
                initialValue: "Tanggal Main: $_bookingDateString",
                readOnly: true,
                decoration: _inputDecoration(
                  "Tanggal",
                  Icons.calendar_today,
                  enabled: false,
                ),
              ),
              const SizedBox(height: 15),

              // Baris Rentang Waktu Mulai & Selesai
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: Key("start_$_startTimeString"),
                      initialValue: _startTimeString,
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
                      key: Key("end_$_endTimeString"),
                      initialValue: _endTimeString,
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
              const SizedBox(height: 30),

              // Tombol Eksekusi Kirim Data ke API
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
