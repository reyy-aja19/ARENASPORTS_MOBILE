// Smoke test dasar untuk aplikasi ARENASPORTS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/screens/login_screen.dart';
import 'package:penyewaan_lapangan/screens/match_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('login screen menampilkan form login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('ARENASPORTS'), findsOneWidget);
    expect(find.text('Email / No. HP'), findsOneWidget);
    expect(find.text('Masukkan Password'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('open match terkunci untuk guest', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MatchScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Login untuk melihat dan bergabung ke Event.'),
      findsOneWidget,
    );
    expect(find.text('Login'), findsOneWidget);
  });
}
