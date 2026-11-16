import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../shared/models.dart';
import 'config.dart';

abstract class TriviaRepository {
  Future<Session?> restore();
  Future<void> requestOtp(String phone);
  Future<Session> verifyOtp(String phone, String code);
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

class DemoRepository implements TriviaRepository {
  Session? _session;
  final registrationStorage = const FlutterSecureStorage();
  Map<String, dynamic> registration = {};
  Future<void> saveRegistration(
    Map<String, dynamic> data,
    DriverStatus status,
  ) async {
    if (_session == null) throw StateError('Sign in first.');
    registration = {...data, 'status': status.name};
    await registrationStorage.write(
      key: 'trivia_driver_${_session!.phone}',
      value: jsonEncode(registration),
    );
    _session = Session(
      firstName: _session!.firstName,
      lastName: _session!.lastName,
      phone: _session!.phone,
      driverStatus: status,
    );
  }

  final List<Ride> _rides = [];
  bool online = false;
  final Map<String, DriverOffer> _localOffers = {};
  @override
  Future<Session?> restore() async => _session;
  @override
  Future<void> requestOtp(String phone) async {}
  @override
  Future<Session> verifyOtp(String phone, String code) async {
    if (code != '123456') {
      throw StateError('Use the displayed demo code: 123456.');
    }
    final saved = await registrationStorage.read(key: 'trivia_driver_$phone');
    registration = saved == null
        ? {}
        : jsonDecode(saved) as Map<String, dynamic>;
    return _session = Session(
      firstName: '',
      lastName: '',
      phone: phone,
      driverStatus: DriverStatus.values.byName(
        registration['status'] as String? ?? 'notRegistered',
      ),
    );
  }

  @override
  Future<Session> profile(String first, String last, String email) async =>
      _session = Session(
        firstName: first,
        lastName: last,
        phone: _session!.phone,
        driverStatus: _session!.driverStatus,
      );
  @override
  Future<void> logout() async {
    _session = null;
    registration = {};
    _rides.clear();
    _localOffers.clear();
    online = false;
  }

  @override
  Future<List<Place>> search(String query) async => demoPlaces
      .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
      .toList();
  @override
  Future<RouteQuote?> quote(
    Place pickup,
    Place destination,
    String category, {
    String currency = 'USD',
  }) async => RouteQuote(
    id: 'demo-quote-${DateTime.now().microsecondsSinceEpoch}',
    currency: 'USD',
    points: [pickup.point, destination.point],
    metres: 5000,
    seconds: 900,
    available: true,
    minimumCents: 200,
    maximumCents: 10000,
    suggestedCents: category == 'XL'
        ? 900
        : category == 'Comfort'
        ? 700
        : 500,
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );
  @override
  Future<List<Ride>> history() async => _rides.reversed.toList();
  @override
  Future<Ride?> activeRide() async => _rides.where((r) => r.active).firstOrNull;
  Ride _get(String id) => _rides.firstWhere((r) => r.id == id);
  Ride _save(Ride ride) {
    final i = _rides.indexWhere((r) => r.id == ride.id);
    if (i < 0) {
      _rides.add(ride);
    } else {
      _rides[i] = ride;
    }
    return ride;
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
  }) async {
    if (_rides.any((r) => r.active)) {
      throw StateError('Finish or cancel your current demo ride first.');
    }
    if (cents <= 0 || pickup.point == destination.point) {
      throw StateError('Choose different locations and a positive fare.');
    }
    return _save(
      Ride(
        id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
        pickup: pickup,
        destination: destination,
        cents: cents,
        category: category,
        status: RideStatus.searching,
        createdAt: DateTime.now().toUtc(),
        currency: 'USD',
        paymentMethodName: directPaymentLabel(paymentMethod, null),
        offeredCents: cents,
        paymentMethod: paymentMethod,
        paymentStatus: 'pending_cash',
      ),
    );
  }

  @override
  Future<List<DriverOffer>> offers(String rideId) async {
    final ride = _get(rideId);
    if (ride.status != RideStatus.searching) {
      return [];
    }
    return [
      if (_localOffers[rideId] != null) _localOffers[rideId]!,
      DriverOffer(
        id: 'demo-tariro',
        name: 'Tariro · Demo driver',
        vehicle: 'White Toyota Aqua',
        plate: 'DEMO 01',
        cents: ride.cents,
        rating: 4.9,
        minutes: 4,
        verified: false,
      ),
      DriverOffer(
        id: 'demo-tendai',
        name: 'Tendai · Demo driver',
        vehicle: 'Silver Honda Fit',
        plate: 'DEMO 02',
        cents: ride.cents + 100,
        rating: 4.8,
        minutes: 6,
      ),
    ];
  }

