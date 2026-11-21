import 'support/fixture_repository.dart';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideflow_mobile/features/passenger/home.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/app/theme.dart';
import 'package:rideflow_mobile/features/entry/entry.dart';
import 'package:rideflow_mobile/shared/models.dart';

class _UnavailableRecoveryRepository extends TestRepository {
  LoginContact? requestedContact;

  @override
  Future<void> requestPasswordRecovery(LoginContact contact) async {
    requestedContact = contact;
    throw UnsupportedError('SMS password recovery is currently unavailable.');
  }
}

class _EmailSignupRepository extends TestRepository {
  _EmailSignupRepository({this.verificationRequired = false});

  final bool verificationRequired;
  final submissions = <List<String>>[];
  bool verified = false;
  bool failLogin = false;
  int loginAttempts = 0;
  int resends = 0;
  int verificationAttempts = 0;
  Object? verifyError;
  Object? resendError;

  @override
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmation,
  }) async {
    submissions.add([firstName, lastName, email, password, confirmation]);
    return verificationRequired;
  }

  @override
  Future<void> verifySignupCode(
    String email,
    String password,
    String code,
  ) async {
    verificationAttempts++;
    expect(email, submissions.single[2]);
    expect(password, submissions.single[3]);
    if (verifyError case final error?) throw error;
    if (code != '004219') {
      final request = RequestOptions();
      throw DioException.badResponse(
        statusCode: 400,
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 400,
          data: {'code': 'INVALID'},
        ),
      );
    }
    verified = true;
  }

  @override
  Future<void> resendSignupCode(String email, String password) async {
    resends++;
    expect(email, submissions.single[2]);
    expect(password, submissions.single[3]);
    if (resendError case final error?) throw error;
  }

  @override
  Future<Session> login(LoginContact contact, String password) async {
    loginAttempts++;
    expect(contact.toJson(), {
      'channel': 'email',
      'identifier': submissions.single[2],
    });
    expect(password, submissions.single[3]);
    if (!verified) {
      final request = RequestOptions();
      throw DioException.badResponse(
        statusCode: 403,
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 403,
          data: {'code': 'EMAIL_VERIFICATION_REQUIRED'},
        ),
      );
    }
    if (failLogin) throw StateError('Sign-in temporarily unavailable.');
    return Session(
      firstName: 'Tariro',
      lastName: 'Moyo',
      phone: '',
      email: contact.identifier,
    );
  }
}

Future<void> _enterAuthField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _tapAuthButton(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _openAuthScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: triviaTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: (_) => screen)),
            child: const Text('Start signup'),
          ),
        ),
      ),
    ),
  );
  await _tapAuthButton(tester, find.text('Start signup'));
}

Future<void> _startEmailSignup(WidgetTester tester, AppController app) async {
  await _openAuthScreen(tester, EmailRegistrationScreen(app: app));
  await _enterAuthField(tester, 'First name', 'Tariro');
  await _enterAuthField(tester, 'Last name', 'Moyo');
  await _enterAuthField(tester, 'Email address', 'tariro@example.net');
  await _enterAuthField(tester, 'Password', 'Horizon-Teak-Glass-187');
  await _enterAuthField(tester, 'Confirm password', 'Horizon-Teak-Glass-187');
  await _tapAuthButton(
    tester,
    find.widgetWithText(FilledButton, 'Create account'),
  );
}

DioException _emailThrottle(String seconds) {
  final request = RequestOptions();
  return DioException.badResponse(
    statusCode: 429,
    requestOptions: request,
    response: Response(
      requestOptions: request,
      statusCode: 429,
      data: {
        'errors': {'detail': 'Too many requests. Try again later.'},
      },
      headers: Headers.fromMap({
        'retry-after': [seconds],
      }),
    ),
  );
}

class _EmailRecoveryRepository extends TestRepository {
  LoginContact? contact;
  String? usedAuthorization;

  @override
  Future<void> requestPasswordRecovery(LoginContact contact) async {
    this.contact = contact;
  }

  @override
  Future<String> verifyPasswordRecovery(
    LoginContact contact,
    String code,
  ) async {
    if (code != '184306') {
      throw const FormatException('Invalid or expired verification.');
    }
    return 'issued-reset-authorization';
  }

