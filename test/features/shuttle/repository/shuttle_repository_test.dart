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

  group('ShuttleRepository journey APIs', () {
    test('parses downstream destination response', () async {
      final repository = ShuttleRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/shuttle/journey-destinations');
          expect(request.url.queryParameters['origin_station_id'], '1');
          expect(request.url.queryParameters['date'], '2026-08-24');
          return http.Response(
            jsonEncode([
              {'station_id': 2, 'station_name': '아산캠퍼스'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final destinations = await repository.fetchJourneyDestinations(
        originStationId: 1,
        date: '2026-08-24',
      );

      expect(destinations, hasLength(1));
      expect(destinations.single.stationId, 2);
      expect(destinations.single.stationName, '아산캠퍼스');
    });

    test('parses journey search response', () async {
      final repository = ShuttleRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/shuttle/journeys');
          expect(request.url.queryParameters['origin_station_id'], '1');
          expect(request.url.queryParameters['destination_station_id'], '2');
          return http.Response(
            jsonEncode({
              'schedule_type': 'Weekday',
              'schedule_type_name': '평일',
              'date': '2026-08-24',
              'origin_station_id': 1,
              'origin_station_name': '천안아산역',
              'destination_station_id': 2,
              'destination_station_name': '아산캠퍼스',
              'journeys': [
                {
                  'schedule_id': 10,
                  'route_id': 4,
                  'route_name': 'KTX 순환',
                  'origin_arrival_time': '08:10:00',
                  'destination_arrival_time': '08:35:00',
                  'origin_stop_order': 1,
                  'destination_stop_order': 3,
                  'duration_minutes': 25,
                  'intermediate_stop_count': 1,
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await repository.fetchJourneys(
        originStationId: 1,
        destinationStationId: 2,
        date: '2026-08-24',
      );

      expect(result.scheduleTypeName, '평일');
      expect(result.journeys.single.routeName, 'KTX 순환');
      expect(result.journeys.single.durationMinutes, 25);
      expect(result.journeys.single.intermediateStopCount, 1);
    });
  });
}
