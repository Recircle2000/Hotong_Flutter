import 'package:flutter/cupertino.dart';
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
  return '지금부터 $text 후 출발';
}

/// 팟 생성 화면의 출발 시각 카드. 오늘/내일과 5분 단위 시각을 카드 안에서 고른다.
class TaxiDepartureTimeCard extends StatelessWidget {
  const TaxiDepartureTimeCard({
    super.key,
    required this.departureAt,
    required this.now,
    required this.onDayChanged,
    required this.onTimeChanged,
  });

  final DateTime departureAt;
  final DateTime now;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<DateTime> onTimeChanged;

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

    // Android 세그먼트 버튼은 폭이 좁아 요일을 빼고 날짜만 보여준다.
    String dayLabel(String label, DateTime day) =>
        '$label ${DateFormat(isIOS ? 'M/d (E)' : 'M/d', 'ko').format(day)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: taxiTint(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '출발 시각',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: taxiAccentText(context),
                ),
              ),
              const Spacer(),
              Text(
                _relativeDepartureLabel(departureAt, now),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: taxiAccentText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: isIOS
                    ? _buildCupertinoDays(
                        theme,
                        dayOffset: dayOffset,
                        canPickToday: canPickToday,
                        todayLabel: dayLabel('오늘', today),
                        tomorrowLabel: dayLabel('내일', tomorrow),
                        onSelected: selectDay,
                      )
                    : _buildMaterialDays(
                        context,
                        dayOffset: dayOffset,
                        canPickToday: canPickToday,
                        todayLabel: dayLabel('오늘', today),
                        tomorrowLabel: dayLabel('내일', tomorrow),
                        onSelected: selectDay,
                      ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 92,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  Widget _buildCupertinoDays(
    ThemeData theme, {
    required int dayOffset,
    required bool canPickToday,
    required String todayLabel,
    required String tomorrowLabel,
    required ValueChanged<int?> onSelected,
  }) {
    Widget segment(String label, {bool enabled = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: enabled
              ? null
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
    return CupertinoSlidingSegmentedControl<int>(
      groupValue: dayOffset,
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      thumbColor: theme.cardColor,
      children: {
        0: segment(todayLabel, enabled: canPickToday),
        1: segment(tomorrowLabel),
      },
      onValueChanged: onSelected,
    );
  }

  Widget _buildMaterialDays(
    BuildContext context, {
    required int dayOffset,
    required bool canPickToday,
    required String todayLabel,
    required String tomorrowLabel,
    required ValueChanged<int?> onSelected,
  }) {
    final theme = Theme.of(context);
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(
          value: 0,
          label: Text(todayLabel, maxLines: 1),
          enabled: canPickToday,
        ),
        ButtonSegment(value: 1, label: Text(tomorrowLabel, maxLines: 1)),
      ],
      selected: {dayOffset},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onSelected(values.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: theme.cardColor.withValues(alpha: 0.6),
        selectedBackgroundColor: theme.cardColor,
        selectedForegroundColor: taxiAccentText(context),
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
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
        borderRadius: BorderRadius.circular(12),
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
      color: selected
          ? taxiTint(context, 0.18)
          : theme.colorScheme.onSurface.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? taxiAccent
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
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
