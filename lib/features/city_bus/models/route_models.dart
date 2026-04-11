/// 버스 노선 관련 모델 클래스
class BusRoute {
  final String routeId; // 노선 ID
  final String displayName; // 표시 이름
  final String simpleName; // 간단 이름
  final String startPoint; // 출발지
  final String endPoint; // 종점
  final List<String> timetable; // 시간표

  BusRoute({
    required this.routeId,
    required this.displayName,
    required this.simpleName,
    required this.startPoint,
    required this.endPoint,
    required this.timetable,
  });

  /// 배차 간격 계산
  String calculateInterval() {
    if (timetable.length < 2) return '-';

    try {
      // 여기서 시간표에서 배차 간격 계산 로직 구현
      return '15분'; // 예시 값
    } catch (e) {
      return '-';
    }
  }
}

/// 버스 정류장 정보 모델
class BusStation {
  final int index; // 정류장 순서
  final String id; // 정류장 ID
  final String name; // 정류장 이름
  final String number; // 정류장 번호
  final double latitude; // 위도
  final double longitude; // 경도

  BusStation({
    required this.index,
    required this.id,
    required this.name,
    required this.number,
    required this.latitude,
    required this.longitude,
  });

  factory BusStation.fromJson(Map<String, dynamic> json, int index) {
    return BusStation(
      index: index,
      id: json['nodeid']?.toString() ?? '',
      name: json['nodenm']?.toString() ?? '정류장',
      number: json['nodeno']?.toString() ?? '',
      latitude: double.tryParse(json['gpslati']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['gpslong']?.toString() ?? '0') ?? 0.0,
    );
  }
}
