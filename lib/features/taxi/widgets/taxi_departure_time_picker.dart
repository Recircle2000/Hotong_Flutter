import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';

Future<DateTime?> showTaxiDepartureTimePicker(
  BuildContext context, {
  required DateTime initialDateTime,
}) {
  final now = DateTime.now();
  final minimum = taxiDepartureMinimum(now: now);
  final maximum = taxiDepartureMaximum(now: now);
  var selected = normalizeTaxiDepartureInitial(initialDateTime, now: now);

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '출발 시각 선택',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('취소'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(sheetContext).pop(selected),
                    child: const Text('완료'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('오늘과 내일 중 10분 단위로 선택할 수 있어요.'),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: selected,
                minimumDate: minimum,
                maximumDate: maximum,
                minuteInterval: taxiDepartureMinuteInterval,
                use24hFormat: true,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
