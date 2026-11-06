import 'dart:convert';

import 'package:http/http.dart' as http;

class MidtransTransaction {
  const MidtransTransaction({required this.orderId, required this.redirectUrl});

  final String orderId;
  final String redirectUrl;

  factory MidtransTransaction.fromJson(Map<String, dynamic> json) {
    return MidtransTransaction(
      orderId: json['orderId'] as String,
      redirectUrl: json['redirectUrl'] as String,
    );
  }
}

class MidtransPaymentStatus {
  const MidtransPaymentStatus({
    required this.isPaid,
    required this.transactionStatus,
  });

  final bool isPaid;
  final String transactionStatus;
}

class MidtransPaymentService {
  static const _baseUrl = String.fromEnvironment(
    'MIDTRANS_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  Future<MidtransTransaction> createTransaction({
    required int amount,
    required String itemName,
    required String customerName,
    required String customerEmail,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/payments/snap'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'amount': amount,
            'itemName': itemName,
            'customerName': customerName,
            'customerEmail': customerEmail,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final data = _decodeResponse(response);
    return MidtransTransaction.fromJson(data);
  }

  Future<MidtransPaymentStatus> checkStatus(String orderId) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/payments/$orderId/status'))
        .timeout(const Duration(seconds: 30));

    final data = _decodeResponse(response);
    return MidtransPaymentStatus(
      isPaid: data['isPaid'] == true,
      transactionStatus: data['transactionStatus']?.toString() ?? 'unknown',
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Respons backend pembayaran tidak valid.');
    }

    final data = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? 'Pembayaran gagal.');
    }
    return data;
  }
}
