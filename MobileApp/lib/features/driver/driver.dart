import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../app/theme.dart' show cardRadius, sheetRadius;
import '../../core/map_view.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../passenger/home.dart';
import 'registration.dart';

// ---------------------------------------------------------------------------
// Shared helpers (private to this file)
// ---------------------------------------------------------------------------

Duration _motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Rounded placeholder that gently pulses while content loads.
class _Skeleton extends StatefulWidget {
  const _Skeleton({required this.height, this.width, this.radius = 12});
  final double height, radius;
  final double? width;
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surfaceContainerHighest,
            scheme.surfaceContainerLow,
            _c.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, {this.size = 40});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * .52, color: scheme.onPrimaryContainer),
    );
  }
}

// ---------------------------------------------------------------------------
// Driver home
// ---------------------------------------------------------------------------

class DriverHome extends StatelessWidget {
  const DriverHome({super.key, required this.app});
  final AppController app;

  static const _sheetStart = .42;

  @override
  Widget build(BuildContext context) {
    final status = app.session!.driverStatus;
    if (status != DriverStatus.approved) return DriverRegistration(app: app);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final ride = app.ride;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: TriviaMap(
              pickup: app.ride?.pickup,
              destination: app.ride?.destination,
              stops: app.ride?.stops ?? const [],
              route: app.ride?.route ?? const [],
              bottomInset: constraints.maxHeight * _sheetStart,
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
                    _AvailabilityPill(app: app),
                  ],
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: _sheetStart,
            minChildSize: .22,
            maxChildSize: .92,
            snap: !MediaQuery.disableAnimationsOf(context),
            snapSizes: const [_sheetStart],
            builder: (context, scroll) => Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: sheetRadius,
                boxShadow: const [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 16),
                ],
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                      key: ValueKey((ride != null, app.online)),
                      child: SizedBox(
                        width: double.infinity,
                        child: ride != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const _IconChip(
                                        Icons.local_taxi_outlined,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Currently on a trip',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TripPanel(app: app),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: app.online
                                              ? scheme.primaryContainer
                                              : scheme.surfaceContainerHighest,
                                        ),
                                        child: Icon(
                                          app.online
                                              ? Icons.radar
                                              : Icons.power_settings_new,
                                          color: app.online
                                              ? scheme.onPrimaryContainer
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app.online
                                                  ? 'Ready for requests'
                                                  : 'You’re offline',
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              app.online
                                                  ? 'Review requests in your approved service area.'
                                                  : 'Go online to receive requests. Location is used while you’re working.',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _DriverServices(app: app),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ActionButton(
                                      app.online
                                          ? 'View ride requests'
                                          : 'Go online',
                                      app.online
                                          ? () => openPage(
                                              context,
                                              DriverRequests(app: app),
                                            )
                                          : () => app.goOnline(true),
                                      busy: app.busy,
                                    ),
                                  ),
                                  ErrorNotice(app),
                                ],
                              ),
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

