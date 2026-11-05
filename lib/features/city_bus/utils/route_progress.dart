import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 정류장 목록 안에서 버스가 있는 위치. [index] 정류장을 지나 다음 정류장으로 가는 중이다.
class RouteBusLocation {
  const RouteBusLocation({
    required this.index,
    required this.progress,
    this.s,
  });

  /// 버스가 마지막으로 지난(또는 도착한) 정류장 인덱스
  final int index;

  /// [index] 정류장에서 다음 정류장까지 진행률 (0.0 ~ [RouteTrack.maxProgress])
  final double progress;

  /// 노선 출발점부터 버스까지 노선을 따라 잰 거리(m). 지도선이 없으면 null.
  final double? s;
}

/// 정류장 순번 확인용 정보
class RouteStopRef {
  const RouteStopRef({required this.nodeOrd, required this.name});

  final int? nodeOrd;
  final String name;
}

/// BIS가 알려 준 정류장 순번(nodeord)을 정류장 목록 인덱스로 바꾼다.
///
/// 앱의 정류장 데이터가 TAGO보다 오래되면 순번이 밀릴 수 있어(1000번 상행 사례),
/// 같은 순번의 정류장 이름이 BIS 정류장 이름과 같을 때만 믿는다.
/// 다르면 앞뒤 [searchRange] 안에서 같은 이름을 찾고, 없으면 null을 돌려준다.
int? resolveStationIndex(
  List<RouteStopRef> stops,
  int? nodeOrd,
  String? nodeName, {
  int searchRange = 3,
}) {
  if (nodeOrd == null || stops.isEmpty) return null;

  final exact = stops.indexWhere((stop) => stop.nodeOrd == nodeOrd);
  final target = _normalizeName(nodeName);
  if (target.isEmpty) {
    return exact >= 0 ? exact : null;
  }
  if (exact >= 0 && _normalizeName(stops[exact].name) == target) {
    return exact;
  }

  // 순번이 어긋났으면 기대 위치 근처에서 이름으로 찾는다 (가까운 쪽 우선)
  final center = exact >= 0
      ? exact
      : (nodeOrd - 1).clamp(0, stops.length - 1).toInt();
  for (var offset = 1; offset <= searchRange; offset++) {
    for (final i in [center - offset, center + offset]) {
      if (i >= 0 && i < stops.length && _normalizeName(stops[i].name) == target) {
        return i;
      }
    }
  }
  return null;
}

String _normalizeName(String? name) =>
    (name ?? '').replaceAll(RegExp(r'\s+'), '');

/// 노선 지도선(폴리라인)을 따라 정류장과 버스 위치를 계산한다.
///
/// 모든 위치를 지도선의 선분 위로 투영해 "출발점부터 노선을 따라 몇 m"(s)로 바꾼 뒤 비교한다.
/// 버스는 정류장의 s를 실제로 넘어야 그 정류장을 지난 것으로 본다.
class RouteTrack {
  RouteTrack._(
    this._points,
    this._cumulative,
    this._lat0,
    this.stationS,
    this.stationOffsets,
  );

  /// 진행률 상한. 정류장을 지나기 전에는 다음 정류장에 닿아 보이지 않게 한다.
  static const double maxProgress = 0.95;

  /// BIS가 다음 정류장 도착을 알렸을 때, 이 거리 안이면 도착으로 표시한다.
  static const double arrivalSnapMeters = 50;

  /// 같은 차량이 이 거리 미만으로 뒤로 가면 GPS 흔들림으로 보고 무시한다.
  static const double jitterMeters = 80;

  /// 지도선에서 이만큼 넘게 떨어진 GPS는 노선 위치로 쓰지 않는다.
  static const double maxOffRouteMeters = 300;

  static const int _candidatesPerStation = 8;

  // 정류장 순서를 어기는 조합에 주는 벌점(m)
  static const double _orderPenalty = 1e6;

  // 좁힌 구간의 투영이 이보다 멀면 전체 노선에서 다시 찾는다
  static const double _windowMissMeters = 100;

  // 가장 가까운 투영과 이만큼 안으로 비슷하면 같은 길의 다른 회차 후보로 본다
  static const double _ambiguityMeters = 25;

  final List<math.Point<double>> _points;
  final List<double> _cumulative;
  final double _lat0;

  /// 정류장별 노선 거리(m). 정류장 순서대로 줄어들지 않는다.
  final List<double> stationS;

  /// 정류장별 지도선에서 떨어진 거리(m)
  final List<double> stationOffsets;

  int get stationCount => stationS.length;