  @override
  Future<Ride> accept(String rideId, String offerId) async {
    final ride = _get(rideId);
    if (ride.status != RideStatus.searching) {
      throw StateError('This ride already has a driver.');
    }
    final offer = (await offers(rideId)).firstWhere((o) => o.id == offerId);
    // Recheck after the asynchronous read, so two selections cannot both win.
    if (_get(rideId).status != RideStatus.searching) {
      throw StateError('An offer was already selected.');
    }
    return _save(ride.copy(status: RideStatus.assigned, driver: offer));
  }

  @override
  Future<Ride> transition(String rideId, RideStatus status) async {
    final r = _get(rideId);
    final allowed = <RideStatus, Set<RideStatus>>{
      RideStatus.searching: {RideStatus.cancelled},
      RideStatus.assigned: {RideStatus.arriving, RideStatus.cancelled},
      RideStatus.arriving: {RideStatus.arrived, RideStatus.cancelled},
      RideStatus.arrived: {RideStatus.inProgress, RideStatus.cancelled},
      RideStatus.inProgress: {RideStatus.completed},
    };
    if (!(allowed[r.status]?.contains(status) ?? false)) {
      throw StateError('This trip transition is not allowed.');
    }
    return _save(r.copy(status: status));
  }

  @override
  Future<DriverStatus> applyDriver(
    Map<String, dynamic> fields,
    Map<String, String> documents,
  ) async {
    await saveRegistration({
      'fields': fields,
      'documents': documents,
      'step': 4,
    }, DriverStatus.submitted);
    return DriverStatus.submitted;
  }

  // Explicit developer simulation, never used by the API adapter.
  Future<void> approveSimulation() async {
    if (!kDebugMode ||
        !AppConfig.demo ||
        ![
          DriverStatus.submitted,
          DriverStatus.underReview,
        ].contains(_session?.driverStatus)) {
      throw StateError(
        'Only submitted debug demo applications may be approved.',
      );
    }
    await saveRegistration(registration, DriverStatus.approved);
    _session = Session(
      firstName: _session!.firstName,
      lastName: _session!.lastName,
      phone: _session!.phone,
      driverStatus: DriverStatus.approved,
    );
  }

  @override
  Future<void> availability(bool value) async {
    if (_session?.driverStatus != DriverStatus.approved) {
      throw StateError('Driver approval is required.');
    }
    online = value;
  }

  @override
  Future<List<Ride>> requests() async =>
      online && _session?.driverStatus == DriverStatus.approved
      ? _rides.where((r) => r.status == RideStatus.searching).toList()
      : [];
  @override
  Future<void> counteroffer(String rideId, int cents) async {
    if (!online || cents <= 0 || _get(rideId).status != RideStatus.searching) {
      throw StateError(
        'Go online and choose an open request with a valid fare.',
      );
    }
    _localOffers[rideId] = DriverOffer(
      id: 'demo-self',
      name: 'Local demo driver',
      vehicle: 'Demo Toyota Aqua',
      plate: 'DEMO 03',
      cents: cents,
    );
  }

