import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/shared/models.dart';
import 'package:rideflow_mobile/app/controller.dart';

void main() {
  test('Fare parsing uses cents and rejects invalid input', () {
    expect(parseFare('12.3'), 1230);
    expect(parseFare('0.01'), 1);
    for (final invalid in ['0', '-1', '1.001', 'NaN', '1e3', '']) {
      expect(() => parseFare(invalid), throwsFormatException);
    }
  });
  test('OTP fails closed and driver access requires approval', () async {
    final repo = DemoRepository();
    await expectLater(
      repo.verifyOtp('+263771234567', '000000'),
      throwsStateError,
    );
    await repo.verifyOtp('+263771234567', '123456');
    await expectLater(repo.availability(true), throwsStateError);
    await repo.applyDriver({}, {});
    await expectLater(repo.availability(true), throwsStateError);
    repo.approveSimulation();
    await repo.availability(true);
    expect(await repo.requests(), isNotEmpty);
  });
  test(
    'Ride lifecycle prevents duplicate assignment and fixes agreed fare',
    () async {
      final repo = DemoRepository();
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
    final repo = DemoRepository();
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
  test(
    'Switching modes is blocked during active trip and logout clears state',
    () async {
      final app = AppController(DemoRepository());
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
    },
  );
}
