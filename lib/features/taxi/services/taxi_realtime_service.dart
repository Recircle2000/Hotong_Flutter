import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TaxiRealtimeService {
  TaxiRealtimeService(this._authService);

  final AuthService _authService;
  final _events = StreamController<TaxiRealtimeEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _shouldRun = false;
  bool _isConnecting = false;
  int _retry = 0;

  Stream<TaxiRealtimeEvent> get events => _events.stream;

  Future<void> connect() async {
    _shouldRun = true;
    _reconnectTimer?.cancel();
    if (_channel != null || _isConnecting) return;
    _isConnecting = true;
    WebSocketChannel? pendingChannel;
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) return;
      final base = Uri.parse(EnvConfig.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/taxi',
        query: null,
      );
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
        pingInterval: const Duration(seconds: 25),
      );
      pendingChannel = channel;
      await channel.ready.timeout(const Duration(seconds: 5));
      if (!_shouldRun) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      pendingChannel = null;
      _retry = 0;
      _subscription = channel.stream.listen(
        _handleData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      await pendingChannel?.sink.close();
      _channel = null;
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) {
        _events.add(TaxiRealtimeEvent.fromJson(decoded));
      }
    } catch (_) {}
  }

  void sendMessage({
    required String partyId,
    required String clientMessageId,
    required String content,
  }) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('채팅 서버에 연결되어 있지 않습니다.');
    }
    channel.sink.add(jsonEncode({
      'type': 'message.send',
      'party_id': partyId,
      'client_message_id': clientMessageId,
      'content': content,
    }));
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (!_shouldRun || _reconnectTimer?.isActive == true) return;
    final seconds = _retry < 5 ? 1 << _retry : 30;
    _retry++;
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  Future<void> disconnect() async {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
