import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/city_bus/utils/route_progress.dart';
import 'package:latlong2/latlong.dart';

// 테스트용 평면 좌표(m) → 위경도. RouteTrack의 평면 근사와 같은 기준을 쓴다.
const _lat0 = 36.8;
const _lng0 = 127.1;
final _metersPerLng = 111320 * math.cos(_lat0 * math.pi / 180);

LatLng _at(double x, [double y = 0]) =>
    LatLng(_lat0 + y / 110540, _lng0 + x / _metersPerLng);

void main() {
  group('직선 노선 (정류장 0m, 500m, 1000m)', () {
    final track = RouteTrack.build(
      [_at(0), _at(250), _at(500), _at(750), _at(1000)],
      [_at(0), _at(500), _at(1000)],
    )!;

    test('정류장 위치를 노선 거리로 계산한다', () {
      expect(track.stationS[0], closeTo(0, 0.5));
      expect(track.stationS[1], closeTo(500, 0.5));
      expect(track.stationS[2], closeTo(1000, 0.5));
    });

    test('정류장 직전이어도 지나기 전에는 다음 정류장으로 넘기지 않는다', () {
      final location = track.locate(_at(480));
      expect(location.index, 0);
      expect(location.progress, RouteTrack.maxProgress);
    });

    test('BIS가 다음 정류장 도착을 알리고 50m 안이면 도착으로 표시한다', () {
      final location = track.locate(_at(470), nodeIndex: 1);
      expect(location.index, 1);
      expect(location.progress, 0);
    });

    test('BIS가 먼저 넘어가도 50m보다 멀면 GPS를 따른다', () {
      final location = track.locate(_at(400), nodeIndex: 1);
      expect(location.index, 0);
      expect(location.progress, closeTo(0.8, 0.01));
    });

    test('BIS 순번이 늦어도 GPS가 정류장을 지났으면 지난 것으로 본다', () {
      final location = track.locate(_at(700), nodeIndex: 0);
      expect(location.index, 1);
      expect(location.progress, closeTo(0.4, 0.01));
    });

    test('지도선 옆으로 벗어난 GPS도 선분에 투영해 계산한다', () {
      final location = track.locate(_at(250, 15));
      expect(location.index, 0);
      expect(location.progress, closeTo(0.5, 0.01));
    });

    test('조금 뒤로 튄 GPS는 무시하고, 크게 뒤로 가면 새 위치를 쓴다', () {
      final small = track.locate(_at(560), previousS: 600);
      expect(small.s, 600);
      expect(small.progress, closeTo(0.2, 0.01));

      final large = track.locate(_at(100), previousS: 600);
      expect(large.index, 0);
      expect(large.progress, closeTo(0.2, 0.01));
    });

    test('마지막 정류장에서는 진행률이 0이다', () {
      final location = track.locate(_at(1000));
      expect(location.index, 2);
      expect(location.progress, 0);
    });
  });

  test('꼭짓점 사이가 먼 구간에서도 정류장에 닿기 전에는 도착으로 보지 않는다', () {
    // 꼭짓점 간격 600m, 정류장은 500m 지점. 310m의 버스는 가장 가까운 꼭짓점이 정류장과 같지만 아직 190m 전이다.
    final track = RouteTrack.build(
      [_at(0), _at(600), _at(1200)],
      [_at(0), _at(500), _at(1200)],
    )!;

    final location = track.locate(_at(310));
    expect(location.index, 0);
    expect(location.progress, closeTo(0.62, 0.01));
  });

  group('같은 길을 왕복하는 노선', () {
    // 가는 길(y=0)로 1000m 갔다가 10m 옆 오는 길(y=10)로 돌아온다
    final polyline = [
      _at(0),
      _at(250),
      _at(500),
      _at(750),
      _at(1000),
      _at(1000, 10),
      _at(750, 10),
      _at(500, 10),
      _at(250, 10),
      _at(0, 10),
    ];
    // 오는 길 정류장은 가는 길 차선에 더 가깝게(y=4) 찍혀 있다
    final stations = [
      _at(0),
      _at(250),
      _at(500),
      _at(750),
      _at(1000, 5),
      _at(750, 4),
      _at(500, 4),
      _at(250, 4),
      _at(0, 4),
    ];
    final track = RouteTrack.build(polyline, stations)!;

    test('오는 길 정류장을 오는 구간에 붙인다', () {
      for (var i = 1; i < track.stationS.length; i++) {
        expect(track.stationS[i], greaterThan(track.stationS[i - 1]));
      }
      expect(track.stationS[6], closeTo(1510, 1));
    });

    test('BIS 순번이 있으면 버스를 오는 구간에 붙인다', () {
      // 오는 길 x=300 지점의 버스가 GPS 오차로 가는 길 차선 위에 찍힘
      final withNode = track.locate(_at(300), nodeIndex: 6);
      expect(withNode.index, 6);
      expect(withNode.progress, closeTo(0.8, 0.02));
    });

    test('직전 위치가 있으면 버스를 오는 구간에 붙인다', () {
      final withPrevious = track.locate(_at(300), previousS: 1600);
      expect(withPrevious.index, 6);
    });
  });

  group('같은 차선을 두 번 지나는 노선 (24번 하행 각원사 구간)', () {
    // 같은 좌표로 갔다가 돌아온다. GPS 하나가 지도선 두 곳에 똑같이 가깝다.
    final polyline = [
      _at(0),
      _at(250),
      _at(500),
      _at(750),
      _at(1000),
      _at(750),
      _at(500),
      _at(250),
      _at(0),
    ];
    final stations = [
      _at(0),
      _at(250),
      _at(500),
      _at(750),
      _at(1000),
      _at(750),
      _at(500),
      _at(250),
      _at(0),
    ];
    final track = RouteTrack.build(polyline, stations)!;

    test('BIS가 회차 지점을 지났다고 하면 돌아오는 쪽으로 본다', () {
      final location = track.locate(_at(900), nodeIndex: 4);
      expect(location.index, 4);
      expect(location.s, closeTo(1100, 1));
      expect(location.progress, closeTo(0.4, 0.01));
    });

    test('BIS가 회차 전이라고 하면 가는 쪽으로 본다', () {
      final location = track.locate(_at(900), nodeIndex: 3);
      expect(location.index, 3);
      expect(location.s, closeTo(900, 1));
    });

    test('BIS 정보가 없으면 직전 위치에 가까운 쪽으로 본다', () {
      final location = track.locate(_at(900), previousS: 1050);
      expect(location.index, 4);
      expect(location.s, closeTo(1100, 1));
    });
  });

  group('BIS 정류장 순번 확인', () {
    const stops = [
      RouteStopRef(nodeOrd: 14, name: '불당이통'),
      RouteStopRef(nodeOrd: 15, name: '불당중흥2차프라디움'),
      RouteStopRef(nodeOrd: 17, name: '호수공원'),
      RouteStopRef(nodeOrd: 18, name: '아산역 건너'),
      RouteStopRef(nodeOrd: 24, name: 'LH14단지 건너'),
    ];

    test('순번과 이름이 같으면 그 정류장이다', () {
      expect(resolveStationIndex(stops, 15, '불당중흥2차프라디움'), 1);
    });

    test('정적 데이터 순번이 밀려 있으면 근처에서 이름으로 찾는다', () {
      // TAGO는 호수공원을 16번으로 보낸다
      expect(resolveStationIndex(stops, 16, '호수공원'), 2);
      expect(resolveStationIndex(stops, 17, '아산역 건너'), 3);
    });

    test('이름이 없으면 순번을 쓰지 않는다', () {
      expect(resolveStationIndex(stops, 24, '금강펜테리움 세교중학교'), isNull);
    });

    test('이름의 띄어쓰기 차이는 무시한다', () {
      expect(resolveStationIndex(stops, 18, '아산역건너'), 3);
    });

    test('순번이 없으면 null이다', () {
      expect(resolveStationIndex(stops, null, '호수공원'), isNull);
    });
  });

  group('실제 노선 데이터', () {
    final routes = Directory('assets/bus_routes')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .map((file) => file.uri.pathSegments.last.replaceAll('.json', ''))
        .where((route) => File('assets/bus_stops/$route.json').existsSync())
        .toList()
      ..sort();

    RouteTrack buildTrack(String route) {
      final geo = jsonDecode(
        File('assets/bus_routes/$route.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final coordinates =
          geo['features'][0]['geometry']['coordinates'] as List<dynamic>;
      final stops = jsonDecode(
        File('assets/bus_stops/$route.json').readAsStringSync(),
      )['response']['body']['items']['item'] as List<dynamic>;
      return RouteTrack.build(
        [
          for (final c in coordinates)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ],
        [
          for (final stop in stops)
            LatLng(
              double.parse(stop['gpslati'].toString()),
              double.parse(stop['gpslong'].toString()),
            ),
        ],
      )!;
    }

    test('모든 노선에서 정류장이 노선 순서대로 놓인다', () {
      expect(routes, isNotEmpty);
      for (final route in routes) {
        final track = buildTrack(route);
        for (var i = 1; i < track.stationS.length; i++) {
          expect(
            track.stationS[i],
            greaterThanOrEqualTo(track.stationS[i - 1]),
            reason: '$route 정류장 $i',
          );
        }
      }
    });

    test('회차·왕복 구간이 있는 노선도 정류장을 제 구간에 붙인다', () {
      for (final route in ['24_DOWN', '821_DOWN']) {
        final track = buildTrack(route);
        final worst = track.stationOffsets.reduce(math.max);
        expect(worst, lessThanOrEqualTo(80), reason: route);
      }
    });
  });
}
