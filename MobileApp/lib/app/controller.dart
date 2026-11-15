import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/repository.dart';
import '../core/realtime.dart';
import '../shared/models.dart';

final appProvider = Provider<AppController>((ref) {
  final controller = AppController(
    AppConfig.demo ? DemoRepository() : ApiRepository(),
  );
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
  Session? session;
  Ride? ride;
  List<DriverOffer> offers = [];
  List<Ride> history = [];
  List<Place> saved = [], recent = [];
  Realtime? realtime;
  StreamSubscription<void>? _expiration;
  Timer? _poll;
  StreamSubscription<Position>? _positions;
  bool _syncing = false;
  bool initializationFailed = false;
  SharedPreferences? _prefs;
  bool _disposed = false;
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
      error = e is FormatException
          ? e.message
          : e is StateError
          ? e.message.toString()
          : 'Unable to reach Trivia. Check your connection and try again.';
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
      session = await repository.restore();
      if (repository is ApiRepository) {
        _expiration = (repository as ApiRepository).expired.stream.listen((_) {
          session = null;
          ride = null;
          online = false;
          driverMode = false;
          _stopSync();
          _positions?.cancel();
          saved = [];
          recent = [];
          offers = [];
          history = [];
          notifyListeners();
        });
      }
      if (session != null) {
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

  Future<bool> sendOtp(String phone) =>
      perform(() => repository.requestOtp(phone));
  Future<bool> verify(String phone, String code) => perform(() async {
    session = await repository.verifyOtp(phone, code);
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
      final current = await repository.activeRide();
      final records = await repository.history();
      final bids = current?.status == RideStatus.searching
          ? await repository.offers(current!.id)
          : <DriverOffer>[];
      if (session == null || _disposed) {
        return;
      }
      ride = current;
      history = records;
      offers = bids;
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
        ticket: () async =>
            (await repository.read('realtime/ticket'))['ticket'] as String,
        reconcile: sync,
      )..addListener(notifyListeners);
      realtime!.connect();
    }
    if (!AppConfig.demo) {
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

  Future<bool> book(Place a, Place b, String category, int cents) =>
      perform(() async {
        ride = await repository.request(a, b, category, cents);
        recent = [b, ...recent.where((p) => p.name != b.name)].take(8).toList();
        await sync();
      });
  Future<bool> accept(DriverOffer offer) => perform(() async {
    ride = await repository.accept(ride!.id, offer.id);
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
    if (value && !AppConfig.demo) {
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
    online = value;
    await _positions?.cancel();
    if (value && !AppConfig.demo) {
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 30,
            ),
          ).listen(
            (p) async {
              try {
                await repository.write('driver/location', {
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                  'timestamp': p.timestamp.toUtc().toIso8601String(),
                });
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
    }
  });
  Future<bool> switchMode() => perform(() async {
    if (ride?.active == true) {
      throw StateError(
        'Complete or cancel your current trip before switching modes.',
      );
    }
    if (online) {
      await repository.availability(false);
      online = false;
      await _positions?.cancel();
    }
    driverMode = !driverMode;
  });
  Future<bool> logout() => perform(() async {
    try {
      if (online) {
        await repository.availability(false);
      }
      await repository.logout();
    } finally {
      _stopSync();
      await _positions?.cancel();
      session = null;
      ride = null;
      history = [];
      offers = [];
      saved = [];
      recent = [];
      driverMode = false;
      online = false;
    }
  });
  void savePlace(Place p) {
    if (!saved.any((v) => v.name == p.name)) {
      saved.add(p);
      notifyListeners();
    }
  }

  Future<void> pause() async {
    _stopSync();
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

  @override
  void dispose() {
    _disposed = true;
    _stopSync();
    _positions?.cancel();
    _expiration?.cancel();
    if (repository is ApiRepository) {
      (repository as ApiRepository).dispose();
    }
    super.dispose();
  }
}