  int get _demoGross => _rides
      .where(
        (r) => r.driver?.id == 'demo-self' && r.status == RideStatus.completed,
      )
      .fold(0, (sum, r) => sum + r.cents);
  Future<Ride> simulatePassengerSelection(Ride request, int cents) async {
    if (!online || _session?.driverStatus != DriverStatus.approved) {
      throw StateError('Go online as an approved demo driver first.');
    }
    final current = _get(request.id);
    if (current.status != RideStatus.searching) {
      throw StateError('This demo request is no longer available.');
    }
    return _save(
      current.copy(
        status: RideStatus.assigned,
        driver: DriverOffer(
          id: 'demo-self',
          name: 'Local demo driver',
          vehicle: 'Demo Toyota Aqua',
          plate: 'DEMO 03',
          cents: cents,
        ),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> read(String resource) async =>
      switch (resource) {
        'currencies' => {
          'items': [
            {'code': 'USD', 'name': 'United States Dollar', 'symbol': 'US\$'},
          ],
          'default': 'USD',
        },
        'payments/methods' => {
          'items': [
            for (final m in directPaymentMethods)
              {
                'id': m.id,
                'name': m.name,
                'kind': m.kind,
                'currencies': m.currencies,
                'enabled': true,
                'description': m.description,
              },
          ],
        },
        'driver/earnings' => {
          'gross_cents': _demoGross,
          'commission_cents': 0,
          'net_cents': _demoGross,
          'trips': _rides
              .where(
                (r) =>
                    r.driver?.id == 'demo-self' &&
                    r.status == RideStatus.completed,
              )
              .length,
          'payout_status': 'Simulated · No funds',
        },
        'driver/requirements' => {
          'documents': [
            {'key': 'national_id', 'label': 'National identification'},
            {
              'key': 'transport_permission',
              'label': 'Passenger transport permission (demo requirement)',
            },
            {'key': 'licence', 'label': 'Driver’s licence'},
            {'key': 'registration', 'label': 'Vehicle registration'},
            {'key': 'vehicle_photo', 'label': 'Vehicle photograph'},
          ],
        },
        'notifications' => {
          'items': _rides
              .map(
                (r) => {
                  'title': statusLabel(r.status),
                  'description':
                      '${r.pickup.name} → ${r.destination.name} · Demo trip',
                },
              )
              .toList(),
        },
        _ => {'items': <dynamic>[]},
      };
  @override
  Future<void> write(String resource, Map<String, dynamic> data) async {}
}

/// Proposed mobile contract. Enable only against a backend implementing README.md.
class ApiRepository implements TriviaRepository {
  ApiRepository() {
    dio = Dio(
      BaseOptions(
        baseUrl:
            '${(AppConfig.api.isEmpty ? 'https://unconfigured.invalid' : AppConfig.api).replaceFirst(RegExp(r'/+$'), '')}/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await storage.read(key: 'access');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onError: (error, handler) async {
          try {
            if (error.response?.statusCode == 401) {
              try {
                await storage.deleteAll();
              } finally {
                if (!expired.isClosed) {
                  expired.add(null);
                }
              }
            }
          } catch (_) {
            /* Still propagate the original request failure. */
          } finally {
            handler.next(error);
          }
        },
      ),
    );
  }
  late final Dio dio;
  final storage = const FlutterSecureStorage();
  final expired = StreamController<void>.broadcast();
  Future<Map<String, dynamic>> _get(String path) async =>
      (await dio.get<Map<String, dynamic>>(path)).data!;
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async => (await dio.post<Map<String, dynamic>>(path, data: body)).data!;
  @override
  Future<Session?> restore() async => await storage.read(key: 'access') == null
      ? null
      : Session.fromJson(await _get('me/'));
  @override
  Future<void> requestOtp(String phone) async {
    await _post('auth/otp/request/', {'phone': phone});
  }

  @override
  Future<Session> verifyOtp(String phone, String code) async {
    final j = await _post('auth/otp/verify/', {'phone': phone, 'code': code});
    await storage.write(key: 'access', value: j['access'] as String);
    if (j['refresh'] != null) {
      await storage.write(key: 'refresh', value: j['refresh'] as String);
    }
    return Session.fromJson(j['user'] as Map<String, dynamic>);
  }

  @override
  Future<Session> profile(String first, String last, String email) async =>
      Session.fromJson(
        await _post('me/', {
          'first_name': first,
          'last_name': last,
          'email': email,
        }),
      );
  @override
  Future<void> logout() async {
    try {
      await _post('auth/logout/', {
        'refresh': await storage.read(key: 'refresh'),
      });
    } finally {
      await storage.deleteAll();
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
    await _post('routes/quote/', {
      'pickup': pickup.toJson(),
      'destination': destination.toJson(),
      'category': category,
      'currency': currency,
    }),
  );
  @override
  Future<List<Ride>> history() async =>
      ((await _get('rides/'))['results'] as List)
          .map((j) => Ride.fromJson(j as Map<String, dynamic>))
          .toList();
  @override
  Future<Ride?> activeRide() async {
    final j = await _get('rides/active/');
    return j['ride'] == null
        ? null
        : Ride.fromJson(j['ride'] as Map<String, dynamic>);
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
    final form = FormData.fromMap(fields);
    for (final d in documents.entries) {
      form.files.add(MapEntry(d.key, await MultipartFile.fromFile(d.value)));
    }
    final j = (await dio.post<Map<String, dynamic>>(
      'driver/application/',
      data: form,
    )).data!;
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

  @override
  Future<Map<String, dynamic>> read(String resource) {
    final uri = Uri.parse(resource);
    return _get('${uri.path}/${uri.hasQuery ? '?${uri.query}' : ''}');
  }

  @override
  Future<void> write(String resource, Map<String, dynamic> data) async {
    await _post('$resource/', data);
  }

  void dispose() {
    dio.close(force: true);
    expired.close();
  }
}
