import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departure_viewmodel.dart';

void main() {
  // 각원사(2)~호서대(천안) 구간 정류장 순번
  const stops24 = ['2', '3', '4', '5', '6', '7'];
  const stops81 = ['2', '3', '4'];

  test('남은 정거장 수를 계산하고 가까운 차부터 정렬한다', () {
    final buses = buildCeanRealtimeBuses(
      {
        '24_DOWN': [
          {'nodeord': 2, 'nodenm': '각원사'},
          {'nodeord': '6', 'nodenm': '호서대 전'},
        ],
        '81_DOWN': [
          {'nodeord': 3, 'nodenm': '중간 정류장'},
        ],
      },
      stops24,
      stops81,
    );

    expect(
      buses.map((bus) => (bus.routeName, bus.departureTime, bus.minutesLeft)),
      [('24', '호서대 전', 1), ('81', '중간 정류장', 1), ('24', '각원사', 5)],
    );
    expect(buses.every((bus) => bus.isRealtimeBus), isTrue);
    expect(buses.first.routeKey, '24_DOWN');
  });

  test('구간 밖이거나 이미 호서대에 도착한 차는 뺀다', () {
    final buses = buildCeanRealtimeBuses(
      {
        '24_DOWN': [
          {'nodeord': 1, 'nodenm': '회차지'},
          {'nodeord': 7, 'nodenm': '호서대(천안)'},
          {'nodeord': 12, 'nodenm': '구간 밖'},
        ],
      },
      stops24,
      stops81,
    );

    expect(buses, isEmpty);
  });

  test('운행 중인 차가 없어 노선 키가 빠진 메시지도 처리한다', () {
    expect(buildCeanRealtimeBuses({}, stops24, stops81), isEmpty);
    expect(
      buildCeanRealtimeBuses({'24_DOWN': null, '81_UP': []}, stops24, stops81),
      isEmpty,
    );
  });
}
