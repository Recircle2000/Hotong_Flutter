class ShuttleRoute {
  // 셔틀 노선 기본 정보 모델
  final int id;
  final String routeName;
  final String direction;

  ShuttleRoute({
    required this.id,
    required this.routeName,
    required this.direction,
  });

  factory ShuttleRoute.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 셔틀 노선 모델로 변환
    return ShuttleRoute(
      id: json['id'],
      routeName: json['route_name'],
      direction: json['direction'],
    );
  }
}

class StationRouteMembership {
  // 정류장별 노선 매핑 정보 모델
  final int stationId;
  final List<int> routeIds;

  StationRouteMembership({
    required this.stationId,
    required this.routeIds,
  });

  factory StationRouteMembership.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 정류장별 노선 매핑 모델로 변환
    return StationRouteMembership(
      stationId: json['station_id'],
      routeIds: (json['route_ids'] as List<dynamic>)
          .map((routeId) => routeId as int)
          .toList(growable: false),
    );
  }
}

class Schedule {
  // 특정 날짜의 셔틀 운행 회차 정보 모델
  final int id;
  final int routeId;
  final String scheduleType;
  final DateTime startTime;
  final DateTime endTime;
  final int round;

  Schedule({
    required this.id,
    required this.routeId,
    required this.scheduleType,
    required this.startTime,
    required this.endTime,
    required this.round,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // 시작/종료 시각을 같은 날짜 기준 DateTime으로 변환
    final startTime = _parseTime(json['start_time']);
    final endTime = _parseTime(
      json['end_time'],
      fallback: startTime,
    );

    return Schedule(
      id: json['id'],
      routeId: json['route_id'],
      scheduleType: json['schedule_type'],
      startTime: startTime,
      endTime: endTime,
      round: json['round'] ?? 1,
    );
  }

  static DateTime _parseTime(dynamic timeValue, {DateTime? fallback}) {
    // HH:mm:ss 문자열을 오늘 날짜 기준 DateTime으로 변환
    final timeStr = timeValue?.toString() ?? '';

    try {
      final now = DateTime.now();
      final timeParts = timeStr.split(':');
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return fallback ?? DateTime.now();
    }
  }
}

class ScheduleStop {
  // 회차별 정류장 경유 정보 모델
  final String stationName;
  final String arrivalTime;
  final int stopOrder;
  final int? stationId;

  ScheduleStop({
    required this.stationName,
    required this.arrivalTime,
    required this.stopOrder,
    this.stationId,
  });

  factory ScheduleStop.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 정류장 경유 정보로 변환
    return ScheduleStop(
      stationName: json['station_name'],
      arrivalTime: json['arrival_time'],
      stopOrder: json['stop_order'],
      stationId: json['station_id'],
    );
  }
}

class ShuttleStation {
  // 셔틀 정류장 상세 정보 모델
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final String? imageUrl;

  ShuttleStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.imageUrl,
  });

  factory ShuttleStation.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 정류장 모델로 변환
    return ShuttleStation(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      description: json['description'],
      imageUrl: json['image_url'],
    );
  }
}

class StationSchedule {
  // 특정 정류장 기준 도착 시간표 모델
  final int routeId;
  final String stationName;
  final String arrivalTime;
  final int stopOrder;
  final String scheduleType;
  final int scheduleId;

  StationSchedule({
    required this.routeId,
    required this.stationName,
    required this.arrivalTime,
    required this.stopOrder,
    required this.scheduleType,
    required this.scheduleId,
  });

  factory StationSchedule.fromJson(Map<String, dynamic> json) {
    // 서버 응답을 정류장 시간표 모델로 변환
    return StationSchedule(
      routeId: json['route_id'],
      stationName: json['station_name'],
      arrivalTime: json['arrival_time'],
      stopOrder: json['stop_order'],
      scheduleType: json['schedule_type'] ?? 'Weekday',
      scheduleId: json['schedule_id'],
    );
  }
}
