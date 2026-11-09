import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/match_model.dart';
import '../services/match_api.dart';
import '../widgets/app_dialog.dart';
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
  Set<int> _joinedMatchIds = {};
  Set<int> _createdMatchIds = {};

  @override
  void initState() {
    super.initState();
    futureMatches = Future.value([]);
    _loadSession();
    MatchApi.dataRevision.addListener(_onMatchDataChanged);
  }

  @override
  void dispose() {
    MatchApi.dataRevision.removeListener(_onMatchDataChanged);
    super.dispose();
  }

  void _onMatchDataChanged() {
    if (!mounted || _isGuest) return;
    _reloadMatchData();
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

    if (!isGuest) _reloadMatchData();
  }

  Future<void> _reloadMatchData() async {
    final matches = await MatchApi.fetchMatches();
    final joined = await MatchApi.fetchJoinedMatchIds();
    final created = await MatchApi.fetchCreatedMatchIds();
    if (!mounted) return;
    setState(() {
      futureMatches = Future.value(matches);
      _joinedMatchIds = joined;
      _createdMatchIds = created;
    });
  }

  void _refreshData() {
    if (_isGuest) return;
    _reloadMatchData();
  }

  Future<void> _handleJoin(MatchModel match) async {
    if (_joinedMatchIds.contains(match.id)) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Konfirmasi Join',
      message: 'Yakin ingin bergabung ke open match "${match.title}"?',
      icon: Icons.group_add_outlined,
      confirmLabel: 'Ya, Gabung',
    );

    if (!confirmed || !mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    // Tampilkan loading sebentar
    showAppLoadingDialog(context, message: 'Mendaftarkan kamu...');

    Map<String, dynamic> result;
    try {
      result = await MatchApi.joinMatch(match.id);
    } catch (e) {
      result = {'success': false, 'message': 'Gagal bergabung: $e'};
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _joinedMatchIds = {..._joinedMatchIds, match.id});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anda berhasil bergabung ke open match "${match.title}" 🎉',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      _refreshData(); // Refresh list agar jumlah pemain update otomatis
    } else {
      final message =
          result['message']?.toString() ?? 'Gagal bergabung ke match.';
      final alreadyJoined = message.toLowerCase().contains('sudah bergabung');

      if (alreadyJoined) {
        setState(() => _joinedMatchIds = {..._joinedMatchIds, match.id});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: alreadyJoined ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Cari Lawan ",
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
                      child: CircularProgressIndicator(
                        color: Color(0xFF00A32A),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 50,
                            color: Colors.red,
                          ),
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
    bool isJoined = _joinedMatchIds.contains(match.id);
    bool isCreator = _createdMatchIds.contains(match.id);
    bool canChat = isJoined || isCreator;

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
                    child: ElevatedButton.icon(
                      onPressed: (isFull || isJoined || isCreator)
                          ? null
                          : () => _handleJoin(match),
                      icon: Icon(
                        isCreator
                            ? Icons.workspace_premium_rounded
                            : (isJoined
                                  ? Icons.check_circle_outline
                                  : Icons.group_add_outlined),
                        size: 18,
                      ),
                      label: Text(
                        isCreator
                            ? "ANDA PEMBUAT MATCH"
                            : (isJoined
                                  ? "SUDAH BERGABUNG"
                                  : (isFull
                                        ? "MATCH PENUH"
                                        : "BERGABUNG DI MATCH")),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A32A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: (isJoined || isCreator)
                            ? const Color(0xFF9E9E9E)
                            : Colors.grey.shade300,
                        disabledForegroundColor: (isJoined || isCreator)
                            ? Colors.white
                            : Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!canChat) {
                          showAppInfoDialog(
                            context,
                            title: 'Belum Bergabung',
                            message:
                                'Gabung ke open match "${match.title}" dulu untuk masuk grup chat.',
                            icon: Icons.lock_outline_rounded,
                            accent: const Color(0xFFF59E0B),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              matchId: match.id,
                              matchTitle: match.title,
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        canChat
                            ? Icons.chat_bubble_outline
                            : Icons.lock_outline,
                        size: 18,
                      ),
                      label: Text(
                        canChat
                            ? "MASUK GRUP CHAT"
                            : "MASUK GRUP CHAT (BERGABUNG DULU)",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canChat
                            ? Colors.blue.shade700
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
    final isFull = match.jumlahBergabung >= match.jumlahPemain;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final isJoined = _joinedMatchIds.contains(match.id);
          final isCreator = _createdMatchIds.contains(match.id);
          final canChat = isJoined || isCreator;

          return Padding(
            padding: const EdgeInsets.all(25),
            child: SingleChildScrollView(
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                    match.tanggal.length >= 10
                        ? match.tanggal.substring(0, 10)
                        : match.tanggal,
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
                    match.deskripsi.isEmpty
                        ? "No Description"
                        : match.deskripsi,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 25),

                  // Tombol bergabung / status sudah bergabung
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isJoined || isCreator || isFull)
                          ? null
                          : () async {
                              await _handleJoin(match);
                              if (sheetContext.mounted) setSheetState(() {});
                            },
                      icon: Icon(
                        isCreator
                            ? Icons.workspace_premium_rounded
                            : (isJoined
                                  ? Icons.check_circle_outline
                                  : Icons.group_add_outlined),
                        size: 18,
                      ),
                      label: Text(
                        isCreator
                            ? "ANDA PEMBUAT MATCH"
                            : (isJoined
                                  ? "SUDAH BERGABUNG"
                                  : (isFull
                                        ? "MATCH PENUH"
                                        : "BERGABUNG DI MATCH")),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A32A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: (isJoined || isCreator)
                            ? const Color(0xFF9E9E9E)
                            : Colors.grey.shade300,
                        disabledForegroundColor: (isJoined || isCreator)
                            ? Colors.white
                            : Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tombol grup chat, hanya bisa dipakai jika sudah bergabung
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!canChat) {
                          showAppInfoDialog(
                            sheetContext,
                            title: 'Belum Bergabung',
                            message:
                                'Gabung ke open match "${match.title}" dulu untuk masuk grup chat.',
                            icon: Icons.lock_outline_rounded,
                            accent: const Color(0xFFF59E0B),
                          );
                          return;
                        }

                        final navigator = Navigator.of(sheetContext);
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              matchId: match.id,
                              matchTitle: match.title,
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        canChat
                            ? Icons.chat_bubble_outline
                            : Icons.lock_outline,
                      ),
                      label: Text(
                        canChat
                            ? "MASUK GRUP CHAT MATCH"
                            : "MASUK GRUP CHAT (BERGABUNG DULU)",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canChat
                            ? Colors.blue.shade700
                            : Colors.grey.shade400,
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
        },
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
