import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const locationA = {
    'id': 1,
    'name': '아산캠퍼스',
    'category': 'campus',
    'sort_order': 1,
    'is_active': true,
  };
  const locationB = {
    'id': 2,
    'name': '천안아산역',
    'category': 'station',
    'sort_order': 2,
    'is_active': true,
  };

  Map<String, dynamic> partyJson({bool detail = false}) => {
    'id': '3e1334aa-973e-4761-aef4-185c1f93552d',
    'meeting_code': 'H7KP',
    'departure_location': locationA,
    'destination_location': locationB,
    'departure_summary': '정문 택시승강장',
    'destination_summary': '3번 출구',
    'departure_at': '2026-09-13T06:00:00Z',
    'max_members': 4,
    'current_members': 1,
    'remaining_seats': 3,
    'status': 'recruiting',
    'is_owner': true,
    'is_member': true,
    'unread_count': 2,
    if (detail) ...{
      'member_note': '검은 우산',
      'members': [
        {
          'label': '방장',
          'is_owner': true,
          'is_me': true,
          'joined_at': '2026-09-13T03:00:00Z',
        },
      ],
      'cancellation_reason': null,
      'created_at': '2026-09-13T03:00:00Z',
    },
  };

  test('목록 응답과 익명 상태를 해석한다', () async {
    late Uri requestedUri;
    final repository = TaxiRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'items': [partyJson()],
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final parties = await repository.getParties(
      date: DateTime(2026, 9, 13),
      departureLocationId: 1,
    );

    expect(requestedUri.path, '/api/taxi/parties');
    expect(requestedUri.queryParameters['date'], '2026-09-13');
    expect(requestedUri.queryParameters['departure_location_id'], '1');
    expect(parties.single.departureLocation.name, '아산캠퍼스');
    expect(parties.single.meetingCode, 'H7KP');
    expect(parties.single.unreadCount, 2);
    expect(parties.single.isOwner, isTrue);
  });

  test('수정 요청은 비어 있는 선택 항목을 null로 보낸다', () async {
    late Map<String, dynamic> body;
    final repository = TaxiRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode(partyJson(detail: true))),
          200,
        );
      }),
    );

    final party = await repository.updateParty(
      '3e1334aa-973e-4761-aef4-185c1f93552d',
      departureSummary: '정문 택시승강장',
      destinationSummary: null,
      memberNote: null,
    );

    expect(body['destination_summary'], isNull);
    expect(body['member_note'], isNull);
    expect(party.members.single.label, '방장');
  });

  test('최근 채팅 범위와 분리된 상태·기한을 해석한다', () async {
    late Uri requestedUri;
    final payload = partyJson()
      ..addAll({
        'status': 'in_progress',
        'recruitment_status': 'ended',
        'chat_status': 'read_only',
        'chat_writable_until': '2026-09-13T09:00:00Z',
        'chat_visible_until': '2026-09-15T06:00:00Z',
      });
    final repository = TaxiRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response.bytes(utf8.encode(jsonEncode([payload])), 200);
      }),
    );

    final parties = await repository.getMyParties(scope: 'recent_chats');

    expect(requestedUri.queryParameters['scope'], 'recent_chats');
    expect(parties.single.recruitmentStatus, 'ended');
    expect(parties.single.chatStatus, 'read_only');
    expect(
      parties.single.chatVisibleUntil.isAfter(parties.single.departureAt),
      isTrue,
    );
  });

  test('서버 오류 코드를 사용자 메시지와 함께 전달한다', () async {
    final repository = TaxiRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'detail': {
                'code': 'OVERLAPPING_PARTY',
                'message': '비슷한 시간에 참여 중인 택시팟이 있습니다.',
              },
            }),
          ),
          409,
        ),
      ),
    );

    expect(
      () => repository.joinParty('3e1334aa-973e-4761-aef4-185c1f93552d'),
      throwsA(
        isA<TaxiApiException>()
            .having((error) => error.code, 'code', 'OVERLAPPING_PARTY')
            .having((error) => error.statusCode, 'status', 409),
      ),
    );
  });

  test('실시간 이벤트의 파티 요약을 해석한다', () {
    final event = TaxiRealtimeEvent.fromJson({
      'type': 'message.created',
      'party_id': '3e1334aa-973e-4761-aef4-185c1f93552d',
      'party': partyJson()..['unread_count'] = 7,
    });

    expect(event.party?.id, '3e1334aa-973e-4761-aef4-185c1f93552d');
    expect(event.party?.unreadCount, 7);
  });
}
