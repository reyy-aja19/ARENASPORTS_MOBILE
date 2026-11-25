import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/match_api.dart';
import '../services/session_service.dart';
import '../widgets/app_network_image.dart';

class ChatScreen extends StatefulWidget {
  final int matchId;
  final String matchTitle;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.matchTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchChatInitial();
    // Ambil pesan baru setiap 10 detik tanpa memuat ulang seluruh daftar.
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchChatSilent();
    });
  }

  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final id = await SessionService.userId();
    if (!mounted) return;
    setState(() => _currentUserId = id);
  }

  Future<void> _fetchChatInitial() async {
    try {
      final data = await MatchApi.fetchMessages(widget.matchId);
      if (!mounted) return;
      setState(() {
        _messages = data;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar("Gagal memuat chat: $e", Colors.red);
    }
  }

  Future<void> _fetchChatSilent() async {
    if (_isLoading) return;
    try {
      final lastId = _messages.isEmpty
          ? 0
          : (_messages.last['id'] as num?)?.toInt() ?? 0;
      final data = await MatchApi.fetchMessages(widget.matchId, after: lastId);
      if (!mounted || data.isEmpty) return;
      setState(() {
        _messages = [..._messages, ...data];
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Gagal sinkronisasi chat otomatis: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);
    final success = await MatchApi.sendMessage(widget.matchId, text);
    if (!mounted) return;
    setState(() => _isSending = false);
    if (success) {
      await _fetchChatSilent();
    } else {
      _showSnackBar("Pesan gagal dikirim", Colors.red);
    }
  }

  Future<void> _handleAttachment() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isSending = true);
    final success = await MatchApi.sendMessage(
      widget.matchId,
      '',
      attachmentPath: picked.path,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (success) {
      await _fetchChatSilent();
    } else {
      _showSnackBar("Gambar gagal dikirim", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.matchTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const Text(
              "Grup Koordinasi Match",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A32A)),
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            "Belum ada obrolan.\nYuk, sapa anggota match lainnya! 👋",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(15),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final chat = _messages[index];
                            final senderId =
                                (chat['user_id'] as num?)?.toInt() ?? 0;
                            final senderName =
                                chat['user_name']?.toString() ?? 'Anonim';
                            final text = chat['message']?.toString() ?? '';
                            final attachment =
                                chat['attachment_url']?.toString();
                            final isMe =
                                _currentUserId != null &&
                                senderId == _currentUserId;

                            return _buildChatBubble(
                              senderName,
                              text,
                              attachment,
                              isMe,
                            );
                          },
                        ),
                ),
                _buildChatInput(),
              ],
            ),
    );
  }

  Widget _buildChatBubble(
    String sender,
    String text,
    String? attachment,
    bool isMe,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF00A32A) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                sender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF00A32A),
                ),
              ),
            if (!isMe) const SizedBox(height: 3),
            if (attachment != null && attachment.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppNetworkImage(
                  attachment,
                  width: 200,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.broken_image_outlined,
                ),
              ),
              if (text.isNotEmpty) const SizedBox(height: 6),
            ],
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _isSending ? null : _handleAttachment,
              icon: const Icon(
                Icons.attach_file_rounded,
                color: Color(0xFF00A32A),
              ),
              tooltip: 'Kirim gambar',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Tulis pesan di sini...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: const Color(0xFFF4F6F8),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF00A32A),
              radius: 22,
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _isSending ? null : _handleSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
