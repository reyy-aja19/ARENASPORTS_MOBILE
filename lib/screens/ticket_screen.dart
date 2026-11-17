import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_service.dart';

/// Tiket digital booking: menampilkan kode booking yang dipindai admin venue.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late Future<TicketData> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.ticket(widget.bookingId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        title: const Text(
          'Tiket Booking',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<TicketData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A32A)),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is ApiException
                      ? error.message
                      : 'Tiket gagal dimuat: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final ticket = snapshot.data;
          if (ticket == null) {
            return const Center(child: Text('Tiket tidak tersedia.'));
          }

          final booking = ticket.booking;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.confirmation_number_rounded,
                        size: 44,
                        color: Color(0xFF00A32A),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        booking.venueName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        booking.courtName,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/'
                          '?size=220x220&data=${Uri.encodeComponent(ticket.qrPayload)}',
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(
                                width: 200,
                                height: 200,
                                child: Icon(Icons.qr_code_2, size: 120),
                              ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'KODE TIKET',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Colors.grey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        ticket.ticketCode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Color(0xFF007A2A),
                        ),
                      ),
                      const Divider(height: 30),
                      _row(Icons.calendar_today_outlined, booking.bookingDate),
                      _row(Icons.access_time_outlined, booking.timeLabel),
                      _row(Icons.payments_outlined, 'Rp ${booking.totalPrice}'),
                      _row(Icons.info_outline, booking.statusLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tunjukkan tiket ini ke admin venue saat datang. '
                  'QR hanya berlaku untuk booking yang sudah lunas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
