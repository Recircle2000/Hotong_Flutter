import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';

/// 실제 WebSocket 대신 테스트에서 이벤트를 직접 흘려보낸다.
class FakeTaxiRealtime extends TaxiRealtimeService {
  FakeTaxiRealtime() : super(AuthService.unavailable());

  final controller = StreamController<TaxiRealtimeEvent>.broadcast();

  @override
  Stream<TaxiRealtimeEvent> get events => controller.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async => controller.close();
}

class TaxiTestApi {
  final activeIds = <String>[];
  final recentChatIds = <String>[];
  bool fail = false;
  // 검색 결과 개수. 스크롤이 필요한 화면을 시험할 때 늘린다.
  int searchPartyCount = 1;
  // 팟의 현재 인원. 놓친 변경을 흉내낼 때 바꾼다.
  int currentMembers = 2;
  int creates = 0;
  int joins = 0;
  int locationsReads = 0;
  int partyListReads = 0;
  int activeReads = 0;
  int recentChatReads = 0;
  int historyReads = 0;
  int detailReads = 0;
  int markReads = 0;
  int? lastMarkedMessageId;
  // 팟 상세의 참여자 목록과 채팅 메시지. 신고 화면을 시험할 때 채운다.
  List<Map<String, Object?>> members = [];
  List<Map<String, Object?>> messages = [];
  // 설정하면 최근 메시지 응답에 "더 오래된 메시지 있음" 위치로 실리고,
  // before_id로 다시 물으면 olderMessages를 돌려준다.
  int? messagesNextBeforeId;
  List<Map<String, Object?>> olderMessages = [];
  // true면 메시지 조회가 서버 오류로 실패한다.
  bool failMessages = false;
  final reports = <Map<String, Object?>>[];
  // 제재 상태. /me/restriction 응답으로 그대로 내려간다.
  Map<String, Object?>? suspension;
  Map<String, Object?>? notice;
  final acknowledgedSanctions = <int>[];
  int restrictionReads = 0;
  // 서버로 나간 모든 요청. "GET /api/taxi/parties" 형태로 쌓인다.
  final requests = <String>[];
  // 서버에 등록된 알림 기기 토큰과 요청 순서.
  final pushTokens = <String, String>{};
  final pushCalls = <String>[];
  // 설정하면 신고 요청이 이 오류로 실패한다.
  ({int status, String code, String message})? reportError;
  final departure = DateTime.now().add(const Duration(hours: 1));
  // 이미 출발한 팟의 출발 시각. 서버처럼 조회할 때마다 같은 값을 준다.
  final recentDeparture = DateTime.now().subtract(const Duration(hours: 1));
  final locations = [
    {
      'id': 1,
      'name': '아산캠퍼스',
      'category': 'campus',
      'sort_order': 1,
      'is_active': true,
    },
    {
      'id': 2,
      'name': '천안아산역',
      'category': 'station',
      'sort_order': 2,
      'is_active': true,
    },
  ];

  int homeReads = 0;

  /// 조회(GET) 요청 수.
  int get totalReads => requests.where((r) => r.startsWith('GET ')).length;

  void resetReads() {
    locationsReads = 0;
    partyListReads = 0;
    activeReads = 0;
    recentChatReads = 0;
    historyReads = 0;
    detailReads = 0;
    homeReads = 0;
    requests.clear();
  }

