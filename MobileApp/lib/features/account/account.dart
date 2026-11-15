import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../core/config.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../entry/entry.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your account')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: pale,
              child: Icon(Icons.person_outline, size: 34, color: darkGreen),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${app.session!.firstName} ${app.session!.lastName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(app.session!.phone),
                  Text(
                    app.driverMode ? 'Driver mode' : 'Passenger mode',
                    style: const TextStyle(color: darkGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: app.busy ? null : app.switchMode,
          icon: const Icon(Icons.swap_horiz),
          label: Text(
            app.driverMode ? 'Switch to Passenger' : 'Switch to Driver',
          ),
        ),
        ErrorNotice(app),
        const SizedBox(height: 16),
        for (final entry in <(IconData, String, Widget)>[
          (
            Icons.person_outline,
            'Personal information',
            ProfileSetup(app: app),
          ),
          (Icons.bookmark_outline, 'Saved places', SavedPlacesPage(app: app)),
          (Icons.receipt_long_outlined, 'Trip history', HistoryPage(app: app)),
          (
            Icons.payments_outlined,
            'Payment methods',
            ResourcePage(
              app: app,
              title: 'Payment methods',
              resource: 'payments/methods',
              empty: 'No payment methods are enabled.',
            ),
          ),
          (
            Icons.account_balance_wallet_outlined,
            'Payment history',
            ResourcePage(
              app: app,
              title: 'Payment history',
              resource: 'payments/history',
              empty: 'No transactions yet.',
            ),
          ),
          (Icons.shield_outlined, 'Safety & support', SafetyPage(app: app)),
          (
            Icons.settings_outlined,
            'Settings & privacy',
            SettingsPage(app: app),
          ),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(entry.$1),
            title: Text(entry.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openPage(context, entry.$3),
          ),
        const Divider(height: 32),
        TextButton(
          onPressed: app.busy
              ? null
              : () async {
                  if (await confirm(
                    context,
                    'Log out?',
                    'You will need to verify your phone number to sign in again.',
                  )) {
                    await app.logout();
                  }
                },
          child: const Text('Log out'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Trivia — Developed by\nMOrdec Solutions (Private) Limited',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your Journey. Your Choice.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: darkGreen),
        ),
      ],
    ),
  );
}

class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved places')),
    body: ListenableBuilder(
      listenable: app,
      builder: (_, _) => app.saved.isEmpty
          ? const EmptyState(
              'Keep your favourites close',
              'Save a landmark using the bookmark in location search. Places are kept for this session.',
              icon: Icons.bookmark_outline,
            )
          : ListView(
              children: app.saved
                  .map(
                    (p) => ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.app});
  final AppController app;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String filter = 'All';
  DateTimeRange? range;
  @override
  Widget build(BuildContext context) {
    final records = widget.app.history
        .where(
          (r) =>
              (filter == 'All' ||
                  (filter == 'Completed'
                      ? r.status == RideStatus.completed
                      : r.status == RideStatus.cancelled)) &&
              (range == null ||
                  (!r.createdAt.isBefore(range!.start.toUtc()) &&
                      r.createdAt.isBefore(
                        range!.end.add(const Duration(days: 1)).toUtc(),
                      ))),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your activity'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final selected = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (mounted) {
                setState(() => range = selected);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => widget.app.perform(widget.app.sync),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              children: ['All', 'Completed', 'Cancelled']
                  .map(
                    (v) => ChoiceChip(
                      label: Text(v),
                      selected: filter == v,
                      onSelected: (_) => setState(() => filter = v),
                    ),
                  )
                  .toList(),
            ),
            if (range != null)
              TextButton(
                onPressed: () => setState(() => range = null),
                child: const Text('Clear date filter'),
              ),
            ErrorNotice(widget.app),
            if (records.isEmpty)
              const EmptyState(
                'Your journeys start here',
                'Completed and cancelled rides will appear in your activity.',
              ),
            for (final r in records)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: pale,
                  child: Icon(Icons.local_taxi_outlined, color: darkGreen),
                ),
                title: Text(r.destination.name),
                subtitle: Text(
                  '${DateFormat('d MMM, HH:mm').format(r.createdAt.toUtc().add(const Duration(hours: 2)))} CAT\n${statusLabel(r.status)}',
                ),
                trailing: Text(money(r.cents)),
                onTap: () =>
                    openPage(context, ReceiptPage(app: widget.app, ride: r)),
              ),
          ],
        ),
      ),
    );
  }
}

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.app, required this.ride});
  final AppController app;
  final Ride ride;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip details')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Brand(),
        const SizedBox(height: 24),
        Text(
          statusLabel(ride.status),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text('${ride.pickup.name}\n↓\n${ride.destination.name}'),
        const Divider(height: 40),
        Text(
          money(ride.cents),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        Text('Payment status: ${ride.paymentStatus}'),
        const SizedBox(height: 12),
        Text('Trip reference: ${ride.id}'),
        if (ride.driver != null)
          Text(
            '${ride.driver!.name}\n${ride.driver!.vehicle} · ${ride.driver!.plate}',
          ),
        const SizedBox(height: 24),
        const Text(
          'This trip summary is not a payment confirmation. Tax receipts require verified backend payment records.',
        ),
        if (ride.status == RideStatus.completed) ...[
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => openPage(
              context,
              FeedbackPage(
                app: app,
                title: 'Rate your journey',
                resource: 'rides/${ride.id}/review',
              ),
            ),
            child: const Text('Rating & review'),
          ),
        ],
        OutlinedButton(
          onPressed: () => openPage(
            context,
            FeedbackPage(
              app: app,
              title: 'Trip dispute',
              resource: 'rides/${ride.id}/dispute',
            ),
          ),
          child: const Text('Report a problem'),
        ),
      ],
    ),
  );
}

