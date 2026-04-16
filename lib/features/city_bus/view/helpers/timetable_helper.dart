import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';

/// 시간표 관련 기능 모음
class TimetableHelper {
  /// 시간표 데이터 로드
  static Future<Map<String, dynamic>> loadTimetable() async {
    return await BusTimesLoader.loadBusTimes();
  }

  /// 시간표에서 대표 배차 간격 계산
  static String calculateInterval(List<dynamic> times) {
    if (times.length < 2) return '-';

    try {
      // 인접한 시간끼리 분 간격 계산
      List<int> intervals = [];
      for (int i = 0; i < times.length - 1; i++) {
        final current = _parseTime(times[i].toString());
        final next = _parseTime(times[i + 1].toString());
        intervals.add(_minutesBetween(current, next));
      }

      // 가장 자주 등장한 간격 찾기
      Map<int, int> frequency = {};
      intervals.forEach((interval) {
        frequency[interval] = (frequency[interval] ?? 0) + 1;
      });

      final mostCommon =
          frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      return '$mostCommon분';
    } catch (e) {
      // 시간 형식이 예상과 다르면 표시 생략
      return '-';
    }
  }

  /// 시간 문자열을 DateTime으로 변환
  static DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    // 날짜는 의미 없고 시:분 비교만 필요해서 임의 고정값 사용
    return DateTime(2024, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// 두 시간 사이 분 차이 계산
  static int _minutesBetween(DateTime time1, DateTime time2) {
    return time2.difference(time1).inMinutes;
  }
}
