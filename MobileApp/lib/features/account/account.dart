import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../legal/legal_page.dart';
import '../entry/entry.dart';
import '../passenger/home.dart' show PlacePicker;
import 'history.dart';
import 'resource.dart';
import 'settings.dart';
import 'support.dart';

export 'history.dart';
export 'resource.dart';
export 'settings.dart';
export 'support.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your account')),
    body: ContentFrame(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InfoCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 30,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
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
                      Text(
                        app.session!.phone.isEmpty
                            ? app.session!.email
                            : app.session!.phone,
                      ),
                      Text(
                        app.driverMode ? 'Driver mode' : 'Passenger mode',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
            if (app.driverMode)
              (
                Icons.notifications_outlined,
                'Notifications',
                ResourcePage(
                  app: app,
                  title: 'Notifications',
                  resource: 'notifications',
                  empty: 'Driver requests and trip updates will appear here.',
                ),
              ),
            (
              Icons.receipt_long_outlined,
              'Trip history',
              HistoryPage(app: app),
            ),
            (
              Icons.payments_outlined,
              'Payment methods',
              Scaffold(
                appBar: AppBar(title: const Text('Payment methods')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Choose during booking. Pay your driver directly in USD.',
                    ),
                    for (final method in directPaymentMethods)
                      ListTile(
                        leading: Icon(
                          method.kind == 'cash'
                              ? Icons.payments_outlined
                              : Icons.phone_android_outlined,
                        ),
                        title: Text(method.name),
                        onTap: () => app.selectPayment(method.id, method.name),
                      ),
                  ],
                ),
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
          const LegalLinks(),
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
          const SizedBox(height: 16),
          const Text(
            'Trivia — Developed by\nMOrdec Solutions (Private) Limited',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key, required this.app});
  final AppController app;

  Future<Place?> selectPlace(BuildContext context, {Place? current}) =>
      Navigator.push<Place>(
        context,
        MaterialPageRoute(
          builder: (_) => PlacePicker(
            app: app,
            title: 'Choose a saved address',
            initialPlace: current,
          ),
        ),
      );

  Future<void> edit(BuildContext context, {SavedAddress? saved}) async {
    var label = saved?.label ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(saved == null ? 'Name this place' : 'Rename place'),
        content: TextFormField(
          autofocus: true,
          initialValue: label,
          onChanged: (value) => label = value,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Home, Work or custom name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = label.trim();
              if (value.isNotEmpty) Navigator.pop(dialog, value);
            },
            child: Text(saved == null ? 'Choose address' : 'Save name'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    final place = saved?.place ?? await selectPlace(context);
    if (place != null) await app.savePlace(place, label: name, id: saved?.id);
  }

  Future<void> changeAddress(BuildContext context, SavedAddress saved) async {
    final place = await selectPlace(context, current: saved.place);
    if (place != null) {
      await app.savePlace(place, label: saved.label, id: saved.id);
    }
  }

  Future<void> remove(BuildContext context, SavedAddress saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${saved.label}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await app.removeSavedPlace(saved.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved places')),
    body: ContentFrame(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () async {
            await app.perform(app.sync);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              ErrorNotice(app),
              if (app.savedAddresses.isEmpty)
                const EmptyState(
                  'No saved places',
                  'Save Home, Work or another address to select it quickly when booking.',
                  icon: Icons.bookmark_outline,
                ),
              for (final saved in app.savedAddresses)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(saved.label),
                  subtitle: Text(saved.place.name),
                  trailing: PopupMenuButton<String>(
                    enabled: !app.busy,
                    onSelected: (action) => switch (action) {
                      'rename' => edit(context, saved: saved),
                      'address' => changeAddress(context, saved),
                      _ => remove(context, saved),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(
                        value: 'address',
                        child: Text('Change address'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ActionButton(
                'Add saved place',
                app.busy ? null : () => edit(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
