import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:penyewaan_lapangan/services/api_service.dart';
import '../utils/auth_guard.dart';
import 'checkout_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final int id;
  final String namaLapangan;
  final String hargaLapangan;

  const ScheduleScreen({
    super.key,
    required this.id,
    required this.namaLapangan,
    required this.hargaLapangan,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Jam yang tersedia di UI
  final List<String> _timeSlots = [
    "08:00",
    "09:00",
    "10:00",
    "11:00",
    "13:00",
    "14:00",
    "15:00",
    "16:00",
    "19:00",
    "20:00",
    "21:00",
  ];

  DateTime selectedDate = DateTime.now();
  List<String> _selectedTimes = [];
  List<String> _bookedSlots = []; // Jam yang bakal diwarnain merah
  bool _isLoadingSlots = true;

  @override
  void initState() {
    super.initState();
    _fetchBookedSlots();
  }

  // Fungsi ambil data jam dari Laravel
  Future<void> _fetchBookedSlots() async {
  if (!mounted) return;
  setState(() => _isLoadingSlots = true);

  try {
    String tanggalApi =
        DateFormat('yyyy-MM-dd').format(selectedDate);

    final apiService = ApiService();
    final data =
        await apiService.getBookedSlots(widget.id, tanggalApi);

    print("DEBUG: Jam terisi dari API -> $data");

    if (mounted) {
      setState(() {
        _bookedSlots = data;
        _isLoadingSlots = false;
      });
    }
  } catch (e) {
    print("DEBUG: Error fetch slots -> $e");
    if (mounted) {
      setState(() => _isLoadingSlots = false);
    }
  }
}

  Future<void> _continueToCheckout() async {
    if (!await requireAuthenticatedUser(context) || !mounted) return;

    final hargaSatuan = int.parse(
      widget.hargaLapangan.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final totalHarga = hargaSatuan * _selectedTimes.length;
    final hargaFinal =
        "Rp ${totalHarga.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          lapanganId: widget.id,
          namaLapangan: widget.namaLapangan,
          tanggal: DateFormat('yyyy-MM-dd').format(selectedDate),
          jam: _selectedTimes.join(', '),
          harga: hargaFinal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Pilih Jadwal",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchBookedSlots,
            icon: const Icon(Icons.refresh, color: Color(0xFF00A32A)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Text(
              "${widget.namaLapangan} • Pilih Maksimal 2 Jam",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              "Tanggal",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          InkWell(
  onTap: () async {
  DateTime? picked = await showDatePicker(
    context: context,
    initialDate: selectedDate,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 30)),
  );

  if (picked != null) {
    setState(() {
      selectedDate = picked;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    _fetchBookedSlots();
  }
},
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF00A32A).withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF00A32A)),
    ),
    child: Row(
      children: [
        const Icon(Icons.calendar_today, color: Color(0xFF00A32A)),
        const SizedBox(width: 15),
        Text(
          DateFormat('dd MMMM yyyy').format(selectedDate),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  ),
),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Text(
              "Pilih Jam",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          Expanded(
            child: _isLoadingSlots
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00A32A)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _timeSlots.length,
                    // Di dalam GridView.builder
                    itemBuilder: (context, index) {
                      String time = _timeSlots[index];
                      bool isBooked = _bookedSlots.contains(
                        time,
                      ); // Mencari "08:00" di dalam ["08:00", "09:00"]
                      bool isSelected = _selectedTimes.contains(time);

                      return GestureDetector(
                        onTap: isBooked
    ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Jam sudah dibooking orang lain"),
            backgroundColor: Colors.red,
          ),
        );
      }
    : () {
        setState(() {
          if (isSelected) {
            _selectedTimes.remove(time);
          } else {
            if (_selectedTimes.length < 2) {
              _selectedTimes.add(time);
              _selectedTimes.sort();
            }
          }
        });
      },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isBooked
                                ? Colors.red.shade400
                                : (isSelected
                                      ? const Color(0xFF00A32A)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBooked
                                  ? Colors.red.shade400
                                  : Colors.grey.shade300,
                            ),
                          ),
                         child: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        time,
        style: TextStyle(
          color: (isBooked || isSelected) ? Colors.white : Colors.black,
          decoration: isBooked ? TextDecoration.lineThrough : null,
          fontWeight: FontWeight.bold,
        ),
      ),

      if (isBooked)
        const Text(
          "Booked",
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
          ),
        ),
    ],
  ),
),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _selectedTimes.isEmpty
                  ? null
                  : _continueToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A32A),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                _selectedTimes.isEmpty
                    ? "Pilih Jam"
                    : "Konfirmasi ${_selectedTimes.length} Jam",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
