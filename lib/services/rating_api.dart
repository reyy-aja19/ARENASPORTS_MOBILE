import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_app_data_service.dart';

class RatingApi {
  static Future<int?> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  static Future<bool> hasRated(int bookingId) async {
    return LocalAppDataService.hasRatedBooking(bookingId);
  }

  static Future<bool> submit({
    required int fieldId,
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    final uid = await _currentUserId();
    if (uid == null) return false;
    return LocalAppDataService.submitRating(
      userId: uid,
      fieldId: fieldId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    );
  }

  static Future<double> average(int fieldId) async {
    return LocalAppDataService.getAverageRating(fieldId);
  }

  static Future<int> count(int fieldId) async {
    return LocalAppDataService.getRatingCount(fieldId);
  }

  static Future<Set<int>> getRatedBookingIds() async {
    final uid = await _currentUserId();
    if (uid == null) return {};
    final ratings = await LocalAppDataService.getUserRatings(uid);
    return ratings.map((r) => r['bookingId'] as int).toSet();
  }
}
