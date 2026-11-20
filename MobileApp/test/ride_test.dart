import 'dart:async';

import 'support/fixture_repository.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rideflow_mobile/shared/models.dart';
import 'package:rideflow_mobile/app/controller.dart';

class _DelayedActiveRide extends TestRepository {
  Completer<void>? hold;
  final waiting = Completer<void>();
  int reads = 0;

  @override
  Future<Ride?> activeRide() async {
    final snapshot = await super.activeRide();
    reads++;
    final pending = hold;
    hold = null;
    if (pending != null) waiting.complete();
    await pending?.future;
    return snapshot;
  }
}

class _LocationRepository extends TestRepository {
  Map<String, dynamic>? location;

  @override
  Future<void> write(String resource, Map<String, dynamic> data) async {
    expect(resource, 'drivers/me/location');
    location = data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Driver GPS uses the backend coordinate precision and rejects stale fixes', () async {
    final repo = _LocationRepository();
    final app = AppController(repo);
    addTearDown(app.dispose);
    await app.verify('+263771234567', '123456');
    app.online = true;
    Position fix(DateTime time) => Position(
      latitude: -17.822512345,
      longitude: 31.045698765,
      timestamp: time,
      accuracy: 4,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    await app.publishPosition(fix(DateTime.now().subtract(const Duration(minutes: 2))));
    expect(repo.location, isNull);
    await app.publishPosition(fix(DateTime.now()));
    expect(repo.location, {'latitude': '-17.822512', 'longitude': '31.045699'});
  });

  test('A cancellation event received during sync refreshes the terminal ride', () async {
    final repo = _DelayedActiveRide();
    final app = AppController(repo);
    addTearDown(app.dispose);
    await app.verify('+263771234567', '123456');
    await app.book(demoPlaces[0], demoPlaces[1], 'Standard', 500);
    final blocked = Completer<void>();
    repo.hold = blocked;
    final startReads = repo.reads;
    final firstSync = app.sync();
    await repo.waiting.future;
    await repo.transition(app.ride!.id, RideStatus.cancelled);
    final eventSync = app.sync();
    blocked.complete();
    await Future.wait([firstSync, eventSync]);
    expect(repo.reads - startReads, 2);
    expect(app.ride?.status, RideStatus.cancelled);
    expect(app.offers, isEmpty);
  });

  test('Fare parsing uses cents and rejects invalid input', () {
    expect(parseFare('12.3'), 1230);
    expect(parseFare('0.01'), 1);
    for (final invalid in ['0', '-1', '1.001', 'NaN', '1e3', '']) {
      expect(() => parseFare(invalid), throwsFormatException);
    }
  });
  test('OTP fails closed and driver access requires approval', () async {
    final repo = TestRepository();
    await expectLater(
      repo.verifyOtp('+263771234567', '000000'),
      throwsStateError,
    );
    await repo.verifyOtp('+263771234567', '123456');
    await expectLater(repo.availability(true), throwsStateError);
    await repo.applyDriver({}, {});
    await expectLater(repo.availability(true), throwsStateError);
    await repo.applyDriver({}, {});
    await repo.approveSimulation();
    await repo.availability(true);
    expect(await repo.requests(), isEmpty);
  });
  test(
    'Ride lifecycle prevents duplicate assignment and fixes agreed fare',
    () async {
      final repo = TestRepository();
      final r = await repo.request(
        demoPlaces[0],
        demoPlaces[1],
        'Standard',
        500,
      );
      await expectLater(
        repo.transition(r.id, RideStatus.completed),
        throwsStateError,
      );
      final offers = await repo.offers(r.id);
      final accepted = await repo.accept(r.id, offers.last.id);
      expect(accepted.cents, 600);
      await expectLater(repo.accept(r.id, offers.first.id), throwsStateError);
      for (final status in [
        RideStatus.arriving,
        RideStatus.arrived,
        RideStatus.inProgress,
        RideStatus.completed,
      ]) {
        final next = await repo.transition(r.id, status);
        expect(next.cents, 600);
      }
      expect(await repo.activeRide(), isNull);
      expect((await repo.history()).single.status, RideStatus.completed);
    },
  );
  test('Concurrent selections cannot assign two drivers', () async {
    final repo = TestRepository();
    final r = await repo.request(demoPlaces[0], demoPlaces[1], 'Standard', 500);
    final results = await Future.wait(
      ['demo-tariro', 'demo-tendai'].map((id) async {
        try {
          await repo.accept(r.id, id);
          return true;
        } catch (_) {
          return false;
        }
      }),
    );
    expect(results.where((v) => v).length, 1);
  });
  test('Demo searching request can be inspected in driver mode and logout clears state', () async {
    final app = AppController(TestRepository());
    await app.verify('+263771234567', '123456');
    await app.updateProfile('Test', 'User', '');
    await app.book(demoPlaces[0], demoPlaces[1], 'Standard', 500);
    expect(await app.switchMode(), isFalse);
    expect(app.driverMode, isFalse);
    await app.transition(RideStatus.cancelled);
    expect(await app.switchMode(), isTrue);
    await app.logout();
    expect(app.session, isNull);
    expect(app.history, isEmpty);
    app.dispose();
  });
  test(
    'Driver simulation preserves assigned fare and active trip when offline',
    () async {
      final repo = TestRepository();
      await repo.verifyOtp('+263771234567', '123456');
      await repo.profile('Driver', 'Test', '');
      await repo.applyDriver({}, {});
      await repo.approveSimulation();
      await repo.availability(true);
      await repo.request(
        demoPlaces[0],
        demoPlaces[1],
        'Standard',
        500,
        paymentMethod: 'ecocash',
      );
      final request = (await repo.requests()).first;
      await repo.counteroffer(request.id, 750);
      final ride = await repo.simulatePassengerSelection(request, 750);
      expect(ride.driver!.id, 'demo-self');
      await repo.availability(false);
      expect((await repo.activeRide())!.id, ride.id);
      for (final status in [
        RideStatus.arriving,
        RideStatus.arrived,
        RideStatus.inProgress,
        RideStatus.completed,
      ]) {
        await repo.transition(ride.id, status);
      }
      final earnings = await repo.read('driver/earnings');
      expect(earnings['net_cents'], 750);
      expect(earnings['trips'], 1);
    },
  );
  test('Route quote preserves road geometry and backend fare rules', () {
    final quote = RouteQuote.fromJson({
      'geometry': [
        [31.0, -17.0],
        [31.1, -17.1],
      ],
      'distance_metres': 3100,
      'duration_seconds': 600,
      'service_available': false,
      'minimum_fare_cents': 400,
    });
    expect(quote.points.first.latitude, -17);
    expect(quote.metres, 3100);
    expect(quote.available, isFalse);
    expect(quote.minimumCents, 400);
    expect(quote.suggestedCents, isNull);
  });
  test(
    'Logout clears the session even when offline availability fails',
    () async {
      final repo = OfflineFailureRepository();
      final app = AppController(repo);
      await app.verify('+263771234567', '123456');
      app.online = true;
      expect(await app.logout(), isTrue);
      expect(repo.loggedOut, isTrue);
      expect(app.session, isNull);
      app.dispose();
    },
  );
}

class OfflineFailureRepository extends TestRepository {
  bool loggedOut = false;
  @override
  Future<void> availability(bool online) async {
    if (!online) {
      throw StateError('Connection lost');
    }
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    await super.logout();
  }
}
