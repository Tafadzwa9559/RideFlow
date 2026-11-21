import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../core/map_view.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../account/account.dart';
import 'booking_controller.dart';
import 'booking_fields.dart';
import 'departure_picker.dart';
import 'parcel_details.dart';

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
    consumeRebook();
  }

  @override
  void didUpdateWidget(PassengerHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    consumeRebook();
  }

  void consumeRebook() {
    final previous = widget.app.rebookDraft;
    if (previous == null) return;
    widget.app.rebookDraft = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) booking.rebook(previous);
    });
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

  static const cities = [
    'Bindura',
    'Bulawayo',
    'Chinhoyi',
    'Gweru',
    'Harare',
    'Kadoma',
    'Kwekwe',
    'Marondera',
    'Masvingo',
    'Mutare',
    'Victoria Falls',
  ];

  Widget cityField(bool origin) {
    final selected = origin ? booking.departureCity : booking.arrivalCity;
    final other = origin ? booking.arrivalCity : booking.departureCity;
    return DropdownButtonFormField<String>(
      key: ValueKey((origin, selected)),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: origin ? 'Departure city' : 'Arrival city',
      ),
      items: [
        for (final city in cities)
          DropdownMenuItem(
            value: city,
            enabled: city != other,
            child: Text(city),
          ),
      ],
      onChanged: booking.submitting
          ? null
          : (city) {
              if (city != null) booking.setCity(origin, city);
            },
    );
  }

  Future<void> choose(bool origin) async {
    if (booking.submitting) {
      return;
    }
    final city = origin ? booking.departureCity : booking.arrivalCity;
    if (booking.intercity && city == null) return;
    final selected = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePicker(
          app: widget.app,
          title: booking.intercity
              ? 'Choose a point in $city'
              : (origin ? 'Choose pickup' : 'Where to?'),
          isPickup: origin,
          searchCity: booking.intercity ? city : null,
          initialPlace: origin ? pickup : destination,
        ),
      ),
    );
    if (selected != null && mounted) {
      final place = booking.intercity
          ? Place(selected.name, selected.lat, selected.lng, city: city)
          : selected;
      await booking.setPlaces(
        pickup: origin ? place : null,
        destination: origin ? null : place,
      );
    }
  }

  Future<void> addStop() async {
    final stop = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePicker(app: widget.app, title: 'Choose a stop'),
      ),
    );
    if (mounted && stop != null) {
      await booking.setStops([...booking.stops, stop]);
    }
  }

  void moveStop(int index, int offset) {
    final ordered = [...booking.stops];
    final stop = ordered.removeAt(index);
    ordered.insert(index + offset, stop);
    booking.setStops(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final ride = app.ride;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: [
              const Flexible(child: Brand()),
              const SizedBox(width: 16),
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('Zimbabwe', style: TextStyle(fontSize: 13)),
              ),
              if (ride?.active == true)
                IconButton(
                  tooltip: 'Emergency numbers',
                  onPressed: () => showEmergencyOptions(context),
                  icon: const Icon(Icons.sos_outlined),
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
                    stops: ride?.stops ?? booking.stops,
                    route: ride?.route ?? booking.quote?.points ?? const [],
                    bottomInset: constraints.maxHeight * .52,
                    driver: ride?.freshLocation == true
                        ? ride!.driverLocation
                        : null,
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: .52,
                  minChildSize: .25,
                  maxChildSize: .92,
                  snap: !MediaQuery.disableAnimationsOf(context),
                  snapSizes: const [.52],
                  builder: (context, scroll) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: sheetRadius,
                      boxShadow: const [
                        BoxShadow(color: Color(0x10000000), blurRadius: 16),
                      ],
                    ),
                    child: ListView(
                      controller: scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
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
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final (value, label, selected) in [
                                (
                                  'Standard',
                                  'City ride',
                                  !booking.intercity && !booking.courier,
                                ),
                                (
                                  'Intercity',
                                  'City-to-City',
                                  booking.intercity,
                                ),
                                ('Courier', 'Courier', booking.courier),
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: selected,
                                  onSelected: booking.submitting || selected
                                      ? null
                                      : (_) => booking.setCategory(value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (booking.intercity) ...[
                            cityField(true),
                            const SizedBox(height: 8),
                            cityField(false),
                            const SizedBox(height: 12),
                          ],
                          Card(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _LocationTile(
                                  icon: Icons.radio_button_checked,
                                  label: booking.courier
                                      ? 'Parcel pickup'
                                      : 'Pickup',
                                  title: pickup?.name ?? 'Choose pickup',
                                  onTap:
                                      booking.intercity &&
                                          booking.departureCity == null
                                      ? null
                                      : () => choose(true),
                                ),
                                const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                _LocationTile(
                                  icon: Icons.location_on_outlined,
                                  label: booking.courier
                                      ? 'Delivery address'
                                      : 'Destination',
                                  title:
                                      destination?.name ??
                                      'Where are you going?',
                                  onTap:
                                      booking.intercity &&
                                          booking.arrivalCity == null
                                      ? null
                                      : () => choose(false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!booking.intercity &&
                              app.savedAddresses.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              children: app.savedAddresses
                                  .map(
                                    (p) => ActionChip(
                                      avatar: const Icon(
                                        Icons.bookmark_outline,
                                        size: 16,
                                      ),
                                      label: Text(p.label),
                                      onPressed: () {
                                        booking.setPlaces(destination: p.place);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 8),
                          for (final (index, stop) in booking.stops.indexed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(stop.name),
                              subtitle: Text('Stop ${index + 1}'),
                              trailing: PopupMenuButton<String>(
                                enabled: !booking.submitting,
                                onSelected: (action) {
                                  if (action == 'remove') {
                                    booking.setStops(
                                      [...booking.stops]..removeAt(index),
                                    );
                                  } else {
                                    moveStop(index, action == 'up' ? -1 : 1);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (index > 0)
                                    const PopupMenuItem(
                                      value: 'up',
                                      child: Text('Move up'),
                                    ),
                                  if (index + 1 < booking.stops.length)
                                    const PopupMenuItem(
                                      value: 'down',
                                      child: Text('Move down'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove stop'),
                                  ),
                                ],
                              ),
                            ),
                          if (!booking.courier && booking.stops.length < 3)
                            TextButton.icon(
                              onPressed: booking.submitting ? null : addStop,
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Add a stop'),
                            ),
                          const Divider(),
                          Text(
                            'Ride options',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          BookingFields(booking: booking),
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
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String title, label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(label, style: Theme.of(context).textTheme.labelMedium),
    subtitle: Text(title, style: Theme.of(context).textTheme.titleSmall),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: onTap,
  );
}

class PlacePicker extends StatefulWidget {
  const PlacePicker({
    super.key,
    required this.app,
    required this.title,
    this.isPickup = true,
    this.initialPlace,
    this.searchCity,
  });
  final bool isPickup;
  final Place? initialPlace;
  final String? searchCity;
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
  bool busy = false, locating = false, map = false;
  Place? selected, currentLocation;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    selected = widget.initialPlace;
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void scheduleSearch(String input) {
    debounce?.cancel();
    final version = ++generation;
    final q = input.trim();
    setState(() {
      busy = q.length >= 2;
      map = false;
      error = null;
      results = [];
    });
    if (!busy) return;
    debounce = Timer(
      const Duration(milliseconds: 350),
      () => search(q, version),
    );
  }

  Future<void> search(String q, int version) async {
    try {
      final found = await widget.app.repository.search(
        widget.searchCity == null ? q : '$q, ${widget.searchCity}',
      );
      if (mounted && version == generation) {
        setState(() => results = found);
      }
    } catch (e) {
      if (mounted && version == generation) {
        final status = e is DioException ? e.response?.statusCode : null;
        setState(
          () => error = switch (status) {
            401 || 403 => 'Sign in again to search for locations.',
            429 => 'Too many searches. Wait a moment and retry.',
            503 => 'Location search is temporarily unavailable. Retry or choose a map pin.',
            null when e is DioException && e.response == null =>
              'Could not reach Trivia. Check your connection and retry.',
            _ => 'Location search failed. Retry or choose a map pin.',
          },
        );
      }
    } finally {
      if (mounted && version == generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> locate() async {
    debounce?.cancel();
    ++generation;
    setState(() {
      busy = false;
      locating = true;
      error = null;
    });
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on device location services.');
      }
      var permission = kIsWeb
          ? LocationPermission.whileInUse
          : await Geolocator.checkPermission();
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
        FocusScope.of(context).unfocus();
        setState(() {
          currentLocation = Place('Current location', p.latitude, p.longitude);
          selected = currentLocation;
          map = true;
        });
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
        setState(() => locating = false);
      }
    }
  }

  void toggleMap() {
    FocusScope.of(context).unfocus();
    setState(() => map = !map);
  }

  @override
  Widget build(BuildContext context) {
    final viewport =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final compact = viewport < 260;
    final mapLabel = map ? 'Search list' : 'Choose on map';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (compact) TextButton(onPressed: toggleMap, child: Text(mapLabel)),
        ],
      ),
      body: ContentFrame(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        controller: query,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search a landmark or neighbourhood',
                          prefixIcon: Icon(Icons.search),
                          counterText: '',
                        ),
                        maxLength: 200,
                        onChanged: scheduleSearch,
                        enabled: !locating,
                        onSubmitted: scheduleSearch,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          onPressed: locating ? null : locate,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use my location'),
                        ),
                        if (!compact)
                          TextButton.icon(
                            onPressed: toggleMap,
                            icon: const Icon(Icons.map_outlined),
                            label: Text(mapLabel),
                          ),
                      ],
                    ),
                    if (busy || locating)
                      LinearProgressIndicator(
                        semanticsLabel: locating
                            ? 'Getting your location'
                            : 'Searching places',
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            InlineNotice(error!, isError: true),
                            if (query.text.trim().length >= 2)
                              TextButton(
                                onPressed: () => scheduleSearch(query.text),
                                child: const Text('Retry search'),
                              ),
                          ],
                        ),
                      ),
                    if (map)
                      SizedBox(
                        height: (constraints.maxHeight * .65).clamp(
                          240.0,
                          500.0,
                        ),
                        child: ClipRRect(
                          borderRadius: cardRadius,
                          child: TriviaMap(
                            pickup: widget.isPickup ? selected : null,
                            destination: widget.isPickup ? null : selected,
                            currentLocation: currentLocation,
                            onTap: locating ? null : selectPlace,
                          ),
                        ),
                      )
                    else ...[
                      ...results.map(tile),
                      if (results.any((place) => place.provider == 'Geoapify'))
                        const GeoapifyAttribution(),
                      if (results.isEmpty &&
                          !busy &&
                          !locating &&
                          error == null &&
                          query.text.trim().length >= 2)
                        const EmptyState(
                          'No places found',
                          'Try another landmark or select a point on the map.',
                          icon: Icons.search,
                        ),
                      if (widget.app.savedAddresses.isNotEmpty)
                        const ListTile(title: Text('Saved places')),
                      ...widget.app.savedAddresses.map(
                        (saved) => tile(saved.place, label: saved.label),
                      ),
                      if (widget.app.recent.isNotEmpty)
                        const ListTile(title: Text('Recent places')),
                      ...widget.app.recent.map(tile),
                    ],
                  ],
                ),
              ),
              if (selected != null &&
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ActionButton(
                        widget.isPickup
                            ? 'Confirm pickup'
                            : 'Confirm destination',
                        locating
                            ? null
                            : () => Navigator.pop(context, selected),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void selectPlace(Place place) {
    FocusScope.of(context).unfocus();
    setState(() => selected = place);
  }

  Widget tile(Place p, {String? label}) => ListTile(
    leading: const Icon(Icons.place_outlined),
    title: Text(label ?? p.name),
    subtitle: Text(
      p.formattedAddress ??
          '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
      style: const TextStyle(fontSize: 11),
    ),
    onTap: locating ? null : () => selectPlace(p),
    trailing: label != null
        ? null
        : IconButton(
            tooltip: 'Save place',
            icon: Icon(
              widget.app.savedAddresses.any(
                    (v) => v.place.lat == p.lat && v.place.lng == p.lng,
                  )
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
            ),
            onPressed:
                widget.app.busy ||
                    widget.app.savedAddresses.any(
                      (v) => v.place.lat == p.lat && v.place.lng == p.lng,
                    )
                ? null
                : () async {
                    await widget.app.savePlace(
                      p,
                      label: p.name.length > 80
                          ? p.name.substring(0, 80)
                          : p.name,
                    );
                    if (mounted) setState(() {});
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
    final connection = switch (app.realtime?.state) {
      'Connected' => 'Live trip updates',
      'Connecting' || 'Reconnecting' => 'Connecting to live updates…',
      'Sync interrupted' || 'Disconnected' => 'Live updates interrupted',
      _ => 'Updates refresh every 15 seconds',
    };
    final next = switch (r.status) {
      RideStatus.assigned => RideStatus.arriving,
      RideStatus.arriving => RideStatus.arrived,
      RideStatus.arrived
          when r.departureAt == null ||
              !DateTime.now().isBefore(r.departureAt!) =>
        RideStatus.inProgress,
      RideStatus.inProgress when !r.courier => RideStatus.completed,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(switch (r.status) {
                RideStatus.searching => Icons.radar,
                RideStatus.completed => Icons.check_circle_outline,
                RideStatus.cancelled => Icons.cancel_outlined,
                _ => Icons.directions_car_outlined,
              }, color: Theme.of(context).colorScheme.primary),
              Text(
                deliveryStatusLabel(r),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (r.active) Text(connection),
        if (r.departureAt case final departure?) ...[
          const SizedBox(height: 6),
          Text('Departure · ${harareTime(departure)}'),
          if (r.status == RideStatus.scheduled) ...[
            const Text('Matching opens 15 minutes before departure.'),
            TextButton(
              onPressed: app.busy
                  ? null
                  : () async {
                      final time = await pickDeparture(
                        context,
                        current: departure,
                      );
                      if (time == null || !context.mounted) return;
                      await app.perform(() async {
                        await app.repository.write('rides/${r.id}/schedule', {
                          'departure_at': time.toUtc().toIso8601String(),
                        });
                        await app.sync();
                      });
                    },
              child: const Text('Edit departure'),
            ),
          ],
        ],
        if (r.courier) ...[
          const SizedBox(height: 8),
          Text(
            'Courier delivery · ${r.parcelSize ?? 'parcel'} · ${r.parcelWeightKg ?? '–'} kg',
          ),
          TextButton.icon(
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(
              app.driverMode && r.status == RideStatus.inProgress
                  ? 'Enter delivery code'
                  : 'Parcel handover',
            ),
            onPressed: () =>
                openPage(context, ParcelDetailsPage(app: app, ride: r)),
          ),
        ],
        if (r.intercity) ...[
          const SizedBox(height: 6),
          Text('City-to-City · ${r.pickup.city} → ${r.destination.city}'),
          Text('${r.passengerCount} passengers · ${luggageLabel(r.luggage)}'),
          if (r.passengerNote.isNotEmpty) Text(r.passengerNote),
        ],
        const SizedBox(height: 16),
        InfoCard(
          child: RouteStops(
            pickup: r.pickup.name,
            stops: r.stops.map((stop) => stop.name).toList(),
            destination: r.destination.name,
          ),
        ),
        const Divider(height: 32),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(r.agreedCents == null ? 'Your proposed fare' : 'Agreed fare'),
            Text(
              money(r.cents, currency: r.currency),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Payment preference: ${directPaymentLabel(r.paymentMethod, r.paymentMethodName)}',
        ),
        if (r.status == RideStatus.searching) ...[
          const SizedBox(height: 20),
          if (app.offers.isNotEmpty)
            Text(
              'Driver offers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          for (final o in app.offers)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: cardRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
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
                    Text(
                      [
                        o.vehicle,
                        if (o.colour?.isNotEmpty == true) o.colour!,
                        o.plate,
                      ].join(' • '),
                    ),
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
            const InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.radar_outlined),
                  SizedBox(height: 12),
                  Text('Waiting for offers. You can cancel at any time.'),
                ],
              ),
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
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(d.name),
            subtitle: Text(
              [
                d.vehicle,
                if (d.colour?.isNotEmpty == true) d.colour!,
                d.plate,
              ].join('\n'),
            ),
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
        ],
        if (r.active)
          TextButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Get help with this trip'),
            onPressed: () => openPage(
              context,
              FeedbackPage(
                app: app,
                title: 'Report a concern about this trip',
                resource: 'rides/${r.id}/report',
              ),
            ),
          ),
        if (app.driverMode && r.active)
          OutlinedButton.icon(
            icon: const Icon(Icons.directions_outlined),
            label: Text(
              r.status == RideStatus.inProgress
                  ? 'Open destination in maps'
                  : 'Open pickup in maps',
            ),
            onPressed: () => openDriverRoute(context, r),
          ),
        if (app.driverMode && next != null) ...[
          const SizedBox(height: 12),
          ActionButton(
            r.courier && next == RideStatus.inProgress
                ? 'Confirm parcel pickup'
                : statusLabel(next),
            () => app.transition(next),
            busy: app.busy,
          ),
        ],
        ErrorNotice(app),
        if (!r.active)
          TextButton(
            onPressed: () {
              app.ride = null;
              app.notifyListeners();
            },
            child: const Text('Book another ride'),
          ),
        if (r.active && r.status != RideStatus.inProgress)
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel ride'),
          ),
      ],
    );
  }
}

Future<void> openDriverRoute(BuildContext context, Ride ride) async {
  final destination = ride.status == RideStatus.inProgress
      ? ride.destination
      : ride.pickup;
  final endpoint = '${destination.lat},${destination.lng}';
  final geo = Uri.parse('geo:$endpoint?q=$endpoint');
  try {
    if (await launchUrl(geo, mode: LaunchMode.externalApplication)) return;
    final map = Uri.https('www.openstreetmap.org', '/', {
      'mlat': '${destination.lat}',
      'mlon': '${destination.lng}',
    }).replace(fragment: 'map=16/${destination.lat}/${destination.lng}');
    if (await launchUrl(map, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Keep the in-app route and stops available if the device has no map handler.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open a maps app. Use the trip map to view the route.',
        ),
      ),
    );
  }
}
