import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';
import '../../core/repository.dart';
import '../../shared/models.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({super.key, required this.app});
  final AppController app;
  @override
  State<DriverRegistration> createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final documents = <String, String>{};
  int step = -1;
  bool declaration = false, saving = false;
  String? error;
  static const sections = [
    ['firstName', 'lastName', 'phone', 'email', 'dateOfBirth', 'nationalId'],
    ['licenceNumber', 'licenceClass', 'licenceExpiry'],
    ['make', 'model', 'year', 'colour', 'registration', 'seats', 'category'],
  ];
  List<String> requiredDocuments = [
    'national_id',
    'licence',
    'registration',
    'vehicle_photo',
    'transport_permission',
  ];
  DemoRepository? get repo => widget.app.repository is DemoRepository
      ? widget.app.repository as DemoRepository
      : null;
  @override
  void initState() {
    super.initState();
    final data = repo?.registration ?? {};
    final savedFields = Map<String, dynamic>.from(data['fields'] as Map? ?? {});
    for (final key in sections.expand((s) => s)) {
      fields[key] = TextEditingController(
        text:
            savedFields[key]?.toString() ??
            switch (key) {
              'firstName' => widget.app.session?.firstName ?? '',
              'lastName' => widget.app.session?.lastName ?? '',
              'phone' => widget.app.session?.phone ?? '',
              'category' => 'Standard',
              _ => '',
            },
      );
    }
    final savedDocs = Map<String, dynamic>.from(
      data['documents'] as Map? ?? {},
    );
    for (final entry in savedDocs.entries) {
      if (File(entry.value as String).existsSync())
        documents[entry.key] = entry.value as String;
    }
    step = data['step'] as int? ?? -1;
    widget.app.repository
        .read('driver/requirements')
        .then((data) {
          if (mounted && data['documents'] is List)
            setState(() {
              requiredDocuments = (data['documents'] as List)
                  .map((d) => d['key'] as String)
                  .toList();
            });
        })
        .catchError((Object e) {
          if (mounted)
            setState(() => error = 'Document requirements unavailable.');
        });
  }

  Map<String, dynamic> get data => {
    'step': step,
    'fields': {for (final e in fields.entries) e.key: e.value.text.trim()},
    'documents': documents,
  };
  Future<void> save({DriverStatus status = DriverStatus.draft}) async {
    if (repo == null) return;
    await repo!.saveRegistration(data, status);
    widget.app.session = await repo!.restore();
    widget.app.notifyListeners();
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  String? validate(String key, String? value) {
    final v = (value ?? '').trim();
    if (key == 'email' && v.isEmpty) return null;
    if (v.isEmpty) return 'Required';
    if (key == 'email' && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v))
      return 'Enter a valid email';
    if (key == 'phone' && !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v))
      return 'Enter a valid phone number';
    if (key == 'licenceExpiry' || key == 'dateOfBirth') {
      final date = DateTime.tryParse(v);
      if (date == null) return 'Use YYYY-MM-DD';
      if (key == 'licenceExpiry' && !date.isAfter(DateTime.now()))
        return 'Licence must not be expired';
      if (key == 'dateOfBirth' &&
          date.isAfter(
            DateTime(
              DateTime.now().year - 18,
              DateTime.now().month,
              DateTime.now().day,
            ),
          ))
        return 'Driver must be at least 18';
    }
    if (key == 'year' &&
        ((int.tryParse(v) ?? 0) < 1950 ||
            int.parse(v) > DateTime.now().year + 1))
      return 'Enter a valid vehicle year';
    if (key == 'seats' && ((int.tryParse(v) ?? 0) < 1 || int.parse(v) > 20))
      return 'Enter 1–20 passenger seats';
    if (key == 'category' && !['Standard', 'Comfort', 'XL'].contains(v))
      return 'Choose Standard, Comfort or XL';
    return null;
  }

  Future<void> pick(String key, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
      );
      if (file == null) return;
      if (await file.length() > 10 * 1024 * 1024 ||
          !RegExp(
            r'\.(jpg|jpeg|png|heic|webp)$',
            caseSensitive: false,
          ).hasMatch(file.path))
        throw StateError('Choose an image under 10 MB.');
      documents[key] = file.path;
      await save();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted)
        setState(
          () => error = 'Unable to select document. Check permissions. $e',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        widget.app.session?.driverStatus ?? DriverStatus.notRegistered;
    final pending = [
      DriverStatus.submitted,
      DriverStatus.underReview,
      DriverStatus.suspended,
    ].contains(status);
    return Scaffold(
      appBar: AppBar(title: const Text('Drive with Trivia')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (repo == null)
                const Text(
                  'Driver registration requires the future verification service.',
                )
              else if (pending) ...[
                Text(
                  status == DriverStatus.suspended
                      ? 'Driver account restricted'
                      : status == DriverStatus.submitted
                      ? 'Application Submitted'
                      : 'Driver Verification Pending',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  status == DriverStatus.suspended
                      ? 'Your account is suspended. Driver operations are unavailable.'
                      : "Your driver application has been recorded in demo mode. Approval will be available once Trivia's verification system is connected.",
                ),
                const ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Registration submitted'),
                ),
                const ListTile(
                  leading: Icon(Icons.hourglass_empty),
                  title: Text('Verification pending'),
                ),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Approval required'),
                ),
                ExpansionTile(
                  title: const Text('View submitted details'),
                  children: [
                    for (final f in fields.entries)
                      ListTile(
                        title: Text(f.key),
                        subtitle: Text(f.value.text),
                      ),
                    for (final d in documents.keys)
                      ListTile(
                        title: Text(d),
                        subtitle: const Text(
                          'Local selection • simulated upload',
                        ),
                      ),
                  ],
                ),
                if (kDebugMode && status != DriverStatus.suspended)
                  TextButton(
                    onPressed: () async {
                      await repo!.approveSimulation();
                      await widget.app.sync();
                      if (mounted) setState(() {});
                    },
                    child: const Text(
                      'Development only: simulate administrative approval',
                    ),
                  ),
              ] else if (status == DriverStatus.approved) ...[
                const Text('Driver approved • Demo'),
                Text(
                  '${fields['make']!.text} ${fields['model']!.text} • ${fields['registration']!.text}',
                ),
              ] else if (step < 0) ...[
                const Icon(Icons.local_taxi_outlined, size: 80),
                Text(
                  'Drive with Trivia',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Join Trivia as a driver and connect with passengers looking for convenient rides around Zimbabwe.',
                ),
                const Text(
                  '1. Enter personal information.\n2. Add driver and vehicle details.\n3. Submit required documents.\n4. Wait for verification.\n5. Start driving once approved.',
                ),
                FilledButton(
                  onPressed: () async {
                    setState(() => step = 0);
                    await save();
                  },
                  child: const Text('Get Started'),
                ),
              ] else ...[
                if (status == DriverStatus.rejected)
                  Text(
                    'Application rejected: ${repo!.registration['reason'] ?? 'Review your details and resubmit.'}',
                  ),
                LinearProgressIndicator(value: (step + 1) / 5),
                Text(
                  'Step ${step + 1} of 5 — ${['Personal information', 'Driver information', 'Vehicle information', 'Documents', 'Review application'][step]}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Form(
                  key: form,
                  child: Column(
                    children: [
                      if (step < 3)
                        for (final key in sections[step])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: fields[key],
                              onTap:
                                  key == 'licenceExpiry' || key == 'dateOfBirth'
                                  ? () async {
                                      final now = DateTime.now();
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: key == 'dateOfBirth'
                                            ? DateTime(now.year - 18)
                                            : now.add(const Duration(days: 1)),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(now.year + 30),
                                      );
                                      if (date != null) {
                                        fields[key]!.text = date
                                            .toIso8601String()
                                            .substring(0, 10);
                                        await save();
                                      }
                                    }
                                  : null,
                              decoration: InputDecoration(
                                labelText: key,
                                hintText:
                                    key == 'licenceExpiry' ||
                                        key == 'dateOfBirth'
                                    ? 'YYYY-MM-DD'
                                    : null,
                              ),
                              validator: (v) => validate(key, v),
                              onChanged: (_) {
                                save().catchError((Object e) {
                                  if (mounted)
                                    setState(
                                      () => error = 'Unable to save securely.',
                                    );
                                });
                              },
                            ),
                          ),
                      if (step == 2)
                        const Text(
                          'Category eligibility requires verification. XL requires at least 6 passenger seats.',
                        ),
                      if (step == 3) ...[
                        const Text(
                          'Images up to 10 MB. Stored as secure local references; uploads are simulated.',
                        ),
                        for (final key in requiredDocuments)
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(key),
                                  subtitle: Text(
                                    documents[key] == null
                                        ? 'Required document'
                                        : 'Selected locally • not uploaded',
                                  ),
                                ),
                                if (documents[key] != null)
                                  Image.file(
                                    File(documents[key]!),
                                    height: 100,
                                    errorBuilder: (_, e, s) => const Text(
                                      'Please select this document again',
                                    ),
                                  ),
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          pick(key, ImageSource.camera),
                                      child: const Text('Camera'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          pick(key, ImageSource.gallery),
                                      child: const Text('Gallery / replace'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        setState(() => documents.remove(key));
                                        await save();
                                      },
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (step == 4) ...[
                        for (var i = 0; i < sections.length; i++)
                          ExpansionTile(
                            title: Text(
                              [
                                'Personal details',
                                'Licence details',
                                'Vehicle details',
                              ][i],
                            ),
                            children: [
                              for (final key in sections[i])
                                ListTile(
                                  title: Text(key),
                                  subtitle: Text(fields[key]!.text),
                                ),
                              TextButton(
                                onPressed: () => setState(() => step = i),
                                child: const Text('Edit section'),
                              ),
                            ],
                          ),
                        for (final key in documents.keys)
                          ListTile(
                            title: Text(key),
                            subtitle: const Text(
                              'Local selection • simulated upload',
                            ),
                          ),
                        TextButton(
                          onPressed: () => setState(() => step = 3),
                          child: const Text('Edit documents'),
                        ),
                        CheckboxListTile(
                          value: declaration,
                          onChanged: (v) => setState(() => declaration = v!),
                          title: const Text(
                            'I confirm the information supplied is accurate.',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          if (step == 2 &&
                              fields['category']!.text == 'XL' &&
                              int.parse(fields['seats']!.text) < 6) {
                            setState(
                              () => error =
                                  'XL requires at least 6 passenger seats.',
                            );
                            return;
                          }
                          if (step >= 3 &&
                              requiredDocuments.any(
                                (k) =>
                                    documents[k] == null ||
                                    !File(documents[k]!).existsSync(),
                              )) {
                            setState(
                              () => error = 'Select all required documents.',
                            );
                            return;
                          }
                          if (step == 4 && !declaration) {
                            setState(() => error = 'Confirm the declaration.');
                            return;
                          }
                          setState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            if (step == 4) {
                              if (fields.entries.any(
                                (e) => validate(e.key, e.value.text) != null,
                              )) {
                                step = 0;
                                throw StateError(
                                  'Review all required details.',
                                );
                              }
                              await save(status: DriverStatus.submitted);
                            } else {
                              step++;
                              await save();
                            }
                          } catch (_) {
                            error = 'Unable to save securely. Please retry.';
                          }
                          if (mounted) setState(() => saving = false);
                        },
                  child: Text(step == 4 ? 'Submit Application' : 'Continue'),
                ),
                TextButton(
                  onPressed: step == 0
                      ? null
                      : () async {
                          setState(() => step--);
                          await save();
                        },
                  child: const Text('Back'),
                ),
              ],
              TextButton(
                onPressed: () async {
                  if (!pending && step >= 0 && status != DriverStatus.approved)
                    await save();
                  if (widget.app.driverMode) await widget.app.switchMode();
                },
                child: const Text('Back to Passenger Mode'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
