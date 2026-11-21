part of 'entry.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.app,
    this.registeredEmail,
    this.initialMessage,
  });
  final AppController app;
  final String? registeredEmail;
  final String? initialMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  late final identifier = TextEditingController(text: widget.registeredEmail);
  final password = TextEditingController();
  late LoginChannel channel = widget.registeredEmail == null
      ? LoginChannel.phone
      : LoginChannel.email;
  bool busy = false;
  bool passengerTesting = false;
  late String? message = widget.initialMessage;

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    final contact = LoginContact(
      channel,
      passengerTesting
          ? identifier.text.trim()
          : _identifier(channel, identifier.text),
      passengerTesting: passengerTesting,
    );
    final submittedPassword = password.text;
    final success = await widget.app.login(contact, submittedPassword);
    if (!mounted) return;
    if (success) {
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
    } else if (widget.app.errorCode == 'EMAIL_VERIFICATION_REQUIRED') {
      password.clear();
      final credentials = _SignupCredentials(submittedPassword);
      final result = await Navigator.of(context).push<_SignupResult>(
        MaterialPageRoute(
          builder: (_) => _SignupVerification(
            app: widget.app,
            email: contact.identifier,
            credentials: credentials,
            codeSent: false,
            returnToLogin: true,
          ),
        ),
      );
      credentials.password = null;
      if (!mounted) return;
      if (result?.signedIn == true) {
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRoute(route);
        return;
      }
      setState(() {
        busy = false;
        message = result?.message;
      });
    } else {
      setState(() {
        busy = false;
        message = widget.app.error;
      });
    }
  }

  void signUp() {
    final app = widget.app;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => EmailRegistrationScreen(app: app)),
    );
  }

  Future<void> recover() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PasswordRecovery(
          repository: widget.app.repository,
          initialChannel: identifier.text.trim().isEmpty
              ? LoginChannel.email
              : channel,
          initialIdentifier: identifier.text,
        ),
      ),
    );
    if (mounted && changed == true) password.clear();
  }

  @override
  Widget build(BuildContext context) => _AccessPage(
    title: 'Log in',
    heading: 'Welcome back',
    subtitle: widget.registeredEmail == null
        ? 'Log in to continue your journey.'
        : 'Your account is ready. Log in with your new password.',
    child: AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (passengerTestingEnabled)
              SwitchListTile(
                title: const Text('Passenger Testing Mode'),
                value: passengerTesting,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        passengerTesting = value;
                        identifier.clear();
                        password.clear();
                        message = null;
                      }),
              ),
            if (!passengerTesting)
              _ChannelSelector(
                channel: channel,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        channel = value;
                        identifier.clear();
                        message = null;
                      }),
              ),
            const SizedBox(height: 18),
            if (passengerTesting)
              TextFormField(
                controller: identifier,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Staging administrator username',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter your username.'
                    : null,
              )
            else
              _ContactField(
                channel: channel,
                controller: identifier,
                enabled: !busy,
              ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: password,
              label: 'Password',
              enabled: !busy,
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Enter your password.' : null,
              onSubmitted: submit,
            ),
            if (!passengerTesting)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : recover,
                  child: const Text('Forgot Password?'),
                ),
              ),
            _AccessMessage(message),
            ActionButton('Log In', submit, busy: busy),
            TextButton(
              onPressed: busy ? null : signUp,
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _RecoveryStep { contact, code, password, success }

class _PasswordRecovery extends StatefulWidget {
  const _PasswordRecovery({
    required this.repository,
    required this.initialChannel,
    required this.initialIdentifier,
  });

  final TriviaRepository repository;
  final LoginChannel initialChannel;
  final String initialIdentifier;

  @override
  State<_PasswordRecovery> createState() => _PasswordRecoveryState();
}

class _PasswordRecoveryState extends State<_PasswordRecovery> {
  final form = GlobalKey<FormState>();
  late final identifier = TextEditingController(text: widget.initialIdentifier);
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  late LoginChannel channel = widget.initialChannel;
  _RecoveryStep step = _RecoveryStep.contact;
  LoginContact? contact;
  String? token;
  String? message;
  bool busy = false;
  Timer? resendTimer;
  int remaining = 0;

  @override
  void dispose() {
    resendTimer?.cancel();
    identifier.dispose();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => message = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startCooldown() {
    resendTimer?.cancel();
    remaining = 60;
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final seconds = 60 - timer.tick;
      setState(() => remaining = seconds > 0 ? seconds : 0);
      if (remaining == 0) timer.cancel();
    });
  }

  Future<void> send() => run(() async {
    final target = step == _RecoveryStep.contact
        ? LoginContact(channel, _identifier(channel, identifier.text))
        : contact!;
    await widget.repository.requestPasswordRecovery(target);
    if (!mounted) return;
    setState(() {
      contact = target;
      code.clear();
      step = _RecoveryStep.code;
      startCooldown();
    });
  });

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    switch (step) {
      case _RecoveryStep.contact:
        await send();
      case _RecoveryStep.code:
        await run(() async {
          final proof = await widget.repository.verifyPasswordRecovery(
            contact!,
            code.text.trim(),
          );
          if (!mounted) return;
          setState(() {
            token = proof;
            code.clear();
            step = _RecoveryStep.password;
          });
        });
      case _RecoveryStep.password:
        await run(() async {
          await widget.repository.resetPassword(
            token!,
            password.text,
            confirmation.text,
          );
          if (mounted) {
            setState(() {
              token = null;
              resendTimer?.cancel();
              password.clear();
              confirmation.clear();
              step = _RecoveryStep.success;
            });
          }
        });
      case _RecoveryStep.success:
        Navigator.of(context).pop(true);
    }
  }

  void startOver() => setState(() {
    step = _RecoveryStep.contact;
    resendTimer?.cancel();
    remaining = 0;
    token = null;
    message = null;
    code.clear();
    password.clear();
    confirmation.clear();
  });

  @override
  Widget build(BuildContext context) {
    final phone = channel == LoginChannel.phone;
    return _AccessPage(
      title: 'Forgot password',
      heading: switch (step) {
        _RecoveryStep.contact => 'Reset your password',
        _RecoveryStep.code => 'Enter your verification code',
        _RecoveryStep.password => 'Choose a new password',
        _RecoveryStep.success => 'Password Reset Successful!',
      },
      subtitle: switch (step) {
        _RecoveryStep.contact => '',
        _RecoveryStep.code =>
          phone
              ? 'If your account is eligible, look for a six-digit SMS code.'
              : 'If your account is eligible, look for a six-digit code in your email. It expires in five minutes.',
        _RecoveryStep.password => '',
        _RecoveryStep.success => 'Your password has been updated. You can now log in using your new password.',
      },
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step == _RecoveryStep.contact) ...[
              _ChannelSelector(
                channel: channel,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        channel = value;
                        identifier.clear();
                        message = null;
                      }),
              ),
              const SizedBox(height: 18),
              _ContactField(
                channel: channel,
                controller: identifier,
                enabled: !busy,
              ),
            ],
            if (step == _RecoveryStep.code) ...[
              _VerificationCodeField(
                controller: code,
                enabled: !busy,
                onSubmitted: submit,
              ),
              TextButton(
                onPressed: busy || remaining > 0 ? null : send,
                child: Text(
                  remaining > 0
                      ? 'Resend code in ${remaining}s'
                      : 'Resend Code',
                ),
              ),
            ],
            if (step == _RecoveryStep.password) ...[
              _PasswordField(
                controller: password,
                label: 'New password',
                enabled: !busy,
                isNew: true,
                validator: _newPasswordError,
              ),
              _PasswordRequirements(password),
              const SizedBox(height: 14),
              _PasswordField(
                controller: confirmation,
                label: 'Confirm New Password',
                enabled: !busy,
                isNew: true,
                validator: (value) =>
                    value != password.text ? 'The passwords must match.' : null,
                onSubmitted: submit,
              ),
            ],
            const SizedBox(height: 16),
            _AccessMessage(message),
            ActionButton(
              switch (step) {
                _RecoveryStep.contact => 'Send Reset Code',
                _RecoveryStep.code => 'Verify Code',
                _RecoveryStep.password => 'Reset Password',
                _RecoveryStep.success => 'Back to Login',
              },
              submit,
              busy: busy,
            ),
            if (step == _RecoveryStep.contact)
              TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Back to Login'),
              ),
            if (step == _RecoveryStep.code || step == _RecoveryStep.password)
              TextButton(
                onPressed: busy ? null : startOver,
                child: const Text('Start over'),
              ),
          ],
        ),
      ),
    );
  }
}

