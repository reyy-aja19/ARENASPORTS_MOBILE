import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/models/match_model.dart';
import 'package:penyewaan_lapangan/services/local_app_data_service.dart';
import 'package:penyewaan_lapangan/services/local_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('local booking is persisted and marks its time slots occupied', () async {
    final user = await LocalAuthService.register(
      name: 'Demo User',
      email: 'demo@example.com',
      phone: '08123456789',
      password: 'Password123',
    );
    final date = DateTime.now().add(const Duration(days: 10));
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final result = await LocalAppDataService.createBooking(
      userId: user['id'] as int,
      fieldId: 2,
      date: dateString,
      startTime: '18:00',
      endTime: '20:00',
      totalPrice: 100000,
      hours: 2,
      paymentMethod: 'Midtrans Sandbox',
    );

    expect(result['status'], isTrue);
    expect(result['local_demo'], isTrue);
    expect(
      (await LocalAppDataService.getBookingHistory(
        user['id'] as int,
      )).first['payment_method'],
      'Midtrans Sandbox',
    );
    expect(
      await LocalAppDataService.getBookedSlots(fieldId: 2, date: dateString),
      ['18:00', '19:00'],
    );
    expect((await LocalAuthService.currentUser())?['points'], 20);
  });

  test('local matches can be joined and created', () async {
    await LocalAuthService.register(
      name: 'Demo User',
      email: 'demo@example.com',
      phone: '08123456789',
      password: 'Password123',
    );

    final matches = await LocalAppDataService.getMatches();
    final initialPlayers = matches.first.jumlahBergabung;
    final joinResult = await LocalAppDataService.joinMatch(matches.first.id);
    final updatedMatches = await LocalAppDataService.getMatches();

    expect(joinResult['success'], isTrue);
    expect(updatedMatches.first.jumlahBergabung, initialPlayers + 1);

    final created = await LocalAppDataService.createMatch(
      MatchModel(
        id: 0,
        title: 'Latihan Futsal Malam',
        jenis: 'Futsal',
        tanggal: '2026-12-01',
        startTime: '20:00',
        endTime: '21:00',
        jumlahPemain: 10,
        jumlahBergabung: 1,
        status: 'Open',
        deskripsi: 'Latihan bareng.',
      ),
    );

    expect(created, isTrue);
    expect(
      (await LocalAppDataService.getMatches()).any(
        (match) => match.title == 'Latihan Futsal Malam',
      ),
      isTrue,
    );
  });

  test('local reward redemption deducts and persists points', () async {
    await LocalAuthService.register(
      name: 'Demo User',
      email: 'demo@example.com',
      phone: '08123456789',
      password: 'Password123',
    );
    await LocalAuthService.updateCurrentUser({'points': 150});

    final result = await LocalAppDataService.redeemReward(1);

    expect(result['status'], isTrue);
    expect(result['current_points'], 50);
    expect((await LocalAuthService.currentUser())?['points'], 50);
  });

  test('featured field provides a three-image gallery for the detail page', () {
    final field = LocalAppDataService.fields.firstWhere(
      (item) => item.name.contains('Indramayu'),
    );

    expect(field.galleryImages.length, 3);
    expect(field.galleryImages.every((url) => url.isNotEmpty), isTrue);
  });

  test('venue court counts and court schedules are independent', () async {
    final user = await LocalAuthService.register(
      name: 'Demo User',
      email: 'courts@example.com',
      phone: '08123456789',
      password: 'Password123',
    );
    final fields = LocalAppDataService.fields;
    final kelapaGadingBadminton = fields.firstWhere(
      (field) =>
          field.name == 'Kelapa Gading Sports Indramayu' &&
          field.type == 'Badminton',
    );
    final kelapaGadingFutsal = fields.firstWhere(
      (field) =>
          field.name == 'Kelapa Gading Sports Indramayu' &&
          field.type == 'Futsal',
    );
    final futsalNci = fields.firstWhere((field) => field.name == 'Futsal NCI');
    final firstCourtId = kelapaGadingBadminton.courtIdFor(1);
    final secondCourtId = kelapaGadingBadminton.courtIdFor(2);
    final firstCourt = kelapaGadingBadminton.courtFor(1);
    final secondCourt = kelapaGadingBadminton.courtFor(2);

    expect(kelapaGadingBadminton.courtCount, 6);
    expect(kelapaGadingFutsal.courtCount, 1);
    expect(futsalNci.courtCount, 6);
    expect(firstCourtId, isNot(secondCourtId));
    expect(firstCourt.imageUrl, isNot(secondCourt.imageUrl));
    expect(firstCourt.facilities, isNot(secondCourt.facilities));
    expect(firstCourt.description, isNot(secondCourt.description));

    final result = await LocalAppDataService.createBooking(
      userId: user['id'] as int,
      fieldId: firstCourtId,
      fieldName: '${kelapaGadingBadminton.name} • Lapangan 1',
      date: '2026-11-20',
      startTime: '18:00',
      endTime: '19:00',
      totalPrice: 50000,
      hours: 1,
    );

    expect(result['status'], isTrue);
    expect(
      await LocalAppDataService.getBookedSlots(
        fieldId: firstCourtId,
        date: '2026-11-20',
      ),
      ['18:00'],
    );
    expect(
      await LocalAppDataService.getBookedSlots(
        fieldId: secondCourtId,
        date: '2026-11-20',
      ),
      isEmpty,
    );
  });
}
