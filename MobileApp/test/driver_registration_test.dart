import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/shared/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Draft resumes per identity and approval requires submission', () async {
    final repo = DemoRepository();
    await repo.verifyOtp('+263771234567', '123456');
    await expectLater(repo.approveSimulation(), throwsStateError);
    await repo.saveRegistration({
      'step': 2,
      'fields': {'make': 'Toyota'},
    }, DriverStatus.draft);
    await repo.logout();
    await repo.verifyOtp('+263771234568', '123456');
    expect((await repo.restore())!.driverStatus, DriverStatus.notRegistered);
    await repo.verifyOtp('+263771234567', '123456');
    expect(repo.registration['step'], 2);
    await repo.saveRegistration(repo.registration, DriverStatus.submitted);
    expect((await repo.restore())!.driverStatus, DriverStatus.submitted);
    await repo.approveSimulation();
    expect((await repo.restore())!.driverStatus, DriverStatus.approved);
  });
  for (final status in [
    DriverStatus.notRegistered,
    DriverStatus.draft,
    DriverStatus.submitted,
    DriverStatus.underReview,
    DriverStatus.rejected,
    DriverStatus.suspended,
  ]) {
    test('$status cannot go online', () async {
      final repo = DemoRepository();
      await repo.verifyOtp('+263771234567', '123456');
      await repo.saveRegistration({}, status);
      await expectLater(repo.availability(true), throwsStateError);
    });
  }
}
