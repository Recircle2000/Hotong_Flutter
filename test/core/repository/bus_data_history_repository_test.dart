import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hsro/core/repository/app_config_repository.dart';
import 'package:hsro/core/repository/bus_data_history_repository.dart';

void main() {
  const baseUrl = 'https://api.example.com';

  BusDataHistoryRepository repositoryWith(MockClient client) {
    return BusDataHistoryRepository(
      client: client,
      appConfig: AppConfigRepository(client: client, baseUrl: baseUrl),
    );
  }

  test('kind에 맞는 주소로 이력을 받아 파싱한다', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response.bytes(
        utf8.encode(jsonEncode([
          {
            'version': '2026.11.05',
            'effective_at': '2026-11-05T00:00:00Z',
            'note': '동계 감차',
            'changes': ['810 상행: 09:40 추가'],
          },
          {
            'version': '2026.11.01',
            'effective_at': '2026-11-01T00:00:00Z',
            'note': null,
            'changes': null,
          },
          {'version': 1},
        ])),
        200,
      );
    });

    final items = await repositoryWith(client).fetch(BusDataHistoryKind.route);

    expect(requested.toString(), '$baseUrl/api/bus-data/history?kind=static');
    expect(items, hasLength(2));
    expect(items.first.version, '2026.11.05');
    expect(items.first.note, '동계 감차');
    expect(items.first.changes, ['810 상행: 09:40 추가']);
    expect(items.last.note, isNull);
    expect(items.last.changes, isNull);
  });

  test('서버 오류는 예외로 올린다', () async {
    final client = MockClient((_) async => http.Response('not found', 404));
    expect(
      repositoryWith(client).fetch(BusDataHistoryKind.timetable),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('형식이 다르면 예외로 올린다', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    expect(
      repositoryWith(client).fetch(BusDataHistoryKind.timetable),
      throwsA(isA<FormatException>()),
    );
  });
}
