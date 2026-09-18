import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';

class TaxiTestApi {
  final activeIds = <String>[];
  final recentChatIds = <String>[];
  bool fail = false;
  int creates = 0;
  int joins = 0;
  int locationsReads = 0;
  int partyListReads = 0;
  int activeReads = 0;
  int recentChatReads = 0;
  int historyReads = 0;
  int detailReads = 0;
  final departure = DateTime.now().add(const Duration(hours: 1));
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

  int get totalReads =>
      locationsReads +
      partyListReads +
      activeReads +
      recentChatReads +
      historyReads +
      detailReads;

  void resetReads() {
    locationsReads = 0;
    partyListReads = 0;
    activeReads = 0;
    recentChatReads = 0;
    historyReads = 0;
    detailReads = 0;
  }

  Map<String, Object?> party(String id, {bool owner = false}) {
    final isRecent = recentChatIds.contains(id);
    final partyDeparture = isRecent
        ? DateTime.now().subtract(const Duration(hours: 1))
        : departure;
    return {
      'id': id,
      'meeting_code': 'H7KP',
      'departure_location': locations[0],
      'destination_location': locations[1],
      'departure_summary': '정문 택시승강장',
      'destination_summary': null,
      'departure_at': partyDeparture.toUtc().toIso8601String(),
      'max_members': 4,
      'current_members': 2,
      'remaining_seats': 2,
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
      'members': [],
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
      Object? result;
      if (path.endsWith('/locations')) {
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
          'items': [party('search-party')],
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
