import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

const harareOffset = Duration(hours: 2);

String harareTime(DateTime stamp) =>
    "${DateFormat('d MMM yyyy, HH:mm').format(stamp.toUtc().add(harareOffset))} CAT";

enum RideStatus {
  scheduled,
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
  const Place(
    this.name,
    this.lat,
    this.lng, {
    this.formattedAddress,
    this.provider,
    this.city,
  });
  final String? formattedAddress, provider, city;
  final String name;
  final double lat, lng;
  LatLng get point => LatLng(lat, lng);
  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': lat,
    'longitude': lng,
    'city': ?city,
  };
  factory Place.fromJson(Map<String, dynamic> j) => Place(
    j['name'] as String,
    double.parse('${j['latitude']}'),
    double.parse('${j['longitude']}'),
    formattedAddress: j['formatted_address'] as String?,
    provider: j['provider'] as String?,
    city: j['city'] as String?,
  );
}

class SavedAddress {
  const SavedAddress(this.id, this.label, this.place);
  final String id, label;
  final Place place;

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    '${json['id']}',
    json['label'] as String,
    Place.fromJson(Map<String, dynamic>.from(json['place'] as Map)),
  );
}

class DriverOffer {
  const DriverOffer({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.plate,
    required this.cents,
    this.colour,
    this.rating,
    this.minutes,
    this.verified = false,
  });
  final String id, name, vehicle, plate;
  final String? colour;
  final int cents;
  final double? rating;
  final int? minutes;
  final bool verified;
  factory DriverOffer.fromJson(Map<String, dynamic> j) => DriverOffer(
    id: '${j['id']}',
    name: j['driver_name'] as String? ?? 'Driver details unavailable',
    vehicle: j['vehicle'] as String? ?? 'Vehicle details unavailable',
    plate: j['registration'] as String? ?? '',
    colour: j['colour'] as String?,
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
    this.distanceMetres,
    this.viewerRole,
    this.departureAt,
    this.parcelSize,
    this.parcelWeightKg,
    this.stops = const [],
    this.passengerCount = 1,
    this.luggage = 'none',
    this.passengerNote = '',
    this.route = const [],
  });
  final String id, category, paymentStatus, currency;
  final int? offeredCents, agreedCents;
  final int? distanceMetres;
  final int passengerCount;
  final String luggage, passengerNote;
  bool get intercity => category == 'Intercity';
  bool get courier => category == 'Courier';
  final String? parcelSize;
  final double? parcelWeightKg;
  String get serviceName => switch (category) {
    'Intercity' => 'City-to-City',
    'Courier' => 'Courier delivery',
    _ => 'Trivia $category',
  };
  final String? viewerRole;
  final String? paymentMethod, paymentMethodName;
  final Place pickup, destination;
  final List<Place> stops;
  final int cents;
  final RideStatus status;
  final DateTime createdAt;
  final DateTime? departureAt;
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
  Ride copy({
    RideStatus? status,
    DriverOffer? driver,
    int? fareCents,
    int? agreedFareCents,
  }) => Ride(
    id: id,
    pickup: pickup,
    destination: destination,
    cents: fareCents ?? cents,
    category: category,
    status: status ?? this.status,
    createdAt: createdAt,
    driver: driver ?? this.driver,
    paymentStatus: paymentStatus,
    currency: currency,
    offeredCents: offeredCents ?? cents,
    agreedCents: agreedFareCents ?? agreedCents,
    paymentMethod: paymentMethod,
    paymentMethodName: paymentMethodName,
    driverLocation: driverLocation,
    locationUpdatedAt: locationUpdatedAt,
    distanceMetres: distanceMetres,
    viewerRole: viewerRole,
    departureAt: departureAt,
    parcelSize: parcelSize,
    parcelWeightKg: parcelWeightKg,
    stops: stops,
    passengerCount: passengerCount,
    luggage: luggage,
    passengerNote: passengerNote,
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
    distanceMetres: j['distance_metres'] as int?,
    viewerRole: j['viewer_role'] as String?,
    stops: [
      for (final stop in j['stops'] as List? ?? [])
        Place.fromJson(Map<String, dynamic>.from(stop as Map)),
    ],
    parcelSize: j['parcel_size'] as String?,
    parcelWeightKg: (j['parcel_weight_kg'] as num?)?.toDouble(),
    departureAt: DateTime.tryParse('${j['departure_at']}'),
    passengerCount: j['passenger_count'] as int? ?? 1,
    luggage: j['luggage'] as String? ?? 'none',
    passengerNote: j['passenger_note'] as String? ?? '',
    route: _parseGeometry(j['route_geometry'] as List? ?? []),
  );
}

class Session {
  const Session({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.driverStatus = DriverStatus.notRegistered,
    this.email = '',
  });
  final String firstName, lastName, phone, email;
  final DriverStatus driverStatus;
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    firstName: j['first_name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    phone: j['phone'] as String,
    email: j['email'] as String? ?? '',
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
  RideStatus.scheduled => 'Scheduled departure',
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
    this.routingProvider,
  });
  final List<LatLng> points;
  final int metres, seconds, minimumCents;
  final int? suggestedCents;
  final bool available;
  final String? id, exchangeRate, routingProvider;
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
    points: _parseGeometry(j['geometry'] as List),
    metres: j['distance_metres'] as int,
    seconds: j['duration_seconds'] as int,
    available: j['service_available'] == true,
    minimumCents: j['minimum_fare_cents'] as int,
    suggestedCents: j['suggested_fare_cents'] as int?,
    id: j['id'] as String?,
    routingProvider: j['routing_provider'] as String?,
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

// API geometry uses longitude/latitude; map coordinates use latitude/longitude.
List<LatLng> _parseGeometry(List<dynamic> coordinates) => coordinates
    .map(
      (point) =>
          LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
    )
    .toList();

String luggageLabel(String value) => switch (value) {
  'small' => 'Small bags',
  'large' => 'Large bags',
  _ => 'No luggage',
};

String deliveryStatusLabel(Ride ride) => !ride.courier
    ? statusLabel(ride.status)
    : switch (ride.status) {
        RideStatus.searching => 'Finding a courier',
        RideStatus.assigned => 'Courier selected',
        RideStatus.arriving => 'Courier on the way',
        RideStatus.arrived => 'Courier at pickup',
        RideStatus.inProgress => 'Parcel in transit',
        RideStatus.completed => 'Parcel delivered',
        _ => statusLabel(ride.status),
      };
