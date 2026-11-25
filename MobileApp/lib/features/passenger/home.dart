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

// ---------------------------------------------------------------------------
// Shared design helpers (private to this file)
// ---------------------------------------------------------------------------

Duration _motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

InputDecoration _homeInput(
  BuildContext context, {
  required String label,
  IconData? icon,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: true,
    fillColor: scheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border(scheme.outlineVariant),
    enabledBorder: border(scheme.outlineVariant),
    focusedBorder: border(scheme.primary, 2),
  );
}

/// Cross-fades short text (place names) when it changes.
Widget _fadeText(
  BuildContext context,
  String text, {
  TextStyle? style,
  int maxLines = 1,
}) => AnimatedSwitcher(
  duration: _motion(context, 200),
  layoutBuilder: (current, previous) =>
      Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
  child: Text(
    text,
    key: ValueKey(text),
    style: style,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
  ),
);

IconData _iconForLabel(String label) {
  final l = label.toLowerCase();
  if (l.contains('home')) return Icons.home_outlined;
  if (l.contains('work') || l.contains('office')) return Icons.work_outline;
  return Icons.bookmark_outline;
}

class _FloatingAction extends StatelessWidget {
  const _FloatingAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: danger ? scheme.errorContainer : scheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 22,
          color: danger ? scheme.onErrorContainer : scheme.onSurface,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Passenger home
// ---------------------------------------------------------------------------

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key, required this.app});
  final AppController app;
  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  static const _sheetStart = .46;

  late final BookingController booking;
  Place? get pickup => booking.pickup;
  Place? get destination => booking.destination;
  Place? _here;
  bool _locating = false;

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

  /// Shows the passenger's own position on the map. Only runs when tapped.
  Future<void> _showMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    String? problem;
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
          'Location access is disabled. Enable it in device settings.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission denied.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        setState(
          () => _here = Place('Current location', p.latitude, p.longitude),
        );
      }
    } catch (e) {
      problem = e is StateError
          ? e.message.toString()
          : 'GPS unavailable right now.';
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    if (problem != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Widget cityField(bool origin) {
    final selected = origin ? booking.departureCity : booking.arrivalCity;
    final other = origin ? booking.arrivalCity : booking.departureCity;
    return DropdownButtonFormField<String>(
      key: ValueKey((origin, selected)),
      initialValue: selected,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      decoration: _homeInput(
        context,
        label: origin ? 'Departure city' : 'Arrival city',
        icon: origin ? Icons.trip_origin : Icons.flag_outlined,
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

  Widget _stopMenu(int index) => PopupMenuButton<String>(
    enabled: !booking.submitting,
    onSelected: (action) {
      if (action == 'remove') {
        booking.setStops([...booking.stops]..removeAt(index));
      } else {
        moveStop(index, action == 'up' ? -1 : 1);
      }
    },
    itemBuilder: (_) => [
      if (index > 0)
        const PopupMenuItem(
          value: 'up',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.arrow_upward),
            title: Text('Move up'),
          ),
        ),
      if (index + 1 < booking.stops.length)
        const PopupMenuItem(
          value: 'down',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.arrow_downward),
            title: Text('Move down'),
          ),
        ),
      const PopupMenuItem(
        value: 'remove',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.close),
          title: Text('Remove stop'),
        ),
      ),
    ],
  );

  Widget _routeCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _RouteRow(
            kind: _RouteKind.pickup,
            label: booking.courier ? 'Parcel pickup' : 'Pickup',
            title: pickup?.name ?? 'Choose pickup',
            placeholder: pickup == null,
            isFirst: true,
            onTap: booking.intercity && booking.departureCity == null
                ? null
                : () => choose(true),
          ),
          for (final (index, stop) in booking.stops.indexed)
            _RouteRow(
              kind: _RouteKind.stop,
              number: index + 1,
              label: 'Stop ${index + 1}',
              title: stop.name,
              trailing: _stopMenu(index),
            ),
          _RouteRow(
            kind: _RouteKind.destination,
            label: booking.courier ? 'Delivery address' : 'Destination',
            title: destination?.name ?? 'Where are you going?',
            placeholder: destination == null,
            isLast: true,
            onTap: booking.intercity && booking.arrivalCity == null
                ? null
                : () => choose(false),
          ),
        ],
      ),
    );
  }

  Widget _quickPicks(BuildContext context) {
    final app = widget.app;
    final saved = app.savedAddresses
        .map((p) => (_iconForLabel(p.label), p.label, p.place))
        .toList();
    final recents = <(IconData, String, Place)>[
      for (final place in app.recent.take(4))
        if (!app.savedAddresses.any(
          (s) => s.place.lat == place.lat && s.place.lng == place.lng,
        ))
          (Icons.history, place.name, place),
    ];
    final all = [...saved, ...recents];
    if (all.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Saved and recent'),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ActionChip(
              avatar: Icon(all[i].$1, size: 18),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(all[i].$2, overflow: TextOverflow.ellipsis),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () {
                booking.setPlaces(destination: all[i].$3);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _intercityCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Travel between cities',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          cityField(true),
          const SizedBox(height: 10),
          cityField(false),
        ],
      ),
    );
  }

  Widget _bookingContent(BuildContext context) {
    final app = widget.app;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where to, ${app.session!.firstName}?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _CategorySelector(
          standard: !booking.intercity && !booking.courier,
          intercity: booking.intercity,
          courier: booking.courier,
          enabled: !booking.submitting,
          onSelect: booking.setCategory,
        ),
        const SizedBox(height: 14),
        if (booking.intercity) ...[
          _intercityCard(context),
          const SizedBox(height: 12),
        ],
        _routeCard(context),
        if (!booking.courier && booking.stops.length < 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: booking.submitting ? null : addStop,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add a stop'),
            ),
          ),
        if (!booking.intercity) _quickPicks(context),
        const _SectionLabel('Ride options'),
        BookingFields(booking: booking),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final ride = app.ride;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: TriviaMap(
              pickup: ride?.pickup ?? pickup,
              destination: ride?.destination ?? destination,
              stops: ride?.stops ?? booking.stops,
              route: ride?.route ?? booking.quote?.points ?? const [],
              currentLocation: _here,
              bottomInset: constraints.maxHeight * _sheetStart,
              driver: ride?.freshLocation == true ? ride!.driverLocation : null,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Brand(),
                      ),
                    ),
                    const Spacer(),
                    _FloatingAction(
                      icon: Icons.my_location,
                      tooltip: 'Show my location',
                      onPressed: _locating ? null : _showMyLocation,
                    ),
                    if (ride?.active == true) ...[
                      const SizedBox(width: 8),
                      _FloatingAction(
                        icon: Icons.sos_outlined,
                        tooltip: 'Emergency numbers',
                        danger: true,
                        onPressed: () => showEmergencyOptions(context),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _FloatingAction(
                      icon: Icons.shield_outlined,
                      tooltip: 'Safety & support',
                      onPressed: () => openPage(context, SafetyPage(app: app)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: _sheetStart,
            minChildSize: .25,
            maxChildSize: .92,
            snap: !MediaQuery.disableAnimationsOf(context),
            snapSizes: const [_sheetStart],
            builder: (context, scroll) => Material(
              color: scheme.surface,
              borderRadius: sheetRadius,
              elevation: 16,
              child: ListView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: _motion(context, 250),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(ride != null),
                      child: SizedBox(
                        width: double.infinity,
                        child: ride != null
                            ? TripPanel(app: app)
                            : _bookingContent(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three selectable booking modes. Values map to the existing
/// `BookingController.setCategory` strings.
class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.standard,
    required this.intercity,
    required this.courier,
    required this.enabled,
    required this.onSelect,
  });
  final bool standard, intercity, courier, enabled;
  final void Function(String value) onSelect;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'Standard',
        'City ride',
        'Around town',
        Icons.local_taxi_outlined,
        standard,
      ),
      (
        'Intercity',
        'City-to-City',
        'Between cities',
        Icons.alt_route,
        intercity,
      ),
      (
        'Courier',
        'Courier',
        'Parcel delivery',
        Icons.inventory_2_outlined,
        courier,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final o in options)
          ChoiceChip(
            avatar: Icon(o.$4, size: 18),
            label: Text(o.$2),
            selected: o.$5,
            showCheckmark: false,
            onSelected: enabled && !o.$5 ? (_) => onSelect(o.$1) : null,
          ),
      ],
    );
  }
}

