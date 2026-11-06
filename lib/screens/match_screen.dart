import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/match_model.dart';
import '../services/match_api.dart';
import '../widgets/guest_access_overlay.dart';
import 'chat_screen.dart'; // FIX: Impor halaman chat baru agar bisa dipanggil

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late Future<List<MatchModel>> futureMatches;
  bool _isGuest = true;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    futureMatches = Future.value([]);
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final isGuest = token == null || token.isEmpty;

    if (!mounted) return;
    setState(() {
      _isGuest = isGuest;
      _isCheckingSession = false;
      if (!isGuest) futureMatches = MatchApi.fetchMatches();
    });
  }

  void _refreshData() {
    if (_isGuest) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      futureMatches = MatchApi.fetchMatches();
    });
  }

  void _handleJoin(int matchId) async {
    ScaffoldMessenger.of(context).clearSnackBars();

    // Tampilkan loading sebentar
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00A32A)),
      ),
    );

    Map<String, dynamic> result = await MatchApi.joinMatch(matchId);

    if (mounted) Navigator.pop(context); // Tutup loading dialog

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Berhasil bergabung ke match! 🔥"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _refreshData(); // Refresh list agar jumlah pemain update otomatis
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Gagal bergabung ke match."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Cari Lawan (Open Match)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00A32A)),
            onPressed: _isGuest ? null : _refreshData,
          ),
        ],
      ),
      body: _isCheckingSession
          ? const Center(child: CircularProgressIndicator())
          : GuestAccessOverlay(
              isGuest: _isGuest,
              message: 'Login untuk melihat dan bergabung ke Open Match.',
              child: FutureBuilder<List<MatchModel>>(
                future: futureMatches,
                builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A32A)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  Text("Waduh! ${snapshot.error}"),
                  TextButton(
                    onPressed: _refreshData,
                    child: const Text("Coba Lagi"),
                  ),
                ],
              ),
            );
          }

          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return Center(
              child: Text(
                'Belum ada yang buka match nih, coy!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                return _matchCard(matches[index]);
              },
            ),
          );
                },
              ),
            ),
    );
  }

  Widget _matchCard(MatchModel match) {
    bool isFull = match.jumlahBergabung >= match.jumlahPemain;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMatchDetail(match),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  match.jenis,
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${match.tanggal.length >= 10 ? match.tanggal.substring(0, 10) : match.tanggal} • ${match.startTime}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(isFull, match),
                    ],
                  ),
                  const Divider(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isFull ? null : () => _handleJoin(match.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A32A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(isFull ? "MATCH PENUH" : "JOIN SEKARANG"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMatchDetail(MatchModel match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              match.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              match.jenis,
              style: const TextStyle(
                color: Color(0xFF00A32A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 30),
            _detailRow(
              Icons.calendar_today,
              "Tanggal",
              match.tanggal.length >= 10 ? match.tanggal.substring(0, 10) : match.tanggal,
            ),
            _detailRow(
              Icons.access_time,
              "Waktu",
              "${match.startTime} - ${match.endTime}",
            ),
            _detailRow(
              Icons.group,
              "Kebutuhan",
              "${match.jumlahBergabung} / ${match.jumlahPemain} Pemain",
            ),
            const SizedBox(height: 15),
            const Text(
              "Deskripsi",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              match.deskripsi.isEmpty ? "No Description" : match.deskripsi,
              style: TextStyle(color: Colors.grey[600]),
            ),
            
            // FIX: Tombol "MASUK GRUP CHAT MATCH" ditaruh di dalam bottom sheet detail pertandingan
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Tutup bottom sheet terlebih dahulu
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        matchId: match.id,
                        matchTitle: match.title,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("MASUK GRUP CHAT MATCH"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isFull, MatchModel match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "${match.jumlahBergabung}/${match.jumlahPemain}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isFull ? Colors.red : const Color(0xFF00A32A),
          ),
        ),
        Text(
          isFull ? "FULL" : "OPEN",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isFull ? Colors.red : const Color(0xFF00A32A),
          ),
        ),
      ],
    );
  }
}