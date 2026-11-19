import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../shared/models.dart';
import 'config.dart';

enum LoginChannel { phone, email }

class LoginContact {
  const LoginContact(this.channel, this.identifier, {this.passengerTesting = false});
  final LoginChannel channel;
  final String identifier;
  final bool passengerTesting;

  Map<String, dynamic> toJson() => {
    'channel': passengerTesting ? 'username' : channel.name,
    'identifier': identifier,
  };
}

abstract class TriviaRepository {
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmation,
  });
  Future<Session> login(LoginContact contact, String password);
  Future<void> requestPasswordRecovery(LoginContact contact);
  Future<String> verifyPasswordRecovery(LoginContact contact, String code);
  Future<void> resetPassword(String token, String password, String confirmation);
  Future<void> changePassword(String current, String password, String confirmation);
  Future<Session?> restore();
  Future<void> requestOtp(String phone);
  Future<Session> verifyOtp(
    String phone,
    String code, {
    Map<String, dynamic>? legalAcknowledgement,
  });
  Future<Session> profile(String first, String last, String email);
  Future<void> logout();
  Future<List<Place>> search(String query);
  Future<RouteQuote?> quote(
    Place pickup,
    Place destination,
    String category, {
    String currency = 'USD',
  });
  Future<List<Ride>> history();
  Future<Ride?> activeRide();
  Future<Ride> request(
    Place pickup,
    Place destination,
    String category,
    int cents, {
    String? paymentMethod,
    String currency = 'USD',
    String? quoteId,
    String? requestKey,
    String? paymentPreference,
    String? passengerNote,
  });
  Future<List<DriverOffer>> offers(String rideId);
  Future<Ride> accept(String rideId, String offerId);
  Future<Ride> transition(String rideId, RideStatus status);
  Future<DriverStatus> applyDriver(
    Map<String, dynamic> fields,
    Map<String, String> documents,
  );
  Future<void> availability(bool online);
  Future<List<Ride>> requests();
  Future<void> counteroffer(String rideId, int cents);
  Future<Map<String, dynamic>> read(String resource);
  Future<void> write(String resource, Map<String, dynamic> data);
}

