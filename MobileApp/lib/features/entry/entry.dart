import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/controller.dart';
import '../../app/theme.dart';
import '../../core/config.dart';
import '../../shared/widgets.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.app});
  final AppController app;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final pages = PageController();
  int index = 0;
  static const titles = [
    'Move Freely.',
    'Your Fare.\nYour Choice.',
    'Your Journey.\nYour Choice.',
  ];
  static const descriptions = [
    'Discover a smarter way to travel around your city.',
    'Propose a fare and choose from available driver offers.',
    'Connect with drivers and experience flexible, convenient travel with Trivia.',
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

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Brand(),
                TextButton(
                  onPressed: widget.app.finishOnboarding,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: pages,
              itemCount: 3,
              onPageChanged: (i) => setState(() => index = i),
              itemBuilder: (context, i) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1.65,
                        child: Image.asset(
                          images[i].asset,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: images[i].alignment,
                          semanticLabel: images[i].label,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '0${i + 1} / YOUR NEXT CHAPTER',
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      titles[i],
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      descriptions[i],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      width: i == index ? 28 : 7,
                      height: 7,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: i == index ? darkGreen : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ActionButton(index == 2 ? 'Get started' : 'Next', () {
                  if (index == 2) {
                    widget.app.finishOnboarding();
                  } else {
                    pages.nextPage(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.app});
  final AppController app;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final phone = TextEditingController(), code = TextEditingController();
  final form = GlobalKey<FormState>();
  bool otp = false;
  String prefix = '+263', submittedPhone = '';
  Timer? timer;
  int remaining = 0;
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
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
    if (!form.currentState!.validate()) {
      return;
    }
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

  Future<void> policy(String url, String name) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name has not been configured for this development build.',
            ),
          ),
        );
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'https') {
      await launchUrl(uri!, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 44),
                const Brand(large: true),
                const SizedBox(height: 10),
                const Text('Your Journey. Your Choice.'),
                const SizedBox(height: 56),
                Text(
                  otp ? 'Check your phone' : 'Let’s get you\nmoving.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  otp
                      ? 'Enter the 6-digit code sent to $submittedPhone.'
                      : 'A better journey starts with your phone number.',
                ),
                const SizedBox(height: 28),
                if (!otp) ...[
                  DropdownButtonFormField<String>(
                    initialValue: prefix,
                    decoration: const InputDecoration(
                      labelText: 'Country code',
                    ),
                    items: const ['+263', '+27', '+260', '+44', '+1']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => prefix = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '77 123 4567',
                    ),
                    validator: (v) {
                      final n = (v ?? '')
                          .replaceAll(RegExp(r'\D'), '')
                          .replaceFirst(RegExp(r'^0+'), '');
                      return prefix == '+263'
                          ? (n.length == 9
                                ? null
                                : 'Enter a 9-digit Zimbabwean number.')
                          : (n.length >= 7 && n.length + prefix.length - 1 <= 15
                                ? null
                                : 'Enter a valid phone number.');
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                    ),
                    validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                        ? null
                        : 'Enter all six digits.',
                  ),
                  TextButton(
                    onPressed: remaining > 0 || widget.app.busy
                        ? null
                        : () async {
                            if (await widget.app.sendOtp(submittedPhone) &&
                                mounted) {
                              countdown();
                            }
                          },
                    child: Text(
                      remaining > 0 ? 'Resend in ${remaining}s' : 'Resend code',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      otp = false;
                      code.clear();
                    }),
                    child: const Text('Change phone number'),
                  ),
                ],
                ErrorNotice(widget.app),
                const SizedBox(height: 16),
                ActionButton(otp ? 'Verify & continue' : 'Continue', () {
                  if (otp) {
                    if (form.currentState!.validate()) {
                      widget.app.verify(submittedPhone, code.text);
                    }
                  } else {
                    send();
                  }
                }, busy: widget.app.busy),
                const SizedBox(height: 24),
                const Text(
                  'By continuing, you agree to Trivia’s Terms and Privacy Policy.',
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => policy(AppConfig.terms, 'Terms'),
                      child: const Text('Terms'),
                    ),
                    TextButton(
                      onPressed: () =>
                          policy(AppConfig.privacy, 'Privacy Policy'),
                      child: const Text('Privacy Policy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your profile')),
    body: ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nice to meet you.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Let your driver know who to look for.'),
              const SizedBox(height: 24),
              for (final entry in [(first, 'First name'), (last, 'Last name')])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: entry.$1,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'This field is required.'
                        : null,
                  ),
                ),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
                validator: (v) =>
                    v!.isEmpty ||
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                    ? null
                    : 'Enter a valid email.',
              ),
              const SizedBox(height: 12),
              Text(widget.app.session!.phone),
              ErrorNotice(widget.app),
              const SizedBox(height: 20),
              ActionButton('Save profile', () async {
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
            ],
          ),
        ),
      ),
    ),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .85, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        ),
        child: const Brand(large: true),
      ),
    ),
  );
}
