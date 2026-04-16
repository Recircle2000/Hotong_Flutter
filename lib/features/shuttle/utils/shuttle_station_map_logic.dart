import 'package:hsro/features/shuttle/models/shuttle_models.dart';

Map<int, Set<int>> buildStationRouteIdMap(
  Iterable<StationRouteMembership> memberships,
) {
  final stationRouteIdsByStationId = <int, Set<int>>{};

  for (final membership in memberships) {
    stationRouteIdsByStationId[membership.stationId] =
        membership.routeIds.toSet();
  }

  return stationRouteIdsByStationId;
}

bool stationMatchesSelectedRouteIds({
  required Set<int> stationRouteIds,
  required Set<int> selectedRouteIds,
}) {
  if (selectedRouteIds.isEmpty) {
    return true;
  }

  return stationRouteIds.any(selectedRouteIds.contains);
}

List<String> resolveStationRouteNames({
  required Iterable<int> routeIds,
  required Map<int, String> routeNameById,
}) {
  return routeIds
      .map((routeId) => routeNameById[routeId] ?? '노선 $routeId')
      .toList(growable: false);
}