/// Backend API access with secure token storage and rotating access tokens.
class ApiRepository implements TriviaRepository {
  ApiRepository({Dio? client, FlutterSecureStorage? tokenStorage})
    : storage = tokenStorage ?? const FlutterSecureStorage() {
    dio = client ?? Dio();
    dio.options = BaseOptions(
      baseUrl: '${AppConfig.api.replaceFirst(RegExp(r'/+$'), '')}/api/v1/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final origin = Uri.parse(AppConfig.api);
          if (options.uri.host != origin.host ||
              options.uri.scheme != origin.scheme ||
              options.uri.port != origin.port ||
              !options.uri.path.startsWith('/api/v1/')) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: StateError('Untrusted API URL.'),
              ),
            );
            return;
          }
          try {
            final token = await storage.read(key: 'access');
            if (token != null && !_isPublicAuth(options.path)) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.extra['retry'] == true) {
            await clearSession();
          }
          if (error.response?.statusCode != 401 ||
              request.extra['retry'] == true ||
              _isPublicAuth(request.path)) {
            handler.next(error);
            return;
          }
          try {
            final current = await storage.read(key: 'access');
            if (current == null ||
                request.headers['Authorization'] == 'Bearer $current') {
              await refreshAccess();
            }
            request.extra['retry'] = true;
            if (request.data is FormData) {
              request.data = (request.data as FormData).clone();
            }
            handler.resolve(await dio.fetch<dynamic>(request));
          } catch (failure) {
            if (failure is DioException &&
                failure.response?.statusCode == 401) {
              await clearSession();
            }
            handler.next(failure is DioException ? failure : error);
          }
        },
      ),
    );
  }
  static bool _isPublicAuth(String path) =>
      path.startsWith('auth/otp/') ||
      path == 'auth/password/request/' ||
      path == 'auth/password/verify/' ||
      path == 'auth/password/reset/' ||
      path == 'auth/login/' ||
      path == 'auth/register/' ||
      path == 'auth/passenger-testing/' ||
      path == 'auth/token/refresh/';

  late final Dio dio;
  final FlutterSecureStorage storage;
  final expired = StreamController<void>.broadcast();
  Future<void>? _refreshing;
  Future<void> clearSession() async {
    await storage.delete(key: 'access');
    await storage.delete(key: 'refresh');
    if (!expired.isClosed) expired.add(null);
  }

  Future<void> refreshAccess() async {
    if (_refreshing != null) return _refreshing!;
    final pending = _rotate();
    _refreshing = pending;
    try {
      await pending;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _rotate() async {
    final refresh = await storage.read(key: 'refresh');
    if (refresh == null) {
      await clearSession();
      throw DioException(
        requestOptions: RequestOptions(path: 'auth/token/refresh/'),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      );
    }
    final data = await _post('auth/token/refresh/', {'refresh': refresh});
    await storage.write(key: 'access', value: data['access'] as String);
    final rotatedRefresh = data['refresh'] as String?;
    if (rotatedRefresh != null) {
      await storage.write(key: 'refresh', value: rotatedRefresh);
    }
  }

  Future<String> accessToken() async {
    var token = await storage.read(key: 'access');
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(token!.split('.')[1])),
        ),
      ) as Map;
      if ((payload['exp'] as num) * 1000 <=
          DateTime.now().millisecondsSinceEpoch + 30000) {
        await refreshAccess();
        token = await storage.read(key: 'access');
      }
    } catch (error) {
      if (error is DioException) rethrow;
      await refreshAccess();
      token = await storage.read(key: 'access');
    }
    if (token == null) throw StateError('Sign in to continue.');
    return token;
  }

  Future<Map<String, dynamic>> _get(String path) async =>
      (await dio.get<Map<String, dynamic>>(path)).data!;
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async =>
      (await dio.post<Map<String, dynamic>>(path, data: body)).data ??
      <String, dynamic>{};
  @override
  Future<Session?> restore() async {
    if (await storage.read(key: 'access') == null) return null;
    try {
      return Session.fromJson(await _get('users/me/'));
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await clearSession();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmation,
  }) async {
    await _post('auth/register/', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'password_confirmation': confirmation,
    });
  }

  @override
  Future<Session> login(LoginContact contact, String password) async {
    if (contact.passengerTesting && !passengerTestingEnabled) {
      throw StateError('Passenger testing requires the configured staging origin.');
    }
    final data = await _post(contact.passengerTesting ? 'auth/passenger-testing/' : 'auth/login/', {
      ...contact.toJson(),
      'password': password,
    });
    final session = Session.fromJson(data['user'] as Map<String, dynamic>);
    await storage.write(key: 'refresh', value: data['refresh'] as String);
    try {
      await storage.write(key: 'access', value: data['access'] as String);
    } catch (_) {
      await storage.delete(key: 'refresh');
      rethrow;
    }
    return session;
  }

  @override
  Future<void> requestPasswordRecovery(LoginContact contact) async {
    await _post('auth/password/request/', contact.toJson());
  }

  @override
  Future<String> verifyPasswordRecovery(
    LoginContact contact,
    String code,
  ) async {
    final data = await _post('auth/password/verify/', {
      ...contact.toJson(),
      'code': code,
    });
    return data['token'] as String;
  }

  @override
  Future<void> resetPassword(String token, String password, String confirmation) async {
    await _post('auth/password/reset/', {
      'token': token,
      'password': password,
      'password_confirmation': confirmation,
    });
  }

  @override
  Future<void> changePassword(String current, String password, String confirmation) async {
    await _post('auth/password/change/', {
      'current_password': current,
      'password': password,
      'password_confirmation': confirmation,
    });
    await clearSession();
  }

  @override
  Future<void> requestOtp(String phone) async {
    await _post('auth/otp/request/', {'phone': phone});
  }

  @override
  Future<Session> verifyOtp(
    String phone,
    String code, {
    Map<String, dynamic>? legalAcknowledgement,
  }) async {
    final payload = <String, dynamic>{
      'phone': phone,
      'code': code,
      ...?legalAcknowledgement == null
          ? null
          : {'legal_acknowledgement': legalAcknowledgement},
    };
    final j = await _post('auth/otp/verify/', payload);
    await storage.write(key: 'access', value: j['access'] as String);
    final refresh = j['refresh'] as String?;
    switch (refresh) {
      case String value:
        await storage.write(key: 'refresh', value: value);
      case null:
        break;
    }
    return Session.fromJson(j['user'] as Map<String, dynamic>);
  }

  @override
  Future<Session> profile(String first, String last, String email) async =>
      Session.fromJson(
        await _patch('users/me/', {
          'first_name': first,
          'last_name': last,
          'email': email,
        }),
      );
  @override
  Future<void> logout() async {
    try {
      await _post('auth/logout/', {});
    } finally {
      await clearSession();
    }
  }

  @override
  Future<List<Place>> search(String query) async =>
      ((await dio.get<Map<String, dynamic>>(
                'places/',
                queryParameters: {'q': query},
              )).data!['results']
              as List)
          .map((j) => Place.fromJson(j as Map<String, dynamic>))
          .toList();
  @override
  Future<RouteQuote?> quote(
    Place pickup,
    Place destination,
    String category, {
    String currency = 'USD',
  }) async => RouteQuote.fromJson(
    await _post('fares/estimate/', {
      'pickup': pickup.toJson(),
      'destination': destination.toJson(),
      'category': category,
      'currency': currency,
    }),
  );
  String? historyNext;
  @override
  Future<List<Ride>> history() async {
    final data = await _get('rides/');
    historyNext = data['next'] as String?;
    return (data['results'] as List)
        .map((j) => Ride.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  @override
  Future<Ride?> activeRide() async {
    final j = await _get('rides/active/');
    if (j['ride'] == null) return null;
    final ride = Map<String, dynamic>.from(j['ride'] as Map);
    final tracking = await _get('rides/${ride['id']}/tracking/');
    if (tracking['location'] is Map) {
      final location = Map<String, dynamic>.from(tracking['location'] as Map);
      ride['driver_location'] = {
        'name': 'Assigned driver',
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      };
      ride['location_updated_at'] = location['created_at'];
    }
    return Ride.fromJson(ride);
  }

  @override
  Future<Ride> request(
    Place pickup,
    Place destination,
    String category,
    int cents, {
    String? paymentMethod,
    String currency = 'USD',
    String? quoteId,
    String? requestKey,
    String? paymentPreference,
    String? passengerNote,
  }) async => Ride.fromJson(
    await _post('rides/', {
      'pickup': pickup.toJson(),
      'destination': destination.toJson(),
      'category': category,
      'fare_cents': cents,
      'payment_method_id': paymentMethod,
      'currency': currency,
      'quote_id': quoteId,
      'idempotency_key': requestKey,
      'payment_preference': paymentPreference,
      'passenger_note': passengerNote,
    }),
  );
  @override
  Future<List<DriverOffer>> offers(String rideId) async =>
      ((await _get('rides/$rideId/offers/'))['results'] as List)
          .map((j) => DriverOffer.fromJson(j as Map<String, dynamic>))
          .toList();
  @override
  Future<Ride> accept(String rideId, String offerId) async => Ride.fromJson(
    await _post('rides/$rideId/accept/', {'offer_id': offerId}),
  );
  @override
  Future<Ride> transition(String rideId, RideStatus status) async =>
      Ride.fromJson(
        await _post('rides/$rideId/status/', {'status': status.name}),
      );
  @override
  Future<DriverStatus> applyDriver(
    Map<String, dynamic> fields,
    Map<String, String> documents,
  ) async {
    final f = Map<String, dynamic>.from(fields['fields'] as Map? ?? fields);
    await _patch('users/me/', {
      'first_name': f['firstName'],
      'last_name': f['lastName'],
      'email': f['email'] ?? '',
    });
    await _patch('drivers/applications/me/', {
      'legal_name': '${f['firstName']} ${f['lastName']}',
      'licence_number': f['licenceNumber'],
      'licence_class': f['licenceClass'],
      'licence_expires': f['licenceExpiry'],
      'vehicle': {
        'make': f['make'],
        'model': f['model'],
        'year': int.parse('${f['year']}'),
        'colour': f['colour'],
        'registration': f['registration'],
        'capacity': int.parse('${f['seats']}'),
        'category': f['category'],
      },
    });
    final requirements =
        (await _get('drivers/document-requirements/'))['results'] as List;
    final vehicles = (await _get('drivers/me/vehicles/'))['results'] as List;
    for (final entry in documents.entries) {
      final requirement = requirements.cast<Map>().firstWhere(
        (r) => r['code'] == entry.key,
      );
      final vehicleScope = requirement['scope'] == 'vehicle';
      final path = vehicleScope
          ? 'drivers/me/vehicles/${vehicles.cast<Map>().firstWhere((v) => v['registration'] == '${f['registration']}'.toUpperCase())['id']}/documents/'
          : 'drivers/applications/me/documents/';
      final expiry = fields['expiry_${entry.key}'];
      if (requirement['expiry_required'] == true &&
          (expiry == null || '$expiry'.isEmpty)) {
        throw StateError('Enter an expiry date for ${requirement['label']}.');
      }
      await dio.post<dynamic>(
        path,
        data: FormData.fromMap({
          'requirement': entry.key,
          'file': await MultipartFile.fromFile(entry.value),
          if (expiry != null && '$expiry'.isNotEmpty) 'expires_on': expiry,
        }),
      );
    }
    final j = await _post('drivers/applications/me/submit/', {});
    return DriverStatus.values.byName(j['status'] as String);
  }

  @override
  Future<void> availability(bool online) async {
    await _post('driver/availability/', {'online': online});
  }

  @override
  Future<List<Ride>> requests() async =>
      ((await _get('driver/requests/'))['results'] as List)
          .map((j) => Ride.fromJson(j as Map<String, dynamic>))
          .toList();
  @override
  Future<void> counteroffer(String rideId, int cents) async {
    await _post('rides/$rideId/offers/', {'fare_cents': cents});
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async => (await dio.patch<Map<String, dynamic>>(path, data: body)).data!;
  String resourcePath(String resource) {
    if (resource == 'me/deletion-request') {
      throw UnsupportedError(
        'Account deletion requests are not supported by the documented API. Contact support.',
      );
    }
    if (resource == 'me/preferences') return 'users/me/preferences';
    if (resource == 'safety/contacts') return 'users/me/emergency-contacts';
    if (resource == 'driver/requirements') {
      return 'drivers/document-requirements';
    }
    if (resource.startsWith('driver/earnings')) {
      return resource.replaceFirst('driver/earnings', 'drivers/me/earnings');
    }
    return resource;
  }

  @override
  Future<Map<String, dynamic>> read(String resource) async {
    final uri = Uri.parse(resourcePath(resource));
    final value = await _get(
      uri.hasScheme
          ? uri.toString()
          : '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/${uri.hasQuery ? '?${uri.query}' : ''}',
    );
    if (value['results'] is List) {
      value['items'] = value['results'];
    }
    return value;
  }

  @override
  Future<void> write(String resource, Map<String, dynamic> data) async {
    if (resource == 'me/preferences') {
      await _patch('users/me/preferences/', {
        'push_notifications': data['trip_notifications'],
      });
      return;
    }
    if (resource == 'safety/contacts') {
      data = {'name': data['name'], 'phone': data['message']};
    }
    if (resource == 'support/tickets' || resource == 'safety/incidents') {
      data = {
        'message': data['message'],
        'category': resource == 'safety/incidents' ? 'safety' : 'support',
      };
      resource = 'support/tickets';
    }
    if (resource.endsWith('/review')) {
      resource = resource.replaceFirst('/review', '/ratings');
      data = {'score': data['rating'], 'comment': data['message']};
    }
    if (resource.endsWith('/dispute')) {
      resource = resource.replaceFirst('/dispute', '/report');
    }
    await _post(
      '${resourcePath(resource).replaceFirst(RegExp(r'/+$'), '')}/',
      data,
    );
  }

  void dispose() {
    dio.close(force: true);
    expired.close();
  }
}
