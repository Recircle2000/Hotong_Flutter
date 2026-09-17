import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';

void main() {
  final now = DateTime(2026, 9, 13, 14, 3, 20);

  test('minimum rounds up after the ten minute lead time', () {
    expect(
      taxiDepartureMinimum(now: now),
      DateTime(2026, 9, 13, 14, 20),
    );
  });

  test('maximum is the final ten minute slot of tomorrow', () {
    expect(
      taxiDepartureMaximum(now: now),
      DateTime(2026, 9, 14, 23, 50),
    );
  });

  test('initial value is rounded and clamped to the allowed range', () {
    expect(
      normalizeTaxiDepartureInitial(
        DateTime(2026, 9, 13, 15, 4),
        now: now,
      ),
      DateTime(2026, 9, 13, 15, 10),
    );
    expect(
      normalizeTaxiDepartureInitial(
        DateTime(2026, 9, 16),
        now: now,
      ),
      DateTime(2026, 9, 14, 23, 50),
    );
  });

  test('validation rejects too-soon, later-day and non-aligned values', () {
    expect(
      validateTaxiDepartureTime(DateTime(2026, 9, 13, 14, 10), now: now),
      isNotNull,
    );
    expect(
      validateTaxiDepartureTime(DateTime(2026, 9, 15), now: now),
      isNotNull,
    );
    expect(
      validateTaxiDepartureTime(DateTime(2026, 9, 13, 15, 5), now: now),
      isNotNull,
    );
    expect(
      validateTaxiDepartureTime(DateTime(2026, 9, 14, 23, 50), now: now),
      isNull,
    );
  });
}