enum _RouteKind { pickup, stop, destination }

/// One row of the connected pickup → stops → destination component.
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.kind,
    required this.label,
    required this.title,
    this.number,
    this.placeholder = false,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.trailing,
  });
  final _RouteKind kind;
  final String label, title;
  final int? number;
  final bool placeholder, isFirst, isLast;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDestination = kind == _RouteKind.destination;

    Widget rail() =>
        Center(child: Container(width: 2, color: scheme.outlineVariant));

    final marker = switch (kind) {
      _RouteKind.pickup => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface,
          border: Border.all(color: scheme.primary, width: 4),
        ),
      ),
      _RouteKind.stop => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primaryContainer,
        ),
        child: Text(
          '$number',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      _RouteKind.destination => Icon(
        Icons.location_on,
        size: 26,
        color: scheme.primary,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Expanded(child: isFirst ? const SizedBox.shrink() : rail()),
                marker,
                Expanded(child: isLast ? const SizedBox.shrink() : rail()),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isDestination ? 14 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDestination
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _fadeText(
                      context,
                      title,
                      style:
                          (isDestination
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(
                                fontWeight: placeholder
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: placeholder
                                    ? scheme.onSurfaceVariant
                                    : null,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Place picker
// ---------------------------------------------------------------------------

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
    final scheme = Theme.of(context).colorScheme;
    final viewport =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final compact = viewport < 260;
    final mapLabel = map ? 'Search list' : 'Choose on map';
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    TextField(
                      controller: query,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search a landmark or neighbourhood',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: locating
                                    ? null
                                    : () {
                                        query.clear();
                                        scheduleSearch('');
                                      },
                              ),
                        counterText: '',
                        filled: true,
                        fillColor: scheme.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: border(scheme.outlineVariant),
                        enabledBorder: border(scheme.outlineVariant),
                        focusedBorder: border(scheme.primary, 2),
                      ),
                      maxLength: 200,
                      onChanged: scheduleSearch,
                      enabled: !locating,
                      onSubmitted: scheduleSearch,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: locating ? null : locate,
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Use my location'),
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: toggleMap,
                              icon: Icon(
                                map ? Icons.list : Icons.map_outlined,
                                size: 18,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(mapLabel),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (busy || locating)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            semanticsLabel: locating
                                ? 'Getting your location'
                                : 'Searching places',
                          ),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
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
                    const SizedBox(height: 8),
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
                      if (results.isNotEmpty) const _SectionLabel('Results'),
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
                        const _SectionLabel('Saved places'),
                      ...widget.app.savedAddresses.map(
                        (saved) => tile(saved.place, label: saved.label),
                      ),
                      if (widget.app.recent.isNotEmpty)
                        const _SectionLabel('Recent places'),
                      ...widget.app.recent.map(tile),
                    ],
                  ],
                ),
              ),
              if (selected != null &&
                  MediaQuery.viewInsetsOf(context).bottom == 0)
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: scheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selected!.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ActionButton(
                            widget.isPickup
                                ? 'Confirm pickup'
                                : 'Confirm destination',
                            locating
                                ? null
                                : () => Navigator.pop(context, selected),
                          ),
                        ),
                      ],
                    ),
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

  Widget tile(Place p, {String? label}) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected =
        selected != null && selected!.lat == p.lat && selected!.lng == p.lng;
    final alreadySaved = widget.app.savedAddresses.any(
      (v) => v.place.lat == p.lat && v.place.lng == p.lng,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            label == null ? Icons.place_outlined : _iconForLabel(label),
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          label ?? p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          p.formattedAddress ??
              '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        onTap: locating ? null : () => selectPlace(p),
        trailing: label != null
            ? null
            : IconButton(
                tooltip: 'Save place',
                icon: Icon(
                  alreadySaved ? Icons.bookmark : Icons.bookmark_outline,
                ),
                onPressed: widget.app.busy || alreadySaved
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip panel
// ---------------------------------------------------------------------------

/// Calm pulsing indicator shown while no driver offers exist yet.
class _WaitingForOffers extends StatefulWidget {
  const _WaitingForOffers();
  @override
  State<_WaitingForOffers> createState() => _WaitingForOffersState();
}

class _WaitingForOffersState extends State<_WaitingForOffers>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36 + 28 * _pulse.value,
                    height: 36 + 28 * _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        scheme.primaryContainer,
                        scheme.surfaceContainerLow,
                        _pulse.value,
                      ),
                    ),
                  ),
                  child!,
                ],
              ),
              child: Icon(Icons.radar, color: scheme.primary, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Looking for drivers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Waiting for offers. You can cancel at any time.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TripPanel extends StatelessWidget {
  const TripPanel({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final r = app.ride!;
    final d = r.driver;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connection = switch (app.realtime?.state) {
      'Connected' => 'Live trip updates',
      'Connecting' || 'Reconnecting' => 'Connecting to live updates…',
      'Sync interrupted' || 'Disconnected' => 'Live updates interrupted',
      _ => 'Updates refresh every 15 seconds',
    };
    final connected = app.realtime?.state == 'Connected';
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
    final cancelled = r.status == RideStatus.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cancelled
                  ? scheme.errorContainer
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (r.status) {
                    RideStatus.searching => Icons.radar,
                    RideStatus.completed => Icons.check_circle_outline,
                    RideStatus.cancelled => Icons.cancel_outlined,
                    _ => Icons.directions_car_outlined,
                  },
                  color: cancelled
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    deliveryStatusLabel(r),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cancelled
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (r.active) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? scheme.primary : scheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(connection, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ],
        if (r.departureAt case final departure?) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(child: Text('Departure · ${harareTime(departure)}')),
            ],
          ),
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      r.agreedCents == null
                          ? 'Your proposed fare'
                          : 'Agreed fare',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    money(r.cents, currency: r.currency),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (r.status == RideStatus.searching) ...[
          const SizedBox(height: 20),
          if (app.offers.isNotEmpty)
            Text(
              'Driver offers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          for (final o in app.offers)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutCubic,
                duration: _motion(context, 260),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: cardRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              Icons.person_outline,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  o.rating == null
                                      ? 'No rating yet'
                                      : '★ ${o.rating}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            money(o.cents, currency: r.currency),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                o.vehicle,
                                if (o.colour?.isNotEmpty == true) o.colour!,
                                o.plate,
                              ].join(' • '),
                            ),
                          ),
                        ],
                      ),
                      if (o.minutes != null || o.verified) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (o.minutes != null)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.schedule, size: 16),
                                label: Text('${o.minutes} min pickup'),
                              ),
                            if (o.verified)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(Icons.verified_outlined, size: 16),
                                label: Text('Verified by platform'),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ActionButton('Choose driver', () async {
                          if (await confirm(
                            context,
                            'Choose ${o.name}?',
                            'Agree to ${money(o.cents, currency: r.currency)} for this trip?',
                          )) {
                            await app.accept(o);
                          }
                        }, busy: app.busy),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (app.offers.isEmpty) const _WaitingForOffers(),
          TextButton.icon(
            onPressed: () => app.perform(app.sync),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh offers'),
          ),
        ] else if (d != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          d.vehicle,
                          if (d.colour?.isNotEmpty == true) d.colour!,
                        ].join(' • '),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Text(
                    d.plate,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            r.freshLocation
                ? 'Driver location updated ${r.locationUpdatedAt!.toUtc().add(const Duration(hours: 2)).toIso8601String().substring(11, 19)} CAT'
                : 'Live driver position unavailable or out of date.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => openPage(context, SafetyPage(app: app)),
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Safety & trip details'),
            ),
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
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              r.courier && next == RideStatus.inProgress
                  ? 'Confirm parcel pickup'
                  : statusLabel(next),
              () => app.transition(next),
              busy: app.busy,
            ),
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
