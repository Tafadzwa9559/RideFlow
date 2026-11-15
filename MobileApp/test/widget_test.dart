import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/app/theme.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/features/entry/entry.dart';

void main() {
  testWidgets('Onboarding swipes and persists completion', (tester) async {
    final app = AppController(DemoRepository());
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
    app.dispose();
  });
  testWidgets('Phone validation rejects incomplete Zimbabwe number', (
    tester,
  ) async {
    final app = AppController(DemoRepository());
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
}
