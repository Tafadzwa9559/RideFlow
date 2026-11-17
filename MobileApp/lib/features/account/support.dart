import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';

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
                      'Trivia trip ${r.id}\n${r.pickup.name} → ${r.destination.name}\n${r.driver?.vehicle ?? 'Driver not assigned'} ${r.driver?.plate ?? ''}\n${statusLabel(r.status)}\nThis is a trip summary, not live tracking.',
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
              'Submitted',
              'The platform received your submission.',
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
                    ActionButton('Submit', () async {
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
                    }, busy: widget.app.busy),
                  ],
                ),
              ),
            ),
    ),
  );
}
