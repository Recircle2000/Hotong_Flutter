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

  group('ShuttleRepository.fetchRouteStations', () {
    test('parses route stations response in stop order', () async {
      final repository = ShuttleRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/shuttle/routes/4/stations');

          return http.Response(
            jsonEncode([
              {
                'stop_order': 1,
                'station_id': 1,
                'station_name': '아산캠퍼스 [출발]',
              },
              {
                'stop_order': 2,
                'station_id': 15,
                'station_name': '천안아산역 [아캠방향]',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final stations = await repository.fetchRouteStations(4);

      expect(stations, hasLength(2));
      expect(stations[0].stopOrder, 1);
      expect(stations[0].stationId, 1);
      expect(stations[0].stationName, '아산캠퍼스 [출발]');
      expect(stations[1].stopOrder, 2);
      expect(stations[1].stationId, 15);
      expect(stations[1].stationName, '천안아산역 [아캠방향]');
    });
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
