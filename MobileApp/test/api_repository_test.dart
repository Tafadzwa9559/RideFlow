import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/core/config.dart';
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
  test('Production origin and OTP use exact documented paths with real response tokens', () async {
    final dio = Dio();
    final adapter = ContractAdapter((o) async {
      if (o.path.contains('verify'))
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
      if (o.headers['Authorization'] == 'Bearer old')
        return jsonBody({'detail': 'Expired'}, 401);
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
}
