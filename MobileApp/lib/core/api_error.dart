import 'package:dio/dio.dart';

/// User-facing API validation messages, without request headers or credentials.
String apiErrorMessage(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  if (error is UnsupportedError) {
    return error.message ?? 'This feature is unavailable.';
  }
  if (error is StateError) {
    return error.message.toString();
  }
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final nested = data['errors'];
      if (nested is Map) {
        final messages = nested.values
            .expand((v) => v is List ? v : [v])
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join(' ');
      }
      if (nested is List) return nested.whereType<String>().join(' ');
      if (data['detail'] is String) {
        return data['detail'] as String;
      }
      final values = data.values
          .whereType<List>()
          .expand((v) => v)
          .whereType<String>()
          .toList();
      if (values.isNotEmpty) {
        return values.join(' ');
      }
    }
    if (data is List) {
      final messages = data.whereType<String>().toList();
      if (messages.isNotEmpty) {
        return messages.join(' ');
      }
    }
  }
  return 'Unable to reach Trivia. Check your connection and retry.';
}
