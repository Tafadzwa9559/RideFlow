import 'package:flutter_test/flutter_test.dart';
import 'package:rideflow_mobile/core/config.dart';

void main() {
  test(
    'Selected build origin and websocket scheme pass startup validation',
    () {
      AppConfig.validate();
      expect(
        AppConfig.websocket,
        startsWith(developmentBuild ? 'ws://' : 'wss://'),
      );
    },
  );

  test('Default builds require HTTPS origins', () {
    AppConfig.validateOrigin('https://trivia-backend-bze2.onrender.com');
    for (final origin in [
      'http://localhost:8000',
      'https://user:password@example.com',
      'https://example.com/api/v1/',
      'https://example.com?token=secret',
    ]) {
      expect(() => AppConfig.validateOrigin(origin), throwsStateError);
    }
  });

  test('Development builds accept only local origins in debug mode', () {
    for (final host in ['localhost', '127.0.0.1', '10.0.2.2', '[::1]']) {
      AppConfig.validateOrigin(
        'http://$host:8000',
        development: true,
        debug: true,
      );
    }
    for (final origin in [
      'https://trivia-backend-bze2.onrender.com',
      'http://localhost.attacker.example:8000',
      'http://localhost:8000/api/v1/',
      'http://user:password@localhost:8000',
    ]) {
      expect(
        () => AppConfig.validateOrigin(origin, development: true, debug: true),
        throwsStateError,
      );
    }
    expect(
      () =>
          AppConfig.validateOrigin('http://localhost:8000', development: true),
      throwsStateError,
    );
  });
}
