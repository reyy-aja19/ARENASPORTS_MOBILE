import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import 'local_app_data_service.dart';
import 'local_auth_service.dart';

class ApiService {
  /*
  |--------------------------------------------------------------------------
  | 1. POST BOOKING (Untuk Checkout)
  |--------------------------------------------------------------------------
  |*/
  Future<Map<String, dynamic>> postBooking({
    required int userId,
    required int lapanganId,
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
    );
  }

  /*
  |--------------------------------------------------------------------------
  | 2. GET HISTORY (Untuk HistoryScreen)
  |--------------------------------------------------------------------------
  |*/
  Future<List<dynamic>> getBookingHistory(int userId) async {
    return LocalAppDataService.getBookingHistory(userId);
  }

  /*
  |--------------------------------------------------------------------------
  | 3. GET BOOKED SLOTS (Untuk Warnain Jam Merah)
  |--------------------------------------------------------------------------
  |*/
  Future<List<String>> getBookedSlots(int lapanganId, String tanggal) async {
    return LocalAppDataService.getBookedSlots(
      fieldId: lapanganId,
      date: tanggal,
    );
  }

  /*
  |--------------------------------------------------------------------------
  | POST CREATE OPEN MATCH
  |--------------------------------------------------------------------------
  |*/
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
    return {
      'status': created,
      'message': created ? 'Match berhasil dibuat.' : 'Gagal membuat match.',
    };
  }

  /*
  |--------------------------------------------------------------------------
  | 4. REWARDS MANAGEMENT (Untuk PointScreen)
  |--------------------------------------------------------------------------
  |*/

  /// Ambil daftar reward dari database Laravel
  Future<Map<String, dynamic>> getRewards() async {
    return LocalAppDataService.getRewards();
  }

  /// Post klaim penukaran reward ke backend Laravel
  Future<Map<String, dynamic>> redeemReward({required int rewardId}) async {
    return LocalAppDataService.redeemReward(rewardId);
  }

  // Tambahkan di dalam class ApiService
  Future<Map<String, dynamic>?> getUserProfile() async {
    return LocalAuthService.currentUser();
  }
}
