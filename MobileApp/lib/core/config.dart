const String baseUrl = String.fromEnvironment(
  'TRIVIA_API_BASE_URL',
  defaultValue: 'https://trivia-backend-bze2.onrender.com',
);

class AppConfig {
  static const api = baseUrl;
  static String get websocket {
    final origin = Uri.parse(api);
    return origin
        .replace(
          scheme: 'wss',
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
  static void validate() {
    final uri = Uri.tryParse(api);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError(
        'Configure TRIVIA_API_BASE_URL as an HTTPS backend origin.',
      );
    }
  }
}
