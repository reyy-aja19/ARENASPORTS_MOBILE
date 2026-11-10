import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/widgets/slider_captcha.dart';

void main() {
  testWidgets('slider captcha requires matching the puzzle piece', (
    tester,
  ) async {
    var verified = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SliderCaptcha(
              onVerificationChanged: (value) => verified = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Drag To Verify'), findsOneWidget);
    expect(find.byKey(const Key('slider-captcha-image')), findsOneWidget);
    expect(verified, isFalse);

    final track = tester.getRect(find.byKey(const Key('slider-captcha-track')));
    await tester.drag(
      find.byKey(const Key('slider-captcha-track')),
      Offset(track.width * 0.4, 0),
    );
    await tester.pump();

    expect(find.text('Belum pas. Coba geser lagi.'), findsOneWidget);
    expect(verified, isFalse);

    await tester.tap(find.byTooltip('Muat puzzle baru'));
    await tester.pump();

    expect(find.text('Belum pas. Coba geser lagi.'), findsNothing);
    expect(verified, isFalse);
  });
}
