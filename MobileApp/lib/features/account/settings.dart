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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings & privacy')),
    body: ContentFrame(
      child: ListenableBuilder(
        listenable: widget.app,
        builder: (_, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (notifications == null && settingsError == null)
              const LinearProgressIndicator(),
            if (settingsError != null) ...[
              InlineNotice(settingsError!, isError: true),
              TextButton(
                onPressed: loadPreferences,
                child: const Text('Retry'),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change password'),
              onTap: () =>
                  openPage(context, ChangePasswordScreen(app: widget.app)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Appearance'),
              trailing: Text(_themeLabel(widget.app.themeMode)),
              onTap: () async {
                final modes = <ThemeMode>[
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ];
                final result = await showDialog<ThemeMode>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) {
                      ThemeMode current = widget.app.themeMode;
                      return SimpleDialog(
                        title: const Text('Appearance'),
                        children: [
                          for (final mode in modes)
                            ListTile(
                              leading: Icon(
                                current == mode
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(_themeLabel(mode)),
                              onTap: () {
                                current = mode;
                                setDialogState(() {});
                                widget.app.updateThemeMode(mode);
                                Navigator.of(context).pop(mode);
                              },
                            ),
                        ],
                      );
                    },
                  ),
                );
                if (result != null && mounted) {
                  setState(() => appearance = _themeLabel(result));
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten),
              title: const Text('Distance units'),
              trailing: Text(widget.app.distanceUnit.toUpperCase()),
              onTap: () async {
                final unit = await showDialog<String>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) {
                      String current = widget.app.distanceUnit;
                      return SimpleDialog(
                        title: const Text('Distance units'),
                        children: [
                          ListTile(
                            leading: Icon(
                              current == 'km'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: const Text('Kilometres'),
                            onTap: () {
                              current = 'km';
                              setDialogState(() {});
                              widget.app.updateDistanceUnit('km');
                              Navigator.of(context).pop('km');
                            },
                          ),
                          ListTile(
                            leading: Icon(
                              current == 'mi'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: const Text('Miles'),
                            onTap: () {
                              current = 'mi';
                              setDialogState(() {});
                              widget.app.updateDistanceUnit('mi');
                              Navigator.of(context).pop('mi');
                            },
                          ),
                        ],
                      );
                    },
                  ),
                );
                if (unit != null && mounted) {
                  setState(() {});
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_outlined),
              title: const Text('Language'),
              trailing: Text(widget.app.language),
              onTap: () async {
                final value = await showDialog<String>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) {
                      String current = widget.app.language;
                      return SimpleDialog(
                        title: const Text('Language'),
                        children: [
                          ListTile(
                            leading: Icon(
                              current == 'English'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: const Text('English'),
                            onTap: () {
                              current = 'English';
                              setDialogState(() {});
                              widget.app.updateLanguage('English');
                              Navigator.of(context).pop('English');
                            },
                          ),
                        ],
                      );
                    },
                  ),
                );
                if (value != null && mounted) {
                  setState(() {});
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.location_on_outlined),
              title: const Text('Location sharing'),
              subtitle: const Text(
                'Share location during active journeys only.',
              ),
              value: widget.app.locationSharing,
              onChanged: widget.app.busy
                  ? null
                  : (v) async {
                      await widget.app.updateLocationSharing(v);
                      if (mounted) setState(() => locationSharing = v);
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Trip notifications'),
              subtitle: const Text(
                'In-app preference. Push delivery requires platform configuration.',
              ),
              value: notifications ?? false,
              onChanged: widget.app.busy || notifications == null
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Legal documents'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalPage(documentId: 'terms'),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: const Text('App version'),
              trailing: Text(appVersion),
            ),
            const Divider(height: 32),
            const Text(
              'Location is requested when you choose your current position. No background location permission is requested. Tokens are stored using the platform’s secure storage.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.delete_outline),
              label: const Text(
                'Account deletion unavailable — contact support',
              ),
            ),
            const SizedBox(height: 12),
            const LegalLinks(),
            ErrorNotice(widget.app),
          ],
        ),
      ),
    ),
  );
}
