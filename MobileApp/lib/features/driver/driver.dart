import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/map_view.dart';
import '../../core/repository.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../passenger/home.dart';

class DriverHome extends StatelessWidget {
  const DriverHome({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final status = app.session!.driverStatus;
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
                onChanged: app.busy || status != DriverStatus.approved
                    ? null
                    : (v) => app.goOnline(v),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(child: TriviaMap()),
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
                            status == DriverStatus.approved
                                ? 'Drive on your terms.'
                                : 'Your next chapter starts here.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text('Verification: ${status.name}'),
                          const SizedBox(height: 12),
                          Text(
                            status == DriverStatus.approved
                                ? 'Go online to review available requests. Location is used only while you’re actively working.'
                                : 'Submit your application for review. Only approved drivers can receive live requests.',
                          ),
                          const SizedBox(height: 20),
                          if (status != DriverStatus.approved)
                            ActionButton(
                              'Driver application',
                              () => openPage(
                                context,
                                DriverApplication(app: app),
                              ),
                            ),
                          if (AppConfig.demo && status != DriverStatus.approved)
                            TextButton(
                              onPressed: () => app.perform(() async {
                                (app.repository as DemoRepository)
                                    .approveSimulation();
                                app.session = await app.repository.restore();
                              }),
                              child: const Text(
                                'Developer demo: simulate approval',
                              ),
                            ),
                          if (status == DriverStatus.approved)
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

class DriverApplication extends StatefulWidget {
  const DriverApplication({super.key, required this.app});
  final AppController app;
  @override
  State<DriverApplication> createState() => _DriverApplicationState();
}

class _DriverApplicationState extends State<DriverApplication> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final k in [
      'make',
      'model',
      'year',
      'colour',
      'registration',
      'seats',
    ])
      k: TextEditingController(),
  };
  final documents = <String, String>{};
  List<Map<String, dynamic>> requirements = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.app.repository.read('driver/requirements');
      if (mounted) {
        setState(
          () => requirements = (data['documents'] as List)
              .cast<Map<String, dynamic>>(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Document requirements unavailable. Retry before applying.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(String key) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => documents[key] = file.path);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Photo access unavailable. Check device permissions.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Become a Trivia driver')),
    body: ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your vehicle',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.app.session!.firstName} ${widget.app.session!.lastName}\n${widget.app.session!.phone}',
              ),
              const SizedBox(height: 20),
              for (final e in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: e.value,
                    keyboardType: ['year', 'seats'].contains(e.key)
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: e.key == 'seats'
                          ? 'Passenger seating capacity'
                          : '${e.key[0].toUpperCase()}${e.key.substring(1)}',
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'Required';
                      }
                      if (e.key == 'year') {
                        final y = int.tryParse(v!);
                        if (y == null ||
                            y < 1950 ||
                            y > DateTime.now().year + 1) {
                          return 'Enter a valid year.';
                        }
                      }
                      if (e.key == 'seats') {
                        final n = int.tryParse(v!);
                        if (n == null || n < 1 || n > 20) {
                          return 'Enter 1–20 passenger seats.';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Text('Documents', style: Theme.of(context).textTheme.titleLarge),
              const Text(
                'Requirements are supplied by the platform. Upload clear photographs. Demo documents are kept only in memory and are not uploaded.',
              ),
              if (loading) const LinearProgressIndicator(),
              for (final d in requirements)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d['label'] as String),
                  subtitle: Text(
                    documents.containsKey(d['key'])
                        ? 'Photo selected'
                        : 'Choose a photograph',
                  ),
                  trailing: Icon(
                    documents.containsKey(d['key'])
                        ? Icons.check_circle
                        : Icons.upload_file,
                    color: darkGreen,
                  ),
                  onTap: () => pick(d['key'] as String),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              ErrorNotice(widget.app),
              const SizedBox(height: 20),
              ActionButton(
                'Submit for review',
                loading || requirements.isEmpty
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) {
                          return;
                        }
                        if (requirements.any(
                          (d) => !documents.containsKey(d['key']),
                        )) {
                          setState(
                            () => error = 'Select all required documents.',
                          );
                          return;
                        }
                        final ok = await widget.app.perform(() async {
                          await widget.app.repository.applyDriver({
                            for (final e in fields.entries)
                              e.key: e.value.text.trim(),
                          }, documents);
                          widget.app.session = await widget.app.repository
                              .restore();
                        });
                        if (ok && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                busy: widget.app.busy,
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(DriverRequests oldWidget) {
    super.didUpdateWidget(oldWidget);
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
        builder: (_) => const _CounterDialog(),
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
  Widget build(BuildContext context) => Scaffold(
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
                      money(r.cents),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text('Trivia ${r.category}'),
                    const SizedBox(height: 16),
                    Text('${r.pickup.name}\n↓\n${r.destination.name}'),
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
                      onPressed: () => setState(() => declined.add(r.id)),
                      child: const Text('Decline'),
                    ),
                    if (AppConfig.demo)
                      TextButton(
                        onPressed: () async {
                          final ok = await widget.app.book(
                            r.pickup,
                            r.destination,
                            r.category,
                            r.cents,
                          );
                          if (ok) {
                            final o = widget.app.offers.firstOrNull;
                            if (o != null) {
                              await widget.app.accept(o);
                            }
                          }
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Demo passenger selected you. Open driver Home for trip controls.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Developer demo: simulate passenger selection',
                        ),
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
  const _CounterDialog();
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
        decoration: const InputDecoration(prefixText: 'USD '),
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
    data = widget.app.repository.read(
      'driver/earnings?period=${period.toLowerCase()}',
    );
    if (AppConfig.demo) {
      data = widget.app.repository.read('driver/earnings');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                const Text('Net earnings'),
                Text(
                  money(j['net_cents'] as int),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 24),
                for (final e in [
                  ('Gross earnings', money(j['gross_cents'] as int)),
                  ('Commission', money(j['commission_cents'] as int)),
                  ('Completed trips', '${j['trips']}'),
                  ('Payout', '${j['payout_status']}'),
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.$1),
                    trailing: Text(e.$2),
                  ),
                const Divider(),
                const EmptyState(
                  'No transactions to show',
                  'Verified transactions and payouts will appear here.',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
