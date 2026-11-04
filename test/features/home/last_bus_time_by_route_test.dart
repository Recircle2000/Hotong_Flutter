import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/home/viewmodel/upcoming_departure_viewmodel.dart';

void main() {
  final day = DateTime(2026, 11, 5);
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  Map<String, dynamic> route(String from, String to, List<String> times) => {
    '출발지': from,
    '종점': to,
    '시간표': times,
  };

  test('출발지와 종점이 같은 노선은 묶어서 가장 늦은 한 대만 막차다', () {
    final result = lastBusTimeByRoute({
      'version': '2026.11.01',
      '810_DOWN': route('호서대학교 기점', '아산고속버스터미널', ['09:40', '18:10']),
      '820_DOWN': route('호서대학교 기점', '아산고속버스터미널', ['07:00', '19:20']),
      '821_DOWN': route('호서대학교 기점', '아산고속버스터미널', ['08:50']),
      '순환5_DOWN': route('호서대학교 기점', '천안아산역', ['19:45', '20:30']),
      '1000_DOWN': route('호서대학교 기점', '탕정면사무소 지중해마을', ['20:40']),
    }, day);

    // 800번대는 모두 820번 19:20 기준이라 810번 18:10은 막차가 아니다.
    expect(result['810_DOWN'], at(19, 20));
    expect(result['820_DOWN'], at(19, 20));
    expect(result['821_DOWN'], at(19, 20));
    // 종점이 다른 노선은 각자 막차를 갖는다.
    expect(result['순환5_DOWN'], at(20, 30));
    expect(result['1000_DOWN'], at(20, 40));
  });

  test('반대 방향이나 시간표가 빈 노선은 섞이지 않는다', () {
    final result = lastBusTimeByRoute({
      '810_DOWN': route('호서대학교 기점', '아산고속버스터미널', ['18:10']),
      '810_UP': route('아산시외버스터미널(환승정류장)', '호서대학교종점 건너', ['17:10']),
      '822_DOWN': route('호서대학교 기점', '아산고속버스터미널', []),
    }, day);

    expect(result['810_DOWN'], at(18, 10));
    expect(result['810_UP'], at(17, 10));
    expect(result.containsKey('822_DOWN'), isFalse);
  });
}
