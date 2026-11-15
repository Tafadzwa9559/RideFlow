import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android and iOS launcher labels remain Trivia', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:label="Trivia"'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      expect(
        RegExp('<key>$key</key>\\s*<string>Trivia</string>').hasMatch(plist),
        isTrue,
        reason: key,
      );
    }
  });
}
