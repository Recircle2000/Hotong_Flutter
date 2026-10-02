import 'package:firebase_messaging/firebase_messaging.dart';

/// 택시팟 푸시 알림 하나. [partyId]는 알림을 눌렀을 때 열 채팅방이다.
class TaxiPushMessage {
  const TaxiPushMessage({required this.partyId, this.title, this.body});

  final String partyId;
  final String? title;
  final String? body;
}

/// 기기의 푸시 기능. 테스트에서는 가짜로 바꾼다.
abstract class TaxiPushMessaging {
  /// OS 알림 권한을 요청하고 허용 여부를 돌려준다.
  Future<bool> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// 앱을 보고 있는 동안 도착한 알림.
  Stream<TaxiPushMessage> get onForegroundMessage;

  /// 백그라운드에 있던 앱을 알림으로 열었을 때.
  Stream<TaxiPushMessage> get onOpened;

  /// 꺼져 있던 앱을 알림으로 켰다면 그 알림.
  Future<TaxiPushMessage?> initialMessage();
}

class FirebaseTaxiPushMessaging implements TaxiPushMessaging {
  FirebaseTaxiPushMessaging([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<TaxiPushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_parse).where(_isTaxi).cast();

  @override
  Stream<TaxiPushMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_parse).where(_isTaxi).cast();

  @override
  Future<TaxiPushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _parse(message);
  }

  static bool _isTaxi(TaxiPushMessage? message) => message != null;

  static TaxiPushMessage? _parse(RemoteMessage message) {
    final partyId = message.data['party_id'];
    if (message.data['type'] != 'taxi_message' ||
        partyId is! String ||
        partyId.isEmpty) {
      return null;
    }
    return TaxiPushMessage(
      partyId: partyId,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}
