import 'support/fixture_repository.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideflow_mobile/features/passenger/home.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/app/theme.dart';
import 'package:rideflow_mobile/features/entry/entry.dart';

class _UnavailableRecoveryRepository extends TestRepository {
  LoginContact? requestedContact;

  @override
  Future<void> requestPasswordRecovery(LoginContact contact) async {
    requestedContact = contact;
    throw UnsupportedError('SMS password recovery is currently unavailable.');
  }
}

class _EmailSignupRepository extends TestRepository {
  final submissions = <List<String>>[];

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmation,
  }) async {
    submissions.add([firstName, lastName, email, password]);
  }
}

class _EmailRecoveryRepository extends TestRepository {
  LoginContact? contact;
  String? usedAuthorization;

  @override
  Future<void> requestPasswordRecovery(LoginContact contact) async {
    this.contact = contact;
  }

  @override
  Future<String> verifyPasswordRecovery(LoginContact contact, String code) async {
    if (code != '184306') throw const FormatException('Invalid or expired verification.');
    return 'issued-reset-authorization';
  }

  @override
  Future<void> resetPassword(String token, String password, String confirmation) async {
    if (password != confirmation) throw const FormatException('The passwords must match.');
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
      MaterialApp(theme: triviaTheme(), home: LoginScreen(app: app)),
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
    expect(find.text('SMS password recovery is currently unavailable.'), findsOneWidget);
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
      MaterialApp(theme: triviaTheme(), home: AuthScreen(app: app)),
    );
    Future<void> tap(String label) async {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.tap(target);
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
    await tap('Create account');
    expect(find.text('The passwords must match.'), findsOneWidget);
    expect(repository.submissions, isEmpty);

    await enter('Confirm password', password);
    await tap('Create account');
    expect(repository.submissions.single, ['Tariro', 'Moyo', email, password]);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(app.session, isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('Email recovery verifies a code before resetting and returns to login', (
    tester,
  ) async {
    final repository = _EmailRecoveryRepository();
    final app = AppController(repository);
    await tester.pumpWidget(MaterialApp(theme: triviaTheme(), home: LoginScreen(app: app)));

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
  });

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
