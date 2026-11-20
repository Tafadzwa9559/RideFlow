import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Uses the documented first-frame JWT authentication; no ticket endpoint.
/// Tokens are never included in the URL. Every event triggers an authoritative read.
class Realtime extends ChangeNotifier {
  Realtime({required this.url, required this.ticket, required this.reconcile});
  final String url;
  final Future<String> Function() ticket;
  final Future<void> Function() reconcile;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _heartbeat, _liveness;
  bool _closed = false;
  int _attempt = 0;
  String state = 'Disconnected';
  void _state(String value) {
    if (_closed) {
      return;
    }
    state = value;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_closed || url.isEmpty) {
      return;
    }
    _state('Connecting');
    try {
      final auth = await ticket();
      if (_closed) {
        return;
      }
      final uri = Uri.parse(url);
      final channel = kIsWeb
          ? WebSocketChannel.connect(uri)
          : IOWebSocketChannel.connect(
              uri,
              headers: {
                'Origin': uri
                    .replace(
                      scheme: uri.scheme == 'ws' ? 'http' : 'https',
                      path: '',
                      query: '',
                      fragment: '',
                    )
                    .toString(),
              },
            );
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 15));
      if (_closed) {
        await channel.sink.close();
        return;
      }
      channel.sink.add(jsonEncode({'token': auth}));
      _liveness = Timer(const Duration(seconds: 15), _reconnect);
      _subscription = channel.stream.listen(
        (raw) async {
          try {
            _liveness?.cancel();
            _liveness = Timer(const Duration(seconds: 60), _reconnect);
            final event = jsonDecode(raw as String) as Map<String, dynamic>;
            if (event['type'] == 'connection.ready') {
              _attempt = 0;
              _state('Connected');
              await reconcile();
            } else if (event['type'] != 'pong') {
              await reconcile();
            }
          } catch (_) {
            _state('Sync interrupted');
          }
        },
        onError: (_) => _reconnect(),
        onDone: _reconnect,
      );
      _heartbeat = Timer.periodic(
        const Duration(seconds: 25),
        (_) => channel.sink.add(jsonEncode({'type': 'ping'})),
      );
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    if (_closed || _retry?.isActive == true) {
      return;
    }
    _liveness?.cancel();
    _heartbeat?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _state('Reconnecting');
    _retry = Timer(
      Duration(seconds: min(30, 1 << min(_attempt++, 5))),
      connect,
    );
  }

  @override
  void dispose() {
    _closed = true;
    _retry?.cancel();
    _liveness?.cancel();
    _heartbeat?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