/// Online / offline control. Locked while busy or during an active ride,
/// exactly like the original switch.
class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = app.online;
    return AnimatedContainer(
      duration: _motion(context, 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: online ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: _motion(context, 220),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? scheme.primary : scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            online ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: online ? scheme.onPrimaryContainer : null,
            ),
          ),
          Semantics(
            label: 'Accept ride requests',
            child: Switch(
              value: online,
              onChanged: app.busy || app.ride?.active == true
                  ? null
                  : (v) => app.goOnline(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverServices extends StatefulWidget {
  const _DriverServices({required this.app});
  final AppController app;

  @override
  State<_DriverServices> createState() => _DriverServicesState();
}

class _DriverServicesState extends State<_DriverServices> {
  static const resource = 'drivers/me/service-preferences';
  Map<String, bool>? services;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({Map<String, bool>? changes}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (changes != null) {
        await widget.app.repository.write(resource, changes);
      }
      final response = await widget.app.repository.read(resource);
      if (!mounted) return;
      if (response['accepts_intercity'] is! bool ||
          response['accepts_courier'] is! bool) {
        throw const FormatException();
      }
      setState(
        () => services = {
          'accepts_intercity': response['accepts_intercity'] as bool,
          'accepts_courier': response['accepts_courier'] as bool,
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          services = null;
          error = 'Could not load service preferences.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (services == null) {
      return Semantics(
        label: 'Loading driver services',
        child: const Column(
          children: [
            _Skeleton(height: 32, radius: 16),
            SizedBox(height: 10),
            _Skeleton(height: 112, radius: 16),
          ],
        ),
      );
    }
    final toggles = [
      (
        'accepts_intercity',
        'Accept City-to-City requests',
        'Trips between cities',
        Icons.alt_route,
      ),
      (
        'accepts_courier',
        'Accept courier requests',
        'Parcel deliveries',
        Icons.inventory_2_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your services',
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            const Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.local_taxi_outlined, size: 16),
              label: Text('City rides'),
            ),
            if (services!['accepts_intercity']!)
              const Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.alt_route, size: 16),
                label: Text('City-to-City'),
              ),
            if (services!['accepts_courier']!)
              const Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.inventory_2_outlined, size: 16),
                label: Text('Courier'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              if (busy) const LinearProgressIndicator(minHeight: 2),
              for (final (i, t) in toggles.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 70,
                    endIndent: 16,
                    color: scheme.outlineVariant,
                  ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  secondary: _IconChip(t.$4),
                  title: Text(t.$2),
                  subtitle: Text(t.$3),
                  value: services![t.$1]!,
                  onChanged: busy
                      ? null
                      : (value) => load(changes: {t.$1: value}),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ride requests
// ---------------------------------------------------------------------------

class DriverRequests extends StatefulWidget {
  const DriverRequests({super.key, required this.app});
  final AppController app;
  @override
  State<DriverRequests> createState() => _DriverRequestsState();
}

class _DriverRequestsState extends State<DriverRequests> {
  List<Ride> requests = [];
  String service = 'city';
  Iterable<Ride> get visibleRequests => requests.where(
    (ride) =>
        (ride.courier ? 'courier' : (ride.intercity ? 'intercity' : 'city')) ==
            service &&
        !declined.contains(ride.id),
  );
  final declined = <String>{};
  String? error;
  bool loading = false;
  bool lastOnline = false;
  int lastRevision = -1;
  int _requestLoad = 0;
  bool get _onTrip => widget.app.driverMode && widget.app.ride?.active == true;
  @override
  void initState() {
    super.initState();
    lastOnline = widget.app.online;
    lastRevision = widget.app.dataRevision;
    widget.app.addListener(_appChanged);
    load();
  }

  @override
  void didUpdateWidget(DriverRequests oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app) {
      oldWidget.app.removeListener(_appChanged);
      widget.app.addListener(_appChanged);
      lastOnline = widget.app.online;
      lastRevision = widget.app.dataRevision;
      load();
    }
  }

  void _appChanged() {
    if (lastOnline != widget.app.online ||
        lastRevision != widget.app.dataRevision) {
      lastRevision = widget.app.dataRevision;
      lastOnline = widget.app.online;
      load();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.app.removeListener(_appChanged);
    super.dispose();
  }

  Future<void> load() async {
    final load = ++_requestLoad;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final available =
          widget.app.session?.driverStatus == DriverStatus.approved &&
          widget.app.online &&
          !_onTrip;
      final result = available
          ? await widget.app.repository.requests()
          : <Ride>[];
      if (mounted && load == _requestLoad) requests = result;
    } catch (_) {
      if (mounted && load == _requestLoad) {
        error = 'Requests unavailable. Check your connection and retry.';
      }
    }
    if (mounted && load == _requestLoad) {
      setState(() => loading = false);
    }
  }

  Future<void> offer(Ride r, {bool counter = false}) async {
    int cents = r.cents;
    if (counter) {
      final value = await showDialog<String>(
        context: context,
        builder: (_) =>
            _CounterDialog(currency: r.currency, offeredCents: r.cents),
      );
      if (value == null || !mounted) {
        return;
      }
      cents = parseFare(value);
    }
    final ok = await widget.app.perform(
      () => counter
          ? widget.app.repository.counteroffer(r.id, cents)
          : widget.app.repository.acceptFare(r.id),
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offer submitted. Waiting for the passenger to choose.',
          ),
        ),
      );
    }
  }

  Future<void> decline(Ride r) async {
    final ok = await widget.app.perform(
      () => widget.app.repository.write(
        'rides/${r.id}/driver-request-decline',
        {},
      ),
    );
    if (ok && mounted) {
      setState(() => declined.add(r.id));
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.app.session?.driverStatus != DriverStatus.approved
      ? DriverRegistration(app: widget.app)
      : Scaffold(
          appBar: AppBar(
            title: const Text('Ride requests'),
            actions: [
              IconButton(
                tooltip: 'Refresh requests',
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _onTrip
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [TripPanel(app: widget.app)],
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'city',
                              label: Text('City rides'),
                            ),
                            ButtonSegment(
                              value: 'intercity',
                              label: Text('City-to-City'),
                            ),
                            ButtonSegment(
                              value: 'courier',
                              label: Text('Courier'),
                            ),
                          ],
                          selected: {service},
                          onSelectionChanged: (selection) =>
                              setState(() => service = selection.first),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (loading && requests.isEmpty) ...[
                        Semantics(
                          label: 'Loading ride requests',
                          child: const _RequestSkeleton(),
                        ),
                        const SizedBox(height: 12),
                        const _RequestSkeleton(),
                      ] else if (loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(
                            semanticsLabel: 'Loading ride requests',
                          ),
                        ),
                      if (error != null) ...[
                        InlineNotice(error!, isError: true),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                      ErrorNotice(widget.app),
                      if (!widget.app.online)
                        const EmptyState(
                          'You’re offline',
                          'Go online from the driver home to see available requests.',
                        ),
                      if (error == null &&
                          widget.app.online &&
                          visibleRequests.isEmpty &&
                          !loading)
                        const EmptyState(
                          'No requests right now',
                          'Pull down to refresh. Availability depends on your approved service area.',
                        ),
                      for (final r in visibleRequests)
                        Padding(
                          key: ValueKey(r.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RequestCard(
                            ride: r,
                            app: widget.app,
                            onAccept: () => offer(r),
                            onCounter: () => offer(r, counter: true),
                            onDecline: () => decline(r),
                          ),
                        ),
                    ],
                  ),
                ),
        );
}

class _RequestSkeleton extends StatelessWidget {
  const _RequestSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: cardRadius,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Skeleton(height: 28, width: 140),
        SizedBox(height: 14),
        _Skeleton(height: 18),
        SizedBox(height: 8),
        _Skeleton(height: 18, width: 220),
        SizedBox(height: 16),
        _Skeleton(height: 48, radius: 16),
      ],
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.ride,
    required this.app,
    required this.onAccept,
    required this.onCounter,
    required this.onDecline,
  });
  final Ride ride;
  final AppController app;
  final VoidCallback onAccept, onCounter, onDecline;

  @override
  Widget build(BuildContext context) {
    final r = ride;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoryIcon = r.courier
        ? Icons.inventory_2_outlined
        : (r.intercity ? Icons.alt_route : Icons.local_taxi_outlined);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      duration: _motion(context, 240),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: cardRadius,
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offered fare',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money(r.cents, currency: r.currency),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryIcon,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r.serviceName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.distanceMetres case final distance?)
                  _InfoPill(
                    Icons.straighten,
                    '${app.distanceLabel(distance)} by road',
                  ),
                if (r.departureAt case final departure?)
                  _InfoPill(Icons.schedule, harareTime(departure)),
                if (r.courier)
                  _InfoPill(
                    Icons.inventory_2_outlined,
                    '${r.parcelSize ?? 'Parcel'} · ${r.parcelWeightKg ?? '–'} kg',
                  ),
                if (r.intercity) ...[
                  _InfoPill(
                    Icons.people_outline,
                    '${r.passengerCount} passengers',
                  ),
                  _InfoPill(Icons.luggage_outlined, luggageLabel(r.luggage)),
                ],
              ],
            ),
            if (r.intercity) ...[
              const SizedBox(height: 12),
              Text(
                '${r.pickup.city} → ${r.destination.city}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            RouteStops(
              pickup: r.pickup.name,
              stops: r.stops.map((stop) => stop.name).toList(),
              destination: r.destination.name,
            ),
            if (r.intercity && r.passengerNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.passengerNote,
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ActionButton('Accept fare', onAccept, busy: app.busy),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: app.busy ? null : onCounter,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Make a counteroffer'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterDialog extends StatefulWidget {
  const _CounterDialog({required this.currency, required this.offeredCents});
  final String currency;
  final int offeredCents;
  @override
  State<_CounterDialog> createState() => _CounterDialogState();
}

class _CounterDialogState extends State<_CounterDialog> {
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, input.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Your counteroffer'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current offer: ${money(widget.offeredCents, currency: widget.currency)}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: input,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Your fare',
                prefixText: '${currencySymbol(widget.currency)} ',
                suffixText: widget.currency,
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (v) {
                try {
                  parseFare(v ?? '');
                  return null;
                } on FormatException catch (e) {
                  return e.message;
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send offer')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings
// ---------------------------------------------------------------------------

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key, required this.app});
  final AppController app;
  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  String period = 'Today';
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    fetch();
  }

  void fetch() {
    if (widget.app.session?.driverStatus != DriverStatus.approved) {
      data = Future.value({});
      return;
    }
    data = widget.app.repository.read(
      'drivers/me/earnings?period=${period == 'Today' ? 'day' : period.toLowerCase()}',
    );
  }

  Widget _loading() => Semantics(
    label: 'Loading earnings',
    child: const Column(
      children: [
        _Skeleton(height: 140, radius: 28),
        SizedBox(height: 12),
        _Skeleton(height: 72, radius: 20),
        SizedBox(height: 12),
        _Skeleton(height: 72, radius: 20),
      ],
    ),
  );

  Widget _content(BuildContext context, Map<String, dynamic> j) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed trip fares (USD)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'US\$ ${j['agreed_fares'] ?? 'Unavailable'}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                period,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ],
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
          child: Row(
            children: [
              const _IconChip(Icons.check_circle_outline, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Completed trips',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '${j['completed_trips'] ?? 'Unavailable'}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Passengers pay drivers directly. Trivia does not verify receipt of funds.',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.app.session?.driverStatus != DriverStatus.approved
      ? DriverRegistration(app: widget.app)
      : Scaffold(
          appBar: AppBar(title: const Text('Your earnings')),
          body: ContentFrame(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'Today', label: Text('Today')),
                      ButtonSegment(value: 'Week', label: Text('Week')),
                      ButtonSegment(value: 'Month', label: Text('Month')),
                    ],
                    selected: {period},
                    onSelectionChanged: (selection) => setState(() {
                      period = selection.first;
                      fetch();
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: _motion(context, 220),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(period),
                    child: SizedBox(
                      width: double.infinity,
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: data,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Column(
                              children: [
                                const EmptyState(
                                  'Earnings unavailable',
                                  'Check your connection and try again.',
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setState(fetch),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            );
                          }
                          if (!snapshot.hasData) return _loading();
                          return _content(context, snapshot.data!);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}
