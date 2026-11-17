import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/features/driver/registration.dart';
import 'package:rideflow_mobile/shared/models.dart';

import 'support/fixture_repository.dart';

void main() {
  testWidgets('Registration keeps edits local until confirmed submission', (
    tester,
  ) async {
    final repository = _RegistrationRepository();
    final app = AppController(repository)
      ..session = const Session(
        firstName: 'Test',
        lastName: 'Driver',
        phone: '+263771234567',
      );
    await tester.pumpWidget(MaterialApp(home: DriverRegistration(app: app)));
    await tester.pumpAndSettle();

    Future<void> tap(String text) async {
      final button = find.text(text);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String value) async {
      final input = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(input);
      await tester.enterText(input, value);
      await tester.pump();
    }

    await tap('Get Started');
    await enter('firstName', 'Updated');
    await tap('Continue');
    await enter('licenceNumber', 'TEST123');
    await enter('licenceClass', '4');
    await enter(
      'licenceExpiry',
      DateTime.now()
          .add(const Duration(days: 365))
          .toIso8601String()
          .substring(0, 10),
    );
    await tap('Continue');
    for (final entry in {
      'make': 'Toyota',
      'model': 'Corolla',
      'year': '${DateTime.now().year}',
      'colour': 'White',
      'registration': 'TEST123',
      'seats': '4',
    }.entries) {
      await enter(entry.key, entry.value);
    }
    await tap('Continue');
    await tap('Continue');
    expect(repository.submissions, isEmpty);
    await tap('I confirm the information supplied is accurate.');
    await tap('Submit Application');
    expect(repository.submissions, hasLength(1));
    final fields = repository.submissions.single['fields'] as Map;
    expect(fields['firstName'], 'Updated');
    expect(fields['registration'], 'TEST123');
    expect(app.session?.driverStatus, DriverStatus.submitted);
    expect(find.text('Application Submitted'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}

class _RegistrationRepository extends TestRepository {
  final submissions = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> read(String resource) async =>
      switch (resource) {
        'drivers/document-requirements' => {
          'results': <Map<String, dynamic>>[],
        },
        'drivers/applications/me' => <String, dynamic>{},
        _ => await super.read(resource),
      };

  @override
  Future<DriverStatus> applyDriver(
    Map<String, dynamic> fields,
    Map<String, String> documents,
  ) async {
    submissions.add(fields);
    return DriverStatus.submitted;
  }

  @override
  Future<Session?> restore() async => const Session(
    firstName: 'Updated',
    lastName: 'Driver',
    phone: '+263771234567',
    driverStatus: DriverStatus.submitted,
  );
}
