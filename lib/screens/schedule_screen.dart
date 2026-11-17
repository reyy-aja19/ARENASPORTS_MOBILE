import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/api_service.dart';
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
  static const int _maxHours = 8;

  DateTime selectedDate = DateTime.now();
  final List<String> _selectedTimes = [];
  List<AvailabilitySlot> _slots = [];
  bool _isLoadingSlots = true;
  String? _error;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _error = null;
    });

    try {
      final tanggalApi = DateFormat('yyyy-MM-dd').format(selectedDate);
      final data = await ApiService.instance.availability(widget.id, tanggalApi);
      if (!mounted) return;
      setState(() {
        _slots = data.slots;
        _isLoadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
        _error = e.message;
      });
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

  /// Slot hanya boleh dipilih sebagai satu blok jam yang berurutan.
  bool _canAddSlot(String time) {
    if (_selectedTimes.length >= _maxHours) return false;
    final candidate = [..._selectedTimes, time]..sort();
    final indexes = <int>[];
    for (final item in candidate) {
      final index = _slots.indexWhere((slot) => slot.startTime == item);
      if (index < 0) return false;
      indexes.add(index);
    }
    return indexes.last - indexes.first == indexes.length - 1;
  }

  double get _pricePerHour =>
      double.tryParse(widget.hargaLapangan.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;

  Future<void> _continueToCheckout() async {
    if (!await requireAuthenticatedUser(context) || !mounted) return;

    final listJam = [..._selectedTimes]..sort();
    if (listJam.isEmpty) return;

    final totalHarga = _pricePerHour * listJam.length;
    final hargaFinal =
        "Rp ${totalHarga.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          lapanganId: widget.id,
          namaLapangan: widget.namaLapangan,
          tanggal: DateFormat('yyyy-MM-dd').format(selectedDate),
          jam: listJam.join(', '),
          jamMulai: listJam.first,
          durasiJam: listJam.length,
          harga: hargaFinal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableSlots = _slots.isEmpty
        ? false
        : _slots.any((slot) => slot.available);

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
            onPressed: _fetchSlots,
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
              "${widget.namaLapangan} • Pilih hingga $_maxHours jam berurutan",
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
                _fetchSlots();
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
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                        TextButton.icon(
                          onPressed: _fetchSlots,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : !availableSlots
                ? const Center(
                    child: Text('Tidak ada slot tersedia pada tanggal ini.'),
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
                    itemCount: _slots.length,
                    itemBuilder: (context, index) {
                      final slot = _slots[index];
                      final time = slot.startTime;
                      final isBooked = !slot.available;
                      final isSelected = _selectedTimes.contains(time);
                      final isPast = _isSlotPast(time);
                      final isDisabled = isBooked || isPast;

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
                                  } else if (_canAddSlot(time)) {
                                    _selectedTimes.add(time);
                                    _selectedTimes.sort();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _selectedTimes.length >= _maxHours
                                              ? "Maksimal $_maxHours jam per booking."
                                              : "Pilih jam yang berurutan dengan slot sebelumnya.",
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
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
