import '../models/match_model.dart';
import 'local_app_data_service.dart';

class MatchApi {
  /*
  |--------------------------------------------------------------------------
  | GET ALL OPEN MATCHES
  |--------------------------------------------------------------------------
  |*/
  static Future<List<MatchModel>> fetchMatches() async {
    return LocalAppDataService.getMatches();
  }

  /*
  |--------------------------------------------------------------------------
  | CREATE OPEN MATCH
  |--------------------------------------------------------------------------
  |*/
  static Future<bool> createMatch(MatchModel match) async {
    return LocalAppDataService.createMatch(match);
  }

  /*
  |--------------------------------------------------------------------------
  | JOIN AN OPEN MATCH (Menangkap Response Pesan Dinamis dari Backend)
  |--------------------------------------------------------------------------
  |*/
  static Future<Map<String, dynamic>> joinMatch(int matchId) async {
    return LocalAppDataService.joinMatch(matchId);
  }

  /*
  |--------------------------------------------------------------------------
  | AMBIL SEMUA PESAN CHAT (GET) - BARU 💬
  |--------------------------------------------------------------------------
  |*/
  static Future<List<dynamic>> fetchMessages(int matchId) async {
    return LocalAppDataService.getMessages(matchId);
  }

  /*
  |--------------------------------------------------------------------------
  | KIRIM PESAN CHAT BARU (POST) - BARU 🚀
  |--------------------------------------------------------------------------
  |*/
  static Future<bool> sendMessage(int matchId, String message) async {
    return LocalAppDataService.sendMessage(matchId, message);
  }
}