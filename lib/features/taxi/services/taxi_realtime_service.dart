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
  final _connected = StreamController<void>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _shouldRun = false;
  bool _isConnecting = false;
  int _retry = 0;

  Stream<TaxiRealtimeEvent> get events => _events.stream;

  /// 연결(재연결 포함)이 맺어질 때마다 알린다. 끊긴 동안 놓친 내용을 다시 불러오는 데 쓴다.
  Stream<void> get onConnected => _connected.stream;

  /// 앱이 백그라운드에 있던 동안 소켓이 죽었는지 알 수 없으므로,
  /// 기존 연결을 버리고 새로 연결한다.
  Future<void> reconnect() async {
    _shouldRun = true;
    _reconnectTimer?.cancel();
    _retry = 0;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    unawaited(subscription?.cancel());
    _closeQuietly(channel);
    await connect();
  }

  Future<void> connect() async {
    _shouldRun = true;
    _reconnectTimer?.cancel();
    if (_channel != null || _isConnecting) return;
    _isConnecting = true;
    WebSocketChannel? pendingChannel;
    try {
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        // 잠금 해제 직후처럼 토큰을 잠시 못 받는 경우에도 재시도를 이어간다.
        _scheduleReconnect();
        return;
      }
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
        connectTimeout: const Duration(seconds: 5),
      );
      pendingChannel = channel;
      await channel.ready.timeout(const Duration(seconds: 5));
      if (!_shouldRun) {
        pendingChannel = null;
        _closeQuietly(channel);
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
      if (!_connected.isClosed) _connected.add(null);
    } catch (_) {
      // 닫기를 기다리면 응답 없는 네트워크에서 재연결이 오래 막힌다.
      _closeQuietly(pendingChannel);
      _channel = null;
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  /// 죽었거나 맺어지지 않은 소켓은 닫기가 끝나지 않을 수 있어 기다리지 않는다.
  void _closeQuietly(WebSocketChannel? channel) {
    if (channel == null) return;
    unawaited(channel.sink.close().then((_) {}, onError: (_) {}));
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
      // 끊긴 상태에서 보내려 하면 바로 재연결을 시도한다.
      if (_shouldRun) unawaited(connect());
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
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    _closeQuietly(channel);
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _connected.close();
  }
}
