import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/friend_api.dart';
import '../widgets/app_dialog.dart';
import '../services/push_notification_service.dart';
import '../widgets/guest_access_overlay.dart';
import '../widgets/top_banner.dart';
import 'direct_chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _isGuest = true;
  bool _isCheckingSession = true;
  bool _isLoading = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  Set<int> _friendIds = {};
  final Map<int, Map<String, dynamic>?> _lastMessage = {};
  final Map<int, String> _requestStatus = {};
  List<Map<String, dynamic>> _incomingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    });

    if (!isGuest) await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final friends = await FriendApi.getFriends();
      final friendIds = friends.map((f) => f['id'] as int).toSet();
      final all = await FriendApi.searchUsers('');
      final incoming = await FriendApi.getIncomingRequests();

      final last = <int, Map<String, dynamic>?>{};
      final status = <int, String>{};
      for (final f in friends) {
        final id = f['id'] as int;
        final msgs = await FriendApi.getMessages(id);
        last[id] = msgs.isEmpty ? null : msgs.last;
        status[id] = 'friends';
      }
      for (final u in all) {
        final id = u['id'] as int;
        if (!status.containsKey(id)) {
          status[id] = await FriendApi.requestStatus(id);
        }
      }

      if (!mounted) return;
      setState(() {
        _friendIds = friendIds;
        _allUsers = all;
        _lastMessage.clear();
        _lastMessage.addAll(last);
        _requestStatus.clear();
        _requestStatus.addAll(status);
        _incomingRequests = incoming;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _query.trim().toLowerCase();
    final list = _allUsers.where((u) {
      if (q.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();

    list.sort((a, b) {
      final aFriend = _friendIds.contains(a['id']);
      final bFriend = _friendIds.contains(b['id']);
      if (aFriend != bFriend) return aFriend ? -1 : 1;
      final aLast = _lastMessage[a['id']]?['time']?.toString();
      final bLast = _lastMessage[b['id']]?['time']?.toString();
      if (aLast != null && bLast != null) {
        return bLast.compareTo(aLast);
      }
      if (aLast != null) return -1;
      if (bLast != null) return 1;
      return (a['name']?.toString() ?? '').compareTo(
        b['name']?.toString() ?? '',
      );
    });
    return list;
  }

  Future<void> _sendRequest(int id, String name) async {
    final status = await FriendApi.sendFriendRequest(id, name);
    await _loadData();
    if (!mounted) return;
    String msg;
    Color color;
    if (status == 'sent') {
      msg = 'Permintaan pertemanan ke $name dikirim. Menunggu persetujuan.';
      color = Colors.green;
      PushNotificationService.sendPushToUser(
        id,
        'Permintaan Pertemanan',
        'Ada permintaan pertemanan baru untuk Anda.',
      );
      PushNotificationService.showLocalNotification(
        title: 'Permintaan Terkirim',
        body: 'Permintaan pertemanan ke $name dikirim.',
      );
      showTopBanner(
        context,
        title: 'Permintaan Terkirim',
        message: 'Permintaan pertemanan ke $name dikirim.',
        icon: Icons.person_add_alt_1_rounded,
      );
    } else if (status == 'pending') {
      msg = 'Permintaan ke $name sudah dikirim sebelumnya.';
      color = Colors.orange;
    } else if (status == 'friends') {
      msg = '$name sudah menjadi teman.';
      color = Colors.green;
    } else {
      msg = 'Gagal mengirim permintaan.';
      color = Colors.red;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _acceptRequest(Map<String, dynamic> req) async {
    final requestId = req['id'] as int;
    final fromId = req['from'] as int?;
    final fromName = req['fromName']?.toString() ?? 'Pengguna';
    await FriendApi.acceptRequest(requestId);
    if (fromId != null) {
      PushNotificationService.sendPushToUser(
        fromId,
        'Permintaan Diterima',
        'Permintaan pertemanan Anda diterima.',
      );
      PushNotificationService.showLocalNotification(
        title: 'Teman Baru',
        body: '$fromName sekarang menjadi teman Anda.',
      );
    }
    await _loadData();
    if (!mounted) return;
    showTopBanner(
      context,
      title: 'Teman Baru',
      message: '$fromName sekarang menjadi teman Anda.',
      icon: Icons.people_alt_rounded,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$fromName sekarang menjadi teman Anda.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _rejectRequest(Map<String, dynamic> req) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Tolak Permintaan',
      message: 'Tolak permintaan pertemanan dari ${req['fromName']}?',
      icon: Icons.person_off_outlined,
      confirmLabel: 'Tolak',
      destructive: true,
    );
    if (!confirmed) return;
    await FriendApi.rejectRequest(req['id'] as int);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permintaan ditolak.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _removeFriend(int id, String name) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Hapus Teman',
      message: 'Hapus $name dari daftar teman?',
      icon: Icons.person_remove_outlined,
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;
    await FriendApi.removeFriend(id);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name dihapus dari teman.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    final id = user['id'] as int;
    final name = user['name']?.toString() ?? 'Teman';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(friendId: id, friendName: name),
      ),
    );
    _loadData();
  }

  Widget _avatar(String name, {double size = 46}) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00A32A), Color(0xFF0D9F4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == now.year) {
      return '${dt.day}/${dt.month}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _statusBadge(String status) {
    String label;
    Color color;
    switch (status) {
      case 'friends':
        label = 'Teman';
        color = const Color(0xFF00A32A);
        break;
      case 'pending_out':
        label = 'Menunggu';
        color = Colors.orange;
        break;
      case 'pending_in':
        label = 'Menunggu persetujuan';
        color = Colors.blue;
        break;
      default:
        label = '';
        color = Colors.grey;
    }
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Pesan",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00A32A)),
            onPressed: _isGuest ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isCheckingSession
          ? const Center(child: CircularProgressIndicator())
          : GuestAccessOverlay(
              isGuest: _isGuest,
              message: 'Login untuk chat dengan pengguna lain.',
              child: Column(
                children: [
                  if (_incomingRequests.isNotEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person_add_alt_1,
                                size: 18,
                                color: Color(0xFF00A32A),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Permintaan Pertemanan (${_incomingRequests.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E2A2B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._incomingRequests.map((req) {
                            final fromName =
                                req['fromName']?.toString() ?? 'Pengguna';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _avatar(fromName, size: 40),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      fromName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _rejectRequest(req),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    onPressed: () => _acceptRequest(req),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00A32A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Terima'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Cari pengguna...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : users.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _query.isEmpty
                                        ? 'Belum ada pengguna lain.'
                                        : 'Tidak ada pengguna yang cocok.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: users.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final u = users[i];
                                final id = u['id'] as int;
                                final name = u['name']?.toString() ?? '-';
                                final status = _requestStatus[id] ?? 'none';
                                final isFriend = status == 'friends';
                                final last = _lastMessage[id];
                                final subtitle = isFriend && last != null
                                    ? (last['text']?.toString() ?? '')
                                    : (u['email']?.toString() ?? '');

                                final tile = Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  elevation: 0,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _openChat(u),
                                    onLongPress: isFriend
                                        ? () => _removeFriend(id, name)
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          _avatar(name),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                          color: Color(
                                                            0xFF1E2A2B,
                                                          ),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    _statusBadge(status),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (status == 'none')
                                            TextButton(
                                              onPressed: () =>
                                                  _sendRequest(id, name),
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFF00A32A,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Tambah',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          else if (status == 'pending_out')
                                            Text(
                                              'Menunggu',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade700,
                                              ),
                                            )
                                          else if (status == 'pending_in')
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton(
                                                  onPressed: () {
                                                    final req =
                                                        _incomingRequests
                                                            .firstWhere(
                                                              (r) =>
                                                                  r['from'] ==
                                                                  id,
                                                              orElse: () => {},
                                                            );
                                                    if (req.isNotEmpty) {
                                                      _rejectRequest(req);
                                                    }
                                                  },
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                  ),
                                                  child: const Text('Tolak'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final req =
                                                        _incomingRequests
                                                            .firstWhere(
                                                              (r) =>
                                                                  r['from'] ==
                                                                  id,
                                                              orElse: () => {},
                                                            );
                                                    if (req.isNotEmpty) {
                                                      _acceptRequest(req);
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF00A32A),
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text('Terima'),
                                                ),
                                              ],
                                            )
                                          else if (isFriend)
                                            Text(
                                              _formatTime(
                                                last?['time']?.toString(),
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                if (isFriend) {
                                  return Dismissible(
                                    key: ValueKey('friend_$id'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (_) async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final confirmed =
                                          await showAppConfirmDialog(
                                            context,
                                            title: 'Hapus Teman',
                                            message:
                                                'Hapus $name dari daftar teman?',
                                            icon: Icons.person_remove_outlined,
                                            confirmLabel: 'Hapus',
                                            destructive: true,
                                          );
                                      if (confirmed) {
                                        await FriendApi.removeFriend(id);
                                        await _loadData();
                                        if (!mounted) return false;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '$name dihapus dari teman.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return confirmed;
                                    },
                                    child: tile,
                                  );
                                }
                                return tile;
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