  Map<String, Object?> party(String id, {bool owner = false}) {
    final isRecent = recentChatIds.contains(id);
    final partyDeparture = isRecent ? recentDeparture : departure;
    return {
      'id': id,
      'meeting_code': 'H7KP',
      'departure_location': locations[0],
      'destination_location': locations[1],
      'departure_summary': '정문 택시승강장',
      'destination_summary': null,
      'departure_at': partyDeparture.toUtc().toIso8601String(),
      'max_members': 4,
      'current_members': currentMembers,
      'remaining_seats': 4 - currentMembers,
      'status': isRecent ? 'in_progress' : 'recruiting',
      'recruitment_status': isRecent ? 'ended' : 'recruiting',
      'chat_status': 'writable',
      'chat_writable_until': partyDeparture
          .add(const Duration(hours: 3))
          .toUtc()
          .toIso8601String(),
      'chat_visible_until': partyDeparture
          .add(const Duration(hours: 48))
          .toUtc()
          .toIso8601String(),
      'is_owner': owner || id == 'created',
      'is_member': activeIds.contains(id),
      'unread_count': 3,
      'member_note': null,
      'members': members,
      'cancellation_reason': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  late final repository = TaxiRepository(
    baseUrl: 'http://taxi.test',
    client: MockClient((request) async {
      if (fail) {
        return http.Response(
          '{"detail":{"code":"OFFLINE","message":"연결 실패"}}',
          503,
        );
      }
      final path = request.url.path;
      final scope = request.url.queryParameters['scope'];
      requests.add(
        '${request.method} $path${scope == null ? '' : '?scope=$scope'}',
      );
      Object? result;
      if (path.endsWith('/home')) {
        // 묶음 조회. 거점과 이용 기록은 요청했을 때만 넣는다.
        homeReads++;
        final include = (request.url.queryParameters['include'] ?? '').split(
          ',',
        );
        if (include.contains('locations')) locationsReads++;
        if (include.contains('history')) historyReads++;
        result = {
          'locations': include.contains('locations') ? locations : null,
          'parties': {
            'items': [
              party('search-party'),
              for (var i = 1; i < searchPartyCount; i++)
                party('search-party-$i'),
            ],
            'next_cursor': null,
          },
          'my_parties': activeIds
              .where((id) => !recentChatIds.contains(id))
              .map((id) => party(id))
              .toList(),
          'recent_chats': recentChatIds.map((id) => party(id)).toList(),
          'history': include.contains('history') ? [] : null,
          'restriction': {
            'user_key': 'a1b2c3',
            'suspension': suspension,
            'notice': notice,
          },
        };
      } else if (path.endsWith('/me/restriction')) {
        restrictionReads++;
        result = {
          'user_key': 'a1b2c3',
          'suspension': suspension,
          'notice': notice,
        };
      } else if (path.endsWith('/me/push-token')) {
        final body = jsonDecode(request.body) as Map;
        final token = body['token'] as String;
        if (request.method == 'DELETE') {
          pushTokens.remove(token);
          pushCalls.add('remove:$token');
        } else {
          pushTokens[token] = body['platform'] as String;
          pushCalls.add('register:$token');
        }
        return http.Response('', 204);
      } else if (path.endsWith('/ack')) {
        acknowledgedSanctions.add(int.parse(path.split('/')[5]));
        notice = null;
        return http.Response('', 204);
      } else if (path.endsWith('/reports')) {
        final error = reportError;
        if (error != null) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'detail': {'code': error.code, 'message': error.message},
              }),
            ),
            error.status,
          );
        }
        reports.add(Map<String, Object?>.from(jsonDecode(request.body) as Map));
        result = {
          'id': reports.length,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        return http.Response(jsonEncode(result), 201);
      } else if (path.endsWith('/messages/read')) {
        markReads++;
        lastMarkedMessageId =
            (jsonDecode(request.body) as Map)['last_message_id'] as int?;
        result = {'ok': true};
      } else if (path.endsWith('/messages')) {
        if (failMessages) {
          return http.Response(
            jsonEncode({
              'detail': {'code': 'SERVER_ERROR', 'message': '일시적인 오류입니다.'},
            }),
            500,
          );
        }
        result = request.url.queryParameters.containsKey('before_id')
            ? {'items': olderMessages, 'next_before_id': null}
            : {'items': messages, 'next_before_id': messagesNextBeforeId};
      } else if (path.endsWith('/locations')) {
        locationsReads++;
        result = locations;
      } else if (path.endsWith('/my-parties')) {
        switch (request.url.queryParameters['scope']) {
          case 'history':
            historyReads++;
          case 'recent_chats':
            recentChatReads++;
          default:
            activeReads++;
        }
        result = switch (request.url.queryParameters['scope']) {
          'history' => [],
          'recent_chats' => recentChatIds.map((id) => party(id)).toList(),
          _ => activeIds.map((id) => party(id)).toList(),
        };
      } else if (path.endsWith('/join')) {
        joins++;
        final id = path.split('/')[4];
        activeIds.add(id);
        result = party(id);
      } else if (path.endsWith('/parties') && request.method == 'POST') {
        creates++;
        activeIds.add('created');
        result = party('created');
      } else if (path.endsWith('/parties')) {
        partyListReads++;
        result = {
          'items': [
            party('search-party'),
            for (var i = 1; i < searchPartyCount; i++) party('search-party-$i'),
          ],
        };
      } else {
        detailReads++;
        result = party(path.split('/').last);
      }
      return http.Response(
        jsonEncode(result),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}