  double get length => _cumulative.last;

  /// 지도선과 정류장 좌표로 트랙을 만든다. 지도선 점이 2개 미만이거나 정류장이 없으면 null.
  static RouteTrack? build(List<LatLng> polyline, List<LatLng> stations) {
    if (polyline.length < 2 || stations.isEmpty) return null;

    final lat0 = polyline.first.latitude;
    final points = [for (final p in polyline) _toPlane(p, lat0)];
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + points[i - 1].distanceTo(points[i]));
    }

    // 정류장마다 지도선 위 후보 위치를 구한다 (선분 투영 거리의 국소 최소)
    final candidates = [
      for (final station in stations)
        _stationCandidates(_toPlane(station, lat0), points, cumulative),
    ];

    // 정류장 순서대로 s가 줄지 않으면서 벗어난 거리 합이 가장 작은 조합을 고른다.
    // 같은 길을 왕복하는 구간에서 반대편 차선에 붙는 것을 막는다.
    const tolerance = 5.0;
    final cost = <List<double>>[];
    final back = <List<int>>[];
    cost.add([for (final c in candidates.first) c.distance]);
    back.add(List.filled(candidates.first.length, 0));
    for (var k = 1; k < candidates.length; k++) {
      final prev = candidates[k - 1];
      final prevCost = cost[k - 1];
      final row = <double>[];
      final rowBack = <int>[];
      for (final c in candidates[k]) {
        var best = double.infinity;
        var bestJ = -1;
        for (var j = 0; j < prev.length; j++) {
          if (prev[j].s <= c.s + tolerance && prevCost[j] < best) {
            best = prevCost[j];
            bestJ = j;
          }
        }
        if (bestJ < 0) {
          // 순서를 지킬 수 없으면 가장 싼 이전 후보에 잇되 큰 벌점을 준다.
          // 순서를 지키는 조합이 하나라도 있으면 그쪽이 고르게 된다 (뒤에서 s를 단조로 맞춤).
          for (var j = 0; j < prev.length; j++) {
            if (prevCost[j] < best) {
              best = prevCost[j];
              bestJ = j;
            }
          }
          best += _orderPenalty;
        }
        row.add(best + c.distance);
        rowBack.add(bestJ);
      }
      cost.add(row);
      back.add(rowBack);
    }

    var j = 0;
    for (var i = 1; i < cost.last.length; i++) {
      if (cost.last[i] < cost.last[j]) j = i;
    }
    final chosen = List<_Projection>.filled(
      candidates.length,
      candidates.last[j],
    );
    for (var k = candidates.length - 1; k >= 0; k--) {
      chosen[k] = candidates[k][j];
      j = back[k][j];
    }

    final stationS = <double>[];
    for (final c in chosen) {
      stationS.add(stationS.isEmpty ? c.s : math.max(c.s, stationS.last));
    }

    return RouteTrack._(
      points,
      cumulative,
      lat0,
      stationS,
      [for (final c in chosen) c.distance],
    );
  }

  /// 버스 위치를 정류장 인덱스와 진행률로 바꾼다.
  ///
  /// [nodeIndex]: BIS 정류장 순번을 [resolveStationIndex]로 확인한 정류장 인덱스.
  /// [previousS]: 같은 차량의 직전 노선 거리.
  RouteBusLocation locate(
    LatLng bus, {
    int? nodeIndex,
    double? previousS,
  }) {
    final p = _toPlane(bus, _lat0);
    final last = stationS.length - 1;
    final k = nodeIndex?.clamp(0, last).toInt();

    // 투영할 구간을 좁혀 같은 길을 왕복하는 노선에서 반대편에 붙지 않게 한다
    double lo = double.negativeInfinity;
    double hi = double.infinity;
    // 같은 길을 두 번 지나 후보가 비슷하게 가까우면 이 구간에 가까운 쪽을 고른다
    double? preferLo;
    double? preferHi;
    if (k != null) {
      lo = stationS[math.max(0, k - 2)] - 200;
      hi = stationS[math.min(last, k + 3)] + 200;
      preferLo = stationS[k];
      preferHi = stationS[math.min(last, k + 1)];
    } else if (previousS != null) {
      lo = previousS - 300;
      hi = previousS + 3000;
      preferLo = previousS - jitterMeters;
      preferHi = previousS + 1500;
    }
    var projection = _project(p, lo, hi, preferLo, preferHi);
    if (projection == null || projection.distance > _windowMissMeters) {
      // 좁힌 구간에서 못 찾으면(새 회차 시작, 순번 착오) 전체 노선에서 다시 찾는다
      final global = _project(
        p,
        double.negativeInfinity,
        double.infinity,
        preferLo,
        preferHi,
      );
      if (global != null &&
          (projection == null || global.distance < projection.distance)) {
        projection = global;
      }
    }

    if (projection == null || projection.distance > maxOffRouteMeters) {
      // 지도선에서 너무 멀면 BIS 정류장에 둔다
      return RouteBusLocation(index: k ?? 0, progress: 0);
    }

    var s = projection.s;
    if (previousS != null && s < previousS && previousS - s < jitterMeters) {
      s = previousS;
    }

    var index = 0;
    for (var i = 0; i <= last; i++) {
      if (stationS[i] <= s) {
        index = i;
      } else {
        break;
      }
    }

    // BIS가 바로 다음 정류장 도착을 알렸고 거의 닿았으면 도착으로 표시
    if (k != null &&
        k == index + 1 &&
        stationS[k] - s <= arrivalSnapMeters) {
      return RouteBusLocation(index: k, progress: 0, s: s);
    }

    return RouteBusLocation(index: index, progress: _progress(index, s), s: s);
  }

  double _progress(int index, double s) {
    if (index >= stationS.length - 1) return 0;
    final segment = stationS[index + 1] - stationS[index];
    if (segment <= 0) return 0;
    return ((s - stationS[index]) / segment).clamp(0.0, maxProgress).toDouble();
  }

  /// 노선 거리 [lo]~[hi] 구간에서 가장 가까운 투영을 찾는다.
  /// [preferLo]~[preferHi]가 주어지면, 가장 가까운 것과 [_ambiguityMeters] 안으로 비슷한 후보 중
  /// 그 구간에 가까운 것을 고른다 (같은 길을 두 번 지나는 구간).
  _Projection? _project(
    math.Point<double> p,
    double lo,
    double hi, [
    double? preferLo,
    double? preferHi,
  ]) {
    final candidates = <_Projection>[];
    _Projection? best;
    for (var i = 0; i < _points.length - 1; i++) {
      if (_cumulative[i + 1] < lo || _cumulative[i] > hi) continue;
      final projection = _projectOnSegment(p, _points, _cumulative, i);
      if (projection.s < lo || projection.s > hi) continue;
      candidates.add(projection);
      if (best == null || projection.distance < best.distance) {
        best = projection;
      }
    }
    if (best == null || preferLo == null || preferHi == null) return best;

    double gap(double s) => s < preferLo
        ? preferLo - s
        : s > preferHi
            ? s - preferHi
            : 0;

    var chosen = best;
    for (final c in candidates) {
      if (c.distance > best.distance + _ambiguityMeters) continue;
      final g = gap(c.s);
      final chosenGap = gap(chosen.s);
      if (g < chosenGap || (g == chosenGap && c.distance < chosen.distance)) {
        chosen = c;
      }
    }
    return chosen;
  }

  static List<_Projection> _stationCandidates(
    math.Point<double> p,
    List<math.Point<double>> points,
    List<double> cumulative,
  ) {
    final all = [
      for (var i = 0; i < points.length - 1; i++)
        _projectOnSegment(p, points, cumulative, i),
    ];
    final minima = <_Projection>[];
    for (var i = 0; i < all.length; i++) {
      final left = i > 0 ? all[i - 1].distance : double.infinity;
      final right = i + 1 < all.length ? all[i + 1].distance : double.infinity;
      if (all[i].distance <= left && all[i].distance <= right) {
        minima.add(all[i]);
      }
    }
    minima.sort((a, b) => a.distance.compareTo(b.distance));
    return minima.take(_candidatesPerStation).toList();
  }

  static _Projection _projectOnSegment(
    math.Point<double> p,
    List<math.Point<double>> points,
    List<double> cumulative,
    int i,
  ) {
    final a = points[i];
    final b = points[i + 1];
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();
    final q = math.Point(a.x + t * dx, a.y + t * dy);
    return _Projection(
      s: cumulative[i] + t * math.sqrt(lengthSquared),
      distance: p.distanceTo(q),
    );
  }

  // 위도 기준 등장방형 근사로 미터 단위 평면 좌표로 바꾼다 (노선 범위 수십 km에서 충분)
  static math.Point<double> _toPlane(LatLng p, double lat0) => math.Point(
        p.longitude * 111320 * math.cos(lat0 * math.pi / 180),
        p.latitude * 110540,
      );
}

class _Projection {
  const _Projection({required this.s, required this.distance});

  final double s;
  final double distance;
}
