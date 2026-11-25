import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/controller.dart';
import '../../shared/widgets.dart';
import '../legal/legal_page.dart';
import '../entry/entry.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? notifications;
  bool? locationSharing;
  String? settingsError;
  String appVersion = '1.0.0';
  String appearance = 'System';

  @override
  void initState() {
    super.initState();
    loadPreferences();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => appVersion = '${info.version}+${info.buildNumber}');
      }
    });
  }

  Future<void> loadPreferences() async {
    try {
      final data = await widget.app.repository.read('users/me/preferences');
      if (mounted) {
        setState(() {
          notifications = data['push_notifications'] as bool? ?? false;
          locationSharing = widget.app.locationSharing;
          settingsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => settingsError = 'Preferences unavailable. Please retry.',
        );
      }
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Shared single-choice dialog used by Appearance, Units and Language.
  Future<T?> _choose<T>({
    required String title,
    required T current,
    required List<(T, String)> options,
    required void Function(T value) onPick,
  }) => showDialog<T>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(title),
      children: [
        for (final option in options)
          ListTile(
            leading: Icon(
              current == option.$1
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: current == option.$1
                  ? Theme.of(dialog).colorScheme.primary
                  : null,
            ),
            title: Text(option.$2),
            onTap: () {
              onPick(option.$1);
              Navigator.of(dialog).pop(option.$1);
            },
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = widget.app;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & privacy')),
      body: ContentFrame(
        child: ListenableBuilder(
          listenable: app,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (notifications == null && settingsError == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (settingsError != null) ...[
                InlineNotice(settingsError!, isError: true),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: loadPreferences,
                    child: const Text('Retry'),
                  ),
                ),
              ],
              _SettingsGroup(
                title: 'Security',
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Change password',
                    onTap: () =>
                        openPage(context, ChangePasswordScreen(app: app)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SettingsGroup(
                title: 'Preferences',
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    value: _themeLabel(app.themeMode),
                    onTap: () async {
                      final result = await _choose<ThemeMode>(
                        title: 'Appearance',
                        current: app.themeMode,
                        options: [
                          for (final m in ThemeMode.values)
                            (m, _themeLabel(m)),
                        ],
                        onPick: app.updateThemeMode,
                      );
                      if (result != null && mounted) {
                        setState(() => appearance = _themeLabel(result));
                      }
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.straighten,
                    title: 'Distance units',
                    value: app.distanceUnit.toUpperCase(),
                    onTap: () async {
                      final unit = await _choose<String>(
                        title: 'Distance units',
                        current: app.distanceUnit,
                        options: const [('km', 'Kilometres'), ('mi', 'Miles')],
                        onPick: app.updateDistanceUnit,
                      );
                      if (unit != null && mounted) setState(() {});
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    value: app.language,
                    onTap: () async {
                      final value = await _choose<String>(
                        title: 'Language',
                        current: app.language,
                        options: const [('English', 'English')],
                        onPick: app.updateLanguage,
                      );
                      if (value != null && mounted) setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SettingsGroup(
                title: 'Privacy and alerts',
                children: [
                  _SettingsSwitch(
                    icon: Icons.location_on_outlined,
                    title: 'Location sharing',
                    subtitle: 'Share location during active journeys only.',
                    value: app.locationSharing,
                    onChanged: app.busy
                        ? null
                        : (v) async {
                            await app.updateLocationSharing(v);
                            if (mounted) setState(() => locationSharing = v);
                          },
                  ),
                  _SettingsSwitch(
                    icon: Icons.notifications_outlined,
                    title: 'Trip notifications',
                    subtitle:
                        'In-app preference. Push delivery requires platform configuration.',
                    value: notifications ?? false,
                    onChanged: app.busy || notifications == null
                        ? null
                        : (v) async {
                            final ok = await app.perform(
                              () => app.repository.write('me/preferences', {
                                'trip_notifications': v,
                              }),
                            );
                            if (ok && mounted) {
                              setState(() => notifications = v);
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location is requested when you choose your current position. No background location permission is requested. Tokens are stored using the platform’s secure storage.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsGroup(
                title: 'About',
                children: [
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Legal documents',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalPage(documentId: 'terms'),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'App version',
                    value: appVersion,
                    showChevron: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(
                    'Account deletion unavailable — contact support',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const LegalLinks(),
              ErrorNotice(app),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titled, rounded card that groups related settings rows.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

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
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
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

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
    );
  }
}

/// Navigation / value row inside a group.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.showChevron = true,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconChip(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (showChevron && onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    secondary: _IconChip(icon),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}