import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_error.dart';
import '../core/config.dart';
import '../core/realtime.dart';
import '../core/repository.dart';
import '../shared/models.dart';

final appProvider = Provider<AppController>((ref) {
  final controller = AppController(ApiRepository());
  ref.onDispose(controller.dispose);
  return controller;
});

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final TriviaRepository repository;
  bool ready = false,
      onboarded = false,
      busy = false,
      driverMode = false,
      online = false;
  String? error;
  String? paymentMethod = 'cash-usd';
  String? paymentLabel = 'Cash';
  String currency = 'USD';
  Session? session;
  Ride? ride;
  int dataRevision = 0;
  String? historyNext;
  List<DriverOffer> offers = [];
  List<Ride> history = [];
  List<Place> saved = [], recent = [];
  Realtime? realtime;
  StreamSubscription<void>? _expiration;
  Timer? _poll, _gpsHeartbeat;
  bool _locationUploading = false;
  DateTime? _lastLocationUpload;
  StreamSubscription<Position>? _positions;
  bool _syncing = false;
  bool initializationFailed = false;
  SharedPreferences? _prefs;
  bool _disposed = false;
  ThemeMode themeMode = ThemeMode.system;
  String distanceUnit = 'km';
  String language = 'English';
  bool locationSharing = true;

  static ThemeMode _themeModeFromString(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  Future<bool> perform(Future<void> Function() action) async {
    if (busy) {
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    initializationFailed = false;
    final ok = await perform(() async {
      AppConfig.validate();
      _prefs = await SharedPreferences.getInstance();
      onboarded = _prefs!.getBool('trivia_onboarded') ?? false;
      currency = 'USD';
      themeMode = _themeModeFromString(_prefs!.getString('trivia_theme_mode'));
      distanceUnit = _prefs!.getString('trivia_distance_unit') ?? 'km';
      language = _prefs!.getString('trivia_language') ?? 'English';
      locationSharing = _prefs!.getBool('trivia_location_sharing') ?? true;
      session = await repository.restore();
      if (repository is ApiRepository) {
        _expiration = (repository as ApiRepository).expired.stream.listen((_) {
          session = null;
          ride = null;
          online = false;
          driverMode = false;
          _stopSync();
          _gpsHeartbeat?.cancel();
          _positions?.cancel();
          saved = [];
          recent = [];
          offers = [];
          history = [];
          notifyListeners();
        });
      }
      if (session != null) {
        driverMode = session?.driverStatus == DriverStatus.approved;
        await sync();
        startSync();
      }
    });
    initializationFailed = !ok;
    ready = true;
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    await _prefs?.setBool('trivia_onboarded', true);
    onboarded = true;
    notifyListeners();
  }

  Future<bool> login(LoginContact contact, String password) =>
      perform(() async {
        session = await repository.login(contact, password);
        driverMode = session?.driverStatus == DriverStatus.approved;
        startSync();
        unawaited(
          sync().catchError((Object _) {
            if (session == null) return;
            error = 'Connection interrupted. Pull to refresh or retry.';
            notifyListeners();
          }),
        );
      });

  Future<bool> sendOtp(String phone) =>
      perform(() => repository.requestOtp(phone));
  Future<bool> verify(
    String phone,
    String code, {
    Map<String, dynamic>? legalAcknowledgement,
  }) => perform(() async {
    session = await repository.verifyOtp(
      phone,
      code,
      legalAcknowledgement: legalAcknowledgement,
    );
    await sync();
    startSync();
  });
  Future<bool> updateProfile(String first, String last, String email) =>
      perform(() async {
        session = await repository.profile(first, last, email);
      });
  Future<void> sync() async {
    if (session == null || _syncing) {
      return;
    }
    _syncing = true;
    try {
      final identity = session;
      final refreshed = await repository.restore();
      final current = await repository.activeRide();
      final records = await repository.history();
      final bids = !driverMode && current?.status == RideStatus.searching
          ? await repository.offers(current!.id)
          : <DriverOffer>[];
      if (!identical(session, identity) || _disposed) {
        return;
      }
      session = refreshed ?? session;
      if (online && session?.driverStatus != DriverStatus.approved) {
        online = false;
        _gpsHeartbeat?.cancel();
        await _positions?.cancel();
        try {
          await repository.availability(false);
        } catch (_) {}
      }
      if (repository is ApiRepository &&
          session?.driverStatus == DriverStatus.approved) {
        final availability = await repository.read('drivers/me/availability');
        online = {
          'online',
          'assigned',
          'arriving',
          'onTrip',
        }.contains(availability['status']);
        if (!online) {
          _gpsHeartbeat?.cancel();
          await _positions?.cancel();
        }
      }
      ride = current == null
          ? (ride?.active == false ? ride : null)
          : current.id == ride?.id && ride?.driver != null
          ? current.copy(driver: ride!.driver)
          : current;
      history = records;
      if (repository is ApiRepository) {
        historyNext = (repository as ApiRepository).historyNext;
      }
      final places = await repository.read('users/me/saved-places');
      saved = ((places['results'] as List?) ?? [])
          .map(
            (p) => Place.fromJson(Map<String, dynamic>.from(p['place'] as Map)),
          )
          .toList();
      offers = bids;
      dataRevision++;
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  void startSync() {
    _stopSync();
    if (repository is ApiRepository && AppConfig.websocket.isNotEmpty) {
      realtime = Realtime(
        url: AppConfig.websocket,
        ticket: () async => (repository as ApiRepository).accessToken(),
        reconcile: sync,
      )..addListener(notifyListeners);
      realtime!.connect();
    }
    if (repository is ApiRepository) {
      _poll = Timer.periodic(const Duration(seconds: 15), (_) async {
        try {
          await sync();
        } catch (_) {
          error = 'Connection interrupted. Pull to refresh or retry.';
          notifyListeners();
        }
      });
    }
  }

  void _stopSync() {
    _poll?.cancel();
    realtime?.dispose();
    realtime = null;
  }

  Future<bool> book(
    Place a,
    Place b,
    String category,
    int cents, {
    String? quoteId,
    String? requestKey,
    String? offeredCurrency,
    String? methodId,
    String? paymentPreference,
    String? passengerNote,
  }) => perform(() async {
    if ((methodId ?? paymentMethod) == null) {
      throw StateError('Choose an enabled payment method before booking.');
    }
    ride = await repository.request(
      a,
      b,
      category,
      cents,
      paymentMethod: methodId ?? paymentMethod,
      currency: offeredCurrency ?? currency,
      quoteId: quoteId,
      requestKey: requestKey,
      paymentPreference: paymentPreference,
      passengerNote: passengerNote,
    );
    recent = [b, ...recent.where((p) => p.name != b.name)].take(8).toList();
    await sync();
  });
  Future<bool> accept(DriverOffer offer) => perform(() async {
    ride = (await repository.accept(ride!.id, offer.id)).copy(driver: offer);
    offers = [];
    await sync();
  });
  Future<bool> transition(RideStatus status) => perform(() async {
    ride = await repository.transition(ride!.id, status);
    await sync();
  });
  Future<bool> goOnline(bool value) => perform(() async {
    if (session?.driverStatus != DriverStatus.approved) {
      throw StateError('Driver approval is required.');
    }
    if (value) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services before going online.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw StateError(
          'Location access is needed to go online. Enable it in device settings.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      await repository.write('driver/location', {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'timestamp': p.timestamp.toUtc().toIso8601String(),
      });
    }
    await repository.availability(value);
    final confirmed = await repository.read('drivers/me/availability');
    online =
        confirmed['status'] == 'online' ||
        confirmed['availability'] == 'online';
    _gpsHeartbeat?.cancel();
    await _positions?.cancel();
    if (value) {
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 30,
            ),
          ).listen(
            (p) async {
              try {
                await publishPosition(p);
              } catch (_) {
                error = 'Location upload interrupted. Check your connection.';
                notifyListeners();
              }
            },
            onError: (_) {
              error = 'GPS interrupted. Check location access.';
              notifyListeners();
            },
          );
      _gpsHeartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!online || _disposed) return;
        try {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          await publishPosition(p);
        } catch (_) {
          error = 'Fresh GPS unavailable. Driver eligibility expires without fresh locations.';
          notifyListeners();
        }
      });
    }
  });
  Future<void> publishPosition(Position p) async {
    if (!online || _disposed || _locationUploading || session == null) return;
    final now = DateTime.now().toUtc();
    if (now.difference(p.timestamp.toUtc()).inSeconds > 30 ||
        (_lastLocationUpload != null &&
            now.difference(_lastLocationUpload!).inSeconds < 3)) {
      return;
    }
    _locationUploading = true;
    try {
      await repository.write('drivers/me/location', {
        'latitude': p.latitude,
        'longitude': p.longitude,
      });
      _lastLocationUpload = now;
    } finally {
      _locationUploading = false;
    }
  }

  Future<bool> switchMode() => perform(() async {
    if (ride?.active == true) {
      throw StateError(
        'Complete or cancel your current trip before switching modes.',
      );
    }
    if (online) {
      await repository.availability(false);
      online = false;
      _gpsHeartbeat?.cancel();
      await _positions?.cancel();
    }
    driverMode = !driverMode;
  });
  Future<bool> logout() => perform(() async {
    _gpsHeartbeat?.cancel();
    await _positions?.cancel();
    try {
      if (online) {
        try {
          await repository.availability(false);
        } catch (_) {
          /* Local logout must still clear credentials. */
        }
      }
      await repository.logout();
    } finally {
      await _clearAccountState();
    }
  });

  Future<bool> changePassword(String current, String password, String confirmation) =>
      perform(() async {
        await repository.changePassword(current, password, confirmation);
        await _clearAccountState();
      });

  Future<void> _clearAccountState() async {
    _stopSync();
    _gpsHeartbeat?.cancel();
    await _positions?.cancel();
    session = null;
    ride = null;
    history = [];
    offers = [];
    saved = [];
    recent = [];
    paymentMethod = 'cash-usd';
    paymentLabel = 'Cash';
    driverMode = false;
    online = false;
  }

  void selectCurrency(String value) {
    currency = value;
    _prefs?.setString('trivia_currency', value);
    notifyListeners();
  }

  void selectPayment(String id, String label) {
    paymentMethod = id;
    paymentLabel = label;
    notifyListeners();
  }

  Future<void> savePlace(Place p) async {
    await perform(() async {
      await repository.write('users/me/saved-places', {
        'label': p.name,
        'place': p.toJson(),
      });
      await sync();
    });
  }

  Future<void> moreHistory() async {
    if (historyNext == null) return;
    await perform(() async {
      final page = await repository.read(historyNext!);
      final rows = (page['results'] as List).map(
        (j) => Ride.fromJson(Map<String, dynamic>.from(j as Map)),
      );
      history = [
        ...history,
        ...rows.where((r) => !history.any((old) => old.id == r.id)),
      ];
      historyNext = page['next'] as String?;
    });
  }

  Future<void> pause() async {
    _stopSync();
    _gpsHeartbeat?.cancel();
    await _positions?.cancel();
    if (online) {
      try {
        await repository.availability(false);
      } catch (_) {
        error = 'Could not confirm offline status. Availability must expire server-side.';
      }
      online = false;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (session != null) {
      try {
        await sync();
      } catch (_) {}
      startSync();
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _prefs?.setString('trivia_theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> updateDistanceUnit(String unit) async {
    distanceUnit = unit;
    await _prefs?.setString('trivia_distance_unit', unit);
    notifyListeners();
  }

  Future<void> updateLanguage(String value) async {
    language = value;
    await _prefs?.setString('trivia_language', value);
    notifyListeners();
  }

  Future<void> updateLocationSharing(bool enabled) async {
    locationSharing = enabled;
    await _prefs?.setBool('trivia_location_sharing', enabled);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopSync();
    _gpsHeartbeat?.cancel();
    _positions?.cancel();
    _expiration?.cancel();
    if (repository is ApiRepository) {
      (repository as ApiRepository).dispose();
    }
    super.dispose();
  }
}
