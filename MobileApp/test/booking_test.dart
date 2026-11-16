import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rideflow_mobile/app/theme.dart';
import 'package:rideflow_mobile/features/passenger/booking_fields.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/features/passenger/booking_controller.dart';
import 'package:rideflow_mobile/shared/models.dart';

// Explicit deterministic test fixtures; never used by the application at runtime.
RouteQuote quoteFixture(String currency, {String id = 'test-quote'}) =>
    RouteQuote(
      id: id,
      currency: currency,
      points: [demoPlaces[0].point, demoPlaces[1].point],
      metres: 3700,
      seconds: 480,
      available: true,
      minimumCents: currency == 'USD' ? 200 : 4000,
      maximumCents: currency == 'USD' ? 10000 : 200000,
      suggestedCents: currency == 'USD' ? 425 : 8500,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

class BookingRepositoryFixture extends DemoRepository {
  bool noRoute = false, noExchange = false, failBooking = false;
  final calls = <String>[];
  final keys = <String?>[];
  final currencies = <String>[];
  Completer<void>? requestWait;
  Future<RouteQuote?> Function(String)? quoteHandler;
  @override
  Future<RouteQuote?> quote(
    Place pickup,
    Place destination,
    String category, {
    String currency = 'USD',
  }) async {
    calls.add('$category:$currency');
    if (noExchange && currency == 'ZWG') {
      throw StateError('A current verified USD/ZiG rate is unavailable.');
    }
    if (quoteHandler != null) {
      return quoteHandler!(currency);
    }
    return noRoute ? null : quoteFixture(currency);
  }

  @override
  Future<Ride> request(
    Place pickup,
    Place destination,
    String category,
    int cents, {
    String? paymentMethod,
    String currency = 'USD',
    String? quoteId,
    String? requestKey,
  }) async {
    keys.add(requestKey);
    currencies.add(currency);
    if (requestWait != null) {
      await requestWait!.future;
    }
    if (failBooking) {
      throw StateError('Connection interrupted');
    }
    return super.request(
      pickup,
      destination,
      category,
      cents,
      paymentMethod: paymentMethod,
      currency: currency,
      quoteId: quoteId,
      requestKey: requestKey,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  TestWidgetsFlutterBinding.ensureInitialized();
  late BookingRepositoryFixture repo;
  late AppController app;
  late BookingController draft;
  setUp(() async {
    repo = BookingRepositoryFixture();
    app = AppController(repo);
    await app.verify('+263771234567', '123456');
    await app.updateProfile('Test', 'Passenger', '');
    draft = BookingController(app);
    await draft.loadConfiguration();
  });
  tearDown(() {
    draft.dispose();
    app.dispose();
  });
  Future<void> route() =>
      draft.setPlaces(pickup: demoPlaces[0], destination: demoPlaces[1]);

  test(
    'A road quote fills the fare and manual editing survives unrelated changes',
    () async {
      await route();
      expect(draft.fare.text, '4.25');
      expect(draft.canSubmit, isTrue);
      draft.fare.text = '4.00';
      draft.editFare('4.00');
      app.notifyListeners();
      draft.setPayment(draft.methods.firstWhere((m) => m.id == 'cash-usd'));
      expect(draft.fare.text, '4.00');
      expect(await draft.submit(), isTrue);
      expect(app.ride!.cents, 400);
      expect(app.ride!.paymentStatus, 'pending_cash');
    },
  );
  test('Route and vehicle changes recalculate and explain the cleared manual offer', () async {
    await route();
    draft.fare.text = '6.00';
    draft.editFare('6.00');
    await draft.setPlaces(destination: demoPlaces[2]);
    expect(draft.fare.text, '4.25');
    expect(draft.notice, contains('previous offer was cleared'));
    await draft.setCategory('Comfort');
    expect(repo.calls.last, 'Comfort:USD');
  });
  test('Only USD and three direct-payment preferences are available', () async {
    await route();
    await draft.setCurrency('ZWG');
    expect(draft.currency, 'USD');
    expect(draft.methods.map((m) => m.name), ['EcoCash', 'OneMoney', 'Cash']);
    for (final method in draft.methods) {
      draft.setPayment(method);
      expect(draft.paymentError, isNull);
      expect(draft.canSubmit, isTrue);
    }
  });
  test('Invalid precision, nonpositive values and platform offer limits disable submission', () async {
    await route();
    for (final value in ['0', '-1', '1.001', 'NaN', '1.99', '100.01']) {
      draft.fare.text = value;
      draft.editFare(value);
      expect(draft.canSubmit, isFalse, reason: value);
    }
  });
  test(
    'Late quote responses cannot overwrite a newer route or currency',
    () async {
      final first = Completer<RouteQuote?>(), second = Completer<RouteQuote?>();
      var count = 0;
      repo.quoteHandler = (_) => count++ == 0 ? first.future : second.future;
      final old = route();
      final newer = draft.setCategory('XL');
      second.complete(quoteFixture('USD', id: 'new'));
      await newer;
      draft.fare.text = '6.25';
      draft.editFare('6.25');
      first.complete(quoteFixture('USD', id: 'old'));
      await old;
      expect(draft.quote!.id, 'new');
      expect(draft.fare.text, '6.25');
    },
  );
  test('Double taps cannot create concurrent requests and retry retains its idempotency key', () async {
    await route();
    repo.requestWait = Completer<void>();
    final pending = draft.submit();
    expect(await draft.submit(), isFalse);
    expect(repo.keys, hasLength(1));
    repo.requestWait!.complete();
    expect(await pending, isTrue);
  });
  test(
    'An uncertain booking retry reuses the key for the same submitted payload',
    () async {
      await route();
      repo.failBooking = true;
      expect(await draft.submit(), isFalse);
      repo.failBooking = false;
      expect(await draft.submit(), isTrue);
      expect(repo.keys, hasLength(2));
      expect(repo.keys[0], repo.keys[1]);
      expect(repo.keys[0], isNotNull);
    },
  );
  testWidgets('Booking UI edits fare and submits EcoCash in USD', (
    tester,
  ) async {
    await route();
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: BookingFields(booking: draft),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '4.25',
    );
    expect(find.textContaining('ZiG'), findsNothing);
    await tester.ensureVisible(find.text('EcoCash'));
    await tester.tap(find.text('EcoCash'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '99.00');
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Request ride'));
    await tester.tap(find.text('Request ride'));
    await tester.pumpAndSettle();
    expect(app.ride!.currency, 'USD');
    expect(app.ride!.cents, 9900);
    expect(app.ride!.paymentStatus, 'pending_cash');
    expect(draft.canSubmit, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
