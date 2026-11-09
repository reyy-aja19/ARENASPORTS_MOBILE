import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_app_data_service.dart';
import '../services/match_api.dart';
import '../widgets/guest_access_overlay.dart';
import 'create_match_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> _historyFuture;
  bool _isGuest = true;
  bool _isCheckingSession = true;
  Set<int> _bookingsWithMatch = {};
  Timer? _statusTicker;

  @override
  void initState() {
    super.initState();
    _historyFuture = Future.value([]);
    _loadSession();

    MatchApi.dataRevision.addListener(_onMatchDataChanged);

    // Booking yang jamnya habis harus langsung pindah ke tab "Selesai"
    // walau halaman ini sedang terbuka.
    _statusTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isGuest) return;
      setState(() {});
    });
  }

  void _onMatchDataChanged() {
    if (!mounted || _isGuest) return;
    _refreshData();
  }

  @override
  void dispose() {
    MatchApi.dataRevision.removeListener(_onMatchDataChanged);
    _statusTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isGuest = token == null || token.isEmpty;

    if (!mounted) return;
    setState(() {
      _isGuest = isGuest;
      _isCheckingSession = false;
      if (!isGuest) {
        _historyFuture = LocalAppDataService.getBookingHistory(
          prefs.getInt('user_id') ?? 0,
        );
      }
    });

    if (!isGuest) _loadBookingsWithMatch();
  }

  Future<void> _loadBookingsWithMatch() async {
    final ids = await MatchApi.fetchBookingsWithMatch();
    if (!mounted) return;
    setState(() => _bookingsWithMatch = ids);
  }

  void _refreshData() {
    if (_isGuest) return;
    setState(() {
      _historyFuture = SharedPreferences.getInstance().then((prefs) {
        return LocalAppDataService.getBookingHistory(
          prefs.getInt('user_id') ?? 0,
        );
      });
    });
    _loadBookingsWithMatch();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Riwayat Sewa"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              onPressed: _isGuest ? null : _refreshData,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Aktif"),
              Tab(text: "Selesai"),
            ],
          ),
        ),
        body: _isCheckingSession
            ? const Center(child: CircularProgressIndicator())
            : GuestAccessOverlay(
                isGuest: _isGuest,
                message: 'Login untuk melihat riwayat sewa.',
                child: FutureBuilder<List<dynamic>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text("Gagal memuat data: ${snapshot.error}"),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          "Belum ada data booking, booking sekarang!!",
                        ),
                      );
                    }

                    final all = snapshot.data!;

                    final active = all.where((b) {
                      final st = LocalAppDataService.effectiveStatus(
                        Map<String, dynamic>.from(b as Map),
                      );
                      return st == 'pending' ||
                          st == 'lunas' ||
                          st == 'dp' ||
                          st == 'check in';
                    }).toList();

                    final done = all.where((b) {
                      final st = LocalAppDataService.effectiveStatus(
                        Map<String, dynamic>.from(b as Map),
                      );
                      return st == 'check out' ||
                          st == 'selesai' ||
                          st == 'batal' ||
                          st == 'expired';
                    }).toList();

                    return TabBarView(
                      children: [_buildList(active), _buildList(done)],
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildList(List bookings) {
    if (bookings.isEmpty) {
      return const Center(child: Text("Tidak ada transaksi di kategori ini."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final b = bookings[i];
        String status = LocalAppDataService.effectiveStatus(
          Map<String, dynamic>.from(b as Map),
        );

        Color statusColor = Colors.grey;
        if (status == 'pending') {
          statusColor = Colors.orange;
        } else if (status == 'dp') {
          statusColor = Colors.amber;
        } else if (status == 'lunas') {
          statusColor = Colors.green;
        } else if (status == 'check in') {
          statusColor = Colors.blue;
        } else if (status == 'check out' || status == 'selesai') {
          statusColor = Colors.blueGrey;
        } else if (status == 'batal' || status == 'expired') {
          statusColor = Colors.red;
        }

        return _historyCard(b, statusColor);
      },
    );
  }

  Widget _historyCard(dynamic booking, Color statusColor) {
    String rawStatus = LocalAppDataService.effectiveStatus(
      Map<String, dynamic>.from(booking as Map),
    );
    String displayStatus = rawStatus;

    if (rawStatus.toLowerCase() == 'check in') displayStatus = 'Sedang Main';
    if (rawStatus.toLowerCase() == 'check out') displayStatus = 'Selesai';

    String namaLapangan =
        booking['lapangan']?['nama'] ??
        booking['lapangan']?['nama_lapangan'] ??
        "Lapangan";

    String date = booking['booking_date'] ?? "-";
    String start = booking['start_time'] ?? "-";
    String end = booking['end_time'] ?? "-";
    String total = booking['total_price']?.toString() ?? "0";

    final bookingId = booking['id'] is int
        ? booking['id'] as int
        : int.tryParse('${booking['id']}') ?? 0;
    final alreadyCreated = _bookingsWithMatch.contains(bookingId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  namaLapangan,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("📅 $date"),
          Text("⏰ $start - $end"),
          Text("💰 Rp $total"),
          const SizedBox(height: 10),
          if (rawStatus.toLowerCase() == 'lunas' && start != '-' && end != '-')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: alreadyCreated
                    ? null
                    : () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateMatchScreen(bookingData: booking),
                          ),
                        );
                        if (created == true && mounted) _refreshData();
                      },
                icon: Icon(
                  alreadyCreated
                      ? Icons.check_circle_outline
                      : Icons.group_add_outlined,
                  size: 18,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A32A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF9E9E9E),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text(
                  alreadyCreated
                      ? "SUDAH MEMBUAT OPEN MATCH"
                      : "BUAT OPEN MATCH",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
