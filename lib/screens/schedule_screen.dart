import 'dart:async';

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
  final List<String> _timeSlots = [
    "08:00",
    "09:00",
    "10:00",
    "11:00",
    "13:00",
    "14:00",
    "15:00",
    "16:00",
    "17:00",
    "18:00",
    "19:00",
    "20:00",
    "21:00",
    "22:00",
    "23:00",
  ];

  DateTime selectedDate = DateTime.now();
  final List<String> _selectedTimes = [];
  List<String> _bookedSlots = [];
  bool _isLoadingSlots = true;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _fetchBookedSlots();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBookedSlots() async {
    if (!mounted) return;
    setState(() => _isLoadingSlots = true);

    try {
      final tanggalApi = DateFormat('yyyy-MM-dd').format(selectedDate);
      final apiService = ApiService();
      final data = await apiService.getBookedSlots(widget.id, tanggalApi);

      if (mounted) {
        setState(() {
          _bookedSlots = data;
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  bool _isSlotPast(String time) {
    final now = DateTime.now();
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    if (!isToday) return false;

    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final slotTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour,
      minute,
    );
    return !slotTime.isAfter(now);
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
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );

              if (picked != null) {
                setState(() {
                  selectedDate = picked;
                  _selectedTimes.clear();
                });

                await Future.delayed(const Duration(milliseconds: 100));
                _fetchBookedSlots();
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF00A32A).withValues(alpha: 0.1),
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
                    itemBuilder: (context, index) {
                      final time = _timeSlots[index];
                      final isBooked = _bookedSlots.contains(time);
                      final isSelected = _selectedTimes.contains(time);
                      final isPast = _isSlotPast(time);
                      final isDisabled = isBooked || isPast;

                      // Prioritas warna: booked selalu merah, baru lewat (abu).
                      Color bgColor;
                      Color borderColor;
                      Color textColor;
                      if (isBooked) {
                        bgColor = Colors.red.shade400;
                        borderColor = Colors.red.shade400;
                        textColor = Colors.white;
                      } else if (isPast) {
                        bgColor = Colors.grey.shade300;
                        borderColor = Colors.grey.shade400;
                        textColor = Colors.grey.shade600;
                      } else if (isSelected) {
                        bgColor = const Color(0xFF00A32A);
                        borderColor = Colors.grey.shade300;
                        textColor = Colors.white;
                      } else {
                        bgColor = Colors.white;
                        borderColor = Colors.grey.shade300;
                        textColor = Colors.black;
                      }

                      return GestureDetector(
                        onTap: isDisabled
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isBooked
                                          ? "Jam sudah dibooking orang lain"
                                          : "Jam $time sudah terlewat",
                                    ),
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
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: textColor,
                                    decoration: isDisabled
                                        ? TextDecoration.lineThrough
                                        : null,
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
                                if (isPast && !isBooked)
                                  Text(
                                    "Lewat",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
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
              onPressed: _selectedTimes.isEmpty ? null : _continueToCheckout,
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
