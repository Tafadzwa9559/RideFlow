import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../legal/legal_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? notifications;
  String? settingsError;
  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    try {
      final data = await widget.app.repository.read('users/me/preferences');
      if (mounted) {
        setState(() {
          notifications = data['push_notifications'] as bool;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings & privacy')),
    body: ListenableBuilder(
      listenable: widget.app,
      builder: (_, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (notifications == null && settingsError == null)
            const LinearProgressIndicator(),
          if (settingsError != null) ...[
            Text(settingsError!),
            TextButton(onPressed: loadPreferences, child: const Text('Retry')),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Currency'),
            trailing: Text(currencySymbol(widget.app.currency)),
          ),
          const LegalLinks(),
          const Divider(height: 32),
          const Text(
            'Location is requested when you choose your current position. No background location permission is requested. Tokens are stored using the platform’s secure storage.',
          ),
          const SizedBox(height: 24),
          const OutlinedButton(
            onPressed: null,
            child: Text('Account deletion unavailable — contact support'),
          ),
          ErrorNotice(widget.app),
        ],
      ),
    ),
  );
}
