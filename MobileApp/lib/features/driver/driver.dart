import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../app/theme.dart' show cardRadius;
import '../../core/map_view.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../passenger/home.dart';
import 'registration.dart';

class DriverHome extends StatelessWidget {
  const DriverHome({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final status = app.session!.driverStatus;
    if (status != DriverStatus.approved) return DriverRegistration(app: app);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Align(alignment: Alignment.centerLeft, child: Brand()),
              ),
              Flexible(
                child: Text(
                  app.online ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Semantics(
                label: 'Accept ride requests',
                child: Switch(
                  value: app.online,
                  onChanged: app.busy || app.ride?.active == true
                      ? null
                      : (v) => app.goOnline(v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ContentFrame(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                ClipRRect(
                  borderRadius: cardRadius,
                  child: SizedBox(
                    height: (MediaQuery.sizeOf(context).height * .38).clamp(
                      210.0,
                      400.0,
                    ),
                    child: TriviaMap(
                      pickup: app.ride?.pickup,
                      destination: app.ride?.destination,
                      stops: app.ride?.stops ?? const [],
                      route: app.ride?.route ?? const [],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (app.ride != null)
                        TripPanel(app: app)
                      else ...[
                        Text(
                          app.online ? 'Ready for requests' : 'You’re offline',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          app.online
                              ? 'Review requests in your approved service area.'
                              : 'Go online to receive requests. Location is used while you’re working.',
                        ),
                        _DriverServices(app: app),
                        const SizedBox(height: 20),
                        ActionButton(
                          app.online ? 'View ride requests' : 'Go online',
                          app.online
                              ? () =>
                                    openPage(context, DriverRequests(app: app))
                              : () => app.goOnline(true),
                          busy: app.busy,
                        ),
                      ],
                      ErrorNotice(app),
                    ],
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
    if (error != null) {
      return TextButton(onPressed: load, child: Text('$error Retry'));
    }
    if (services == null) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Loading driver services',
      );
    }
    return Column(
      children: [
        for (final (key, label) in [
          ('accepts_intercity', 'Accept City-to-City requests'),
          ('accepts_courier', 'Accept courier requests'),
        ])
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            value: services![key]!,
            onChanged: busy ? null : (value) => load(changes: {key: value}),
          ),
      ],
    );
  }
}

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
        builder: (_) => _CounterDialog(currency: r.currency),
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
                    padding: const EdgeInsets.all(20),
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final (value, label) in [
                            ('city', 'City rides'),
                            ('intercity', 'City-to-City'),
                            ('courier', 'Courier'),
                          ])
                            ChoiceChip(
                              selected: service == value,
                              label: Text(label),
                              onSelected: (_) =>
                                  setState(() => service = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (loading)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Loading ride requests',
                        ),
                      if (error != null) InlineNotice(error!, isError: true),
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
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card.outlined(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    money(r.cents, currency: r.currency),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  Text(r.serviceName),
                                  if (r.courier)
                                    Text(
                                      '${r.parcelSize ?? 'Parcel'} · ${r.parcelWeightKg ?? '–'} kg',
                                    ),
                                  if (r.departureAt case final departure?)
                                    Text(harareTime(departure)),
                                  if (r.intercity) ...[
                                    Text(
                                      '${r.pickup.city} → ${r.destination.city}',
                                    ),
                                    Text(
                                      '${r.passengerCount} passengers · ${luggageLabel(r.luggage)}',
                                    ),
                                    if (r.passengerNote.isNotEmpty)
                                      Text(r.passengerNote),
                                  ],
                                  const SizedBox(height: 16),
                                  RouteStops(
                                    pickup: r.pickup.name,
                                    stops: r.stops
                                        .map((stop) => stop.name)
                                        .toList(),
                                    destination: r.destination.name,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Payment preference: ${directPaymentLabel(r.paymentMethod, r.paymentMethodName)}',
                                  ),
                                  const SizedBox(height: 12),
                                  if (r.distanceMetres case final distance?)
                                    Text(
                                      '${widget.app.distanceLabel(distance)} by road',
                                    ),
                                  const SizedBox(height: 16),
                                  ActionButton(
                                    'Accept fare',
                                    () => offer(r),
                                    busy: widget.app.busy,
                                  ),
                                  TextButton(
                                    onPressed: widget.app.busy
                                        ? null
                                        : () => offer(r, counter: true),
                                    child: const Text('Make a counteroffer'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final ok = await widget.app.perform(
                                        () => widget.app.repository.write(
                                          'rides/${r.id}/driver-request-decline',
                                          {},
                                        ),
                                      );
                                      if (ok && mounted) {
                                        setState(() => declined.add(r.id));
                                      }
                                    },
                                    child: const Text('Decline'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
}

class _CounterDialog extends StatefulWidget {
  const _CounterDialog({required this.currency});
  final String currency;
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your counteroffer'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: input,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixText: '${currencySymbol(widget.currency)} ',
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
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, input.text);
          }
        },
        child: const Text('Send offer'),
      ),
    ],
  );
}

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

  @override
  Widget build(BuildContext context) =>
      widget.app.session?.driverStatus != DriverStatus.approved
      ? DriverRegistration(app: widget.app)
      : Scaffold(
          appBar: AppBar(title: const Text('Your earnings')),
          body: ContentFrame(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Wrap(
                  spacing: 8,
                  children: ['Today', 'Week', 'Month']
                      .map(
                        (p) => ChoiceChip(
                          label: Text(p),
                          selected: period == p,
                          onSelected: (_) => setState(() {
                            period = p;
                            fetch();
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                FutureBuilder<Map<String, dynamic>>(
                  future: data,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const EmptyState(
                            'Earnings unavailable',
                            'Check your connection and try again.',
                          ),
                          OutlinedButton(
                            onPressed: () => setState(fetch),
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final j = snapshot.data!;
                    return InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Completed trip fares (USD)'),
                          Text(
                            'US\$ ${j['agreed_fares'] ?? 'Unavailable'}',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 24),
                          ListTile(
                            title: const Text('Completed trips'),
                            trailing: Text(
                              '${j['completed_trips'] ?? 'Unavailable'}',
                            ),
                          ),
                          const Text(
                            'Passengers pay drivers directly. Trivia does not verify receipt of funds.',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
}
