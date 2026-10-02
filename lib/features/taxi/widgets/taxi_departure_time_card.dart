import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:intl/intl.dart';

/// 5분 단위로 올림된 출발 시각이 지금부터 실제로 얼마 뒤인지 알려준다.
String _relativeDepartureLabel(DateTime departureAt, DateTime now) {
  final seconds = departureAt.difference(now).inSeconds;
  if (seconds <= 0) return '출발 시각이 지났어요';
  final minutes = (seconds / 60).ceil();
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final text = hours == 0
      ? '$minutes분'
      : rest == 0
      ? '$hours시간'
      : '$hours시간 $rest분';
  return '$text 후 출발';
}

/// 팟 생성 화면의 출발 시각 카드. 오늘/내일과 5분 단위 시각을 카드 안에서 고른다.
class TaxiDepartureTimeCard extends StatelessWidget {
  const TaxiDepartureTimeCard({
    super.key,
    required this.departureAt,
    required this.now,
    required this.onDayChanged,
    required this.onTimeChanged,
    this.footer,
  });

  final DateTime departureAt;
  final DateTime now;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<DateTime> onTimeChanged;

  /// 날짜·시각 선택 아래에 붙는 영역 (빠른 선택 칩, 안내 문구).
  final Widget? footer;

  /// 시트 없이 카드 안에서 오늘/내일과 시각을 바로 고른다.
  /// iOS는 네이티브 compact 시간 선택기, Android는 머티리얼 시계 선택기를 쓴다.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = theme.platform == TargetPlatform.iOS;
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final selectedDay = DateTime(
      departureAt.year,
      departureAt.month,
      departureAt.day,
    );
    final dayOffset = selectedDay == today ? 0 : 1;
    final minimum = taxiDepartureMinimum(now: now);
    final maximum = taxiDepartureMaximum(now: now);
    // 자정 직전에는 오늘 고를 수 있는 시각이 남지 않는다.
    final canPickToday =
        DateTime(minimum.year, minimum.month, minimum.day) == today;

    final dayStart = dayOffset == 0 ? today : tomorrow;
    final dayEnd = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day + 1,
    ).subtract(const Duration(minutes: taxiDepartureMinuteInterval));
    final pickerMinimum = minimum.isAfter(dayStart) ? minimum : dayStart;
    final pickerMaximum = dayEnd.isBefore(maximum) ? dayEnd : maximum;

    void selectDay(int? value) {
      if (value == null || value == dayOffset) return;
      if (value == 0 && !canPickToday) return;
      onDayChanged(value);
    }

    String dayLabel(DateTime day) => DateFormat('M/d E', 'ko').format(day);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: taxiCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '출발 시각',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _relativeDepartureLabel(departureAt, now),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: taxiAccentText(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DaySegment(
                          label: '오늘',
                          date: dayLabel(today),
                          selected: dayOffset == 0,
                          enabled: canPickToday,
                          onTap: () => selectDay(0),
                        ),
                      ),
                      Expanded(
                        child: _DaySegment(
                          label: '내일',
                          date: dayLabel(tomorrow),
                          selected: dayOffset == 1,
                          onTap: () => selectDay(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 116,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: taxiAccent, width: 1.5),
                ),
                child: isIOS
                    ? IOSCompactTimePickerField(
                        // 날짜나 선택 가능 범위가 바뀌면 네이티브 선택기를 새로 만든다.
                        key: ValueKey(
                          '${departureAt.millisecondsSinceEpoch}|'
                          '${pickerMinimum.millisecondsSinceEpoch}|'
                          '${pickerMaximum.millisecondsSinceEpoch}',
                        ),
                        initialDateTime: departureAt,
                        minimumDateTime: pickerMinimum,
                        maximumDateTime: pickerMaximum,
                        minuteInterval: taxiDepartureMinuteInterval,
                        onChanged: onTimeChanged,
                      )
                    : _MaterialTimeButton(
                        departureAt: departureAt,
                        minimum: pickerMinimum,
                        maximum: pickerMaximum,
                        onChanged: onTimeChanged,
                      ),
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

/// 오늘/내일 선택 칸. 위에는 오늘·내일, 아래에는 날짜와 요일을 보여준다.
class _DaySegment extends StatelessWidget {
  const _DaySegment({
    required this.label,
    required this.date,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final color = !enabled
        ? onSurface.withValues(alpha: 0.3)
        : selected
        ? onSurface
        : theme.colorScheme.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.cardColor
              : theme.cardColor.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 1),
            Text(
              date,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android용 시간 칸. 누르면 머티리얼 시계 선택기를 24시간 형식으로 연다.
class _MaterialTimeButton extends StatelessWidget {
  const _MaterialTimeButton({
    required this.departureAt,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final DateTime departureAt;
  final DateTime minimum;
  final DateTime maximum;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(departureAt),
      helpText: '출발 시각',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        final theme = Theme.of(context);
        // 택시 화면의 주황색 톤에 맞춘다.
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: taxiAccent,
              onPrimary: taxiAccentForeground,
              primaryContainer: taxiTint(context, 0.35),
              onPrimaryContainer: taxiAccentText(context),
              tertiaryContainer: taxiTint(context, 0.35),
              onTertiaryContainer: taxiAccentText(context),
            ),
            timePickerTheme: TimePickerThemeData(
              dialHandColor: taxiAccent,
              dialTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? taxiAccentForeground
                    : theme.colorScheme.onSurface,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: taxiAccentText(context),
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked == null) return;
    var value = DateTime(
      departureAt.year,
      departureAt.month,
      departureAt.day,
      picked.hour,
      picked.minute,
    );
    // 머티리얼 시계는 분 단위 제한이 없으므로 선택 가능 범위로 맞춘다.
    // 5분 단위 올림은 화면 상태를 바꿀 때 한 번 더 정리된다.
    if (value.isBefore(minimum)) value = minimum;
    if (value.isAfter(maximum)) value = maximum;
    onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pick(context),
        child: Center(
          child: Text(
            DateFormat('HH:mm').format(departureAt),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/// 지금 출발·20분 후처럼 자주 쓰는 출발 시각을 한 번에 고르는 칩.
class TaxiQuickTimeChip extends StatelessWidget {
  const TaxiQuickTimeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? taxiTint(context, 0.18) : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? taxiAccent
              : theme.colorScheme.onSurface.withValues(alpha: 0.12),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? taxiAccentText(context) : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
