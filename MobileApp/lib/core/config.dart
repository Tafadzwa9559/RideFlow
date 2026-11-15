class AppConfig {
  static const demo = bool.fromEnvironment('TRIVIA_DEMO', defaultValue: true);
  static const api = String.fromEnvironment('TRIVIA_API_URL');
  static const websocket = String.fromEnvironment('TRIVIA_WS_URL');
  static const mapTiles = String.fromEnvironment(
    'TRIVIA_MAP_TILES',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const privacy = String.fromEnvironment('TRIVIA_PRIVACY_URL');
  static const terms = String.fromEnvironment('TRIVIA_TERMS_URL');
  static void validate() {
    if (!demo &&
        (Uri.tryParse(api)?.scheme != 'https' ||
            Uri.tryParse(api)?.host.isEmpty != false)) {
      throw StateError(
        'Live service is not configured. Set an HTTPS TRIVIA_API_URL.',
      );
    }
    if (websocket.isNotEmpty && Uri.tryParse(websocket)?.scheme != 'wss') {
      throw StateError('A secure WebSocket URL is required.');
    }
  }
}
