part of 'entry.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.app, this.registeredEmail});
  final AppController app;
  final String? registeredEmail;

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
  String? message;

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
    final success = await widget.app.login(
      LoginContact(
        channel,
        passengerTesting ? identifier.text.trim() : _identifier(channel, identifier.text),
        passengerTesting: passengerTesting,
      ),
      password.text,
    );
    if (!mounted) return;
    if (success) {
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).removeRoute(route);
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
          initialChannel: channel,
          initialIdentifier: identifier.text,
        ),
      ),
    );
    if (mounted && changed == true) {
      password.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Log in to continue.')),
      );
    }
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
                onChanged: busy ? null : (value) => setState(() {
                  passengerTesting = value;
                  identifier.clear();
                  password.clear();
                  message = null;
                }),
              ),
            if (!passengerTesting) _ChannelSelector(
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
                decoration: const InputDecoration(labelText: 'Staging administrator username'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Enter your username.' : null,
              )
            else _ContactField(
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
            if (!passengerTesting) Align(
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

enum _RecoveryStep { contact, code, password }

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

  @override
  void dispose() {
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
          await widget.repository.resetPassword(token!, password.text);
          if (mounted) Navigator.of(context).pop(true);
        });
    }
  }

  void startOver() => setState(() {
    step = _RecoveryStep.contact;
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
      title: 'Password recovery',
      heading: switch (step) {
        _RecoveryStep.contact => 'Reset your password',
        _RecoveryStep.code => 'Enter your verification code',
        _RecoveryStep.password => 'Choose a new password',
      },
      subtitle: switch (step) {
        _RecoveryStep.contact =>
          'Enter the contact details registered with Trivia.',
        _RecoveryStep.code =>
          phone
              ? 'If your account is eligible, look for a six-digit SMS code.'
              : 'If your account is eligible, look for a verification code in your email.',
        _RecoveryStep.password => 'Use at least eight characters.',
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
              TextFormField(
                controller: code,
                enabled: !busy,
                keyboardType: phone ? TextInputType.number : TextInputType.text,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: phone
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                maxLength: phone ? 6 : 64,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                ),
                validator: (value) {
                  final pattern = phone ? r'^\d{6}$' : r'^[A-Za-z0-9_-]{6,64}$';
                  return RegExp(pattern).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter the verification code.';
                },
              ),
              TextButton(
                onPressed: busy ? null : send,
                child: const Text('Resend code'),
              ),
            ],
            if (step == _RecoveryStep.password) ...[
              _PasswordField(
                controller: password,
                label: 'New password',
                enabled: !busy,
                isNew: true,
                validator: (value) => (value ?? '').length < 8
                    ? 'Enter at least eight characters.'
                    : null,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: confirmation,
                label: 'Confirm password',
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
                _RecoveryStep.contact => 'Send verification code',
                _RecoveryStep.code => 'Verify code',
                _RecoveryStep.password => 'Set new password',
              },
              submit,
              busy: busy,
            ),
            if (step != _RecoveryStep.contact)
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/trivia-icon.png',
                          width: 58,
                          height: 58,
                          semanticLabel: 'Trivia',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(subtitle, textAlign: TextAlign.center),
                      const SizedBox(height: 22),
                      child,
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
