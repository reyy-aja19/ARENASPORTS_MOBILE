import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/local_app_data_service.dart';
import '../widgets/top_banner.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final uid = await LocalAppDataService.currentUserId();
    _userId = uid;
    final list = uid == null
        ? LocalAppDataService.notifications
        : await LocalAppDataService.getNotifications(uid);
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  Future<void> _markAllRead() async {
    final uid = _userId;
    if (uid == null) return;
    await LocalAppDataService.markAllNotificationsRead(uid);
    await _load();
    if (mounted) {
      showTopBanner(
        context,
        title: 'Notifikasi dibaca',
        message: 'Semua notifikasi ditandai sudah dibaca.',
        icon: Icons.done_all_rounded,
      );
    }
  }

  Future<void> _delete(NotificationModel notif) async {
    final uid = _userId;
    if (uid == null) return;
    await LocalAppDataService.deleteNotification(uid, notif.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final uid = _userId;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus semua notifikasi?'),
        content: const Text('Semua notifikasi akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalAppDataService.clearNotifications(uid);
    await _load();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'booking':
        return Icons.event_available_rounded;
      case 'friend':
        return Icons.person_add_alt_1_rounded;
      case 'reward':
        return Icons.card_giftcard_rounded;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'booking':
        return const Color(0xFF00A32A);
      case 'friend':
        return const Color(0xFF2563EB);
      case 'reward':
        return const Color(0xFFF59E0B);
      case 'chat':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF00A32A);
    }
  }

  String _relativeTime(NotificationModel notif) {
    final now = DateTime.now();
    final diff = now.difference(notif.createdAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return notif.time;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              tooltip: 'Tandai semua dibaca',
              icon: const Icon(
                Icons.done_all_rounded,
                color: Color(0xFF00A32A),
              ),
              onPressed: _markAllRead,
            ),
            IconButton(
              tooltip: 'Hapus semua',
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              onPressed: _clearAll,
            ),
          ],
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Color(0xFF00A32A)),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada notifikasi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Notifikasi booking, pertemanan, dan reward akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final color = _colorFor(notif.type);
                        return Dismissible(
                          key: ValueKey(notif.id),
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
                          onDismissed: (_) => _delete(notif),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notif.isRead
                                    ? Colors.transparent
                                    : color.withValues(alpha: 0.25),
                                width: notif.isRead ? 0 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconFor(notif.type),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
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
                                              notif.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: const Color(0xFF1E2A2B),
                                              ),
                                            ),
                                          ),
                                          if (!notif.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.message,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _relativeTime(notif),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
