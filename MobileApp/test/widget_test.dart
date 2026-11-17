import 'support/fixture_repository.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideflow_mobile/features/passenger/home.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/app/theme.dart';
import 'package:rideflow_mobile/features/entry/entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('Onboarding swipes and persists completion', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(TestRepository());
    await app.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: Onboarding(app: app),
      ),
    );
    expect(find.text('Move Freely.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your Fare.\nYour Choice.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(app.onboarded, isTrue);
    final reopened = AppController(TestRepository());
    await reopened.initialize();
    expect(reopened.onboarded, isTrue);
    reopened.dispose();
    app.dispose();
  });
  testWidgets('Phone validation rejects incomplete Zimbabwe number', (
    tester,
  ) async {
    final app = AppController(TestRepository());
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: AuthScreen(app: app),
      ),
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a 9-digit Zimbabwean number.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets(
    'Passenger home stays usable on a small phone with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(TestRepository());
      await app.verify('+263771234567', '123456');
      await app.updateProfile('Tariro', 'Test', '');
      await tester.pumpWidget(
        MaterialApp(
          theme: triviaTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
              size: Size(320, 640),
            ),
            child: Scaffold(body: PassengerHome(app: app)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Where to, Tariro?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
