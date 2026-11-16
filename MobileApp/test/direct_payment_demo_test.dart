import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/shared/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final method in directPaymentMethods) {
    test(
      '${method.name} demo booking completes without a payment service',
      () async {
        final repo = DemoRepository();
        final quote = await repo.quote(
          demoPlaces[0],
          demoPlaces[1],
          'Standard',
        );
        expect(quote!.currency, 'USD');
        var ride = await repo.request(
          demoPlaces[0],
          demoPlaces[1],
          'Standard',
          500,
          paymentMethod: method.id,
        );
        expect(ride.paymentMethodName, method.name);
        await repo.verifyOtp('+263771234567', '123456');
      await repo.applyDriver({}, {});
      await repo.approveSimulation();
      repo.online = true;
        expect((await repo.requests()).single.paymentMethod, method.id);
        await repo.counteroffer(ride.id, 600);
        final offer = (await repo.offers(ride.id)).first;
        ride = await repo.accept(ride.id, offer.id);
        expect(ride.cents, 600);
        for (final status in [
          RideStatus.arriving,
          RideStatus.arrived,
          RideStatus.inProgress,
          RideStatus.completed,
        ]) {
          ride = await repo.transition(ride.id, status);
        }
        expect((await repo.history()).single.paymentMethodName, method.name);
        expect(await repo.activeRide(), isNull);
        expect(money(ride.cents), contains('6.00'));
      },
    );
  }
  test('Cancelled demo ride leaves no active request', () async {
    final repo = DemoRepository();
    final ride = await repo.request(
      demoPlaces[0],
      demoPlaces[1],
      'Standard',
      500,
      paymentMethod: 'cash-usd',
    );
    await repo.transition(ride.id, RideStatus.cancelled);
    expect(await repo.activeRide(), isNull);
  });
}
