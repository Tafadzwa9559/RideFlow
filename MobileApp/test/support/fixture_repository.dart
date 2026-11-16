import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rideflow_mobile/shared/models.dart';
import 'package:rideflow_mobile/core/repository.dart';

const demoPlaces = [
  Place('Harare Gardens', -17.8225, 31.0456),
  Place('Avondale Shopping Centre', -17.8002, 31.0328),
  Place('Sam Levy’s Village', -17.7626, 31.0863),
  Place('Robert Gabriel Mugabe Airport', -17.9318, 31.0928),
  Place('Eastgate Centre', -17.8331, 31.0528),
  Place(
    'National University of Science and Technology, Bulawayo',
    -20.163,
    28.643,
  ),
  Place('Mutare city centre', -18.9707, 32.6709),
  Place('Gweru city centre', -19.4500, 29.8167),
  Place('Masvingo city centre', -20.0744, 30.8328),
  Place('Chitungwiza town centre', -18.0127, 31.0755),
  Place('Norton town centre', -17.8833, 30.7000),
];

class TestRepository implements TriviaRepository {
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
        !true ||
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
