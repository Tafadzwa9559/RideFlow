import 'package:flutter/foundation.dart';

const bool developmentBuild = bool.fromEnvironment('TRIVIA_DEVELOPMENT_BUILD');
const bool passengerTestingBuild = bool.fromEnvironment('TRIVIA_PASSENGER_TESTING');
const String passengerTestingOrigin = String.fromEnvironment('TRIVIA_PASSENGER_TESTING_ORIGIN');

bool get passengerTestingEnabled =>
    passengerTestingBuild && passengerTestingOrigin.isNotEmpty &&
    baseUrl == passengerTestingOrigin && Uri.parse(baseUrl).scheme == 'https' &&
    Uri.parse(baseUrl).host != 'trivia-backend-bze2.onrender.com';

const String baseUrl = String.fromEnvironment(
  'TRIVIA_API_BASE_URL',
  defaultValue: developmentBuild
      ? 'http://10.0.2.2:8000'
      : 'https://trivia-backend-bze2.onrender.com',
);

class AppConfig {
  static const api = baseUrl;
  static String get websocket {
    final origin = Uri.parse(api);
    return origin
        .replace(
          scheme: origin.scheme == 'http' ? 'ws' : 'wss',
          path: '/ws/v1/notifications/',
          query: '',
          fragment: '',
        )
        .toString();
  }

  static const mapTiles = String.fromEnvironment(
    'TRIVIA_MAP_TILES',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const privacy = String.fromEnvironment('TRIVIA_PRIVACY_URL');
  static const terms = String.fromEnvironment('TRIVIA_TERMS_URL');
  static void validate() =>
      validateOrigin(api, development: developmentBuild, debug: kDebugMode);

  static void validateOrigin(
    String origin, {
    bool development = false,
    bool debug = false,
  }) {
    final uri = Uri.tryParse(origin);
    final local =
        uri != null &&
        const {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(uri.host);
    if ((development && (!debug || !local)) ||
        uri == null ||
        (uri.scheme != 'https' &&
            !(development && debug && uri.scheme == 'http')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError(
        development
            ? 'Development builds require debug mode and a local backend origin.'
            : 'Configure TRIVIA_API_BASE_URL as an HTTPS backend origin.',
      );
    }
  }
}
