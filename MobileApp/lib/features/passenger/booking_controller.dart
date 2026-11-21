import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../core/api_error.dart';
import '../../shared/models.dart';

/// Owns only the editable booking draft. Live quote/pricing is always backend-fed.
class BookingController extends ChangeNotifier {
  BookingController(this.app) : currency = 'USD';
  final AppController app;
  final fare = TextEditingController();
  final note = TextEditingController();
  Place? pickup, destination;
  String category = 'Standard', currency;
  RouteQuote? quote;
  bool get intercity => category == 'Intercity';
  int passengerCount = 1;
  String luggage = 'none';
  DateTime? departureAt;
  List<Place> stops = const [];
  bool get courier => category == 'Courier';
  final Map<String, dynamic> parcel = {
    'size': 'small',
    'permitted_goods': false,
  };

  void setParcelValue(String key, Object? value) {
    if (submitting) return;
    parcel[key] = value;
    notifyListeners();
  }

  bool get canSendParcel {
    final weight = parcel['weight_kg'];
    return [
          'sender_name',
          'sender_phone',
          'recipient_name',
          'recipient_phone',
          'description',
        ].every((key) => (parcel[key] as String? ?? '').trim().isNotEmpty) &&
        weight is num &&
        weight.isFinite &&
        weight >= 0.1 &&
        weight <= 20 &&
        parcel['permitted_goods'] == true;
  }

  Future<void> rebook(Ride previous) async {
    if (submitting) return;
    category = previous.category;
    pickup = previous.pickup;
    destination = previous.destination;
    departureCity = previous.pickup.city;
    arrivalCity = previous.destination.city;
    stops = List.unmodifiable(previous.stops);
    passengerCount = previous.passengerCount;
    luggage = previous.luggage;
    departureAt = null;
    note.clear();
    parcel
      ..clear()
      ..addAll({'size': 'small', 'permitted_goods': false});
    await refreshQuote(changed: true);
  }

  Future<void> setStops(List<Place> value) async {
    if (submitting) return;
    stops = List.unmodifiable(value);
    await refreshQuote(changed: true);
  }

  void setDeparture(DateTime? value) {
    if (submitting) return;
    departureAt = value;
    notifyListeners();
  }

  String? departureCity, arrivalCity;

  void setCity(bool origin, String city) {
    if (submitting) return;
    if (origin) {
      departureCity = city;
      pickup = null;
    } else {
      arrivalCity = city;
      destination = null;
    }
    unawaited(refreshQuote(changed: true));
  }

  void setIntercityDetails({int? count, String? bags}) {
    if (submitting) return;
    passengerCount = count ?? passengerCount;
    luggage = bags ?? luggage;
    notifyListeners();
  }

  List<BookingPaymentMethod> methods = [];
  List<String> currencies = [];
  bool quoting = false,
      loadingMethods = false,
      submitting = false,
      manuallyEdited = false;
  String? error, configurationError, notice, _requestKey, _lastSubmission;
  int _generation = 0;
  bool _disposed = false;
  Timer? _expiry;
  static const int fareStepCents = 50;

  void adjustFare(int deltaCents) {
    if (quote == null || fare.text.trim().isEmpty) {
      final current = quote == null
          ? 0
          : quote!.suggestedCents ?? quote!.minimumCents;
      final next = (current + deltaCents).clamp(
        quote?.minimumCents ?? 0,
        quote?.maximumCents ?? current + deltaCents,
      );
      fare.text = (next / 100).toStringAsFixed(2);
      manuallyEdited = true;
      notifyListeners();
      return;
    }
    try {
      final value = parseFare(fare.text);
      final next = (value + deltaCents).clamp(
        quote!.minimumCents,
        quote!.maximumCents ?? double.maxFinite.toInt(),
      );
      fare.text = (next / 100).toStringAsFixed(2);
      manuallyEdited = true;
      notifyListeners();
    } on FormatException {
      final fallback = quote!.suggestedCents ?? quote!.minimumCents;
      fare.text = (fallback / 100).toStringAsFixed(2);
      manuallyEdited = true;
      notifyListeners();
    }
  }

