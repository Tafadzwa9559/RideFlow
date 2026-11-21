import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../shared/models.dart';
import 'config.dart';

class TriviaMap extends StatefulWidget {
  const TriviaMap({
    super.key,
    this.pickup,
    this.destination,
    this.stops = const [],
    this.onTap,
    this.route = const [],
    this.driver,
    this.currentLocation,
    this.bottomInset = 0,
    this.tileProvider,
  });
  final Place? pickup, destination, driver, currentLocation;
  final double bottomInset;
  final TileProvider? tileProvider;
  final List<LatLng> route;
  final List<Place> stops;
  final ValueChanged<Place>? onTap;
  @override
  State<TriviaMap> createState() => _TriviaMapState();
}

class _TriviaMapState extends State<TriviaMap> {
  final controller = MapController();
  final tileReset = StreamController<void>.broadcast();
  bool ready = false, failed = false;
  @override
  void dispose() {
    tileReset.close();
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TriviaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickup?.point != oldWidget.pickup?.point ||
        widget.destination?.point != oldWidget.destination?.point ||
        widget.currentLocation?.point != oldWidget.currentLocation?.point ||
        (widget.driver == null) != (oldWidget.driver == null) ||
        !listEquals(widget.stops, oldWidget.stops) ||
        !listEquals(widget.route, oldWidget.route)) {
      scheduleFit();
    }
  }

  void scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ready) return;
      final points = {
        ...widget.route,
        ...widget.stops.map((stop) => stop.point),
        if (widget.pickup != null) widget.pickup!.point,
        if (widget.destination != null) widget.destination!.point,
        if (widget.currentLocation != null) widget.currentLocation!.point,
        if (widget.driver != null) widget.driver!.point,
      };
      if (points.isEmpty) return;
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points.toList(),
          padding: EdgeInsets.fromLTRB(30, 45, 48, 30 + widget.bottomInset),
          maxZoom: 15,
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  final tiles = AppConfig.mapTiles;
  bool get hasTiles => tiles != null || widget.tileProvider != null;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter:
              widget.pickup?.point ??
              widget.destination?.point ??
              widget.currentLocation?.point ??
              const LatLng(-17.8225, 31.0456),
          initialZoom: 14,
          onMapReady: () {
            ready = true;
            scheduleFit();
          },
          onTap: (_, p) => widget.onTap?.call(
            Place('Selected map pin', p.latitude, p.longitude),
          ),
        ),
        children: [
          if (hasTiles)
            TileLayer(
              urlTemplate: tiles,
              tileProvider: widget.tileProvider,
              reset: tileReset.stream,
              userAgentPackageName: 'com.mordecsolutions.trivia',
              errorTileCallback: (_, _, _) {
                if (!failed && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !failed) {
                      setState(() => failed = true);
                    }
                  });
                  WidgetsBinding.instance.ensureVisualUpdate();
                }
              },
            ),
          if (widget.route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route,
                  color: darkGreen,
                  strokeWidth: 5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (widget.currentLocation != null)
                Marker(
                  point: widget.currentLocation!.point,
                  width: 28,
                  height: 28,
                  child: const _Pin(icon: Icons.gps_fixed),
                ),
              if (widget.driver != null)
                Marker(
                  point: widget.driver!.point,
                  width: 44,
                  height: 44,
                  child: const _Pin(icon: Icons.local_taxi),
                ),
              if (widget.pickup != null)
                Marker(
                  point: widget.pickup!.point,
                  width: 44,
                  height: 44,
                  child: const _Pin(icon: Icons.my_location),
                ),
              for (final (index, stop) in widget.stops.indexed)
                Marker(
                  point: stop.point,
                  width: 36,
                  height: 36,
                  child: CircleAvatar(child: Text('${index + 1}')),
                ),
              if (widget.destination != null)
                Marker(
                  point: widget.destination!.point,
                  width: 44,
                  height: 44,
                  child: const _Pin(icon: Icons.location_on),
                ),
            ],
          ),
        ],
      ),
      Positioned(
        top: 8,
        left: 8,
        right: 76,
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            child: Wrap(
              children: [
                const _AttributionLink(
                  '© OpenStreetMap contributors',
                  'https://www.openstreetmap.org/copyright',
                ),
                if (tiles != null && AppConfig.mapTileAttribution.isNotEmpty)
                  const _AttributionLink(
                    AppConfig.mapTileAttribution,
                    AppConfig.mapTileAttributionUrl,
                  ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 16,
        top: 16,
        child: Column(
          children: [
            FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Zoom in',
              onPressed: () {
                if (ready) {
                  controller.move(
                    controller.camera.center,
                    controller.camera.zoom + 1,
                  );
                }
              },
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Zoom out',
              onPressed: () {
                if (ready) {
                  controller.move(
                    controller.camera.center,
                    controller.camera.zoom - 1,
                  );
                }
              },
              child: const Icon(Icons.remove),
            ),
          ],
        ),
      ),
      if (!hasTiles || failed)
        Positioned(
          top: 54,
          left: 12,
          right: 70,
          child: Card(
            child: !hasTiles
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Map tiles are not configured.'),
                  )
                : TextButton(
                    onPressed: () {
                      setState(() => failed = false);
                      tileReset.add(null);
                    },
                    child: const Text('Map tiles unavailable. Tap to retry.'),
                  ),
          ),
        ),
    ],
  );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: darkGreen,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
    child: Icon(icon, color: Colors.white, size: 22),
  );
}

class GeoapifyAttribution extends StatelessWidget {
  const GeoapifyAttribution({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    children: [
      TextButton(
        onPressed: () => launchUrl(Uri.parse('https://www.geoapify.com/')),
        child: const Text('Powered by Geoapify'),
      ),
      TextButton(
        onPressed: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        child: const Text('© OpenStreetMap contributors'),
      ),
    ],
  );
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink(this.label, this.url);
  final String label, url;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: url.isEmpty ? null : () => launchUrl(Uri.parse(url)),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: darkGreen,
          decoration: url.isEmpty ? null : TextDecoration.underline,
        ),
      ),
    ),
  );
}
