import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/field_model.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/areno_logo.dart';
import 'detail_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;

  static const List<String> _quickCommands = [
    'Info lapangan',
    'Harga lapangan',
    'Cara booking',
    'Pembayaran',
    'Poin dan reward',
    'Open match',
  ];

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Halo! Saya Arena Assistant. Saya bisa membantu info lapangan, harga, '
      'fasilitas, jadwal, booking, pembayaran, poin, dan open match.',
    );
    _detectLocation(silent: true);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(
    String text, {
    List<Map<String, dynamic>> courts = const [],
  }) {
    _messages.add(
      ChatMessage(
        text: text,
        isUser: false,
        time: DateTime.now(),
        courts: courts,
      ),
    );
  }

  void _addUserMessage(String text) {
    _messages.add(ChatMessage(text: text, isUser: true, time: DateTime.now()));
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _detectLocation({bool silent = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent && mounted) {
          _showSnackBar(
            'Aktifkan layanan lokasi untuk mencari venue terdekat.',
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !silent) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          _showSnackBar('Izin lokasi tidak diberikan.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (!silent) {
        _showSnackBar(
          'Lokasi aktif. Venue terdekat akan dipertimbangkan.',
          const Color(0xFF00A32A),
        );
      }
    } on TimeoutException {
      if (!silent && mounted) _showSnackBar('Waktu mendapatkan lokasi habis.');
    } catch (_) {
      if (!silent && mounted) {
        _showSnackBar('Lokasi tidak dapat diambil. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || _isTyping) return;

    _addUserMessage(message);
    _inputController.clear();
    setState(() => _isTyping = true);
    await _scrollToBottom();

    try {
      final data = await ApiService.instance.chatbot(
        message,
        latitude: _latitude,
        longitude: _longitude,
      );

      final reply = (data['reply'] ?? data['answer'] ?? data['message'] ?? data['response'])
          ?.toString()
          .trim();
      final courtsRaw = data['courts'] ?? data['venues'] ?? data['data'];
      final courts = (courtsRaw is List ? courtsRaw : const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;
      setState(() {
        _addBotMessage(
          reply == null || reply.isEmpty
              ? 'Maaf, saya belum memahami pertanyaan itu.'
              : reply,
          courts: courts,
        );
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _addBotMessage(
          e is ApiException
              ? e.message
              : 'Maaf, asisten sedang tidak dapat dihubungi. Coba lagi nanti.',
        );
        _isTyping = false;
      });
    }
    await _scrollToBottom();
  }

  void _openVenue(Map<String, dynamic> court) {
    final venueId = (court['venue_id'] as num?)?.toInt();
    if (venueId == null) {
      _showSnackBar('Detail venue tidak tersedia untuk lapangan ini.');
      return;
    }

    final field = FieldModel(
      id: venueId,
      name: court['venue_name']?.toString() ?? 'Venue ArenaSports',
      type: court['type']?.toString() ?? 'Umum',
      price: (court['price'] as num?)?.toInt() ?? 0,
      imageUrl: court['image_url']?.toString(),
      address: court['venue_address']?.toString(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailScreen(field: field)),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _showSnackBar(String message, [Color color = Colors.red]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ArenoLogo(size: 36, animate: true),
            const SizedBox(width: 10),
            const Text(
              'Areno - Asisten Virtual',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _latitude == null ? 'Aktifkan lokasi' : 'Perbarui lokasi',
            onPressed: _isLocating ? null : () => _detectLocation(),
            icon: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _latitude == null
                        ? Icons.location_off_outlined
                        : Icons.location_on,
                  ),
          ),
        ],
        backgroundColor: const Color(0xFF00A32A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingBubble();
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          _buildRecommendedCommands(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: msg.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              color: msg.isUser
                  ? const Color(0xFF00A32A)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
          if (msg.courts.isNotEmpty)
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                itemCount: msg.courts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _buildCourtCard(msg.courts[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    final name = court['name']?.toString() ?? 'Lapangan';
    final venueName = court['venue_name']?.toString();
    final type = court['type']?.toString() ?? 'Umum';
    final price = (court['price'] as num?)?.toInt() ?? 0;
    final distance = (court['distance_km'] as num?)?.toDouble();
    final image = court['image_url']?.toString();

    return InkWell(
      onTap: () => _openVenue(court),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                image,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: _courtPlaceholder(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (venueName != null && venueName.isNotEmpty)
                    Text(
                      venueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  Text(type, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${_formatPrice(price)}/jam',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A32A),
                    ),
                  ),
                  if (distance != null)
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courtPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFFE6F5EA),
      child: const Icon(Icons.sports_soccer, color: Color(0xFF00A32A)),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF00A32A)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Areno mengetik...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCommands() {
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _quickCommands.length,
        itemBuilder: (context, i) {
          final command = _quickCommands[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                command,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              avatar: const Icon(
                Icons.sports_outlined,
                size: 16,
                color: Color(0xFF00A32A),
              ),
              backgroundColor: Colors.grey.shade100,
              onPressed: () => _sendMessage(command),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Ketik pertanyaan...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF00A32A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _isTyping
                    ? null
                    : () => _sendMessage(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final List<Map<String, dynamic>> courts;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.courts = const [],
  });
}
