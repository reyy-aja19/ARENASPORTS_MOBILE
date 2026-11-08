// Smoke test dasar untuk aplikasi ARENASPORTS.
//
// Menggantikan template "counter" bawaan Flutter yang tidak relevan dengan
// aplikasi ini.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/screens/home_screen.dart';
import 'package:penyewaan_lapangan/screens/login_screen.dart';
import 'package:penyewaan_lapangan/screens/match_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('login screen menampilkan form login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('ARENASPORTS'), findsOneWidget);
    expect(find.text('Email / No. HP'), findsOneWidget);
    expect(find.text('Masukkan Password'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('home screen menampilkan daftar venue lokal', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('Semua Venue'), findsOneWidget);
    expect(find.textContaining('Kelapa Gading Sports'), findsWidgets);
  });

  testWidgets('open match terkunci untuk guest', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MatchScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Login untuk melihat dan bergabung ke Open Match.'),
      findsOneWidget,
    );
    expect(find.text('Login'), findsOneWidget);
  });
}
