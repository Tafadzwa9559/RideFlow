import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/features/passenger/home.dart';
import 'package:rideflow_mobile/shared/models.dart';

import 'support/fixture_repository.dart';

class SearchRepository extends TestRepository {
  final pending = <String, Completer<List<Place>>>{};

  @override
  Future<List<Place>> search(String query) =>
      pending.putIfAbsent(query, Completer<List<Place>>.new).future;
}

void main() {
  testWidgets('New input invalidates prior results during debounce', (
    tester,
  ) async {
    final repository = SearchRepository();
    final app = AppController(repository);
    addTearDown(app.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PlacePicker(app: app, title: 'Choose pickup'),
      ),
    );
    final search = find.byType(TextField);
    await tester.enterText(search, 'Harare');
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.pending.keys, ['Harare']);

    await tester.enterText(search, 'Avondale');
    repository.pending['Harare']!.complete([
      const Place('Harare', -17.82, 31.05),
    ]);
    await tester.pump();
    expect(find.text('Harare'), findsNothing);
    expect(repository.pending.keys, ['Harare']);

    await tester.pump(const Duration(milliseconds: 350));
    repository.pending['Avondale']!.complete([
      const Place(
        'Avondale',
        -17.8,
        31.03,
        formattedAddress: 'Avondale, Harare',
      ),
    ]);
    await tester.pump();
    expect(find.text('Avondale, Harare'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Avondale'));
    await tester.pump();
    expect(find.text('Confirm pickup'), findsOneWidget);
  });
}