String _identifier(LoginChannel channel, String value) {
  if (channel == LoginChannel.email) return value.trim();
  final number = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (number.startsWith('+')) return number;
  if (number.startsWith('00')) return '+${number.substring(2)}';
  if (number.startsWith('263') && number.length > 9) return '+$number';
  return '+263${number.replaceFirst(RegExp(r'^0'), '')}';
}

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.channel,
    required this.controller,
    required this.enabled,
  });

  final LoginChannel channel;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final phone = channel == LoginChannel.phone;
    return TextFormField(
      key: ValueKey(channel),
      controller: controller,
      enabled: enabled,
      keyboardType: phone ? TextInputType.phone : TextInputType.emailAddress,
      autofillHints: [
        phone ? AutofillHints.telephoneNumber : AutofillHints.email,
      ],
      autocorrect: false,
      decoration: InputDecoration(
        labelText: phone ? 'Phone number' : 'Email address',
        prefixIcon: phone
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(widthFactor: 1, child: Text('+263')),
              )
            : null,
        hintText: phone ? '77 123 4567' : 'you@example.com',
      ),
      validator: (value) {
        final contact = _identifier(channel, value ?? '');
        if (phone) {
          final valid =
              RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(contact) &&
              (!contact.startsWith('+263') || contact.length == 13);
          return valid ? null : 'Enter a valid phone number.';
        }
        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)
            ? null
            : 'Enter a valid email address.';
      },
    );
  }
}

