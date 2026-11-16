import 'package:latlong2/latlong.dart';

enum RideStatus {
  searching,
  assigned,
  arriving,
  arrived,
  inProgress,
  completed,
  cancelled,
  expired,
}

enum DriverStatus {
  notRegistered,
  draft,
  submitted,
  underReview,
  approved,
  rejected,
  suspended,
}

class Place {
  const Place(this.name, this.lat, this.lng);
  final String name;
  final double lat, lng;
  LatLng get point => LatLng(lat, lng);
  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': lat,
    'longitude': lng,
  };
  factory Place.fromJson(Map<String, dynamic> j) => Place(
    j['name'] as String,
    double.parse('${j['latitude']}'),
    double.parse('${j['longitude']}'),
  );
}

class DriverOffer {
  const DriverOffer({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.plate,
    required this.cents,
    this.rating,
    this.minutes,
    this.verified = false,
  });
  final String id, name, vehicle, plate;
  final int cents;
  final double? rating;
  final int? minutes;
  final bool verified;
  factory DriverOffer.fromJson(Map<String, dynamic> j) => DriverOffer(
    id: '${j['id']}',
    name: j['driver_name'] as String? ?? 'Driver details unavailable',
    vehicle: j['vehicle'] as String? ?? 'Vehicle details unavailable',
    plate: j['registration'] as String? ?? '',
    cents: j['fare_cents'] as int,
    rating: (j['rating'] as num?)?.toDouble(),
    minutes: j['pickup_minutes'] as int?,
    verified: j['verified'] == true,
  );
}

class Ride {
  const Ride({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.cents,
    required this.category,
    required this.status,
    required this.createdAt,
    this.driver,
    this.paymentStatus = 'Unpaid',
    this.currency = 'USD',
    this.offeredCents,
    this.agreedCents,
    this.paymentMethod,
    this.paymentMethodName,
    this.driverLocation,
    this.locationUpdatedAt,
    this.route = const [],
  });
  final String id, category, paymentStatus, currency;
  final int? offeredCents, agreedCents;
  final String? paymentMethod, paymentMethodName;
  final Place pickup, destination;
  final int cents;
  final RideStatus status;
  final DateTime createdAt;
  final DriverOffer? driver;
  final Place? driverLocation;
  final DateTime? locationUpdatedAt;
  final List<LatLng> route;
  bool get freshLocation {
    final stamp = locationUpdatedAt;
    if (stamp == null || driverLocation == null) {
      return false;
    }
    final age = DateTime.now().toUtc().difference(stamp.toUtc());
    return age >= const Duration(seconds: -30) &&
        age <= const Duration(seconds: 90);
  }

  bool get active =>
      status != RideStatus.completed &&
      status != RideStatus.cancelled &&
      status != RideStatus.expired;
  Ride copy({RideStatus? status, DriverOffer? driver}) => Ride(
    id: id,
    pickup: pickup,
    destination: destination,
    cents: driver?.cents ?? cents,
    category: category,
    status: status ?? this.status,
    createdAt: createdAt,
    driver: driver ?? this.driver,
    paymentStatus: paymentStatus,
    currency: currency,
    offeredCents: offeredCents ?? cents,
    agreedCents: driver?.cents ?? agreedCents,
    paymentMethod: paymentMethod,
    paymentMethodName: paymentMethodName,
    driverLocation: driverLocation,
    locationUpdatedAt: locationUpdatedAt,
    route: route,
  );
  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
    id: '${j['id']}',
    pickup: Place.fromJson(j['pickup'] as Map<String, dynamic>),
    destination: Place.fromJson(j['destination'] as Map<String, dynamic>),
    cents: j['fare_cents'] as int,
    category: j['category'] as String,
    status: RideStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
    driver: j['driver'] == null
        ? null
        : DriverOffer.fromJson(j['driver'] as Map<String, dynamic>),
    paymentStatus: j['payment_status'] as String? ?? 'Unpaid',
    currency: j['currency'] as String? ?? 'USD',
    offeredCents: j['offered_fare'] == null
        ? null
        : parseFare('${j['offered_fare']}'),
    agreedCents: j['agreed_fare'] == null
        ? null
        : parseFare('${j['agreed_fare']}'),
    paymentMethod: j['payment_method_id'] as String?,
    paymentMethodName: j['payment_method_name'] as String?,
    driverLocation: j['driver_location'] == null
        ? null
        : Place.fromJson(j['driver_location'] as Map<String, dynamic>),
    locationUpdatedAt: j['location_updated_at'] == null
        ? null
        : DateTime.parse(j['location_updated_at'] as String),
    route: (j['route_geometry'] as List? ?? [])
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList(),
  );
}

class Session {
  const Session({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.driverStatus = DriverStatus.notRegistered,
  });
  final String firstName, lastName, phone;
  final DriverStatus driverStatus;
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    firstName: j['first_name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    phone: j['phone'] as String,
    driverStatus: DriverStatus.values.byName(
      j['driver_status'] as String? ?? 'notRegistered',
    ),
  );
}

