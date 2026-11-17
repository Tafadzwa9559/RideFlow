import 'package:flutter/material.dart';

import '../../app/controller.dart';
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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Brand(),
              const Spacer(),
              Text(
                app.online ? 'Online' : 'Offline',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Switch(
                value: app.online,
                onChanged: app.busy || app.ride?.active == true
                    ? null
                    : (v) => app.goOnline(v),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: TriviaMap(
                  pickup: app.ride?.pickup,
                  destination: app.ride?.destination,
                  route: app.ride?.route ?? const [],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 380),
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (app.ride != null)
                          TripPanel(app: app)
                        else ...[
                          Text(
                            'Drive on your terms.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text('Verification: ${status.name}'),

                          const SizedBox(height: 12),
                          Text(
                            'Go online to review available requests. Location is used only while you’re actively working.',
                          ),
                          const SizedBox(height: 20),
                          ActionButton(
                            app.online ? 'View ride requests' : 'Go online',
                            app.online
                                ? () => openPage(
                                    context,
                                    DriverRequests(app: app),
                                  )
                                : () => app.goOnline(true),
                            busy: app.busy,
                          ),
                        ],
                        ErrorNotice(app),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
  final declined = <String>{};
  String? error;
  bool loading = false;
  bool lastOnline = false;
  int lastRevision = -1;
  @override
  void initState() {
    super.initState();
    lastOnline = widget.app.online;
    load();
  }

  @override
  void didUpdateWidget(DriverRequests oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (lastOnline != widget.app.online ||
        lastRevision != widget.app.dataRevision) {
      lastRevision = widget.app.dataRevision;
      lastOnline = widget.app.online;
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (widget.app.session!.driverStatus != DriverStatus.approved ||
          !widget.app.online) {
        requests = [];
      } else {
        requests = await widget.app.repository.requests();
      }
    } catch (_) {
      error = 'Requests unavailable. Check your connection and retry.';
    }
    if (mounted) {
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
      if (value == null) {
        return;
      }
      cents = parseFare(value);
    }
    final ok = await widget.app.perform(
      () => widget.app.repository.counteroffer(r.id, cents),
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
          body: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (loading) const LinearProgressIndicator(),
                if (error != null) Text(error!),
                ErrorNotice(widget.app),
                if (!widget.app.online)
                  const EmptyState(
                    'You’re offline',
                    'Go online from the driver home to see available requests.',
                  ),
                if (widget.app.online &&
                    requests.where((r) => !declined.contains(r.id)).isEmpty &&
                    !loading)
                  const EmptyState(
                    'No requests right now',
                    'Pull down to refresh. Availability depends on your approved service area.',
                  ),
                for (final r in requests.where((r) => !declined.contains(r.id)))
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            money(r.cents, currency: r.currency),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text('Trivia ${r.category}'),
                          const SizedBox(height: 16),
                          Text('${r.pickup.name}\n↓\n${r.destination.name}'),
                          Text(
                            'Payment method: ${directPaymentLabel(r.paymentMethod, r.paymentMethodName)}',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Road distance and pickup estimate unavailable.',
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
          body: ListView(
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
                  return Column(
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
                  );
                },
              ),
            ],
          ),
        );
}
