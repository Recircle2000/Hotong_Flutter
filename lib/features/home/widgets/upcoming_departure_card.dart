import 'package:flutter/material.dart';
import 'package:hsro/shared/widgets/auto_scroll_text.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

// 곧 출발/곧 도착 위젯 본문(섹션 제목 + 카드 3개)의 고정 높이
const double upcomingDepartureBodyHeight = 226;

// 남은 분을 표시 문구로 변환 (60분 이상은 '1시간 6분')
String formatMinutesLeft(int minutes) {
  if (minutes < 60) return '$minutes분';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
}

// 곧 출발/곧 도착 위젯에서 공통으로 쓰는 색상
class UpcomingDepartureColors {
  UpcomingDepartureColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // 공지·교통 메뉴 카드와 같은 면 색을 쓴다.
  static Color card(BuildContext context) => Theme.of(context).cardColor;
  static Color title(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xFF16181D);
  static Color secondary(BuildContext context) =>
      _isDark(context) ? Colors.grey[400]! : const Color(0xFF5B616E);
  static Color description(BuildContext context) =>
      _isDark(context) ? Colors.grey[300]! : const Color(0xFF3A3F4A);
  static Color muted(BuildContext context) =>
      _isDark(context) ? Colors.grey[500]! : const Color(0xFF8A909C);
  // 카드 안 줄 구분선: 제목 색을 아주 옅게
  static Color hairline(BuildContext context) =>
      title(context).withValues(alpha: 0.08);
}

// 시각·남은 분처럼 자리가 바뀌는 숫자는 고정폭으로 맞춘다.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

// 셔틀버스/시내버스 섹션 제목
class UpcomingDepartureSectionTitle extends StatelessWidget {
  const UpcomingDepartureSectionTitle(this.title, {super.key, this.caption});

  final String title;
  // 제목 옆에 작게 붙는 기준 안내 (예: 기점 출발 · 실시간)
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: title,
          children: [
            if (caption != null)
              TextSpan(
                text: '  $caption',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: UpcomingDepartureColors.secondary(context),
        ),
      ),
    );
  }
}

// 남은 시간(또는 남은 정류장)을 크게, 시각과 행선지를 보조로 보여주는 카드
class UpcomingDepartureCard extends StatelessWidget {
  const UpcomingDepartureCard({
    super.key,
    required this.primaryText,
    this.primaryColor,
    required this.description,
    required this.onTap,
    this.trailingText,
    this.routeLabel,
    this.routeColor = Colors.blue,
    this.isLastBus = false,
    this.scrollDescription = false,
    this.isRealtime = false,
    this.inGroup = false,
  });

  final String primaryText;
  // null이면 기본 제목 색상 사용
  final Color? primaryColor;
  final String? trailingText;
  final String? routeLabel;
  final Color routeColor;
  final String description;
  final bool isLastBus;
  // true면 긴 행선지를 말줄임표 대신 자동 스크롤로 표시
  final bool scrollDescription;
  // true면 실시간 위치 기반 정보임을 알리는 배지 표시
  final bool isRealtime;
  // true면 UpcomingDepartureCardGroup 안의 한 줄로 그린다(배경·간격은 그룹이 맡는다).
  final bool inGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 막차 배지 (카드 오른쪽 아래)
    final lastBusBadge = Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFFB42318).withValues(alpha: 0.25)
            : const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '막차',
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? const Color(0xFFFF8A80) : const Color(0xFFB42318),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: inGroup ? 0 : 8),
      child: ScaleButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // 그룹 안에서는 투명하게 두되, 줄 전체가 눌리도록 색은 채워 둔다.
            color: inGroup
                ? Colors.transparent
                : UpcomingDepartureColors.card(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    primaryText,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabularFigures,
                      color:
                          primaryColor ??
                          UpcomingDepartureColors.title(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isRealtime)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFEEF0F3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: UpcomingDepartureColors.title(
                                      context,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '실시간',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: UpcomingDepartureColors.title(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (trailingText != null)
                          Flexible(
                            child: Text(
                              trailingText!,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontFeatures: tabularFigures,
                                color: UpcomingDepartureColors.secondary(
                                  context,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (scrollDescription)
                Row(
                  children: [
                    if (routeLabel != null) ...[
                      Text(
                        routeLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: routeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: AutoScrollText(
                        // 목록이 갱신돼 행선지가 바뀌면 스크롤 다시 시작
                        key: ValueKey(description),
                        text: description,
                        height: 17,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: UpcomingDepartureColors.description(context),
                        ),
                      ),
                    ),
                    if (isLastBus) lastBusBadge,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (routeLabel != null)
                              TextSpan(
                                text: '$routeLabel ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: routeColor,
                                ),
                              ),
                            TextSpan(text: description),
                          ],
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: UpcomingDepartureColors.description(context),
                        ),
                      ),
                    ),
                    if (isLastBus) lastBusBadge,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 셔틀버스/시내버스 출발 정보 여러 줄을 카드 한 장으로 묶고 줄 사이에 구분선을 둔다.
class UpcomingDepartureCardGroup extends StatelessWidget {
  const UpcomingDepartureCardGroup({super.key, required this.children});

  // inGroup: true로 만든 UpcomingDepartureCard 목록
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: 12,
      endIndent: 12,
      color: UpcomingDepartureColors.hairline(context),
    );
    return Container(
      decoration: BoxDecoration(
        color: UpcomingDepartureColors.card(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) divider,
            children[index],
          ],
        ],
      ),
    );
  }
}
