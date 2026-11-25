import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../core/api_error.dart';
import '../../core/config.dart';
import '../../core/repository.dart';
import '../legal/legal_content.dart';
import '../legal/legal_page.dart';
import '../../shared/widgets.dart';

part 'registration_art.dart';
part 'password_access.dart';
part 'email_registration.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Animation duration that collapses to zero when the user asks for reduced
/// motion.
Duration _motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// One consistent field style for every input on the entry screens.
InputDecoration _premiumInput(
  BuildContext context, {
  required String label,
  String? hint,
  Widget? prefixIcon,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 18,
  ),
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
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    contentPadding: contentPadding,
    errorMaxLines: 3,
    border: border(scheme.outlineVariant),
    enabledBorder: border(scheme.outlineVariant),
    focusedBorder: border(scheme.primary, 2),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 2),
  );
}

/// Groups typed digits as "77 123 4567" without changing the digits that the
/// validators and `send()` read back.
class _PhoneGroupFormatter extends TextInputFormatter {
  const _PhoneGroupFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding
// ---------------------------------------------------------------------------

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.app});
  final AppController app;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final pages = PageController();
  final index = ValueNotifier<int>(0);
  bool _precached = false;

  static const titles = [
    'Move Freely.',
    'Your Fare.\nYour Choice.',
    'Your Journey.\nYour Choice.',
  ];
  static const descriptions = [
    'Discover a smarter, simpler way to travel around your city.',
    'Propose your fare, receive driver offers and choose what works for you.',
    'Connect with drivers and enjoy convenient, flexible journeys with Trivia.',
  ];
  static const images = [
    (
      asset: 'assets/images/onboarding/trivia_onboarding_1.png',
      label: 'A passenger requesting a Trivia ride',
      alignment: Alignment.center,
    ),
    (
      asset: 'assets/images/onboarding/trivia_onboarding_2.png',
      label: 'A Trivia driver ready for your journey',
      alignment: Alignment(0.1, -0.2),
    ),
    (
      asset: 'assets/images/onboarding/trivia_onboarding_3.png',
      label: 'A completed Trivia ride on a passenger’s phone',
      alignment: Alignment(0, 0.2),
    ),
  ];

  /// Decodes at screen resolution instead of the full source size.
  ImageProvider _provider(BuildContext context, String asset) {
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(360, 1440);
    return ResizeImage(AssetImage(asset), width: width);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final image in images) {
      precacheImage(
        _provider(context, image.asset),
        context,
        onError: (error, stack) {},
      );
    }
  }

  @override
  void dispose() {
    pages.dispose();
    index.dispose();
    super.dispose();
  }

  void _next() {
    if (index.value == 2) {
      widget.app.finishOnboarding();
    } else {
      pages.nextPage(
        duration: _motion(context, 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = (constraints.maxHeight * 0.5).clamp(220.0, 480.0);
          return Column(
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(32),
                        ),
                        child: PageView.builder(
                          controller: pages,
                          itemCount: images.length,
                          onPageChanged: (i) => index.value = i,
                          itemBuilder: (context, i) => _OnboardingImage(
                            provider: _provider(context, images[i].asset),
                            alignment: images[i].alignment,
                            label: images[i].label,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Brand(),
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.surface,
                                foregroundColor: scheme.onSurface,
                                minimumSize: const Size(64, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: widget.app.finishOnboarding,
                              child: const Text('Skip'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: ValueListenableBuilder<int>(
                              valueListenable: index,
                              builder: (context, i, _) => AnimatedSwitcher(
                                duration: _motion(context, 260),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topLeft,
                                  children: [...previous, if (current != null) current],
                                ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.06, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(i),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titles[i],
                                          style: theme.textTheme.headlineLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                height: 1.1,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          descriptions[i],
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<int>(
                          valueListenable: index,
                          builder: (context, i, _) => Column(
                            children: [
                              Semantics(
                                label: 'Page ${i + 1} of ${images.length}',
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    images.length,
                                    (n) => AnimatedContainer(
                                      duration: _motion(context, 250),
                                      curve: Curves.easeOutCubic,
                                      width: n == i ? 28 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: n == i
                                            ? scheme.primary
                                            : scheme.outlineVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ActionButton(
                                  i == images.length - 1 ? 'Get started' : 'Next',
                                  _next,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OnboardingImage extends StatelessWidget {
  const _OnboardingImage({
    required this.provider,
    required this.alignment,
    required this.label,
  });
  final ImageProvider provider;
  final Alignment alignment;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Image(
      image: provider,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      semanticLabel: label,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Registration + OTP
// ---------------------------------------------------------------------------

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.app});
  final AppController app;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final phone = TextEditingController(), code = TextEditingController();
  final codeFocus = FocusNode();
  final form = GlobalKey<FormState>();
  bool otp = false, acceptedTerms = false;
  String? consentError;
  final legalContent = LegalContent.load();
  String prefix = '+263', submittedPhone = '';
  Timer? timer;
  int remaining = 0;

  static const _countries = [
    ('+263', '🇿🇼', 'Zimbabwe'),
    ('+27', '🇿🇦', 'South Africa'),
    ('+260', '🇿🇲', 'Zambia'),
    ('+44', '🇬🇧', 'United Kingdom'),
    ('+1', '🇺🇸', 'United States'),
  ];

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    codeFocus.dispose();
    timer?.cancel();
    super.dispose();
  }

  void countdown() {
    timer?.cancel();
    setState(() => remaining = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => remaining--);
      if (remaining <= 0) {
        t.cancel();
      }
    });
  }

  Future<void> send() async {
    if (widget.app.busy) return;
    if (!form.currentState!.validate()) {
      return;
    }
    if (!checkTerms()) return;
    final local = phone.text
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    final number = '$prefix$local';
    if (await widget.app.sendOtp(number) && mounted) {
      submittedPhone = number;
      setState(() => otp = true);
      countdown();
    }
  }

  bool checkTerms() {
    if (acceptedTerms) return true;
    setState(
      () => consentError =
          'Please acknowledge the Terms & Conditions before continuing.',
    );
    return false;
  }

  Future<void> verify() async {
    if (widget.app.busy) return;
    if (!form.currentState!.validate() || !checkTerms()) return;
    final app = widget.app;
    final verifiedPhone = submittedPhone;
    try {
      final content = await legalContent;
      if (!await app.verify(
        verifiedPhone,
        code.text,
        legalAcknowledgement: content.acknowledgement(),
      )) {
        return;
      }
      if (app.session?.phone == verifiedPhone) {
        await LegalAcknowledgementStore().record(verifiedPhone, content);
      }
    } catch (_) {
      app.error =
          'Unable to save the local legal acknowledgement. Please retry or contact support.';
      app.notifyListeners();
    }
  }

  Future<void> resend() async {
    if (await widget.app.sendOtp(submittedPhone) && mounted) {
      countdown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A new code is on its way.')));
    }
  }

  Widget _phoneField(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 128,
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: prefix,
          borderRadius: BorderRadius.circular(14),
          decoration: _premiumInput(
            context,
            label: 'Country',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 18,
            ),
          ),
          selectedItemBuilder: (_) => [
            for (final c in _countries)
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${c.$2} ${c.$1}'),
                ),
              ),
          ],
          items: [
            for (final c in _countries)
              DropdownMenuItem(
                value: c.$1,
                child: Text('${c.$2}  ${c.$3} (${c.$1})'),
              ),
          ],
          onChanged: widget.app.busy
              ? null
              : (v) => setState(() => prefix = v!),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextFormField(
          controller: phone,
          readOnly: widget.app.busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => send(),
          inputFormatters: const [_PhoneGroupFormatter()],
          autofillHints: const [AutofillHints.telephoneNumberNational],
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(letterSpacing: 0.5),
          decoration: _premiumInput(
            context,
            label: 'Phone number',
            hint: '77 123 4567',
          ),
          validator: (value) {
            final digits = (value ?? '')
                .replaceAll(RegExp(r'\D'), '')
                .replaceFirst(RegExp(r'^0+'), '');
            return prefix == '+263'
                ? (RegExp(r'^7\d{8}$').hasMatch(digits)
                      ? null
                      : 'Enter a 9-digit Zimbabwean number.')
                : (digits.length >= 7 && digits.length + prefix.length - 1 <= 15
                      ? null
                      : 'Enter a valid phone number.');
          },
        ),
      ),
    ],
  );

  Widget _consent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<LegalContent>(
      future: legalContent,
      builder: (context, snapshot) => Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: consentError != null ? scheme.error : scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  label: 'Accept Terms and Conditions',
                  child: Checkbox(
                    value: acceptedTerms,
                    onChanged: widget.app.busy || !snapshot.hasData
                        ? null
                        : (value) => setState(() {
                            acceptedTerms = value ?? false;
                            consentError = null;
                          }),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        snapshot.data?.status == 'published'
                            ? 'I agree to the'
                            : 'I acknowledge the draft',
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => openPage(
                          context,
                          const LegalPage(documentId: 'terms'),
                        ),
                        child: const Text('Terms & Conditions'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (snapshot.data case final content?)
              if (content.status != 'published')
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
                  child: Text(
                    content.reviewNotice,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            if (!snapshot.hasData)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
                child: Text(
                  snapshot.hasError
                      ? 'Legal documents could not be loaded.'
                      : 'Loading legal documents…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resendRow(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          remaining > 0 ? 'Didn’t get a code?' : 'Still waiting?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      TextButton(
        onPressed: remaining > 0 || widget.app.busy ? null : resend,
        child: Text(remaining > 0 ? 'Resend in ${remaining}s' : 'Resend code'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final headline = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final body = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.app,
          builder: (context, _) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _RegistrationBrand(),
                      if (!otp && !keyboardVisible)
                        const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: _RegistrationHero(),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        otp ? 'Verify your number' : 'Get started with Trivia',
                        style: headline,
                      ),
                      const SizedBox(height: 8),
                      if (otp)
                        Text.rich(
                          TextSpan(
                            text: 'Enter the 6-digit code sent to ',
                            children: [
                              TextSpan(
                                text: submittedPhone,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          style: body,
                        )
                      else
                        Text(
                          'Create an account to request rides or apply to drive in Zimbabwe.',
                          style: body,
                        ),
                      const SizedBox(height: 20),
                      if (!otp)
                        _phoneField(context)
                      else ...[
                        _PremiumOtpInput(
                          controller: code,
                          focusNode: codeFocus,
                        ),
                        const SizedBox(height: 4),
                        _resendRow(context),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              otp = false;
                              code.clear();
                              acceptedTerms = false;
                              consentError = null;
                            }),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Change phone number'),
                          ),
                        ),
                      ],
                      ErrorNotice(widget.app),
                      const SizedBox(height: 12),
                      _consent(context),
                      if (consentError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              consentError!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => openPage(
                            context,
                            const LegalPage(documentId: 'privacy'),
                          ),
                          child: const Text('Privacy Policy'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: ActionButton(
                          otp ? 'Verify & continue' : 'Continue',
                          otp ? verify : send,
                          busy: widget.app.busy,
                        ),
                      ),
                      if (!otp) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: widget.app.busy
                                ? null
                                : () => openPage(
                                    context,
                                    EmailRegistrationScreen(app: widget.app),
                                  ),
                            icon: const Icon(Icons.mail_outline),
                            label: const Text('Sign up with email'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Already have an account?'),
                              TextButton(
                                onPressed: widget.app.busy
                                    ? null
                                    : () => openPage(
                                        context,
                                        LoginScreen(app: widget.app),
                                      ),
                                child: const Text('Log in'),
                              ),
                            ],
                          ),
                        ),
                        const _RegistrationFooter(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Six styled boxes driven by ONE real text field.
///
/// The field sits invisibly on top of the boxes, so the controller still holds
/// the plain 6-digit string that `verify()` reads, SMS autofill and the
/// keyboard's clipboard suggestion work natively, and focus moves from box to
/// box as digits are typed.
class _PremiumOtpInput extends StatelessWidget {
  const _PremiumOtpInput({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  static const _length = 6;

  Future<void> _paste(FormFieldState<String> state) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < _length) return;
    final value = digits.substring(0, _length);
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    state.didChange(value);
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: '',
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (_) => RegExp(r'^\d{6}$').hasMatch(controller.text)
        ? null
        : 'Enter all six digits.',
    builder: (state) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Verification code, six digits',
            child: Stack(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([controller, focusNode]),
                  builder: (context, _) {
                    final text = controller.text;
                    final active = focusNode.hasFocus
                        ? text.length.clamp(0, _length - 1)
                        : -1;
                    return Row(
                      children: [
                        for (var i = 0; i < _length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedContainer(
                              duration: _motion(context, 150),
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: state.hasError
                                      ? scheme.error
                                      : i == active
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: state.hasError || i == active ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                i < text.length ? text[i] : '',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                Positioned.fill(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    autocorrect: false,
                    enableSuggestions: false,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    decoration: const InputDecoration.collapsed(hintText: null),
                    onChanged: state.didChange,
                  ),
                ),
              ],
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.errorText!,
                style: TextStyle(color: scheme.error),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _paste(state),
              icon: const Icon(Icons.content_paste_outlined, size: 18),
              label: const Text('Paste code'),
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Profile setup
// ---------------------------------------------------------------------------

class ProfileSetup extends StatefulWidget {
  const ProfileSetup({super.key, required this.app});
  final AppController app;
  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  final first = TextEditingController(),
      last = TextEditingController(),
      email = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    first.text = widget.app.session!.firstName;
    last.text = widget.app.session!.lastName;
    email.text = widget.app.session!.email;
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) => ContentFrame(
          maxWidth: 480,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nice to meet you.',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let your driver know who to look for.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: first,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: _premiumInput(
                      context,
                      label: 'First name',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'This field is required.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: last,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: _premiumInput(
                      context,
                      label: 'Last name',
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'This field is required.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    decoration: _premiumInput(
                      context,
                      label: 'Email (optional)',
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        v!.isEmpty ||
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                        ? null
                        : 'Enter a valid email.',
                  ),
                  if (widget.app.session!.phone.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verified phone number',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                                Text(
                                  widget.app.session!.phone,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const LegalLinks(),
                  ErrorNotice(widget.app),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ActionButton('Save profile', () async {
                      if (form.currentState!.validate()) {
                        final ok = await widget.app.updateProfile(
                          first.text.trim(),
                          last.text.trim(),
                          email.text.trim(),
                        );
                        if (ok && context.mounted && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    }, busy: widget.app.busy),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash
// ---------------------------------------------------------------------------

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOutCubic,
        duration: _motion(context, 420),
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.9 + 0.1 * value, child: child),
        ),
        child: const Brand(large: true),
      ),
    ),
  );
}