class _ChannelSelector extends StatelessWidget {
  const _ChannelSelector({required this.channel, required this.onChanged});
  final LoginChannel channel;
  final ValueChanged<LoginChannel>? onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<LoginChannel>(
    segments: const [
      ButtonSegment(value: LoginChannel.phone, label: Text('Phone number')),
      ButtonSegment(value: LoginChannel.email, label: Text('Email')),
    ],
    selected: {channel},
    showSelectedIcon: false,
    onSelectionChanged: onChanged == null
        ? null
        : (values) => onChanged!(values.single),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    this.isNew = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled, isNew;
  final FormFieldValidator<String> validator;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: !visible,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
    ],
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: visible ? 'Hide password' : 'Show password',
        onPressed: () => setState(() => visible = !visible),
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
    validator: widget.validator,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
  );
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

class _VerificationCodeField extends StatelessWidget {
  const _VerificationCodeField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    maxLength: 6,
    autocorrect: false,
    enableSuggestions: false,
    decoration: const InputDecoration(labelText: 'Verification code'),
    onFieldSubmitted: (_) => onSubmitted(),
    validator: (value) =>
        (value ?? '').length == 6 ? null : 'Enter the six-digit code.',
  );
}

class _AccessPage extends StatelessWidget {
  const _AccessPage({
    required this.title,
    required this.heading,
    required this.subtitle,
    required this.child,
  });

  final String title, heading, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Brand(large: true)),
                    const SizedBox(height: 14),
                    Text(
                      heading,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(subtitle, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 22),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _passwordRequirements = [
  ('At least 8 characters', (String value) => value.runes.length >= 8),
  ('One uppercase letter', RegExp(r'[A-Z]').hasMatch),
  ('One lowercase letter', RegExp(r'[a-z]').hasMatch),
  ('One number', RegExp(r'[0-9]').hasMatch),
  ('One special character', RegExp(r'[!-\/:-@\[-`{-~]').hasMatch),
];

String? _newPasswordError(String? value) =>
    _passwordRequirements.every((rule) => rule.$2(value ?? ''))
    ? null
    : 'Choose a password that meets all five requirements.';

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements(this.controller);
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Password requirements'),
            for (final (label, check) in _passwordRequirements)
              Builder(
                builder: (context) {
                  final satisfied = check(value.text);
                  final color = satisfied
                      ? (colors.brightness == Brightness.dark
                            ? Colors.greenAccent
                            : darkGreen)
                      : colors.onSurfaceVariant;
                  return Row(
                    children: [
                      Icon(
                        satisfied ? Icons.check : Icons.circle_outlined,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label, style: TextStyle(color: color)),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.app});
  final AppController app;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    final app = widget.app;
    final changed = await app.changePassword(
      current.text,
      password.text,
      confirmation.text,
    );
    if (!mounted) return;
    if (changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Sign in with your new password.'),
        ),
      );
    } else {
      setState(() {
        busy = false;
        message = app.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _AccessPage(
    title: 'Security',
    heading: 'Change password',
    subtitle: 'You’ll sign in again after updating your password.',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PasswordField(
            controller: current,
            label: 'Current password',
            enabled: !busy,
            validator: (value) =>
                (value ?? '').isEmpty ? 'Enter your current password.' : null,
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: password,
            label: 'New password',
            enabled: !busy,
            isNew: true,
            validator: _newPasswordError,
          ),
          _PasswordRequirements(password),
          _PasswordField(
            controller: confirmation,
            label: 'Confirm new password',
            enabled: !busy,
            isNew: true,
            validator: (value) =>
                value == password.text ? null : 'The passwords must match.',
            onSubmitted: submit,
          ),
          const SizedBox(height: 16),
          _AccessMessage(message),
          ActionButton('Change password', submit, busy: busy),
        ],
      ),
    ),
  );
}
