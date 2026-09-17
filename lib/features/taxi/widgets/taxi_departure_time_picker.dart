import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';

const _taxiAccent = Color(0xFFF5A623);
const _taxiAccentForeground = Color(0xFF30210A);

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
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final accentText = theme.brightness == Brightness.dark
          ? const Color(0xFFFFC766)
          : const Color(0xFF855300);
      return Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 390,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 14, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '출발 시각 선택',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style:
                            TextButton.styleFrom(foregroundColor: accentText),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selected),
                        style: FilledButton.styleFrom(
                          backgroundColor: _taxiAccent,
                          foregroundColor: _taxiAccentForeground,
                        ),
                        child: const Text('완료'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 7),
                      Text(
                        '오늘과 내일 중 10분 단위로 선택할 수 있어요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
    },
  );
}
