import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/app/theme.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/features/entry/entry.dart';

const paths = [
  'assets/images/onboarding/trivia_onboarding_1.png',
  'assets/images/onboarding/trivia_onboarding_2.png',
  'assets/images/onboarding/trivia_onboarding_3.png',
];
const descriptions = [
  'Discover a smarter way to travel around your city.',
  'Propose a fare and choose from available driver offers.',
  'Connect with drivers and experience flexible, convenient travel with Trivia.',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the bundled production font so text-fit checks use real glyph metrics.
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });

  test('All three supplied photographs are bundled and decode', () async {
    for (final path in paths) {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1200);
      expect(frame.image.height, 750);
      frame.image.dispose();
      codec.dispose();
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ]) {
    testWidgets(
      'Photographs and complete descriptions fit ${size.width}×${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = AppController(DemoRepository());
        await tester.pumpWidget(
          MaterialApp(
            theme: triviaTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 47, bottom: 34),
              ),
              child: Onboarding(app: app),
            ),
          ),
        );
        final photoSizes = <Size>[];
        for (var i = 0; i < 3; i++) {
          await tester.pumpAndSettle();
          final imageFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == paths[i],
          );
          expect(imageFinder, findsOneWidget);
          final image = tester.widget<Image>(imageFinder);
          expect(image.fit, BoxFit.cover);
          final clip = tester.widget<ClipRRect>(
            find
                .ancestor(of: imageFinder, matching: find.byType(ClipRRect))
                .first,
          );
          expect(clip.borderRadius, BorderRadius.circular(12));
          final photo = tester.getRect(imageFinder);
          expect(photo.width / photo.height, closeTo(1.65, 0.001));
          expect(photo.left, 24);
          expect(photo.right, size.width - 24);
          final heading = tester.getRect(
            find.text(
              i == 0
                  ? 'Move Freely.'
                  : i == 1
                  ? 'Your Fare.\nYour Choice.'
                  : 'Your Journey.\nYour Choice.',
            ),
          );
          expect(photo.left, heading.left);
          expect(photo.left, tester.getRect(find.text(descriptions[i])).left);
          expect(photo.top - tester.getRect(find.byType(PageView)).top, 40);
          final label = tester.getRect(
            find.text('0${i + 1} / YOUR NEXT CHAPTER'),
          );
          expect(label.top - photo.bottom, closeTo(24, 0.001));
          expect(heading.top - label.bottom, closeTo(16, 0.001));
          photoSizes.add(tester.getSize(imageFinder));
          await tester.ensureVisible(find.text(descriptions[i]));
          await tester.pumpAndSettle();
          final description = tester.getRect(find.text(descriptions[i]));
          final footer = tester.getRect(
            find.text(i == 2 ? 'Get started' : 'Next'),
          );
          // The entire description is above the fixed indicators/button area.
          expect(description.bottom, lessThan(footer.top - 24));
          expect(tester.takeException(), isNull);
          if (i < 2) {
            await tester.tap(find.text('Next'));
          }
        }
        expect(photoSizes.toSet(), hasLength(1));
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();
        expect(app.onboarded, isTrue);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      },
    );
  }

  testWidgets('Swipe back and Skip preserve the existing completion flow', (
    tester,
  ) async {
    final app = AppController(DemoRepository());
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: Onboarding(app: app),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your Fare.\nYour Choice.'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Move Freely.'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(app.onboarded, isTrue);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('Enlarged text scrolls without clipping the fixed controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppController(DemoRepository());
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: SizedBox(),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Onboarding(app: app),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(descriptions[i]));
      await tester.pumpAndSettle();
      expect(
        find.text(i == 2 ? 'Get started' : 'Next').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text(descriptions[i])).bottom,
        lessThan(
          tester.getRect(find.text(i == 2 ? 'Get started' : 'Next')).top,
        ),
      );
      expect(tester.takeException(), isNull);
      if (i < 2) {
        await tester.tap(find.text('Next'));
      }
    }
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
