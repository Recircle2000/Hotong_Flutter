import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/view/taxi_party_create_view.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  testWidgets('마지막 단계의 만들기 버튼이 파티 생성 요청을 보낸다', (tester) async {
    const departure = TaxiLocation(
      id: 1,
      name: '아산캠퍼스',
      category: 'campus',
      sortOrder: 1,
      isActive: true,
    );
    const destination = TaxiLocation(
      id: 2,
      name: '천안아산역',
      category: 'station',
      sortOrder: 2,
      isActive: true,
    );
    var createRequests = 0;
    final departureAt = DateTime.now().add(const Duration(hours: 1));
    final repository = TaxiRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/taxi/parties') {
          createRequests += 1;
          return http.Response(
            jsonEncode({
              'id': '3e1334aa-973e-4761-aef4-185c1f93552d',
              'meeting_code': 'H7KP',
              'departure_location': {
                'id': departure.id,
                'name': departure.name,
                'category': departure.category,
                'sort_order': departure.sortOrder,
                'is_active': departure.isActive,
              },
              'destination_location': {
                'id': destination.id,
                'name': destination.name,
                'category': destination.category,
                'sort_order': destination.sortOrder,
                'is_active': destination.isActive,
              },
              'departure_summary': '정문 택시승강장',
              'destination_summary': null,
              'departure_at': departureAt.toUtc().toIso8601String(),
              'max_members': 4,
              'current_members': 1,
              'remaining_seats': 3,
              'status': 'recruiting',
              'is_owner': true,
              'is_member': true,
              'unread_count': 0,
              'member_note': null,
              'members': [],
              'cancellation_reason': null,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TaxiPartyCreateView(
                    locations: const [departure, destination],
                    repository: repository,
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('출발 거점'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(departure.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('도착 거점'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(destination.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      '정문 택시승강장',
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '택시팟 만들기'));
    await tester.pumpAndSettle();

    expect(createRequests, 1);
  });
}
