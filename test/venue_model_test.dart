import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/models/booking_model.dart';
import 'package:penyewaan_lapangan/models/field_model.dart';

void main() {
  test('detail venue memetakan ulasan dan seluruh foto', () {
    final venue = FieldModel.fromJson({
      'id': 1,
      'name': 'Arena Sports',
      'photo_url': 'https://example.com/venue.jpg',
      'gallery': ['https://example.com/venue-1.jpg'],
      'rating': 4.5,
      'review_count': 1,
      'courts': [
        {
          'id': 11,
          'name': 'Lapangan A',
          'image_url': 'https://example.com/court.jpg',
          'gallery_images': ['https://example.com/court-1.jpg'],
          'rating_average': 5,
          'review_count': 1,
          'reviews': [
            {
              'id': 3,
              'rating': 5,
              'message': 'Mantap',
              'reply_message': 'Terima kasih',
              'user_name': 'Andi',
              'created_at': '2026-11-10T10:00:00Z',
            },
          ],
        },
      ],
    });

    expect(venue.allImages, [
      'https://example.com/venue.jpg',
      'https://example.com/venue-1.jpg',
    ]);
    expect(venue.reviews, hasLength(1));
    expect(venue.reviews.first.userName, 'Andi');
    expect(venue.reviews.first.replyMessage, 'Terima kasih');
    expect(venue.averageReviewRating, 5);
  });

  test('riwayat booking memakai foto utama dan galeri lapangan', () {
    final booking = BookingModel.fromJson({
      'id': 7,
      'court': {
        'id': 11,
        'image_url': 'https://example.com/court.jpg',
        'gallery_images': [
          'https://example.com/court-1.jpg',
          'https://example.com/court-2.jpg',
        ],
        'venue_name': 'Arena Sports',
        'venue_address': 'Jakarta Utara',
      },
    });

    expect(booking.galleryImages, hasLength(3));
    expect(booking.venueAddress, 'Jakarta Utara');
  });
}
