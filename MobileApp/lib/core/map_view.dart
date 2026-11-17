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
    this.onTap,
    this.route = const [],
    this.driver,
  });
  final Place? pickup, destination, driver;
  final List<LatLng> route;
  final ValueChanged<Place>? onTap;
  @override
  State<TriviaMap> createState() => _TriviaMapState();
}

class _TriviaMapState extends State<TriviaMap> {
  final controller = MapController();
  bool ready = false, failed = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TriviaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ready && widget.pickup != oldWidget.pickup && widget.pickup != null) {
      controller.move(widget.pickup!.point, 14);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter:
              widget.pickup?.point ?? const LatLng(-17.8225, 31.0456),
          initialZoom: 14,
          onMapReady: () => ready = true,
          onTap: (_, p) => widget.onTap?.call(
            Place('Selected map pin', p.latitude, p.longitude),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: AppConfig.mapTiles,
            userAgentPackageName: 'com.mordecsolutions.trivia',
            errorTileCallback: (_, _, _) {
              if (!failed && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => failed = true);
                  }
                });
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
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 10,
                    color: darkGreen,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
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
      if (failed)
        const Positioned(
          top: 54,
          left: 12,
          right: 70,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Map tiles unavailable. Location search is still available.',
                style: TextStyle(fontSize: 11),
              ),
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
