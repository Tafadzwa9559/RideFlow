import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/map_view.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../account/account.dart';
import 'booking_controller.dart';
import 'booking_fields.dart';

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key, required this.app});
  final AppController app;
  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  late final BookingController booking;
  Place? get pickup => booking.pickup;
  Place? get destination => booking.destination;
  @override
  void initState() {
    super.initState();
    booking = BookingController(widget.app)..addListener(refresh);
    booking.loadConfiguration();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    booking.removeListener(refresh);
    booking.dispose();
    super.dispose();
  }

  Future<void> choose(bool origin) async {
    if (booking.submitting) {
      return;
    }
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePicker(
          app: widget.app,
          title: origin ? 'Choose pickup' : 'Where to?',
        ),
      ),
    );
    if (place != null && mounted) {
      await booking.setPlaces(
        pickup: origin ? place : null,
        destination: origin ? null : place,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final ride = app.ride;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
          child: Row(
            children: [
              const Brand(),
              const SizedBox(width: 16),
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: darkGreen,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('Zimbabwe', style: TextStyle(fontSize: 13)),
              ),
              IconButton(
                tooltip: 'Safety & support',
                onPressed: () => openPage(context, SafetyPage(app: app)),
                icon: const Icon(Icons.shield_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: TriviaMap(
                    pickup: ride?.pickup ?? pickup,
                    destination: ride?.destination ?? destination,
                    route: ride?.route ?? booking.quote?.points ?? const [],
                    driver: ride?.freshLocation == true
                        ? ride!.driverLocation
                        : null,
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: .52,
                  minChildSize: .25,
                  maxChildSize: .92,
                  builder: (context, scroll) => Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x10000000), blurRadius: 16),
                      ],
                    ),
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (ride != null)
                          TripPanel(app: app)
                        else ...[
                          Text(
                            'Where to, ${app.session!.firstName}?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          const Text('A little freedom in every journey.'),
                          const SizedBox(height: 20),
                          _LocationTile(
                            icon: Icons.radio_button_checked,
                            title: pickup?.name ?? 'Choose pickup',
                            onTap: () => choose(true),
                          ),
                          const SizedBox(height: 10),
                          _LocationTile(
                            icon: Icons.location_on_outlined,
                            title: destination?.name ?? 'Where are you going?',
                            onTap: () => choose(false),
                          ),
                          const SizedBox(height: 12),
                          if (app.saved.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              children: app.saved
                                  .map(
                                    (p) => ActionChip(
                                      avatar: const Icon(
                                        Icons.bookmark_outline,
                                        size: 16,
                                      ),
                                      label: Text(p.name),
                                      onPressed: () {
                                        booking.setPlaces(destination: p);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'Your ride. Your way.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          BookingFields(booking: booking),
                          const SizedBox(height: 12),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: darkGreen,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Your choice, from start to finish.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF8F9F7),
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      leading: Icon(icon, color: darkGreen),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    ),
  );
}

class PlacePicker extends StatefulWidget {
  const PlacePicker({super.key, required this.app, required this.title});
  final AppController app;
  final String title;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final query = TextEditingController();
  Timer? debounce;
  List<Place> results = [];
  String? error;
  bool busy = false, map = false;
  Place? pin;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    search('');
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  Future<void> search(String q) async {
    final version = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final found = await widget.app.repository.search(q);
      if (mounted && version == generation) {
        setState(() => results = found);
      }
    } catch (_) {
      if (mounted && version == generation) {
        setState(
          () =>
              error = 'Location search unavailable. Retry or choose a map pin.',
        );
      }
    } finally {
      if (mounted && version == generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on device location services.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location access is disabled. Enable it in device settings or choose manually.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw StateError(
          'Location permission denied. You can still choose manually.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        Navigator.pop(
          context,
          Place('Current location', p.latitude, p.longitude),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'GPS unavailable. Choose a location manually.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: query,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search a landmark or neighbourhood',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (q) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 350),
                () => search(q),
              );
            },
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton.icon(
              onPressed: busy ? null : locate,
              icon: const Icon(Icons.my_location),
              label: const Text('Use my location'),
            ),
            TextButton.icon(
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => map = !map);
              },
              icon: const Icon(Icons.map_outlined),
              label: Text(map ? 'Search list' : 'Choose on map'),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (AppConfig.demo && !map)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Demo landmarks • Examples do not confirm service availability.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: map
              ? Stack(
                  children: [
                    TriviaMap(
                      pickup: pin,
                      onTap: (p) => setState(() => pin = p),
                    ),
                    if (pin != null)
                      Positioned(
                        bottom: 30,
                        left: 20,
                        right: 20,
                        child: ActionButton(
                          'Use selected pin',
                          () => Navigator.pop(context, pin),
                        ),
                      ),
                  ],
                )
              : ListView(
                  children: [
                    if (widget.app.saved.isNotEmpty)
                      const ListTile(title: Text('Saved places')),
                    ...widget.app.saved.map(tile),
                    if (widget.app.recent.isNotEmpty)
                      const ListTile(title: Text('Recent places')),
                    ...widget.app.recent.map(tile),
                    ...results.map(tile),
                    if (results.isEmpty && !busy)
                      const EmptyState(
                        'No places found',
                        'Try another landmark or select a point on the map.',
                        icon: Icons.search,
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
  Widget tile(Place p) => ListTile(
    leading: const Icon(Icons.place_outlined),
    title: Text(p.name),
    subtitle: Text(
      '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
      style: const TextStyle(fontSize: 11),
    ),
    onTap: () => Navigator.pop(context, p),
    trailing: IconButton(
      tooltip: 'Save place for this session',
      icon: Icon(
        widget.app.saved.any((v) => v.name == p.name)
            ? Icons.bookmark
            : Icons.bookmark_outline,
      ),
      onPressed: () {
        widget.app.savePlace(p);
        setState(() {});
      },
    ),
  );
}

class TripPanel extends StatelessWidget {
  const TripPanel({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final r = app.ride!;
    final d = r.driver;
    final next = switch (r.status) {
      RideStatus.assigned => RideStatus.arriving,
      RideStatus.arriving => RideStatus.arrived,
      RideStatus.arrived => RideStatus.inProgress,
      RideStatus.inProgress => RideStatus.completed,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          statusLabel(r.status),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          AppConfig.demo
              ? 'Simulated trip • No real vehicle is on the way.'
              : app.realtime?.state ?? 'Updates refresh every 15 seconds',
        ),
        const SizedBox(height: 16),
        Text('${r.pickup.name}\n↓\n${r.destination.name}'),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(r.driver == null ? 'Your proposed fare' : 'Agreed fare'),
            Text(
              money(r.cents, currency: r.currency),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${r.paymentMethodName == null ? '' : '${r.paymentMethodName} · '}${paymentStatusLabel(r.paymentStatus)}',
        ),
        if (r.status == RideStatus.searching) ...[
          const SizedBox(height: 20),
          const Text('Choose the offer that works for you.'),
          for (final o in app.offers)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: pale,
                          child: Icon(Icons.person_outline, color: darkGreen),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            o.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          money(o.cents, currency: r.currency),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${o.vehicle} • ${o.plate}'),
                    Text(
                      '${o.rating == null ? 'No rating yet' : '★ ${o.rating}'}${o.minutes == null ? '' : ' · ${o.minutes} min pickup'}${o.verified ? ' · Verified by platform' : ''}',
                    ),
                    const SizedBox(height: 12),
                    ActionButton('Choose driver', () async {
                      if (await confirm(
                        context,
                        'Choose ${o.name}?',
                        'Agree to ${money(o.cents, currency: r.currency)} for this trip?',
                      )) {
                        await app.accept(o);
                      }
                    }, busy: app.busy),
                  ],
                ),
              ),
            ),
          if (app.offers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Waiting for offers. You can cancel at any time.'),
            ),
          TextButton.icon(
            onPressed: () => app.perform(app.sync),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh offers'),
          ),
        ] else if (d != null) ...[
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: pale,
              child: Icon(Icons.person_outline),
            ),
            title: Text(d.name),
            subtitle: Text('${d.vehicle}\n${d.plate}'),
          ),
          Text(
            r.freshLocation
                ? 'Driver location updated ${r.locationUpdatedAt!.toUtc().add(const Duration(hours: 2)).toIso8601String().substring(11, 19)} CAT'
                : 'Live driver position unavailable or out of date.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => openPage(context, SafetyPage(app: app)),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Safety & trip details'),
          ),
          if ((AppConfig.demo || app.driverMode) && next != null) ...[
            const SizedBox(height: 12),
            ActionButton(
              '${AppConfig.demo ? 'Simulate: ' : ''}${statusLabel(next)}',
              () => app.transition(next),
              busy: app.busy,
            ),
          ],
        ],
        ErrorNotice(app),
        if (r.status != RideStatus.inProgress)
          TextButton(
            onPressed: app.busy
                ? null
                : () async {
                    if (await confirm(
                      context,
                      'Cancel this ride?',
                      'Your current request will be cancelled.',
                    )) {
                      await app.transition(RideStatus.cancelled);
                    }
                  },
            child: const Text(
              'Cancel ride',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
      ],
    );
  }
}
