import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LegalContent {
  LegalContent(this.data, this.digest);
  final Map<String, dynamic> data;
  final String digest;
  String get version => data['version'] as String;
  String get status => data['status'] as String;
  String get attribution => data['attribution'] as String;
  String get reviewNotice => data['reviewNotice'] as String;
  String get effectiveDate =>
      data['effectiveDate'] as String? ?? 'To be confirmed';
  Map<String, dynamic> document(String id) =>
      (data['documents'] as Map<String, dynamic>)[id] as Map<String, dynamic>;

  Map<String, dynamic> acknowledgement() => {
    'version': version,
    'content_sha256': digest,
    'terms_accepted': status == 'published',
    'draft_acknowledged': status != 'published',
    'privacy_notice_presented': true,
    'privacy_consent_given': false,
    'method': 'unselected_checkbox',
  };

  static Future<LegalContent> load() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/legal/policies.json'),
    ) as Map<String, dynamic>;
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/legal/content-digest.json'),
    ) as Map<String, dynamic>;
    if (data['version'] != manifest['version']) {
      throw StateError('Legal content version mismatch.');
    }
    return LegalContent(data, manifest['sha256'] as String);
  }
}

/// Local acknowledgement only; not a server-verified contractual audit trail.
class LegalAcknowledgementStore {
  LegalAcknowledgementStore({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;

  Future<void> record(String verifiedPhone, LegalContent content) =>
      storage.write(
        key: 'trivia_legal_ack:$verifiedPhone:${content.version}',
        value: jsonEncode({
          'account_phone': verifiedPhone,
          'version': content.version,
          'content_sha256': content.digest,
          'status': content.status,
          'draft_acknowledged': content.status == 'draft',
          'terms_accepted': content.status == 'published',
          'privacy_notice_presented': true,
          'privacy_consent_given': false,
          'method': 'unselected_checkbox',
          'recorded_at_device_utc': DateTime.now().toUtc().toIso8601String(),
        }),
      );
}
