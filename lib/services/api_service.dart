import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_model.dart';
import 'local_app_data_service.dart';
import 'local_auth_service.dart';

class ApiService {
  Future<Map<String, dynamic>> postBooking({
    required int userId,
    required int lapanganId,
    required String fieldName,
    required String paymentMethod,
    required String date,
    required String startTime,
    required String endTime,
    required double totalPrice,
    required int hours,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      return {
        'status': false,
        'message': 'Login terlebih dahulu untuk membuat booking.',
      };
    }
    return LocalAppDataService.createBooking(
      userId: userId,
      fieldId: lapanganId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      hours: hours,
      paymentMethod: paymentMethod,
      fieldName: fieldName,
    );
  }

  Future<List<dynamic>> getBookingHistory(int userId) async {
    return LocalAppDataService.getBookingHistory(userId);
  }

  Future<List<String>> getBookedSlots(int lapanganId, String tanggal) async {
    return LocalAppDataService.getBookedSlots(
      fieldId: lapanganId,
      date: tanggal,
    );
  }

  Future<Map<String, dynamic>> createOpenMatch({
    required int bookingId,
    required String title,
    required String jenis,
    required String tanggal,
    required int jumlahPemain,
    String? startTime,
    String? endTime,
    String? deskripsi,
  }) async {
    final created = await LocalAppDataService.createMatch(
      MatchModel(
        id: bookingId,
        title: title,
        jenis: jenis,
        tanggal: tanggal,
        startTime: startTime ?? '',
        endTime: endTime ?? '',
        jumlahPemain: jumlahPemain,
        jumlahBergabung: 1,
        status: 'Open',
        deskripsi: deskripsi ?? '',
      ),
    );
    final success = created > 0;
    return {
      'status': success,
      'message': success ? 'Match berhasil dibuat.' : 'Gagal membuat match.',
    };
  }

  Future<Map<String, dynamic>> getRewards() async {
    return LocalAppDataService.getRewards();
  }

  Future<Map<String, dynamic>> redeemReward({required int rewardId}) async {
    return LocalAppDataService.redeemReward(rewardId);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    return LocalAuthService.currentUser();
  }
}
