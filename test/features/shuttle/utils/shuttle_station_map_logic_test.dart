import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/utils/shuttle_station_map_logic.dart';

void main() {
  group('buildStationRouteIdMap', () {
    test('builds a station-id keyed route-id cache', () {
      final result = buildStationRouteIdMap([
        StationRouteMembership(
          stationId: 1,
          routeIds: [1, 2],
        ),
        StationRouteMembership(
          stationId: 7,
          routeIds: [4],
        ),
      ]);

      expect(result.keys, containsAll([1, 7]));
      expect(result[1], equals({1, 2}));
      expect(result[7], equals({4}));
    });
  });

  group('stationMatchesSelectedRouteIds', () {
    test('returns true when no filter is selected', () {
      expect(
        stationMatchesSelectedRouteIds(
          stationRouteIds: {1, 2},
          selectedRouteIds: {},
        ),
        isTrue,
      );
    });

    test('returns true when station shares at least one selected route', () {
      expect(
        stationMatchesSelectedRouteIds(
          stationRouteIds: {1, 2},
          selectedRouteIds: {2, 4},
        ),
        isTrue,
      );
    });

    test('returns false when station has no selected routes', () {
      expect(
        stationMatchesSelectedRouteIds(
          stationRouteIds: {6},
          selectedRouteIds: {1, 2, 4},
        ),
        isFalse,
      );
    });
  });

  group('resolveStationRouteNames', () {
    test('resolves route ids to route names in cache order', () {
      final routeNames = resolveStationRouteNames(
        routeIds: {1, 2, 4},
        routeNameById: {
          1: '아산-천안',
          2: '아산-천안',
          4: 'KTX',
        },
      );

      expect(routeNames, orderedEquals(['아산-천안', '아산-천안', 'KTX']));
    });

    test('falls back to route id text when a name is missing', () {
      final routeNames = resolveStationRouteNames(
        routeIds: [7],
        routeNameById: const {},
      );

      expect(routeNames, orderedEquals(['노선 7']));
    });
  });
}