  @override
  Future<void> resetPassword(
    String token,
    String password,
    String confirmation,
  ) async {
    if (password != confirmation) {
      throw const FormatException('The passwords must match.');
    }
    usedAuthorization = token;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('Login validates both channels and shows unavailable delivery', (
    tester,
  ) async {
    final repository = _UnavailableRecoveryRepository();
    final app = AppController(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: LoginScreen(app: app),
      ),
    );
    Future<void> tapText(String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('+263'), findsOneWidget);
    await tapText('Log In');
    expect(find.text('Enter a valid phone number.'), findsOneWidget);
    await tapText('Email');
    await tapText('Log In');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tapText('Phone number');
    await tester.enterText(find.byType(TextFormField).first, '077 123 4567');
    await tapText('Forgot Password?');
    await tapText('Send Reset Code');
    expect(repository.requestedContact?.identifier, '+263771234567');
    expect(
      find.text('SMS password recovery is currently unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Enter your verification code'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('Email signup confirms the password and opens email login', (
    tester,
  ) async {
    final repository = _EmailSignupRepository();
    final app = AppController(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: AuthScreen(app: app),
      ),
    );
    Future<void> tap(String label) async {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> submit() async {
      final button = find.widgetWithText(FilledButton, 'Create account');
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
    }

    const email = 'tariro@example.net';
    const password = 'Horizon-Teak-Glass-187';
    await tap('Sign up with email');
    await enter('First name', 'Tariro');
    await enter('Last name', 'Moyo');
    await enter('Email address', email);
    await enter('Password', password);
    await enter('Confirm password', 'a different password');
    await submit();
    expect(find.text('The passwords must match.'), findsOneWidget);
    expect(repository.submissions, isEmpty);

    await enter('Confirm password', password);
    await submit();
    expect(repository.submissions.single, [
      'Tariro',
      'Moyo',
      email,
      password,
      password,
    ]);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(app.session, isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets(
    'Email recovery verifies a code before resetting and returns to login',
    (tester) async {
      final repository = _EmailRecoveryRepository();
      final app = AppController(repository);
      await tester.pumpWidget(
        MaterialApp(
          theme: triviaTheme(),
          home: LoginScreen(app: app),
        ),
      );

      Future<void> tap(String label) async {
        final target = find.text(label).last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await tap('Forgot Password?');
      await enter('Email address', 'tariro@example.net');
      await tap('Send Reset Code');
      expect(repository.contact?.channel, LoginChannel.email);
      expect(find.textContaining('Resend code in'), findsOneWidget);
      await enter('Verification code', '123456');
      await tap('Verify Code');
      expect(find.text('Invalid or expired verification.'), findsOneWidget);
      expect(find.text('Reset Password'), findsNothing);
      await enter('Verification code', '184306');
      await tap('Verify Code');
      await enter('New password', 'A9!nest7');
      await enter('Confirm New Password', 'A9!nest7');
      await tap('Reset Password');
      expect(repository.usedAuthorization, 'issued-reset-authorization');
      expect(find.text('Password Reset Successful!'), findsOneWidget);
      await tap('Back to Login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.session, isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );

  testWidgets('Verified signup signs in and dismisses authentication', (
    tester,
  ) async {
    final repository = _EmailSignupRepository(verificationRequired: true);
    final app = AppController(repository);
    addTearDown(app.dispose);
    await withClock(tester.binding.clock, () async {
      await _startEmailSignup(tester, app);
      expect(find.textContaining('tariro@example.net'), findsOneWidget);
      expect(find.textContaining('expires in five minutes'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
      final verify = find.widgetWithText(FilledButton, 'Verify email');
      await _enterAuthField(tester, 'Verification code', '123456');
      await _tapAuthButton(tester, verify);
      expect(
        find.textContaining('incorrect, expired, or out of attempts'),
        findsOneWidget,
      );
      expect(repository.loginAttempts, 0);
      await _enterAuthField(tester, 'Verification code', '004219');
      await _tapAuthButton(tester, verify);
      expect(repository.verified, isTrue);
      expect(repository.loginAttempts, 1);
      expect(app.session?.email, 'tariro@example.net');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Start signup'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'Email OTP expires and resend respects local and server cooldowns',
    (tester) async {
      final repository = _EmailSignupRepository(verificationRequired: true);
      final app = AppController(repository);
      addTearDown(app.dispose);
      await withClock(tester.binding.clock, () async {
        await _startEmailSignup(tester, app);
        await _enterAuthField(tester, 'Verification code', '004219');
        final countdown = find.widgetWithText(TextButton, 'Resend code in 60s');
        expect(tester.widget<TextButton>(countdown).onPressed, isNull);
        await tester.pump(const Duration(minutes: 5));
        expect(
          find.text('This code has expired. Request a new one.'),
          findsOneWidget,
        );
        final verify = find.widgetWithText(FilledButton, 'Verify email');
        expect(tester.widget<FilledButton>(verify).onPressed, isNull);
        expect(repository.verificationAttempts, 0);

        final resend = find.widgetWithText(TextButton, 'Resend Code');
        repository.resendError = _emailThrottle('90');
        await _tapAuthButton(tester, resend);
        expect(repository.resends, 1);
        expect(find.textContaining('Too many requests.'), findsOneWidget);
        expect(find.text('Resend code in 90s'), findsOneWidget);
        await tester.pump(const Duration(seconds: 90));

        repository.resendError = null;
        await _tapAuthButton(tester, resend);
        expect(repository.resends, 2);
        expect(
          find.text('This code has expired. Request a new one.'),
          findsNothing,
        );
        expect(find.text('004219'), findsNothing);
        expect(find.text('Resend code in 60s'), findsOneWidget);
        await _enterAuthField(tester, 'Verification code', '004219');
        repository.verifyError = _emailThrottle('30');
        await _tapAuthButton(tester, verify);
        expect(repository.verificationAttempts, 1);
        final limited = find.widgetWithText(FilledButton, 'Try again in 30s');
        expect(tester.widget<FilledButton>(limited).onPressed, isNull);
        await tester.pump(const Duration(seconds: 30));
        expect(tester.widget<FilledButton>(verify).onPressed, isNotNull);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets(
    'Sign-in failure after email verification opens login without the password',
    (tester) async {
      final repository = _EmailSignupRepository(verificationRequired: true)
        ..failLogin = true;
      final app = AppController(repository);
      addTearDown(app.dispose);
      await _startEmailSignup(tester, app);
      await _enterAuthField(tester, 'Verification code', '004219');
      await _tapAuthButton(
        tester,
        find.widgetWithText(FilledButton, 'Verify email'),
      );
      expect(repository.verificationAttempts, 1);
      expect(repository.loginAttempts, 1);
      expect(app.session, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.textContaining('Email verified. Sign in to continue.'),
        findsOneWidget,
      );
      expect(find.text('tariro@example.net'), findsOneWidget);
      final password = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Password'),
      );
      expect(password.controller?.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Pending email login resumes verification and dismisses both screens',
    (tester) async {
      final repository = _EmailSignupRepository(verificationRequired: true);
      final app = AppController(repository);
      addTearDown(app.dispose);
      const email = 'tariro@example.net';
      const password = 'Horizon-Teak-Glass-187';
      await repository.register(
        firstName: 'Tariro',
        lastName: 'Moyo',
        email: email,
        password: password,
        confirmation: password,
      );
      await _openAuthScreen(
        tester,
        LoginScreen(app: app, registeredEmail: email),
      );
      await _enterAuthField(tester, 'Password', password);
      await _tapAuthButton(tester, find.widgetWithText(FilledButton, 'Log In'));
      expect(repository.loginAttempts, 1);
      expect(find.textContaining('Enter the code for $email'), findsOneWidget);
      await _enterAuthField(tester, 'Verification code', '004219');
      await _tapAuthButton(
        tester,
        find.widgetWithText(FilledButton, 'Verify email'),
      );
      expect(repository.loginAttempts, 2);
      expect(app.session?.email, email);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Start signup'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Onboarding swipes and persists completion', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(TestRepository());
    await app.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: Onboarding(app: app),
      ),
    );
    expect(find.text('Move Freely.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your Fare.\nYour Choice.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(app.onboarded, isTrue);
    final reopened = AppController(TestRepository());
    await reopened.initialize();
    expect(reopened.onboarded, isTrue);
    reopened.dispose();
    app.dispose();
  });
  testWidgets('Phone validation rejects incomplete Zimbabwe number', (
    tester,
  ) async {
    final app = AppController(TestRepository());
    await tester.pumpWidget(
      MaterialApp(
        theme: triviaTheme(),
        home: AuthScreen(app: app),
      ),
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a 9-digit Zimbabwean number.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0, 1100.0]) {
    testWidgets('Registration layout and links at $width logical pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final app = AppController(TestRepository());
      await tester.pumpWidget(
        MaterialApp(
          theme: triviaTheme(),
          home: AuthScreen(app: app),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Image>(find.byType(Image)).first.semanticLabel,
        'Trivia',
      );
      expect(find.byType(Image), findsNWidgets(3));
      final phone = find.widgetWithText(TextFormField, 'Phone number');
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '0771234567');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Please acknowledge'), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      for (final label in ['Terms & Conditions', 'Privacy Policy']) {
        final link = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(BackButton), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      final login = find.widgetWithText(TextButton, 'Log in');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
  testWidgets(
    'Passenger home stays usable on a small phone with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(TestRepository());
      await app.verify('+263771234567', '123456');
      await app.updateProfile('Tariro', 'Test', '');
      await tester.pumpWidget(
        MaterialApp(
          theme: triviaTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
              size: Size(320, 640),
            ),
            child: Scaffold(body: PassengerHome(app: app)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Where to, Tariro?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