class ResourcePage extends StatefulWidget {
  const ResourcePage({
    super.key,
    required this.app,
    required this.title,
    required this.resource,
    required this.empty,
  });
  final AppController app;
  final String title, resource, empty;
  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    data = widget.app.repository.read(widget.resource);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (_, s) {
        if (s.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmptyState(
                'Unable to load',
                'Check your connection and try again.',
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => data = widget.app.repository.read(widget.resource),
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          );
        }
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = s.data!['items'] as List? ?? [];
        if (items.isEmpty) {
          return EmptyState(
            widget.title,
            widget.empty,
            icon: Icons.inbox_outlined,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.resource == 'payments/methods')
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Only platform-enabled payment methods appear here. The final payment choice must be confirmed with your booking.',
                ),
              ),
            for (final item in items)
              ListTile(
                leading: Icon(
                  widget.resource.startsWith('payments')
                      ? Icons.payments_outlined
                      : Icons.notifications_outlined,
                ),
                title: Text('${item['name'] ?? item['title'] ?? 'Update'}'),
                subtitle: item['description'] == null
                    ? null
                    : Text('${item['description']}'),
              ),
          ],
        );
      },
    ),
  );
}

class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Safety & support')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.shield_outlined, size: 64, color: darkGreen),
        const SizedBox(height: 20),
        Text(
          'A little peace of mind.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Check the driver and vehicle details before entering a car. In an emergency, contact local emergency services directly. Trivia does not provide emergency dispatch.',
        ),
        const SizedBox(height: 24),
        if (app.ride != null) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share trip details'),
            subtitle: const Text(
              'Share a text summary, without a live tracking link.',
            ),
            onTap: () async {
              final r = app.ride!;
              final box = context.findRenderObject() as RenderBox?;
              await SharePlus.instance.share(
                ShareParams(
                  text:
                      '${AppConfig.demo ? 'SIMULATED DEMO TRIP\n' : ''}Trivia trip ${r.id}\n${r.pickup.name} → ${r.destination.name}\n${r.driver?.vehicle ?? 'Driver not assigned'} ${r.driver?.plate ?? ''}\n${statusLabel(r.status)}\nThis is a trip summary, not live tracking.',
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ),
              );
            },
          ),
          if (app.ride!.driver != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_car_outlined),
              title: Text(app.ride!.driver!.vehicle),
              subtitle: Text(
                '${app.ride!.driver!.name}\n${app.ride!.driver!.plate}',
              ),
            ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.contact_emergency_outlined),
          title: const Text('Emergency contact'),
          onTap: () => openPage(
            context,
            FeedbackPage(
              app: app,
              title: 'Emergency contact',
              resource: 'safety/contacts',
              contact: true,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Report an incident'),
          onTap: () => openPage(
            context,
            FeedbackPage(
              app: app,
              title: 'Report an incident',
              resource: 'safety/incidents',
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & support'),
          onTap: () => openPage(
            context,
            FeedbackPage(
              app: app,
              title: 'Help & support',
              resource: 'support/tickets',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (AppConfig.demo)
          const Text(
            'Demo submissions are simulated. No support agent or emergency service will receive them.',
          ),
      ],
    ),
  );
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.app,
    required this.title,
    required this.resource,
    this.contact = false,
  });
  final AppController app;
  final String title, resource;
  final bool contact;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final message = TextEditingController(), name = TextEditingController();
  final form = GlobalKey<FormState>();
  int rating = 5;
  bool sent = false;
  @override
  void dispose() {
    message.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ListenableBuilder(
      listenable: widget.app,
      builder: (_, _) => sent
          ? EmptyState(
              AppConfig.demo ? 'Demo submission recorded' : 'Submitted',
              AppConfig.demo
                  ? 'Nothing was sent to a live service.'
                  : 'The platform received your submission.',
              icon: Icons.check_circle_outline,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: form,
                child: Column(
                  children: [
                    if (widget.contact) ...[
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Contact name',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.resource.endsWith('/review'))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => IconButton(
                            tooltip: '${i + 1} stars',
                            onPressed: () => setState(() => rating = i + 1),
                            icon: Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: darkGreen,
                            ),
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: message,
                      maxLines: widget.contact ? 1 : 5,
                      keyboardType: widget.contact
                          ? TextInputType.phone
                          : TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: widget.contact
                            ? 'Contact phone (+country code)'
                            : 'Tell us more',
                      ),
                      validator: (v) => widget.contact
                          ? (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v ?? '')
                                ? null
                                : 'Enter a valid international phone number.')
                          : ((v ?? '').trim().length < 5
                                ? 'Please add a little more detail.'
                                : null),
                    ),
                    ErrorNotice(widget.app),
                    const SizedBox(height: 24),
                    ActionButton(
                      AppConfig.demo ? 'Simulate submission' : 'Submit',
                      () async {
                        if (form.currentState!.validate()) {
                          final ok = await widget.app.perform(
                            () => widget.app.repository.write(widget.resource, {
                              'message': message.text.trim(),
                              if (widget.contact) 'name': name.text.trim(),
                              if (widget.resource.endsWith('/review'))
                                'rating': rating,
                            }),
                          );
                          if (ok && mounted) {
                            setState(() => sent = true);
                          }
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notifications = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings & privacy')),
    body: ListenableBuilder(
      listenable: widget.app,
      builder: (_, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Trip notifications'),
            subtitle: const Text(
              'In-app preference. Push delivery requires platform configuration.',
            ),
            value: notifications,
            onChanged: widget.app.busy
                ? null
                : (v) async {
                    final ok = await widget.app.perform(
                      () => widget.app.repository.write('me/preferences', {
                        'trip_notifications': v,
                      }),
                    );
                    if (ok && mounted) {
                      setState(() => notifications = v);
                    }
                  },
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Language'),
            trailing: Text('English'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Timezone'),
            trailing: Text('Africa/Harare'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Currency'),
            trailing: Text('USD'),
          ),
          const Divider(height: 32),
          const Text(
            'Location is requested when you choose your current position. No background location permission is requested. Tokens are stored using the platform’s secure storage.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              if (await confirm(
                context,
                'Request account deletion?',
                'The platform will process your deletion request according to its retention policy.',
              )) {
                await widget.app.perform(
                  () => widget.app.repository.write('me/deletion-request', {}),
                );
                if (context.mounted && widget.app.error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppConfig.demo
                            ? 'Demo deletion request simulated.'
                            : 'Deletion request submitted.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Request account deletion',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
          ErrorNotice(widget.app),
        ],
      ),
    ),
  );
}
