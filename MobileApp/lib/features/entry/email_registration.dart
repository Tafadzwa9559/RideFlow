part of 'entry.dart';

class EmailRegistrationScreen extends StatefulWidget {
  const EmailRegistrationScreen({super.key, required this.app});
  final AppController app;

  @override
  State<EmailRegistrationScreen> createState() =>
      _EmailRegistrationScreenState();
}

class _EmailRegistrationScreenState extends State<EmailRegistrationScreen> {
  final form = GlobalKey<FormState>();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
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
    final address = _identifier(LoginChannel.email, email.text).toLowerCase();
    final app = widget.app;
    final signupPassword = password.text;
    bool verificationRequired;
    try {
      verificationRequired = await app.repository.register(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        email: address,
        password: signupPassword,
        confirmation: confirmation.text,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          message = apiErrorMessage(error);
        });
      }
      return;
    }
    if (!mounted) return;
    final credentials = _SignupCredentials(
      verificationRequired ? signupPassword : null,
    );
    password.clear();
    confirmation.clear();
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => verificationRequired
            ? _SignupVerification(
                app: app,
                email: address,
                credentials: credentials,
                codeSent: true,
              )
            : LoginScreen(app: app, registeredEmail: address),
      ),
    );
  }

  Widget nameField(
    String label,
    TextEditingController controller,
    String hint,
  ) => TextFormField(
    controller: controller,
    enabled: !busy,
    textCapitalization: TextCapitalization.words,
    autofillHints: [hint],
    decoration: InputDecoration(labelText: label),
    validator: (value) => (value ?? '').trim().isEmpty
        ? 'Enter your ${label.toLowerCase()}.'
        : null,
  );

  @override
  Widget build(BuildContext context) => _AccessPage(
    title: 'Sign up',
    heading: 'Create a passenger account',
    subtitle: '',
    child: AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            nameField('First name', firstName, AutofillHints.givenName),
            const SizedBox(height: 14),
            nameField('Last name', lastName, AutofillHints.familyName),
            const SizedBox(height: 14),
            _ContactField(
              channel: LoginChannel.email,
              controller: email,
              enabled: !busy,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: password,
              label: 'Password',
              enabled: !busy,
              isNew: true,
              validator: _newPasswordError,
            ),
            _PasswordRequirements(password),
            const SizedBox(height: 14),
            _PasswordField(
              controller: confirmation,
              label: 'Confirm password',
              enabled: !busy,
              isNew: true,
              validator: (value) =>
                  value == password.text ? null : 'The passwords must match.',
              onSubmitted: submit,
            ),
            const SizedBox(height: 16),
            _AccessMessage(message),
            ActionButton('Create account', submit, busy: busy),
          ],
        ),
      ),
    ),
  );
}

class _SignupCredentials {
  _SignupCredentials(this.password);
  String? password;
}

typedef _SignupResult = ({bool signedIn, String? message});

class _SignupVerification extends StatefulWidget {
  const _SignupVerification({
    required this.app,
    required this.email,
    required this.credentials,
    required this.codeSent,
    this.returnToLogin = false,
  });

  final AppController app;
  final String email;
  final _SignupCredentials credentials;
  final bool codeSent, returnToLogin;

  @override
  State<_SignupVerification> createState() => _SignupVerificationState();
}

class _SignupVerificationState extends State<_SignupVerification> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _clock;
  DateTime? _sentAt;
  DateTime? _resendAt;
  DateTime? _verifyAt;
  bool _busy = false;
  String? _error;

  int _secondsUntil(DateTime? retry) {
    if (retry == null) return 0;
    final milliseconds = retry.difference(clock.now()).inMilliseconds;
    return milliseconds > 0 ? (milliseconds / 1000).ceil() : 0;
  }

  bool get _expired =>
      _sentAt != null &&
      clock.now().difference(_sentAt!) >= const Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    if (widget.codeSent) _startClock();
  }

  void _startClock() {
    final now = clock.now();
    _sentAt = now;
    _resendAt = now.add(const Duration(seconds: 60));
    _scheduleClock();
  }

  void _scheduleClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
      if ((_sentAt == null || _expired) &&
          _secondsUntil(_resendAt) == 0 &&
          _secondsUntil(_verifyAt) == 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _code.dispose();
    widget.credentials.password = null;
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(String password) action, {
    bool resend = false,
  }) async {
    if (_busy) return;
    final password = widget.credentials.password;
    if (password == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(password);
    } catch (error) {
      if (mounted) {
        setState(() {
          final retry = apiRetryAfter(error);
          if (retry != null && retry > 0) {
            final deadline = clock.now().add(Duration(seconds: retry));
            if (resend) {
              _resendAt = deadline;
            } else {
              _verifyAt = deadline;
            }
            _scheduleClock();
          }
          _error = !resend && apiErrorCode(error) == 'INVALID'
              ? 'This code is incorrect, expired, or out of attempts. Check it or request a new one.'
              : apiErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsUntil(_resendAt) > 0) return;
    await _run((password) async {
      await widget.app.repository.resendSignupCode(widget.email, password);
      if (!mounted) return;
      _code.clear();
      setState(_startClock);
    }, resend: true);
  }

  Future<void> _verify() async {
    if (_busy ||
        _expired ||
        _secondsUntil(_verifyAt) > 0 ||
        !_form.currentState!.validate()) {
      return;
    }
    await _run((password) async {
      await widget.app.repository.verifySignupCode(
        widget.email,
        password,
        _code.text,
      );
      if (!mounted) return;
      _code.clear();
      widget.credentials.password = null;
      final app = widget.app;
      final email = widget.email;
      final signedIn = await app.login(
        LoginContact(LoginChannel.email, email),
        password,
      );
      if (!mounted) return;
      final message = signedIn
          ? null
          : 'Email verified. Sign in to continue. ${app.error ?? ''}'.trim();
      final navigator = Navigator.of(context);
      if (widget.returnToLogin) {
        navigator.pop<_SignupResult>((signedIn: signedIn, message: message));
      } else if (signedIn) {
        navigator.removeRoute(ModalRoute.of(context)!);
      } else {
        navigator.pushReplacement<void, void>(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              app: app,
              registeredEmail: email,
              initialMessage: message,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final resendWait = _secondsUntil(_resendAt);
    final verifyWait = _secondsUntil(_verifyAt);
    return PopScope(
      canPop: !_busy,
      child: _AccessPage(
        title: 'Verify email',
        heading: 'Enter your verification code',
        subtitle: _sentAt == null
            ? 'Enter the code for ${widget.email} or request a new one. Codes expire in five minutes.'
            : 'Check ${widget.email} for a six-digit code. It expires in five minutes.',
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VerificationCodeField(
                controller: _code,
                enabled: !_busy && !_expired,
                onSubmitted: _verify,
              ),
              if (_expired)
                const _AccessMessage(
                  'This code has expired. Request a new one.',
                ),
              Semantics(liveRegion: true, child: _AccessMessage(_error)),
              ActionButton(
                verifyWait > 0 ? 'Try again in ${verifyWait}s' : 'Verify email',
                _expired || verifyWait > 0 ? null : _verify,
                busy: _busy,
              ),
              TextButton(
                onPressed: _busy || resendWait > 0 ? null : _resend,
                child: Text(
                  resendWait > 0
                      ? 'Resend code in ${resendWait}s'
                      : 'Resend Code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
