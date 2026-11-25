import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';
import '../../core/api_error.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../legal/legal_page.dart';

// ---------------------------------------------------------------------------
// Shared helpers (private to this file)
// ---------------------------------------------------------------------------

Duration _motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

InputDecoration _regInput(
  BuildContext context, {
  required String label,
  IconData? icon,
  String? hint,
  String? helper,
  Widget? suffix,
  bool locked = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    errorMaxLines: 3,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: locked ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(scheme.outlineVariant),
    enabledBorder: border(scheme.outlineVariant),
    focusedBorder: border(scheme.primary, 2),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 2),
  );
}

ButtonStyle _primaryStyle() => FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, {this.size = 44});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: size * .5, color: scheme.onPrimaryContainer),
    );
  }
}

/// Rounded surface used for every card in this flow.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

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
  static const fieldLabels = {
    'firstName': 'First name',
    'lastName': 'Last name',
    'phone': 'Phone number',
    'email': 'Email address',
    'licenceNumber': 'Licence number',
    'licenceClass': 'Licence class',
    'licenceExpiry': 'Licence expiry date',
    'make': 'Vehicle make',
    'model': 'Vehicle model',
    'year': 'Model year',
    'colour': 'Colour',
    'registration': 'Registration number',
    'seats': 'Passenger seats',
    'category': 'Ride category',
  };
  static const fieldIcons = {
    'firstName': Icons.person_outline,
    'lastName': Icons.badge_outlined,
    'phone': Icons.phone_outlined,
    'email': Icons.mail_outline,
    'licenceNumber': Icons.credit_card_outlined,
    'licenceClass': Icons.workspace_premium_outlined,
    'licenceExpiry': Icons.event_outlined,
    'make': Icons.directions_car_outlined,
    'model': Icons.directions_car_filled_outlined,
    'year': Icons.calendar_today_outlined,
    'colour': Icons.palette_outlined,
    'registration': Icons.pin_outlined,
    'seats': Icons.event_seat_outlined,
  };
  static const stepTitles = [
    'Personal information',
    'Driver information',
    'Vehicle information',
    'Document verification',
    'Review and submission',
  ];
  static const stepHints = [
    'Tell us who you are. Your phone number comes from your Trivia account.',
    'Enter your licence details exactly as they appear on your licence.',
    'Tell us about the vehicle you will drive with Trivia.',
    'JPEG/PNG images up to 5 MiB. Selected files upload when you submit. Draft entries remain on this screen until submission.',
    'Check your details. Use Edit to change anything before you submit.',
  ];

  String documentLabel(String code) {
    for (final requirement in requirements) {
      if (requirement
          case {'code': final String id, 'label': final String label}
          when id == code && label.isNotEmpty) {
        return label;
      }
    }
    return code;
  }

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
      if (await file.length() > 5 * 1024 * 1024) {
        if (mounted) {
          setState(
            () => error = 'That image is larger than 5 MiB. Choose a smaller one.',
          );
        }
        return;
      }
      if (!RegExp(
        r'\.(jpg|jpeg|png)$',
        caseSensitive: false,
      ).hasMatch(file.path)) {
        if (mounted) {
          setState(() => error = 'Only JPEG or PNG images are supported.');
        }
        return;
      }
      documents[key] = file.path;
      if (mounted) {
        setState(() => error = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to select document. Check camera and photo permissions.',
        );
      }
    }
  }

  Future<void> _pickDate(String key, {required bool future}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final first = future ? tomorrow : DateTime(2000);
    final last = DateTime(now.year + 30);
    var initial = DateTime.tryParse(fields[key]!.text.trim());
    if (initial == null || initial.isBefore(first) || initial.isAfter(last)) {
      initial = future ? tomorrow : today;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date != null) {
      fields[key]!.text = date.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _continue() async {
    if (!form.currentState!.validate()) return;
    if (step == 2 &&
        fields['category']!.text == 'XL' &&
        int.parse(fields['seats']!.text) < 6) {
      setState(() => error = 'XL requires at least 6 passenger seats.');
      return;
    }
    if (step >= 3 &&
        requiredDocuments.any(
          (k) => documents[k] == null || !File(documents[k]!).existsSync(),
        )) {
      setState(() => error = 'Select all required documents.');
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
        if (fields.entries.any((e) => validate(e.key, e.value.text) != null)) {
          step = 0;
          throw StateError('Review all required details.');
        }
        await submitApplication();
      } else {
        step++;
      }
    } catch (e) {
      error = apiErrorMessage(e);
    }
    if (mounted) setState(() => saving = false);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final status =
        widget.app.session?.driverStatus ?? DriverStatus.notRegistered;
    final pending = [
      DriverStatus.submitted,
      DriverStatus.underReview,
      DriverStatus.suspended,
    ].contains(status);
    final inForm =
        !loadingRequirements &&
        requirementError == null &&
        !pending &&
        status != DriverStatus.approved &&
        step >= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Drive with Trivia')),
      body: ContentFrame(
        maxWidth: 560,
        child: inForm
            ? _formLayout(context, status)
            : _infoLayout(context, status, pending),
      ),
    );
  }

  // ---- Non-form screens ---------------------------------------------------

  Widget _infoLayout(BuildContext context, DriverStatus status, bool pending) {
    final Widget body;
    final String key;
    if (loadingRequirements) {
      key = 'loading';
      body = _Panel(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                semanticsLabel: 'Loading registration',
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Loading your application…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    } else if (requirementError != null) {
      key = 'error';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineNotice(requirementError!, isError: true),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: loadRequirements,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    } else if (pending) {
      key = 'pending-$status';
      body = _pendingPanel(context, status);
    } else if (status == DriverStatus.approved) {
      key = 'approved';
      body = _approvedPanel(context);
    } else {
      key = 'welcome';
      body = _welcome(context, status);
    }
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: _motion(context, 250),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: KeyedSubtree(
              key: ValueKey(key),
              child: SizedBox(width: double.infinity, child: body),
            ),
          ),
          const LegalLinks(),
          _backToPassenger(),
        ],
      ),
    );
  }

  Widget _backToPassenger() => TextButton(
    onPressed: () async {
      if (widget.app.driverMode) await widget.app.switchMode();
    },
    child: const Text('Back to Passenger Mode'),
  );

  Widget _welcome(BuildContext context, DriverStatus status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(360, 1200);
    const stages = [
      ('Personal information', 'Your name and contact details'),
      ('Driver information', 'Licence number, class and expiry'),
      ('Vehicle information', 'Make, model, seats and category'),
      ('Document verification', 'Photos of your required documents'),
      ('Review and submission', 'Check everything and submit'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image(
              image: ResizeImage(
                const AssetImage(
                  'assets/images/onboarding/trivia_onboarding_2.png',
                ),
                width: width,
              ),
              fit: BoxFit.cover,
              alignment: const Alignment(0.1, -0.2),
              semanticLabel: 'A Trivia driver ready for your journey',
              errorBuilder: (context, error, stack) => ColoredBox(
                color: scheme.primaryContainer,
                child: Center(
                  child: Icon(
                    Icons.local_taxi_outlined,
                    size: 72,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Brand(large: true),
        const SizedBox(height: 16),
        Text(
          'Drive with Trivia',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join Trivia as a driver and connect with passengers looking for convenient rides around Zimbabwe.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (status == DriverStatus.rejected) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Application rejected. Review the server verification result and resubmit your details.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Panel(
          child: Column(
            children: [
              for (final (i, s) in stages.indexed)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primaryContainer,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (i < stages.length - 1)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: scheme.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i < stages.length - 1 ? 16 : 0,
                            left: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.$1,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                s.$2,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'After you submit, an administrator verifies your application. You can start driving once approved.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: _primaryStyle(),
          onPressed: () => setState(() => step = 0),
          child: const Text('Get Started'),
        ),
      ],
    );
  }

  Widget _approvedPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Panel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.verified, size: 40, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver approved',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fields['make']!.text} ${fields['model']!.text} • ${fields['registration']!.text}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingPanel(BuildContext context, DriverStatus status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suspended = status == DriverStatus.suspended;
    final submitted = status == DriverStatus.submitted;
    final title = suspended
        ? 'Driver Account Restricted'
        : submitted
        ? 'Application Submitted'
        : 'Driver Verification Pending';
    final message = suspended
        ? 'Your account is suspended. Driver operations are unavailable.'
        : "Your application was submitted to Trivia. An administrator must verify it before you can go online.";
    final icon = suspended
        ? Icons.block
        : submitted
        ? Icons.check_circle_outline
        : Icons.hourglass_top;
    final timeline = [
      (Icons.check_circle_outline, 'Registration submitted', true),
      (Icons.hourglass_empty, 'Verification pending', false),
      (Icons.lock_outline, 'Approval required', false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: suspended ? scheme.errorContainer : scheme.primaryContainer,
            ),
            child: Icon(
              icon,
              size: 42,
              color: suspended
                  ? scheme.onErrorContainer
                  : scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (!suspended) ...[
          const SizedBox(height: 20),
          _Panel(
            child: Column(
              children: [
                for (final (i, t) in timeline.indexed)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Icon(
                                t.$1,
                                size: 24,
                                color: t.$3 || (i == 1)
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                              if (i < timeline.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: t.$3
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 10,
                              bottom: i < timeline.length - 1 ? 18 : 0,
                            ),
                            child: Text(
                              t.$2,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: i <= 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Panel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('View submitted details'),
            children: [
              for (final f in fields.entries)
                ListTile(
                  dense: true,
                  title: Text(fieldLabels[f.key] ?? f.key),
                  subtitle: Text(f.value.text),
                ),
              for (final d in documents.keys)
                ListTile(
                  dense: true,
                  title: Text(documentLabel(d)),
                  subtitle: const Text('Selected document'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Form steps ---------------------------------------------------------

  Widget _formLayout(BuildContext context, DriverStatus status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Semantics(
            label: 'Step ${step + 1} of 5',
            child: Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: _motion(context, 250),
                      curve: Curves.easeOutCubic,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= step ? scheme.primary : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: Form(
            key: form,
            child: SingleChildScrollView(
              key: ValueKey(step),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutCubic,
                duration: _motion(context, 240),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(16 * (1 - value), 0),
                    child: child,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (status == DriverStatus.rejected) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Application rejected. Review the server verification result and resubmit your details.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Step ${step + 1} of 5',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stepTitles[step],
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stepHints[step],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (step < 3) ..._detailFields(context),
                    if (step == 3) ..._documentCards(context),
                    if (step == 4) ..._review(context),
                    const SizedBox(height: 8),
                    const LegalLinks(),
                    _backToPassenger(),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InlineNotice(error!, isError: true),
                  ),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(92, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: step == 0 || saving
                          ? null
                          : () => setState(() => step--),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: _primaryStyle(),
                        onPressed: saving ? null : _continue,
                        child: saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Saving application',
                                ),
                              )
                            : Text(
                                step == 4 ? 'Submit Application' : 'Continue',
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _detailFields(BuildContext context) => [
    for (final key in sections[step])
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: key == 'category'
            ? _categorySelector(context)
            : _textField(context, key),
      ),
    if (step == 2)
      _Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Category eligibility requires verification. XL requires at least 6 passenger seats.',
              ),
            ),
          ],
        ),
      ),
  ];

  Widget _textField(BuildContext context, String key) {
    final isExpiry = key == 'licenceExpiry';
    final isPhone = key == 'phone';
    return TextFormField(
      controller: fields[key],
      readOnly: isPhone || isExpiry,
      textInputAction: TextInputAction.next,
      keyboardType: switch (key) {
        'email' => TextInputType.emailAddress,
        'phone' => TextInputType.phone,
        'year' || 'seats' => TextInputType.number,
        _ => TextInputType.text,
      },
      textCapitalization: switch (key) {
        'firstName' ||
        'lastName' ||
        'make' ||
        'model' ||
        'colour' => TextCapitalization.words,
        'licenceNumber' ||
        'licenceClass' ||
        'registration' => TextCapitalization.characters,
        _ => TextCapitalization.none,
      },
      inputFormatters: switch (key) {
        'year' => [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        'seats' => [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        _ => null,
      },
      onTap: isExpiry ? () => _pickDate(key, future: true) : null,
      decoration: _regInput(
        context,
        label: fieldLabels[key] ?? key,
        icon: fieldIcons[key],
        hint: isExpiry ? 'Choose a date' : null,
        locked: isPhone,
        helper: isPhone
            ? 'Linked to your Trivia account'
            : key == 'email'
            ? 'Optional'
            : null,
        suffix: isPhone
            ? const Icon(Icons.lock_outline)
            : isExpiry
            ? IconButton(
                tooltip: 'Choose date',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => _pickDate(key, future: true),
              )
            : null,
      ),
      validator: (v) => validate(key, v),
    );
  }

  Widget _categorySelector(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    const options = [
      ('Standard', Icons.local_taxi_outlined, null),
      ('Comfort', Icons.airline_seat_recline_normal, null),
      ('XL', Icons.airport_shuttle_outlined, '6+ seats'),
    ];
    return FormField<String>(
      initialValue: fields['category']!.text,
      validator: (_) => validate('category', fields['category']!.text),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldLabels['category']!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, o) in options.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final selected = fields['category']!.text == o.$1;
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: '${o.$1} ride category',
                        child: AnimatedContainer(
                          duration: _motion(context, 200),
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                fields['category']!.text = o.$1;
                                state.didChange(o.$1);
                                setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 6,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      o.$2,
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      o.$1,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? scheme.onPrimaryContainer
                                                : null,
                                          ),
                                    ),
                                    if (o.$3 != null)
                                      Text(
                                        o.$3!,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                state.errorText!,
                style: TextStyle(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _documentCards(BuildContext context) => [
    for (final key in requiredDocuments)
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _DocumentCard(
          title: documentLabel(key),
          path: documents[key],
          expiry:
              requirements.any(
                (r) => r['code'] == key && r['expiry_required'] == true,
              )
              ? fields['expiry_$key']
              : null,
          onPickExpiry: () => _pickDate('expiry_$key', future: false),
          onCamera: () => pick(key, ImageSource.camera),
          onGallery: () => pick(key, ImageSource.gallery),
          onRemove: () => setState(() => documents.remove(key)),
        ),
      ),
  ];

  List<Widget> _review(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const titles = ['Personal details', 'Licence details', 'Vehicle details'];
    const icons = [
      Icons.person_outline,
      Icons.badge_outlined,
      Icons.directions_car_outlined,
    ];
    return [
      for (var i = 0; i < sections.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Panel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: _IconChip(icons[i], size: 36),
              title: Text(
                titles[i],
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                for (final key in sections[i])
                  ListTile(
                    dense: true,
                    title: Text(fieldLabels[key] ?? key),
                    subtitle: Text(
                      fields[key]!.text.isEmpty ? '—' : fields[key]!.text,
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => step = i),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit section'),
                  ),
                ),
              ],
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Panel(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconChip(Icons.description_outlined, size: 36),
                  const SizedBox(width: 12),
                  Text(
                    'Documents',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              for (final key in documents.keys)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: scheme.primary,
                  ),
                  title: Text(documentLabel(key)),
                  subtitle: const Text('Selected document'),
                ),
              TextButton.icon(
                onPressed: () => setState(() => step = 3),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit documents'),
              ),
            ],
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: CheckboxListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          value: declaration,
          onChanged: (v) => setState(() => declaration = v ?? false),
          title: Text(
            'I confirm the information supplied is accurate.',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
        ),
      ),
    ];
  }
}

/// Upload card for one required document. Shows what is true: a picked image
/// is only selected on this device until the application is submitted.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.path,
    required this.expiry,
    required this.onPickExpiry,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });
  final String title;
  final String? path;
  final TextEditingController? expiry;
  final VoidCallback onPickExpiry, onCamera, onGallery, onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = path != null;
    return _Panel(
      child: AnimatedSize(
        duration: _motion(context, 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _IconChip(
                  selected ? Icons.task_alt : Icons.upload_file_outlined,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primaryContainer
                              : scheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selected
                              ? 'Selected on this device'
                              : 'Required document',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 140,
                  child: Image.file(
                    File(path!),
                    fit: BoxFit.cover,
                    cacheWidth: 640,
                    frameBuilder: (context, child, frame, sync) =>
                        AnimatedOpacity(
                          opacity: frame == null && !sync ? 0 : 1,
                          duration: _motion(context, 200),
                          child: child,
                        ),
                    errorBuilder: (_, e, s) => Container(
                      color: scheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Text('Please select this document again'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ready for submission. It uploads when you submit your application.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (expiry != null) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: expiry,
                keyboardType: TextInputType.datetime,
                decoration: _regInput(
                  context,
                  label: 'Document expiry (YYYY-MM-DD)',
                  icon: Icons.event_outlined,
                  suffix: IconButton(
                    tooltip: 'Choose date',
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: onPickExpiry,
                  ),
                ),
                validator: (v) => DateTime.tryParse(v ?? '') == null
                    ? 'Enter a valid expiry date'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery / replace'),
                ),
                if (selected)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: onRemove,
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}