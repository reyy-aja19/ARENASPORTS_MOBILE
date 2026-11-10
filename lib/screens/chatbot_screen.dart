import 'package:flutter/material.dart';

import '../services/local_app_data_service.dart';
import '../widgets/areno_logo.dart';

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

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Halo! Mau main olahraga apa hari ini? ⚽🏸 '
      'Areno siap bantu cari lapangan, cek jadwal, atau bantuan booking.',
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    _messages.add(ChatMessage(text: text, isUser: false, time: DateTime.now()));
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;
    _addUserMessage(text);
    _inputController.clear();
    setState(() => _isTyping = true);
    await _scrollToBottom();

    final response = _generateResponse(text);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _addBotMessage(response);
      _isTyping = false;
    });
    await _scrollToBottom();
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // ---------------- AI response logic (rule-based) ----------------

  String _generateResponse(String text) {
    final q = text.toLowerCase().trim();

    // Greeting
    if (_isGreeting(q)) {
      return 'Halo! Mau main olahraga apa hari ini? ⚽🏸 '
          'Areno siap bantu cari lapangan, cek jadwal, atau bantuan booking.';
    }

    // Help / capabilities
    if (q.contains('bantu') ||
        q.contains('help') ||
        q.contains('apa aja') ||
        q.contains('bisa apa')) {
      return _helpResponse();
    }

    // List all fields
    if (q.contains('lapangan') || q.contains('venue') || q.contains('cari')) {
      return _fieldsResponse(q);
    }

    // Price / tarif
    if (q.contains('harga') ||
        q.contains('tarif') ||
        q.contains('biaya') ||
        q.contains('price')) {
      return _priceResponse();
    }

    // Facilities
    if (q.contains('fasilitas') ||
        q.contains('fasilit') ||
        q.contains('ac') ||
        q.contains('parkir') ||
        q.contains('kantin')) {
      return _facilitiesResponse();
    }

    // Schedule / availability
    if (q.contains('jadwal') ||
        q.contains('tersedia') ||
        q.contains('kosong') ||
        q.contains('available') ||
        q.contains('waktu')) {
      return _scheduleResponse();
    }

    // Booking process
    if (q.contains('booking') ||
        q.contains('pesan') ||
        q.contains('order') ||
        q.contains('daftar') ||
        q.contains('cara')) {
      return _bookingResponse();
    }

    // Payment
    if (q.contains('bayar') ||
        q.contains('pembayaran') ||
        q.contains('qris') ||
        q.contains('transfer') ||
        q.contains('e-wallet') ||
        q.contains('dompet')) {
      return _paymentResponse();
    }

    // Cancellation / refund
    if (q.contains('batal') ||
        q.contains('refund') ||
        q.contains('kembali') ||
        q.contains('cancel')) {
      return _cancellationResponse();
    }

    // Location / address
    if (q.contains('lokasi') ||
        q.contains('alamat') ||
        q.contains('dimana') ||
        q.contains('mana')) {
      return _locationResponse();
    }

    // Escalation / CS
    if (q.contains('admin') ||
        q.contains('cs') ||
        q.contains('customer') ||
        q.contains('keluhan') ||
        q.contains('masalah') ||
        q.contains('error') ||
        q.contains('stuck')) {
      return _escalationResponse();
    }

    // Thank you
    if (q.contains('terima') || q.contains('thanks') || q.contains('makasih')) {
      return 'Sama-sama! Mau main lagi kapan? Areno siap bantu kapan saja. ⚽🏸';
    }

    // Default / out of scope
    return 'Maaf, Areno belum paham pertanyaan itu. '
        'Areno bisa bantu soal cari lapangan, cek jadwal, cara booking, pembayaran, atau pembatalan di ArenaSports. '
        'Ada yang bisa Areno bantu?';
  }

  bool _isGreeting(String q) {
    final greetings = [
      'halo',
      'hai',
      'hi',
      'selamat pagi',
      'selamat siang',
      'selamat sore',
      'selamat malam',
      'areno',
      'assalamualaikum',
    ];
    return greetings.any((g) => q.contains(g)) && q.length < 40;
  }

  String _helpResponse() {
    return '''Areno bisa bantu kamu di sini:
• Cari lapangan futsal & badminton
• Cek harga dan fasilitas lapangan
• Cek ketersediaan jadwal
• Panduan booking lapangan
• Info pembayaran (QRIS, E-Wallet, Transfer)
• Info pembatalan booking

Ketik misalnya: "cari lapangan futsal" atau "booking gimana?". Mau coba apa dulu?''';
  }

  String _fieldsResponse(String q) {
    final fields = LocalAppDataService.fields;
    String typeFilter = '';
    if (q.contains('futsal')) typeFilter = 'Futsal';
    if (q.contains('badminton')) typeFilter = 'Badminton';

    final filtered = typeFilter.isEmpty
        ? fields
        : fields
              .where((f) => f.type.toLowerCase() == typeFilter.toLowerCase())
              .toList();

    if (filtered.isEmpty) {
      return 'Maaf, belum ada lapangan ${typeFilter.isEmpty ? '' : typeFilter} di daftar Areno.';
    }

    final buffer = StringBuffer();
    buffer.write(
      'Ini daftar lapangan ${typeFilter.isEmpty ? '' : typeFilter}:\n\n',
    );
    for (final f in filtered) {
      buffer.write('• ${f.name} (${f.type})\n');
      buffer.write('  Rp ${_formatPrice(f.price)} / jam\n');
      if (f.fasilitas is List) {
        final fas = List<String>.from(f.fasilitas);
        buffer.write('  Fasilitas: ${fas.take(3).join(', ')}\n');
      }
      buffer.write('\n');
    }
    buffer.write(
      'Mau Areno amankan jadwal lapangan mana? Sebutkan nama lapangannya ya.',
    );
    return buffer.toString();
  }

  String _priceResponse() {
    final fields = LocalAppDataService.fields;
    final buffer = StringBuffer();
    buffer.write('Daftar harga sewa lapangan per jam:\n\n');
    for (final f in fields) {
      buffer.write('• ${f.name} (${f.type}): Rp ${_formatPrice(f.price)}\n');
    }
    buffer.write(
      '\nHarga bisa berbeda tiap cabang. Mau booking lapangan mana?',
    );
    return buffer.toString();
  }

  String _facilitiesResponse() {
    final fields = LocalAppDataService.fields;
    final buffer = StringBuffer();
    buffer.write('Fasilitas lapangan di ArenaSports:\n\n');
    for (final f in fields) {
      buffer.write('• ${f.name} (${f.type}): ');
      if (f.fasilitas is List) {
        buffer.write(List<String>.from(f.fasilitas).join(', '));
      } else {
        buffer.write('Tidak tersedia');
      }
      buffer.write('\n');
    }
    buffer.write('\nLapangan mana yang kamu inginkan?');
    return buffer.toString();
  }

  String _scheduleResponse() {
    return '''Areno bisa bantu cek ketersediaan jadwal.

Kamu perlu sebutkan:
• Nama lapangan
• Tanggal main
• Jam yang diinginkan

Contoh: "Cek jadwal Kelapa Gading futsal besok jam 19.00".

Kalo udah tahu jadwalnya, Areno bisa bantu langkah booking-nya. Mau coba?''';
  }

  String _bookingResponse() {
    return '''Panduan booking lapangan di ArenaSports:

1. Pilih lapangan di halaman Home.
2. Pilih tanggal dan jam main (maksimal 2 jam).
3. Klik "Konfirmasi" untuk lanjut ke pembayaran.
4. Pilih metode: Midtrans (QRIS, E-Wallet, Transfer) atau Bayar di Tempat.
5. Selesai! Booking akan masuk ke riwayat.

Mau Areno bantu cari lapangan dulu? Sebutkan jenis olahraganya.''';
  }

  String _paymentResponse() {
    return '''Opsi pembayaran di ArenaSports:

• Midtrans – QRIS, E-Wallet (GoPay, OVO, Dana, dll), Transfer Bank
• Bayar di Tempat – bayar langsung saat datang ke venue

Pembayaran via Midtrans akan diverifikasi otomatis.
Kalo ada kendala teknis pembayaran, Areno bisa arahkan ke Customer Service.

Mau booking sekarang?''';
  }

  String _cancellationResponse() {
    return '''Pembatalan booking di ArenaSports:

• Buka riwayat booking di menu "Booking".
• Pilih booking yang ingin dibatalkan.
• Klik tombol batal (jika masih bisa).

Kalo booking sudah lunas atau waktu mainnya dekat, silakan hubungi Customer Service untuk dibantu manual.

Butuh bantuan pembatalan booking tertentu? Sebutkan detailnya ya.''';
  }

  String _locationResponse() {
    final fields = LocalAppDataService.fields;
    final buffer = StringBuffer();
    buffer.write('Lokasi venue ArenaSports:\n\n');
    for (final f in fields) {
      buffer.write('• ${f.name}\n');
      buffer.write(
        '  Koordinat: ${f.latitude?.toStringAsFixed(4)}, ${f.longitude?.toStringAsFixed(4)}\n\n',
      );
    }
    buffer.write('Venue mana yang kamu pilih?');
    return buffer.toString();
  }

  String _escalationResponse() {
    return '''Kalo ada kendala teknis pembayaran atau masalah di lokasi yang butuh tindakan admin, silakan hubungi Customer Service resmi ArenaSports.

Areno tidak bisa menangani kasus yang butuh intervensi manusia langsung.

Ada yang lain yang bisa Areno bantu soal booking atau jadwal lapangan?''';
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF00A32A) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg.text,
          style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87),
        ),
      ),
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
    final commands = [
      {'label': 'Cari lapangan futsal', 'text': 'cari lapangan futsal'},
      {'label': 'Cari lapangan badminton', 'text': 'cari lapangan badminton'},
      {'label': 'Harga lapangan', 'text': 'harga lapangan'},
      {'label': 'Cara booking', 'text': 'cara booking'},
      {'label': 'Pembayaran', 'text': 'pembayaran'},
      {'label': 'Pembatalan', 'text': 'pembatalan'},
    ];
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: commands.length,
        itemBuilder: (context, i) {
          final cmd = commands[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                cmd['label']!,
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
              onPressed: () => _sendMessage(cmd['text']!),
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
              decoration: BoxDecoration(
                color: const Color(0xFF00A32A),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _sendMessage(_inputController.text),
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

  ChatMessage({required this.text, required this.isUser, required this.time});
}
