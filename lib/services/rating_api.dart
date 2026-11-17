import 'api_client.dart';
import 'api_service.dart';

/// Penilaian lapangan berbasis API Laravel.
///
/// Rating disimpan per lapangan (satu ulasan per pengguna per lapangan), dan
/// hanya dapat dikirim untuk booking yang sudah lunas/selesai.
class RatingApi {
  static Future<bool> hasRated(int bookingId) async {
    final bookings = await ApiService.instance.bookings();
    return bookings.any((booking) => booking.id == bookingId && booking.hasReview);
  }

  /// Mengirim review ke `POST /bookings/{id}/review`.
  ///
  /// Mengembalikan `true` bila berhasil dan `false` bila server menolak.
  static Future<bool> submit({
    required int fieldId,
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    try {
      await ApiService.instance.submitReview(
        bookingId,
        rating: rating,
        message: comment.trim(),
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  static Future<double> average(int fieldId) async {
    try {
      final court = await ApiService.instance.courtDetail(fieldId);
      return court.rating;
    } on ApiException {
      return 0;
    }
  }

  static Future<int> count(int fieldId) async {
    try {
      final court = await ApiService.instance.courtDetail(fieldId);
      return court.reviewCount;
    } on ApiException {
      return 0;
    }
  }

  static Future<Set<int>> getRatedBookingIds() async {
    final bookings = await ApiService.instance.bookings();
    return bookings
        .where((booking) => booking.hasReview)
        .map((booking) => booking.id)
        .toSet();
  }
}