String currencySymbol(String currency) => 'US\$';
String money(int cents, {String currency = 'USD'}) =>
    '${currencySymbol(currency)} ${(cents / 100).toStringAsFixed(2)}';
int parseFare(String input) {
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(input.trim())) {
    throw const FormatException(
      'Enter a positive fare with up to two decimal places.',
    );
  }
  final parts = input.trim().split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (cents <= 0) {
    throw const FormatException('Your fare must be greater than zero.');
  }
  return cents;
}

String statusLabel(RideStatus s) => switch (s) {
  RideStatus.searching => 'Finding your driver',
  RideStatus.assigned => 'Driver selected',
  RideStatus.arriving => 'Driver on the way',
  RideStatus.arrived => 'Driver has arrived',
  RideStatus.inProgress => 'Enjoy your journey',
  RideStatus.completed => 'Trip completed',
  RideStatus.cancelled => 'Trip cancelled',
  RideStatus.expired => 'Ride request expired',
};

class RouteQuote {
  const RouteQuote({
    required this.points,
    required this.metres,
    required this.seconds,
    required this.available,
    required this.minimumCents,
    this.suggestedCents,
    this.id,
    this.currency = 'USD',
    this.maximumCents,
    this.expiresAt,
    this.exchangeRate,
    this.exchangeRateTimestamp,
    this.pricing = const {},
  });
  final List<LatLng> points;
  final int metres, seconds, minimumCents;
  final int? suggestedCents;
  final bool available;
  final String? id, exchangeRate;
  final String currency;
  final int? maximumCents;
  final DateTime? expiresAt, exchangeRateTimestamp;
  final Map<String, dynamic> pricing;
  bool get valid =>
      available &&
      suggestedCents != null &&
      suggestedCents! > 0 &&
      points.length >= 2 &&
      metres > 0 &&
      seconds > 0 &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc()));
  factory RouteQuote.fromJson(Map<String, dynamic> j) => RouteQuote(
    points: (j['geometry'] as List)
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList(),
    metres: j['distance_metres'] as int,
    seconds: j['duration_seconds'] as int,
    available: j['service_available'] == true,
    minimumCents: j['minimum_fare_cents'] as int,
    suggestedCents: j['suggested_fare_cents'] as int?,
    id: j['id'] as String?,
    currency: j['currency'] as String? ?? 'USD',
    maximumCents: j['maximum_fare_cents'] as int?,
    expiresAt: j['expires_at'] == null
        ? null
        : DateTime.parse(j['expires_at'] as String),
    exchangeRate: j['exchange_rate'] as String?,
    exchangeRateTimestamp: j['exchange_rate_timestamp'] == null
        ? null
        : DateTime.parse(j['exchange_rate_timestamp'] as String),
    pricing: j['pricing_configuration'] as Map<String, dynamic>? ?? {},
  );
}

class BookingPaymentMethod {
  const BookingPaymentMethod({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencies,
    required this.enabled,
    required this.description,
  });
  final String id, name, kind, description;
  final List<String> currencies;
  final bool enabled;
  bool supports(String currency) => currencies.contains(currency);
  factory BookingPaymentMethod.fromJson(Map<String, dynamic> j) =>
      BookingPaymentMethod(
        id: '${j['id']}',
        name: j['name'] as String,
        kind: j['kind'] as String,
        currencies: (j['currencies'] as List).cast<String>(),
        enabled: j['enabled'] == true,
        description: j['description'] as String? ?? '',
      );
}

String paymentStatusLabel(String status) => switch (status) {
  'pending_cash' => 'Cash due to driver',
  'awaiting_confirmation' => 'Awaiting payment confirmation',
  'unverified' => 'Direct payment — not verified by Trivia',
  'paid' => 'Driver-reported receipt',
  'failed' => 'Payment failed',
  'cancelled' => 'Cancelled',
  _ => status,
};

/// Informational preferences: no payment is initiated by Trivia.
const directPaymentMethods = [
  BookingPaymentMethod(
    id: 'ecocash',
    name: 'EcoCash',
    kind: 'mobile_money',
    currencies: ['USD'],
    enabled: true,
    description: 'Mobile money — pay the driver directly.',
  ),
  BookingPaymentMethod(
    id: 'onemoney',
    name: 'OneMoney',
    kind: 'mobile_money',
    currencies: ['USD'],
    enabled: true,
    description: 'Mobile money — pay the driver directly.',
  ),
  BookingPaymentMethod(
    id: 'cash-usd',
    name: 'Cash',
    kind: 'cash',
    currencies: ['USD'],
    enabled: true,
    description: 'Pay the driver directly using cash.',
  ),
];

String directPaymentLabel(String? id, String? name) =>
    directPaymentMethods.where((m) => m.id == id).firstOrNull?.name ??
    name ??
    'Not specified';
