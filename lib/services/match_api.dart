import 'package:flutter/foundation.dart';

import '../models/match_model.dart';
import 'local_app_data_service.dart';

class MatchApi {
  static Future<List<MatchModel>> fetchMatches() async {
    return LocalAppDataService.getMatches();
  }

  static Future<int> createMatch(MatchModel match) async {
    return LocalAppDataService.createMatch(match);
  }

  static Future<Map<String, dynamic>> joinMatch(int matchId) async {
    return LocalAppDataService.joinMatch(matchId);
  }

  static Future<Set<int>> fetchJoinedMatchIds() async {
    return LocalAppDataService.getJoinedMatchIds();
  }

  static Future<Set<int>> fetchCreatedMatchIds() async {
    return LocalAppDataService.getCreatedMatchIds();
  }

  static Future<Set<int>> fetchBookingsWithMatch() async {
    return LocalAppDataService.getBookingsWithMatch();
  }

  static Future<List<dynamic>> fetchMessages(int matchId) async {
    return LocalAppDataService.getMessages(matchId);
  }

  static Future<bool> sendMessage(int matchId, String message) async {
    return LocalAppDataService.sendMessage(matchId, message);
  }

  /// Notifier untuk sinkronisasi data match antar halaman.
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static void bumpData() => dataRevision.value++;
}
