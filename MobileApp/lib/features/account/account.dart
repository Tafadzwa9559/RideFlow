import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../legal/legal_page.dart';
import '../entry/entry.dart';
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
