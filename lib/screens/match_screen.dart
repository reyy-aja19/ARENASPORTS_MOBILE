import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/match_model.dart';
import '../services/match_api.dart';
import '../services/session_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/guest_access_overlay.dart';
import 'chat_screen.dart';
import 'create_match_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late Future<List<MatchModel>> futureMatches;
  bool _isGuest = true;
  bool _isCheckingSession = true;
  bool _isRefreshing = false;
  DateTime? _lastRefreshAt;
  Set<int> _joinedMatchIds = {};
  Set<int> _createdMatchIds = {};
  String _selectedEventType = 'open_match';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    futureMatches = Future.value([]);
    _loadSession();
    MatchApi.dataRevision.addListener(_onMatchDataChanged);
    // Perbarui label waktu/status secara lokal tanpa memanggil API.
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && !_isGuest) setState(() {});
    });
  }

  @override
  void dispose() {
    MatchApi.dataRevision.removeListener(_onMatchDataChanged);
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onMatchDataChanged() {
    if (!mounted || _isGuest) return;
    _reloadMatchData();
  }

  Future<void> _loadSession() async {
    final isGuest = !await SessionService.isLoggedIn();

    if (!mounted) return;
    setState(() {
      _isGuest = isGuest;
      _isCheckingSession = false;
      if (!isGuest) futureMatches = _fetchMatches();
    });
  }

  Future<List<MatchModel>> _fetchMatches() async {
    final feed = await MatchApi.fetchFeed();
    if (mounted) {
      setState(() {
        _joinedMatchIds = feed.matches
            .where((match) => match.joined)
            .map((match) => match.id)
            .toSet();
        _createdMatchIds = feed.matches
            .where((match) => match.isHost)
            .map((match) => match.id)
            .toSet();
      });
    }
    return feed.matches;
  }

  Future<void> _reloadMatchData({bool force = false}) async {
    if (_isGuest || _isRefreshing) return;
    final now = DateTime.now();
    final last = _lastRefreshAt;
    if (!force && last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _isRefreshing = true;
    _lastRefreshAt = now;
    try {
      final matches = await _fetchMatches();
      if (!mounted) return;
      setState(() {
        futureMatches = Future.value(matches);
      });
    } catch (_) {
      // Keep current UI state on transient refresh errors.
    } finally {
      _isRefreshing = false;
    }
  }

  void _refreshData({bool force = false}) {
    if (_isGuest) return;
    _reloadMatchData(force: force);
  }

  DateTime? _eventDateTime(String date, String time) {
    final dateParts = date.split('-');
    if (dateParts.length != 3) return null;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;

    final timeParts = time.split(':');
    final hour = int.tryParse(timeParts.first);
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;
    if (hour == null || minute == null) return null;

    return DateTime(year, month, day, hour, minute);
  }

  bool _eventStarted(MatchModel event) {
    final start = _eventDateTime(event.tanggal, event.startTime);
    return start != null && !DateTime.now().isBefore(start);
  }

  bool _eventEnded(MatchModel event) {
    final end = _eventDateTime(event.tanggal, event.endTime.isNotEmpty ? event.endTime : event.startTime);
    return end != null && DateTime.now().isAfter(end);
  }

  List<MatchModel> _filteredEvents(List<MatchModel> matches) {
    return matches.where((match) {
      if (match.eventType != _selectedEventType) return false;
      // Open Match hilang setelah waktu booking berakhir
      if (match.eventType == 'open_match' && _eventEnded(match)) return false;
      return true;
    }).toList();
  }

  Widget _buildEventTabs() {
    final tabs = [
      ('open_match', 'Open Match', Icons.groups_rounded),
      ('tournament', 'Turnamen', Icons.emoji_events_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      child: Row(
        children: tabs.map((tab) {
          final selected = _selectedEventType == tab.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() => _selectedEventType = tab.$1),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF00A32A) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.$3,
                        size: 18,
                        color: selected ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.$2,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openExternal(String? url) async {
    final raw = (url ?? '').trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showMatchDetail(MatchModel matchArg) async {
    showAppLoadingDialog(context, message: 'Memuat detail...');
    var loadingOpen = true;
    void closeLoading() {
      if (loadingOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingOpen = false;
      }
    }
    try {
      var match = matchArg;
      if (match.isOpenMatch) {
        try {
          match = await MatchApi.matchDetail(match.id);
        } catch (_) {
          // Pakai data feed jika detail gagal dimuat.
        }
      }
      closeLoading();
      final embed = (match.googleMapsEmbedUrl ?? '').trim();
      WebViewController? mapController;
      if (embed.isNotEmpty) {
        try {
          mapController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse(embed));
        } catch (_) {
          mapController = null;
        }
      }

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)))),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00A32A), Color(0xFF1F8F5F)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chipOnDark(match.isTournament ? 'TURNAMEN' : 'OPEN MATCH'),
                    _chipOnDark(match.isOpenMatch ? match.modeLabel : match.registrationType),
                  ]),
                  const SizedBox(height: 10),
                  Text(match.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '${match.venueName.isNotEmpty ? match.venueName : "Venue"} • ${match.fieldName.isNotEmpty ? match.fieldName : "-"}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip(
                  match.isFree ? 'Gratis' : 'Rp ${match.biayaPerPemain ?? match.registrationFee} / ${match.capacityLabel}',
                  match.isFree ? Colors.green : Colors.orange,
                ),
                if (match.level.isNotEmpty) _chip(match.level, Colors.blue),
                _chip('${match.jumlahBergabung}/${match.jumlahPemain} ${match.capacityLabel}', Colors.teal),
                if (match.statusLabel.isNotEmpty) _chip(match.statusLabel, Colors.indigo),
              ]),
              const SizedBox(height: 16),
              _detailSection('Informasi', [
                _detailRow(Icons.calendar_today, '${match.tanggal} • ${match.startTime}-${match.endTime}'),
                _detailRow(Icons.location_on_outlined, match.venueAddress.isNotEmpty ? match.venueAddress : 'Lokasi belum tersedia'),
                _detailRow(Icons.sports, '${match.jenis} • ${match.fieldName}'),
                _detailRow(Icons.person_outline, 'Host: ${match.organizer}'),
                _detailRow(Icons.info_outline, 'Mode: ${match.isOpenMatch ? match.modeLabel : match.registrationType}'),
                if (match.deskripsi.isNotEmpty) _detailRow(Icons.notes_outlined, match.deskripsi),
              ]),
              if (match.participants.isNotEmpty || match.registrations.isNotEmpty) ...[
                const SizedBox(height: 14),
                _detailSection(
                  match.isTournament ? 'Tim/Peserta Terdaftar' : 'Peserta Open Match',
                  [
                    if (match.isOpenMatch)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          match.isGroupMatch
                              ? 'Mode Cari Lawan: daftar tim/kelompok yang sudah bergabung.'
                              : 'Mode Cari Pemain: daftar pemain yang sudah bergabung.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ...match.participants.map((p) => _participantTile(
                          name: p.teamName != null && p.teamName!.isNotEmpty ? p.teamName! : p.name,
                          subtitle: p.teamName != null && p.teamName!.isNotEmpty
                              ? 'Ketua/Host: ${p.name} • ${p.memberCount} anggota'
                              : (p.isHost ? 'Host' : 'Pemain'),
                          role: p.role,
                          isHost: p.isHost,
                        )),
                    ...match.registrations.map((r) => _participantTile(
                          name: r.displayName.isNotEmpty ? r.displayName : (r.teamName ?? 'Peserta'),
                          subtitle: r.teamName != null && r.teamName!.isNotEmpty
                              ? 'Tim: ${r.teamName} • ${r.memberCount} anggota'
                              : '${r.registrationType} • ${r.memberCount} anggota',
                          role: r.status.isNotEmpty ? r.status : r.registrationType,
                          isHost: r.isMine,
                        )),
                  ],
                ),
              ],
              if (match.participants.isEmpty && match.registrations.isEmpty) ...[
                const SizedBox(height: 14),
                _detailSection(match.isTournament ? 'Tim/Peserta Terdaftar' : 'Peserta Open Match', [
                  Text(
                    match.isTournament
                        ? 'Belum ada pendaftar. Jadilah yang pertama mendaftar.'
                        : (match.isGroupMatch
                            ? 'Belum ada tim lawan. Bagikan open match ini untuk mencari lawan.'
                            : 'Belum ada pemain bergabung. Bagikan open match ini untuk mencari pemain.'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ]),
              ],
              if (mapController != null) ...[
                const SizedBox(height: 14),
                _detailSection('Lokasi', [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(height: 220, child: WebViewWidget(controller: mapController)),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              Row(children: [
                if ((match.googleMapsUrl ?? '').isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openExternal(match.googleMapsUrl),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Buka Maps'),
                    ),
                  ),
                if ((match.googleMapsUrl ?? '').isNotEmpty &&
                    ((match.isTournament && match.contactWhatsapp.isNotEmpty) ||
                        (match.isOpenMatch && (match.joined || match.isHost || match.chatAvailable))))
                  const SizedBox(width: 10),
                if (match.isTournament && match.contactWhatsapp.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openExternal('https://wa.me/${match.contactWhatsapp}'),
                      icon: const Icon(Icons.chat),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                if (match.isOpenMatch && (match.joined || match.isHost || match.chatAvailable))
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(matchId: match.id, matchTitle: match.title)),
                        );
                      },
                      icon: const Icon(Icons.forum_outlined),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                      label: const Text('Grup Chat'),
                    ),
                  ),
              ]),
            ],
          ),
        );
      },
    );
    } catch (e) {
      closeLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka detail: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _chip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color.shade700, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _chipOnDark(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECE7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _participantTile({
    required String name,
    required String subtitle,
    required String role,
    bool isHost = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECE9)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isHost ? const Color(0xFFFFF3CD) : const Color(0xFFEAF7EE),
            child: Icon(isHost ? Icons.star_rounded : Icons.person, size: 16, color: isHost ? Colors.amber.shade700 : const Color(0xFF00A32A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: const Color(0xFF168653)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ]),
    );
  }

  Future<void> _handleEventRegister(MatchModel match) async {
    final teamCtrl = TextEditingController();
    final captainCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final memberCtrl = TextEditingController(text: '5');
    final notesCtrl = TextEditingController();
    bool agree = false;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)))),
              Text('Daftar ${match.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Data tim disimpan, lalu kamu diarahkan ke WhatsApp penyelenggara.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(controller: teamCtrl, decoration: const InputDecoration(labelText: 'Nama Tim', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: captainCtrl, decoration: const InputDecoration(labelText: 'Nama Ketua Tim', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp Ketua', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: memberCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Anggota', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder())),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: agree, onChanged: (v) => setModal(() => agree = v ?? false),
                title: const Text('Saya setuju data tim dibagikan ke penyelenggara dan lanjut konfirmasi via WhatsApp.', style: TextStyle(fontSize: 12))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () {
                  if (teamCtrl.text.trim().isEmpty || captainCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama tim, ketua, dan WhatsApp wajib diisi.')));
                    return;
                  }
                  if (!agree) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setujui ketentuan pendaftaran terlebih dahulu.')));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF168653), foregroundColor: Colors.white),
                child: const Text('Simpan & Lanjut WhatsApp'),
              )),
            ]),
          ),
        );
      }),
    );

    if (submitted != true || !mounted) return;
    showAppLoadingDialog(context, message: 'Mendaftarkan tim...');
    final result = await MatchApi.registerEvent(
      eventId: match.id,
      teamName: teamCtrl.text.trim(),
      captainName: captainCtrl.text.trim(),
      captainPhone: phoneCtrl.text.trim(),
      memberCount: int.tryParse(memberCtrl.text.trim()) ?? 1,
      notes: notesCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;

    final ok = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? ''), backgroundColor: ok ? Colors.green : Colors.red));
    if (ok) {
      final wa = result['whatsapp_url']?.toString();
      if (wa != null && wa.isNotEmpty) {
        await _openExternal(wa);
      }
      _refreshData();
    }
  }

  Future<void> _handleJoin(MatchModel match) async {
    if (_joinedMatchIds.contains(match.id) || match.joined) return;

    String? teamName;
    int? memberCount;
    if (match.isGroupMatch) {
      final teamCtrl = TextEditingController();
      final memberCtrl = TextEditingController(text: '1');
      final submitted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Gabung ${match.title}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Mode Cari Lawan: daftarkan tim/kelompok kamu.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: teamCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Tim/Kelompok',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: memberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Anggota',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final name = teamCtrl.text.trim();
                    final count = int.tryParse(memberCtrl.text.trim()) ?? 0;
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama tim/kelompok wajib diisi.')),
                      );
                      return;
                    }
                    if (count < 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Jumlah anggota tidak valid.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A32A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Gabung Tim'),
                ),
              ),
            ],
          ),
        ),
      );
      if (submitted != true || !mounted) return;
      teamName = teamCtrl.text.trim();
      memberCount = int.tryParse(memberCtrl.text.trim()) ?? 1;
    } else {
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'Konfirmasi Join',
        message: 'Yakin ingin bergabung ke open match "${match.title}"?',
        icon: Icons.group_add_outlined,
        confirmLabel: 'Ya, Gabung',
      );
      if (!confirmed || !mounted) return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    showAppLoadingDialog(context, message: 'Mendaftarkan kamu...');

    Map<String, dynamic> result;
    try {
      result = await MatchApi.joinMatch(
        match.id,
        teamName: teamName,
        memberCount: memberCount,
      );
    } catch (e) {
      result = {'success': false, 'message': 'Gagal bergabung: $e'};
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _joinedMatchIds = {..._joinedMatchIds, match.id});
      await _reloadMatchData(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Expanded(child: Text('Berhasil bergabung ke open match.')),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                child: const Text(
                  'Masuk Grup Chat',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      final message = result['message']?.toString() ?? 'Gagal bergabung ke match.';
      final alreadyJoined = message.toLowerCase().contains('sudah bergabung');
      if (alreadyJoined) {
        setState(() => _joinedMatchIds = {..._joinedMatchIds, match.id});
        await _reloadMatchData(force: true);
      }
      if (!mounted) return;
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
          "Event",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isGuest)
            TextButton.icon(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
                );
                if (created == true && mounted) _refreshData(force: true);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00A32A)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00A32A)),
            onPressed: _isGuest ? null : () => _refreshData(force: true),
          ),
        ],
      ),
      body: _isCheckingSession
          ? const Center(child: CircularProgressIndicator())
          : GuestAccessOverlay(
              isGuest: _isGuest,
              message: 'Login untuk melihat dan bergabung ke Event.',
              child: Column(
                children: [
                  _buildEventTabs(),
                  Expanded(
                    child: FutureBuilder<List<MatchModel>>(
                      future: futureMatches,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                                  onPressed: () => _refreshData(force: true),
                                  child: const Text("Coba Lagi"),
                                ),
                              ],
                            ),
                          );
                        }

                        final matches = _filteredEvents(snapshot.data ?? []);
                        if (matches.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _selectedEventType == 'open_match'
                                    ? 'Belum ada Open Match.\nTap "Tambah" untuk membuat open match dari booking yang sudah lunas.'
                                    : 'Belum ada Turnamen dari Admin.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async => _refreshData(force: true),
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
                ],
              ),
            ),
    );
  }

  Widget _matchCard(MatchModel match) {
    bool isFull = match.jumlahBergabung >= match.jumlahPemain;
    bool isJoined = match.joined || match.isRegistered || _joinedMatchIds.contains(match.id);
    bool isCreator = match.isHost || _createdMatchIds.contains(match.id);
    bool isStarted = _eventStarted(match);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _eventTypeBadge(match.eventType),
                                if (match.isOpenMatch) _modeBadge(match.modeLabel),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      match.isTournament
                                          ? Icons.verified_user_outlined
                                          : Icons.person_outline,
                                      size: 14,
                                      color: Colors.blueGrey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      match.organizer,
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.stadium_outlined,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    match.fieldName.isEmpty
                                        ? 'Lapangan belum ditentukan'
                                        : match.fieldName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  match.jenis,
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${match.tanggal.length >= 10 ? match.tanggal.substring(0, 10) : match.tanggal} • ${match.startTime} - ${match.endTime}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (match.isTournament) ...[
                              const SizedBox(height: 2),
                              Text(
                                "Biaya: ${match.registrationFee == 0 ? 'GRATIS' : 'Rp ${match.registrationFee}'} • ${match.prize.isEmpty ? 'Turnamen resmi' : match.prize}",
                                style: const TextStyle(
                                  color: Color(0xFF1E2A2B),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(isFull, isStarted, match),
                    ],
                  ),
                  const Divider(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isFull || isJoined || isCreator || isStarted)
                          ? null
                          : () => match.isTournament ? _handleEventRegister(match) : _handleJoin(match),
                      icon: Icon(
                        isCreator
                            ? Icons.workspace_premium_rounded
                            : (isJoined
                                  ? Icons.check_circle_outline
                                  : (isStarted
                                        ? Icons.block_rounded
                                        : Icons.group_add_outlined)),
                        size: 18,
                      ),
                      label: Text(
                        isCreator
                            ? 'ANDA PEMBUAT MATCH'
                            : (isJoined
                                  ? (match.isTournament ? 'SUDAH TERDAFTAR' : 'SUDAH BERGABUNG')
                                  : (isStarted
                                        ? (match.isTournament ? 'TURNAMEN SUDAH DIMULAI' : 'MATCH SUDAH DIMULAI')
                                        : (isFull
                                              ? (match.isTournament ? 'KUOTA PENUH' : 'MATCH PENUH')
                                              : (match.isTournament ? 'DAFTAR TURNAMEN' : 'BERGABUNG DI MATCH')))),
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
                    child: OutlinedButton.icon(
                      onPressed: () => _showMatchDetail(match),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Detail & Lokasi'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF168653), side: const BorderSide(color: Color(0xFF168653))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: match.isTournament
                        ? ElevatedButton.icon(
                            onPressed: () async {
                              final waUrl = match.contactWhatsapp.isNotEmpty
                                  ? 'https://wa.me/${match.contactWhatsapp}'
                                  : '';
                              if (waUrl.isEmpty) {
                                showAppInfoDialog(
                                  context,
                                  title: 'WhatsApp Tidak Tersedia',
                                  message:
                                      'Nomor WhatsApp penyelenggara belum tersedia untuk turnamen ini.',
                                  icon: Icons.info_outline_rounded,
                                  accent: const Color(0xFFF59E0B),
                                );
                                return;
                              }
                              await _openExternal(waUrl);
                            },
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text(
                              'HUBUNGI PENYELENGGARA',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              final canAccessChat = isJoined || isCreator || match.chatAvailable;
                              if (!canAccessChat) {
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
                              (isJoined || isCreator || match.chatAvailable)
                                  ? Icons.forum_outlined
                                  : Icons.lock_outline,
                              size: 18,
                            ),
                            label: Text(
                              (isJoined || isCreator || match.chatAvailable)
                                  ? 'MASUK GRUP CHAT'
                                  : 'MASUK GRUP CHAT (BERGABUNG DULU)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (isJoined || isCreator || match.chatAvailable)
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


  Widget _buildStatusBadge(bool isFull, bool isStarted, MatchModel match) {
    final statusLabel = isStarted ? 'MULAI' : (isFull ? 'PENUH' : (match.statusLabel.isNotEmpty ? match.statusLabel.toUpperCase() : 'OPEN'));
    final color = isStarted || isFull ? Colors.orange : const Color(0xFF00A32A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${match.jumlahBergabung}/${match.jumlahPemain}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          match.capacityLabel,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        Text(
          statusLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _eventTypeBadge(String eventType) {
    final isTournament = eventType == 'tournament';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isTournament ? const Color(0xFFFFF7D6) : const Color(0xFFE8F5EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isTournament ? 'TURNAMEN' : 'OPEN MATCH',
        style: TextStyle(
          color: isTournament ? Colors.amber.shade800 : const Color(0xFF00A32A),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _modeBadge(String label) {
    final isCariLawan = label.toLowerCase().contains('lawan');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCariLawan ? const Color(0xFFFFE8E8) : const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isCariLawan ? Colors.red.shade700 : Colors.blue.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
