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

/// A single row in a grouped menu section.
class _MenuItem {
  const _MenuItem(this.icon, this.title, this.page, {this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget page;
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final profileItems = <_MenuItem>[
      _MenuItem(
        Icons.person_outline,
        'Personal information',
        ProfileSetup(app: app),
        subtitle: 'Name, phone and email',
      ),
      if (app.driverMode)
        _MenuItem(
          Icons.notifications_outlined,
          'Notifications',
          ResourcePage(
            app: app,
            title: 'Notifications',
            resource: 'notifications',
            empty: 'Driver requests and trip updates will appear here.',
          ),
          subtitle: 'Requests and trip updates',
        ),
    ];

    final helpItems = <_MenuItem>[
      _MenuItem(
        Icons.shield_outlined,
        'Safety & support',
        SafetyPage(app: app),
        subtitle: 'Get help and manage safety tools',
      ),
      _MenuItem(
        Icons.settings_outlined,
        'Settings & privacy',
        SettingsPage(app: app),
        subtitle: 'Language, permissions and data',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ContentFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProfileHeader(app: app),
            const SizedBox(height: 16),
            _ModeSwitch(app: app),
            ErrorNotice(app),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Trips',
                    onTap: () => openPage(context, HistoryPage(app: app)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bookmark_outline,
                    label: 'Saved places',
                    onTap: () => openPage(context, SavedPlacesPage(app: app)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Section(title: 'Profile', items: profileItems),
            const SizedBox(height: 20),
            _Section(title: 'Help and privacy', items: helpItems),
            const SizedBox(height: 8),
            const LegalLinks(),
            const SizedBox(height: 16),
            _LogoutButton(app: app),
            const SizedBox(height: 24),
            Text(
              'Trivia — Developed by\nMOrdec Solutions (Private) Limited',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero card with avatar initials, name, contact and the current mode.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.app});
  final AppController app;

  String get _initials {
    final s = app.session!;
    final a = s.firstName.trim().isEmpty ? '' : s.firstName.trim()[0];
    final b = s.lastName.trim().isEmpty ? '' : s.lastName.trim()[0];
    final value = '$a$b'.toUpperCase();
    return value.isEmpty ? '?' : value;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final session = app.session!;
    final contact = session.phone.isEmpty ? session.email : session.phone;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.45)!,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.onPrimary,
            ),
            child: Text(
              _initials,
              style: text.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.firstName} ${session.lastName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: scheme.onPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        app.driverMode
                            ? Icons.local_taxi_outlined
                            : Icons.person_pin_circle_outlined,
                        size: 14,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        app.driverMode ? 'Driver mode' : 'Passenger mode',
                        style: text.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Edit profile',
            onPressed: () => openPage(context, ProfileSetup(app: app)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

/// Segmented Passenger / Driver switch.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.person_outline),
          label: Text('Passenger'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.local_taxi_outlined),
          label: Text('Driver'),
        ),
      ],
      selected: {app.driverMode},
      onSelectionChanged: app.busy
          ? null
          : (selection) {
              if (selection.first != app.driverMode) app.switchMode();
            },
    ),
  );
}

/// Compact tile used for the three most common destinations.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled, rounded group of menu rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      items[i].icon,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    items[i].title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: items[i].subtitle == null
                      ? null
                      : Text(items[i].subtitle!),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => openPage(context, items[i].page),
                ),
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    indent: 74,
                    endIndent: 16,
                    color: scheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
      ),
    );
  }
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

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home_outlined;
    if (l.contains('work') || l.contains('office')) {
      return Icons.work_outline;
    }
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconFor(saved.label),
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          saved.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          saved.place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          enabled: !app.busy,
                          onSelected: (action) => switch (action) {
                            'rename' => edit(context, saved: saved),
                            'address' => changeAddress(context, saved),
                            _ => remove(context, saved),
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'address',
                              child: Text('Change address'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
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
}
