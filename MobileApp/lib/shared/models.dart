import 'package:latlong2/latlong.dart';

enum RideStatus {
  searching,
  assigned,
  arriving,
  arrived,
  inProgress,
  completed,
  cancelled,
}

enum DriverStatus {
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
    (j['latitude'] as num).toDouble(),
    (j['longitude'] as num).toDouble(),
  );
}

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
    name: j['driver_name'] as String,
    vehicle: j['vehicle'] as String,
    plate: j['registration'] as String,
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
  });
  final String id, category, paymentStatus;
  final Place pickup, destination;
  final int cents;
  final RideStatus status;
  final DateTime createdAt;
  final DriverOffer? driver;
  bool get active =>
      status != RideStatus.completed && status != RideStatus.cancelled;
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
  );
}

class Session {
  const Session({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.driverStatus = DriverStatus.draft,
  });
  final String firstName, lastName, phone;
  final DriverStatus driverStatus;
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    firstName: j['first_name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    phone: j['phone'] as String,
    driverStatus: DriverStatus.values.byName(
      j['driver_status'] as String? ?? 'draft',
    ),
  );
}

String money(int cents) => 'USD ${(cents / 100).toStringAsFixed(2)}';
int parseFare(String input) {
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(input.trim())) {
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
};

class RouteQuote {
  const RouteQuote({
    required this.points,
    required this.metres,
    required this.seconds,
    required this.available,
    required this.minimumCents,
    this.suggestedCents,
  });
  final List<LatLng> points;
  final int metres, seconds, minimumCents;
  final int? suggestedCents;
  final bool available;
  factory RouteQuote.fromJson(Map<String, dynamic> j) => RouteQuote(
    points: (j['geometry'] as List)
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList(),
    metres: j['distance_metres'] as int,
    seconds: j['duration_seconds'] as int,
    available: j['service_available'] == true,
    minimumCents: j['minimum_fare_cents'] as int,
    suggestedCents: j['suggested_fare_cents'] as int?,
  );
}
