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
    final address = email.text.trim();
    final app = widget.app;
    try {
      await app.repository.register(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        email: address,
        password: password.text,
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
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => LoginScreen(app: app, registeredEmail: address),
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
