import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/core/config.dart';
import 'package:rideflow_mobile/app/controller.dart';
import 'package:rideflow_mobile/core/repository.dart';
import 'package:rideflow_mobile/shared/models.dart';

class ContractAdapter implements HttpClientAdapter {
  ContractAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Location search uses the canonical path and accepts both place shapes', () async {
    final dio = Dio();
    final adapter = ContractAdapter((options) async => jsonBody({
      'results': [
        {
          'name': 'Avondale',
          'formatted_address': 'Avondale, Harare, Zimbabwe',
          'latitude': -17.8,
          'longitude': 31.03,
        },
        {'name': 'Harare', 'latitude': '-17.82', 'longitude': '31.05'},
      ],
    }));
    dio.httpClientAdapter = adapter;
    final repo = ApiRepository(client: dio);
    addTearDown(repo.dispose);

    expect(await repo.search('  '), isEmpty);
    expect(adapter.calls, isEmpty);
    final places = await repo.search('  Avon ');
    expect(adapter.calls.single.uri.path, '/api/v1/locations/search/');
    expect(adapter.calls.single.queryParameters, {'q': 'Avon'});
    expect(places.first.formattedAddress, 'Avondale, Harare, Zimbabwe');
    expect(places.last.formattedAddress, isNull);
    expect(places.last.lat, -17.82);
  });

  test('Production origin and OTP use exact documented paths with real response tokens', () async {
    final dio = Dio();
    final adapter = ContractAdapter((o) async {
      if (o.path.contains('verify')) {
        return jsonBody({
          'access': 'server-access',
          'refresh': 'server-refresh',
          'user': {
            'phone': '+263771234567',
            'first_name': '',
            'last_name': '',
            'driver_status': 'notRegistered',
          },
        });
      }
      return jsonBody({'detail': 'Verification code requested.'}, 202);
    });
    dio.httpClientAdapter = adapter;
    final repo = ApiRepository(client: dio);
    addTearDown(repo.dispose);
    expect(AppConfig.api, 'https://trivia-backend-bze2.onrender.com');
    await repo.requestOtp('+263771234567');
    final user = await repo.verifyOtp('+263771234567', '654321');
    expect(user.driverStatus, DriverStatus.notRegistered);
    expect(adapter.calls.first.uri.path, '/api/v1/auth/otp/request/');
    expect(await repo.storage.read(key: 'access'), 'server-access');
    expect(adapter.calls.last.data['code'], '654321');
  });
  test('Email registration submits passenger fields before secure login', () async {
    const email = 'tariro@example.net';
    const password = 'Horizon-Teak-Glass-187';
    final dio = Dio();
    final adapter = ContractAdapter((options) async {
      expect(options.headers['Authorization'], isNull);
      switch (options.path) {
        case 'auth/register/':
          expect(options.method, 'POST');
          expect(options.data, {
            'first_name': 'Tariro',
            'last_name': 'Moyo',
            'email': email,
            'password': password,
            'password_confirmation': password,
          });
          return jsonBody({'email': email, 'email_verified': false}, 201);
        case 'auth/login/':
          expect(options.data, {
            'channel': 'email',
            'identifier': email,
            'password': password,
          });
          return jsonBody({
            'access': 'passenger-access',
            'refresh': 'passenger-refresh',
            'user': {'phone': '', 'email': email, 'first_name': 'Tariro'},
          });
      }
      fail('Unexpected path: ${options.path}');
    });
    dio.httpClientAdapter = adapter;
    final repository = ApiRepository(client: dio);
    addTearDown(repository.dispose);
    await repository.register(
      firstName: 'Tariro',
      lastName: 'Moyo',
      email: email,
      password: password,
      confirmation: password,
    );
    expect(await repository.storage.read(key: 'access'), isNull);
    final session = await repository.login(
      const LoginContact(LoginChannel.email, email),
      password,
    );
    expect(session.driverStatus, DriverStatus.notRegistered);
    expect(session.email, email);
    expect(await repository.storage.read(key: 'access'), 'passenger-access');
    expect(await repository.storage.read(key: 'refresh'), 'passenger-refresh');
    expect(adapter.calls.map((call) => call.path), [
      'auth/register/',
      'auth/login/',
    ]);
  });

  test('Password login stores backend tokens and recovery stays public', () async {
    const contact = LoginContact(LoginChannel.email, 'user@example.net');
    final dio = Dio();
    final adapter = ContractAdapter((options) async {
      switch (options.path) {
        case 'auth/login/':
          expect(options.data, {...contact.toJson(), 'password': 'test-password'});
          return jsonBody({
            'access': 'access',
            'refresh': 'refresh',
            'user': {
              'phone': '+263771234567',
              'first_name': 'Rudo',
              'driver_status': 'approved',
            },
          });
        case 'auth/password/request/':
          expect(options.data, contact.toJson());
          return jsonBody({}, 202);
        case 'auth/password/verify/':
          expect(options.data, {...contact.toJson(), 'code': 'test-code'});
          return jsonBody({'token': 'reset-token'});
        case 'auth/password/reset/':
          expect(options.data, {'token': 'reset-token', 'password': 'new-password', 'password_confirmation': 'new-password'});
          return ResponseBody.fromString('', 204);
      }
      fail('Unexpected path: ${options.path}');
    });
    dio.httpClientAdapter = adapter;
    final repository = ApiRepository(client: dio);
    addTearDown(repository.dispose);

    final session = await repository.login(contact, 'test-password');
    expect(session.driverStatus, DriverStatus.approved);
    expect(await repository.storage.read(key: 'access'), 'access');
    expect(await repository.storage.read(key: 'refresh'), 'refresh');
    await repository.requestPasswordRecovery(contact);
    final proof = await repository.verifyPasswordRecovery(contact, 'test-code');
    await repository.resetPassword(proof, 'new-password', 'new-password');
    for (final call in adapter.calls) {
      expect(call.headers['Authorization'], isNull);
    }
  });

  test('Invalid credentials and timeouts never trigger auth retries', () async {
    const contact = LoginContact(LoginChannel.phone, '+263771234567');
    final dio = Dio();
    var offline = false;
    final adapter = ContractAdapter((options) async {
      if (offline) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      }
      return jsonBody({'detail': 'Invalid credentials'}, 401);
    });
    dio.httpClientAdapter = adapter;
    final repository = ApiRepository(client: dio);
    addTearDown(repository.dispose);

    await expectLater(repository.login(contact, 'bad-password'), throwsA(isA<DioException>()));
    expect(adapter.calls.single.path, 'auth/login/');
    offline = true;
    await expectLater(repository.requestPasswordRecovery(contact), throwsA(isA<DioException>()));
    expect(adapter.calls.length, 2);
    expect(await repository.storage.read(key: 'access'), isNull);
  });

  test('Concurrent 401s share one refresh and replay with the rotated access token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access': 'old',
      'refresh': 'server-refresh',
    });
    var refreshes = 0;
    final dio = Dio();
    dio.httpClientAdapter = ContractAdapter((o) async {
      if (o.path.contains('token/refresh')) {
        refreshes++;
        return jsonBody({'access': 'new', 'refresh': 'rotated'});
      }
      if (o.headers['Authorization'] == 'Bearer old') {
        return jsonBody({'detail': 'Expired'}, 401);
      }
      return jsonBody({'results': [], 'next': null});
    });
    final repo = ApiRepository(client: dio);
    addTearDown(repo.dispose);
    await Future.wait([repo.read('notifications'), repo.read('rides')]);
    expect(refreshes, 1);
    expect(await repo.storage.read(key: 'refresh'), 'rotated');
  });
  test(
    'Revoked refresh clears credentials; network errors retain them',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'access': 'old',
        'refresh': 'old-refresh',
      });
      final dio = Dio();
      dio.httpClientAdapter = ContractAdapter(
        (o) async => jsonBody({'detail': 'Invalid token'}, 401),
      );
      final repo = ApiRepository(client: dio);
      addTearDown(repo.dispose);
      expect(await repo.restore(), isNull);
      expect(await repo.storage.read(key: 'refresh'), isNull);
    },
  );
  test('Empty history stays empty and pagination origin cannot leak bearer credentials', () async {
    FlutterSecureStorage.setMockInitialValues({'access': 'server-access'});
    final dio = Dio();
    final adapter = ContractAdapter(
      (o) async => jsonBody({'results': [], 'next': null}),
    );
    dio.httpClientAdapter = adapter;
    final repo = ApiRepository(client: dio);
    addTearDown(repo.dispose);
    expect(await repo.history(), isEmpty);
    await expectLater(
      repo.read('https://untrusted.invalid/api/v1/rides/'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls.length, 1);
  });
  test('Network failure preserves stored credentials', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access': 'saved-access',
      'refresh': 'saved-refresh',
    });
    final dio = Dio();
    dio.httpClientAdapter = ContractAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final repo = ApiRepository(client: dio);
    addTearDown(repo.dispose);
    await expectLater(repo.restore(), throwsA(isA<DioException>()));
    expect(await repo.storage.read(key: 'refresh'), 'saved-refresh');
  });
  test(
    'Logout accepts HTTP 204 and revokes through the documented endpoint',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'access': 'access',
        'refresh': 'refresh',
      });
      final dio = Dio();
      final adapter = ContractAdapter(
        (options) async => ResponseBody.fromString('', 204),
      );
      dio.httpClientAdapter = adapter;
      final repo = ApiRepository(client: dio);
      addTearDown(repo.dispose);
      await repo.logout();
      expect(adapter.calls.single.uri.path, '/api/v1/auth/logout/');
      expect(await repo.storage.read(key: 'access'), isNull);
      expect(await repo.storage.read(key: 'refresh'), isNull);
    },
  );
  test('Road fares are parsed from backend; expired rides are terminal and decimal GPS is accepted', () {
    expect(
      Place.fromJson({
        'name': 'Actual GPS',
        'latitude': '-17.8',
        'longitude': '31.0',
      }).lat,
      -17.8,
    );
    final quote = RouteQuote.fromJson({
      'id': 'server-quote',
      'geometry': [
        [31, -17.8],
        [31.1, -17.9],
      ],
      'distance_metres': 7000,
      'duration_seconds': 900,
      'service_available': true,
      'minimum_fare_cents': 300,
      'suggested_fare_cents': 650,
    });
    expect(quote.suggestedCents, 650);
    expect(quote.valid, isTrue);
    final ride = Ride.fromJson({
      'id': 'real-ride',
      'pickup': {'name': 'A', 'latitude': -17.8, 'longitude': 31},
      'destination': {'name': 'B', 'latitude': -17.9, 'longitude': 31.1},
      'fare_cents': 650,
      'category': 'Standard',
      'status': 'expired',
      'created_at': '2026-11-16T10:00:00Z',
    });
    expect(ride.active, isFalse);
  });
  test(
    'Driver availability and empty history reconcile from the backend',
    () async {
      FlutterSecureStorage.setMockInitialValues({'access': 'access'});
      final dio = Dio();
      dio.httpClientAdapter = ContractAdapter((options) async {
        if (options.path == 'users/me/') {
          return jsonBody({
            'phone': '+263771234567',
            'driver_status': 'approved',
          });
        }
        if (options.path == 'rides/active/') return jsonBody({'ride': null});
        if (options.path.contains('availability')) {
          return jsonBody({'status': 'offline'});
        }
        return jsonBody({'results': [], 'next': null});
      });
      final repo = ApiRepository(client: dio);
      final app = AppController(repo);
      addTearDown(app.dispose);
      app.session = const Session(
        firstName: '',
        lastName: '',
        phone: '+263771234567',
        driverStatus: DriverStatus.approved,
      );
      app.online = true;
      await app.sync();
      expect(app.online, isFalse);
      expect(app.ride, isNull);
      expect(app.history, isEmpty);
    },
  );
}
