import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';
import '../../core/api_error.dart';
import '../../shared/models.dart';
import '../legal/legal_page.dart';

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
    ['firstName', 'lastName', 'phone', 'email'],
    ['licenceNumber', 'licenceClass', 'licenceExpiry'],
    ['make', 'model', 'year', 'colour', 'registration', 'seats', 'category'],
  ];
  List<String> requiredDocuments = [];
  List<Map<String, dynamic>> requirements = [];
  bool loadingRequirements = true;
  String? requirementError;
  @override
  void initState() {
    super.initState();
    for (final key in sections.expand((section) => section)) {
      fields[key] = TextEditingController(
        text: switch (key) {
          'firstName' => widget.app.session?.firstName ?? '',
          'lastName' => widget.app.session?.lastName ?? '',
          'phone' => widget.app.session?.phone ?? '',
          'category' => 'Standard',
          _ => '',
        },
      );
    }
    loadRequirements();
  }

  Future<void> loadRequirements() async {
    setState(() {
      loadingRequirements = true;
      requirementError = null;
    });
    try {
      final result = await widget.app.repository.read(
        'drivers/document-requirements',
      );
      final application = await widget.app.repository.read(
        'drivers/applications/me',
      );
      final vehicle = Map<String, dynamic>.from(
        application['vehicle'] as Map? ?? {},
      );
      final values = <String, dynamic>{
        'licenceNumber': application['licence_number'],
        'licenceClass': application['licence_class'],
        'licenceExpiry': application['licence_expires'],
        ...vehicle,
        'seats': vehicle['capacity'],
      };
      if (!mounted) return;
      requirements = (result['results'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      requiredDocuments = requirements
          .where((r) => r['required'] == true)
          .map((r) => '${r['code']}')
          .toList();
      for (final req in requirements) {
        if (req['expiry_required'] == true) {
          fields.putIfAbsent(
            'expiry_${req['code']}',
            TextEditingController.new,
          );
        }
      }
      for (final entry in values.entries) {
        if (fields.containsKey(entry.key) && entry.value != null) {
          fields[entry.key]!.text = '${entry.value}';
        }
      }
    } catch (e) {
      if (mounted) requirementError = apiErrorMessage(e);
    }
    if (mounted) setState(() => loadingRequirements = false);
  }

  Map<String, dynamic> get data => {
    'step': step,
    'fields': {for (final e in fields.entries) e.key: e.value.text.trim()},
    'documents': documents,
  };
  Future<void> submitApplication() async {
    final submitted = await widget.app.repository.applyDriver({
      ...data,
      for (final entry in fields.entries.where(
        (e) => e.key.startsWith('expiry_'),
      ))
        entry.key: entry.value.text.trim(),
    }, documents);
    if (submitted != DriverStatus.submitted &&
        submitted != DriverStatus.underReview) {
      throw StateError('Application was not confirmed as submitted.');
    }
    widget.app.session = await widget.app.repository.restore();
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
    if (key == 'email' && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) {
      return 'Enter a valid email';
    }
    if (key == 'phone' && !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v)) {
      return 'Enter a valid phone number';
    }
    if (key == 'licenceExpiry') {
      final date = DateTime.tryParse(v);
      if (date == null) return 'Use YYYY-MM-DD';
      if (!date.isAfter(DateTime.now())) {
        return 'Licence must not be expired';
      }
    }
    if (key == 'year' &&
        ((int.tryParse(v) ?? 0) < 1950 ||
            int.parse(v) > DateTime.now().year + 1)) {
      return 'Enter a valid vehicle year';
    }
    if (key == 'seats' && ((int.tryParse(v) ?? 0) < 1 || int.parse(v) > 20)) {
      return 'Enter 1–20 passenger seats';
    }
    if (key == 'category' && !['Standard', 'Comfort', 'XL'].contains(v)) {
      return 'Choose Standard, Comfort or XL';
    }
    return null;
  }

  Future<void> pick(String key, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024 ||
          !RegExp(
            r'\.(jpg|jpeg|png)$',
            caseSensitive: false,
          ).hasMatch(file.path)) {
        throw StateError('Choose an image under 5 MiB.');
      }
      documents[key] = file.path;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Unable to select document. Check permissions. $e',
        );
      }
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
              if (loadingRequirements)
                const Center(child: CircularProgressIndicator())
              else if (requirementError != null) ...[
                Text(requirementError!),
                OutlinedButton(
                  onPressed: loadRequirements,
                  child: const Text('Retry'),
                ),
              ] else if (pending) ...[
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
                      : "Your application was submitted to Trivia. An administrator must verify it before you can go online.",
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
                        subtitle: const Text('Selected document'),
                      ),
                  ],
                ),
              ] else if (status == DriverStatus.approved) ...[
                const Text('Driver approved'),
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
                  onPressed: () => setState(() => step = 0),
                  child: const Text('Get Started'),
                ),
              ] else ...[
                if (status == DriverStatus.rejected)
                  Text(
                    'Application rejected. Review the server verification result and resubmit your details.',
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
                              readOnly: key == 'phone',
                              onTap: key == 'licenceExpiry'
                                  ? () async {
                                      final now = DateTime.now();
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: now.add(
                                          const Duration(days: 1),
                                        ),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(now.year + 30),
                                      );
                                      if (date != null) {
                                        fields[key]!.text = date
                                            .toIso8601String()
                                            .substring(0, 10);
                                      }
                                    }
                                  : null,
                              decoration: InputDecoration(
                                labelText: key,
                                hintText: key == 'licenceExpiry'
                                    ? 'YYYY-MM-DD'
                                    : null,
                              ),
                              validator: (v) => validate(key, v),
                            ),
                          ),
                      if (step == 2)
                        const Text(
                          'Category eligibility requires verification. XL requires at least 6 passenger seats.',
                        ),
                      if (step == 3) ...[
                        const Text(
                          'JPEG/PNG images up to 5 MiB. Selected files upload when you submit. Draft entries remain on this screen until submission.',
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
                                if (requirements.any(
                                  (r) =>
                                      r['code'] == key &&
                                      r['expiry_required'] == true,
                                ))
                                  TextFormField(
                                    controller: fields['expiry_$key'],
                                    decoration: const InputDecoration(
                                      labelText: 'Document expiry (YYYY-MM-DD)',
                                    ),
                                    validator: (v) =>
                                        DateTime.tryParse(v ?? '') == null
                                        ? 'Enter a valid expiry date'
                                        : null,
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
                                      onPressed: () =>
                                          setState(() => documents.remove(key)),
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
                            subtitle: const Text('Selected document'),
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
                              await submitApplication();
                            } else {
                              step++;
                            }
                          } catch (e) {
                            error = apiErrorMessage(e);
                          }
                          if (mounted) setState(() => saving = false);
                        },
                  child: Text(step == 4 ? 'Submit Application' : 'Continue'),
                ),
                TextButton(
                  onPressed: step == 0 ? null : () => setState(() => step--),
                  child: const Text('Back'),
                ),
              ],
              const LegalLinks(),
              TextButton(
                onPressed: () async {
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