  void resetFareToSuggested() {
    if (quote?.suggestedCents == null) return;
    fare.text = (quote!.suggestedCents! / 100).toStringAsFixed(2);
    manuallyEdited = false;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  BookingPaymentMethod? get method =>
      methods.where((m) => m.id == app.paymentMethod).firstOrNull;
  String? get paymentError {
    final selected = method;
    if (selected == null) {
      return 'Choose a payment method.';
    }
    if (!selected.enabled) {
      return selected.kind == 'mobile_money'
          ? 'This offline payment preference is currently unavailable.'
          : 'This payment method is unavailable.';
    }
    if (!selected.supports(currency)) {
      return 'This payment method does not support ${currencySymbol(currency)}. Choose a compatible option.';
    }
    return null;
  }

  String? get fareError {
    try {
      final value = parseFare(fare.text);
      if (quote != null && value < quote!.minimumCents) {
        return 'Minimum offer: ${money(quote!.minimumCents, currency: currency)}';
      }
      if (quote?.maximumCents != null && value > quote!.maximumCents!) {
        return 'Maximum offer: ${money(quote!.maximumCents!, currency: currency)}';
      }
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  bool get canSubmit =>
      !submitting &&
      (!courier || canSendParcel) &&
      app.ride?.active != true &&
      !app.busy &&
      !quoting &&
      !loadingMethods &&
      configurationError == null &&
      currencies.contains(currency) &&
      pickup != null &&
      destination != null &&
      quote?.valid == true &&
      quote?.id != null &&
      quote?.currency == currency &&
      fareError == null &&
      paymentError == null;
  Future<void> loadConfiguration() async {
    loadingMethods = true;
    configurationError = null;
    notifyListeners();
    try {
      final config = await app.repository.read('payments/methods');
      methods = (config['items'] as List)
          .map(
            (j) => BookingPaymentMethod.fromJson(
              Map<String, dynamic>.from(j as Map),
            ),
          )
          .where((m) => m.enabled && m.supports('USD'))
          .toList();
      currencies = ['USD'];
      currency = 'USD';
      if (method == null) {
        app.selectPayment('cash-usd', 'Cash');
      }
    } catch (e) {
      configurationError =
          'Payment/currency options unavailable. Retry before booking.';
    } finally {
      loadingMethods = false;
      notifyListeners();
    }
  }

  Future<void> setPlaces({Place? pickup, Place? destination}) async {
    if (submitting) {
      return;
    }
    this.pickup = pickup ?? this.pickup;
    this.destination = destination ?? this.destination;
    await refreshQuote(changed: true);
  }

  Future<void> setCategory(String value) async {
    if (category == value || submitting) {
      return;
    }
    if (intercity != (value == 'Intercity') ||
        courier != (value == 'Courier')) {
      pickup = null;
      destination = null;
      stops = const [];
      if (value == 'Courier') departureAt = null;
    }
    category = value;
    await refreshQuote(changed: true);
  }

  Future<void> setCurrency(String value) async {
    if (value == currency || submitting || !currencies.contains(value)) {
      return;
    }
    currency = value;
    app.selectCurrency(value);
    await refreshQuote(changed: true);
  }

  void setPayment(BookingPaymentMethod selected) {
    if (submitting) {
      return;
    }
    _requestKey = null;
    app.selectPayment(selected.id, selected.name);
    notifyListeners();
  }

  void editFare(String value) {
    manuallyEdited = true;
    _requestKey = null;
    error = null;
    notifyListeners();
  }

  Future<void> refreshQuote({bool changed = false}) async {
    if (submitting) {
      return;
    }
    final generation = ++_generation;
    _expiry?.cancel();
    if (changed) {
      notice = manuallyEdited
          ? 'Route, category or currency changed. Your previous offer was cleared; review the new suggestion.'
          : null;
      fare.clear();
      manuallyEdited = false;
      _requestKey = null;
    }
    quote = null;
    error = null;
    quoting = pickup != null && destination != null;
    notifyListeners();
    if (!quoting) {
      return;
    }
    final preserveEdit = manuallyEdited;
    try {
      final result = await app.repository.quote(
        pickup!,
        destination!,
        category,
        currency: currency,
        stops: stops,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      if (result == null ||
          !result.valid ||
          result.id == null ||
          result.currency != currency) {
        throw StateError(
          'No driving route and fare are available. Check your pickup and destination, then retry.',
        );
      }
      quote = result;
      if (!preserveEdit && !manuallyEdited) {
        fare.text = (result.suggestedCents! / 100).toStringAsFixed(2);
      }
      if (result.expiresAt != null) {
        _expiry = Timer(
          result.expiresAt!.difference(DateTime.now().toUtc()),
          () {
            error =
                'Your route quote expired. Retry to calculate a current fare.';
            notifyListeners();
          },
        );
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = apiErrorMessage(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        quoting = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submit() async {
    if (!canSubmit) {
      return false;
    }
    submitting = true;
    error = null;
    notifyListeners();
    final signature =
        '${quote!.id}|${method!.id}|$currency|${fare.text}|${note.text}|$passengerCount|$luggage|$departureAt|${courier ? parcel : ''}';
    if (signature != _lastSubmission) {
      _requestKey = _uuid();
      _lastSubmission = signature;
    }
    _requestKey ??= _uuid();
    final paymentPreference = method?.id == 'ecocash'
        ? 'ecocash'
        : method?.id == 'onemoney'
        ? 'onemoney'
        : 'cash';
    final ok = await app.book(
      pickup!,
      destination!,
      category,
      parseFare(fare.text),
      quoteId: quote!.id,
      requestKey: _requestKey,
      offeredCurrency: currency,
      methodId: method!.id,
      paymentPreference: paymentPreference,
      passengerNote: note.text,
      passengerCount: intercity ? passengerCount : null,
      luggage: intercity ? luggage : null,
      departureAt: departureAt,
      parcel: courier ? Map.of(parcel) : null,
      stops: stops,
    );
    if (ok) {
      _expiry?.cancel();
      quote = null;
      if (courier) {
        parcel
          ..clear()
          ..addAll({'size': 'small', 'permitted_goods': false});
        note.clear();
      }
    }
    if (!ok) {
      error =
          app.error ??
          'Booking could not be confirmed. Retry using the same request.';
    }
    submitting = false;
    notifyListeners();
    return ok;
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _expiry?.cancel();
    fare.dispose();
    note.dispose();
    super.dispose();
  }
}
