import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.com');
  });

  group('ShuttleRepository.fetchStationRouteMemberships', () {
    test('parses station route memberships response', () async {
      final repository = ShuttleRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/shuttle/stations/route-memberships');

          return http.Response(
            jsonEncode([
              {
                'station_id': 1,
                'route_ids': [1, 2, 4],
              },
              {
                'station_id': 7,
                'route_ids': [6],
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final memberships = await repository.fetchStationRouteMemberships();

      expect(memberships, hasLength(2));
      expect(memberships[0].stationId, 1);
      expect(memberships[0].routeIds, orderedEquals([1, 2, 4]));
      expect(memberships[1].stationId, 7);
      expect(memberships[1].routeIds, orderedEquals([6]));
    });

    test('returns an empty list for an empty response array', () async {
      final repository = ShuttleRepository(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final memberships = await repository.fetchStationRouteMemberships();

      expect(memberships, isEmpty);
    });
  });
}
