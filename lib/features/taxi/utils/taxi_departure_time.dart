// 셔틀을 놓친 직후처럼 바로 모여 출발하는 경우를 위해 5분 뒤부터, 5분 단위로 받는다.
// 서버(services/taxi.py)의 BOOKING_MIN_LEAD, DEPARTURE_MINUTE_INTERVAL과 같아야 한다.
const taxiDepartureMinuteInterval = 5;
const taxiDepartureMinimumLead = Duration(minutes: 5);

DateTime _ceilToTaxiInterval(DateTime value) {
  final local = value.toLocal();
  final remainder = local.minute % taxiDepartureMinuteInterval;
  final alreadyAligned = remainder == 0 &&
      local.second == 0 &&
      local.millisecond == 0 &&
      local.microsecond == 0;
  if (alreadyAligned) return local;

  final minutesToAdd = taxiDepartureMinuteInterval - remainder;
  return DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  ).add(Duration(minutes: minutesToAdd));
}

DateTime taxiDepartureMinimum({DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  return _ceilToTaxiInterval(current.add(taxiDepartureMinimumLead));
}

DateTime taxiDepartureMaximum({DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  return DateTime(
    current.year,
    current.month,
    current.day + 2,
  ).subtract(const Duration(minutes: taxiDepartureMinuteInterval));
}

DateTime normalizeTaxiDepartureInitial(
  DateTime candidate, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final minimum = taxiDepartureMinimum(now: current);
  final maximum = taxiDepartureMaximum(now: current);
  final rounded = _ceilToTaxiInterval(candidate);
  if (rounded.isBefore(minimum)) return minimum;
  if (rounded.isAfter(maximum)) return maximum;
  return rounded;
}

String? validateTaxiDepartureTime(
  DateTime value, {
  DateTime? now,
}) {
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  if (local.isBefore(current.add(taxiDepartureMinimumLead))) {
    return '출발 시각은 현재보다 5분 이후여야 합니다.';
  }
  if (local.isAfter(taxiDepartureMaximum(now: current))) {
    return '출발 시각은 오늘 또는 내일만 선택할 수 있습니다.';
  }
  if (local.minute % taxiDepartureMinuteInterval != 0 ||
      local.second != 0 ||
      local.millisecond != 0 ||
      local.microsecond != 0) {
    return '출발 시각은 5분 단위로 선택해야 합니다.';
  }
  return null;
}
