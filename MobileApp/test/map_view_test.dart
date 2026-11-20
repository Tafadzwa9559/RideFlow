import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rideflow_mobile/core/config.dart';
import 'package:rideflow_mobile/core/map_view.dart';
import 'package:rideflow_mobile/shared/models.dart';

class _LocalTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/trivia-icon.png');
}

void main() {
  testWidgets(
    'Fits the route, renders all markers and supports map pin selection',
    (tester) async {
      const pickup = Place('Pickup', -17.83, 31.05);
      const destination = Place('Destination', -17.79, 31.03);
      const driver = Place('Driver', -17.85, 31.08);
      const currentLocation = Place('Current location', -17.82, 31.04);
      Place? selection;
      final road = [
        pickup.point,
        const LatLng(-17.81, 31.08),
        destination.point,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TriviaMap(
              pickup: pickup,
              destination: destination,
              driver: driver,
              currentLocation: currentLocation,
              onTap: (place) => selection = place,
              route: road,
              bottomInset: 250,
              tileProvider: _LocalTileProvider(),
            ),
          ),
        ),
      );
      await tester.pump();

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(tiles.urlTemplate, AppConfig.mapTiles);
      final bounds = map.mapController!.camera.visibleBounds;
      expect([...road, driver.point].every(bounds.contains), isTrue);

      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(
        layer.markers.map((marker) => marker.point),
        unorderedEquals([
          pickup.point,
          destination.point,
          driver.point,
          currentLocation.point,
        ]),
      );
      final routeLayer = tester.widget<PolylineLayer>(
        find.byType(PolylineLayer),
      );
      expect(routeLayer.polylines.single.points, road);
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pumpAndSettle();
      expect(selection?.name, 'Selected map pin');
    },
  );
}
