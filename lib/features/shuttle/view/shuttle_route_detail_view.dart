import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/shared/widgets/scale_button.dart';
import 'package:hsro/features/shuttle/view/naver_map_station_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';

class ShuttleRouteDetailView extends StatefulWidget {
  final int scheduleId;
  final String routeName;
  final int round;
  final String startTime;

  const ShuttleRouteDetailView({
    Key? key,
    required this.scheduleId,
    required this.routeName,
    required this.round,
    required this.startTime,
  }) : super(key: key);

  @override
  _ShuttleRouteDetailViewState createState() => _ShuttleRouteDetailViewState();
}

class _ShuttleRouteDetailViewState extends State<ShuttleRouteDetailView> {
  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 정류장 경유 목록 조회
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.fetchScheduleStops(widget.scheduleId).then((success) {
        if (!success) {
          // 404 에러: 해당 스케줄의 정류장 정보가 없음
          _showNoStopsAlert(context);
        }
      });
    });
  }

  // 정류장 정보가 없을 때 안내 팝업 표시
  void _showNoStopsAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('알림'),
          content: Text('해당 스케줄의 정류장 정보가 없어요'),
          actions: [
            CupertinoDialogAction(
              child: Text('확인'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // 이전 화면으로 돌아가기
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('알림'),
          content: Text('해당 스케줄의 정류장 정보가 없어요'),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // 이전 화면으로 돌아가기
              },
            ),
          ],
        ),
      );
    }
  }

  static const Color _shuttleColor = Color(0xFFB83227);
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // 다크 모드에서는 셔틀 빨강을 밝은 톤으로 바꿔 대비를 맞춘다
  Color get _accentColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.redAccent
      : _shuttleColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '노선 상세 정보',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Obx(() {
        // 로딩/빈 상태/목록 상태 전환
        if (viewModel.isLoadingStops.value) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderInfo(),
              const Expanded(
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            ],
          );
        }
        if (viewModel.scheduleStops.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderInfo(),
              Expanded(
                child: Center(
                  child: Text(
                    '정류장 정보를 불러올 수 없어요',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ),
            ],
          );
        }

        final stops = viewModel.scheduleStops;
        final list = ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeaderInfo(),
            // 정류장 경유 목록을 노선도로 표시. 화면에 목록 하나뿐이라 카드로 감싸지 않는다.
            for (var index = 0; index < stops.length; index++)
              _buildStopItem(context, index),
          ],
        );
        return Platform.isIOS ? list : Scrollbar(child: list);
      }),
    );
  }

  String _shortTime(String time) =>
      time.length > 5 ? time.substring(0, 5) : time;

  int? _minutesOf(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  // 첫 정류장과 마지막 정류장 시각 차이로 소요 시간 계산
  String? _durationLabel() {
    final stops = viewModel.scheduleStops;
    if (stops.length < 2) return null;
    final start = _minutesOf(stops.first.arrivalTime);
    final end = _minutesOf(stops.last.arrivalTime);
    if (start == null || end == null) return null;
    var minutes = end - start;
    if (minutes < 0) minutes += 24 * 60;
    if (minutes == 0) return null;
    if (minutes < 60) return '$minutes분';
    final rest = minutes % 60;
    return rest == 0 ? '${minutes ~/ 60}시간' : '${minutes ~/ 60}시간 $rest분';
  }

  Widget _buildHeaderInfo() {
    // stop_order가 1인 정류장 기준 출발 시각 계산
    var departureTime = widget.startTime;
    if (viewModel.scheduleStops.isNotEmpty) {
      final firstStop = viewModel.scheduleStops.firstWhere(
        (stop) => stop.stopOrder == 1,
        orElse: () => viewModel.scheduleStops.first,
      );
      departureTime = _shortTime(firstStop.arrivalTime);
    }

    final duration = _durationLabel();
    final summary = [
      '$departureTime 출발',
      if (viewModel.scheduleStops.isNotEmpty)
        '정류장 ${viewModel.scheduleStops.length}곳',
      ?duration,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.routeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).hintColor,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }

  // "천안아산역 [천캠방향]"을 이름과 보조 설명으로 나눈다
  (String, String?) _splitStationName(String raw) {
    final match = RegExp(r'^(.*?)\s*\[(.+)\]$').firstMatch(raw.trim());
    if (match == null) return (raw, null);
    final tag = match.group(2)!.replaceAllMapped(
          RegExp(r'(\S)방향$'),
          (m) => '${m.group(1)} 방향',
        );
    return (match.group(1)!, tag);
  }

  // 정류장 행 빌더
  Widget _buildStopItem(BuildContext context, int index) {
    final stops = viewModel.scheduleStops;
    final stop = stops[index];
    final isFirst = index == 0;
    final isLast = index == stops.length - 1;
    final theme = Theme.of(context);
    final (name, tag) = _splitStationName(stop.stationName);

    // 정류장 탭 시 정류장 상세 지도 화면으로 이동
    void openStation() {
      if (stop.stationId != null) {
        Get.to(() => NaverMapStationDetailView(stationId: stop.stationId!));
      } else {
        _showNoStationDetailAlert(context);
      }
    }

    // 줄 어디를 눌러도 이동한다. 누름 효과는 이름·화살표 부분(ScaleButton)에만 줘서
    // 시각과 노선 줄은 움직이지 않는다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        openStation();
      },
      child: SizedBox(
        height: 60,
        child: Stack(
          children: [
            // 정류장 이름과 오른쪽 화살표가 같은 줄로 읽히도록 줄 사이에 옅은 선을 둔다.
            // 노선 줄을 끊지 않게 이름이 시작하는 곳(24 + 시각 48 + 12 + 점 16 + 12)부터 긋는다.
            if (!isLast)
              Positioned(
                left: _stopTextStart,
                right: 16,
                bottom: 0,
                child: Container(
                  height: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
            _buildStopRow(
              context,
              stop,
              isFirst,
              isLast,
              name,
              tag,
              openStation,
            ),
          ],
        ),
      ),
    );
  }

  static const double _stopTextStart = 24 + 48 + 12 + 16 + 12;

  Widget _buildStopRow(
    BuildContext context,
    ScheduleStop stop,
    bool isFirst,
    bool isLast,
    String name,
    String? tag,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final accent = _accentColor;
    final isEndpoint = isFirst || isLast;
    return Padding(
          // 시각이 위 노선 제목과 같은 선(24)에서 시작한다.
          padding: const EdgeInsets.only(left: 24, right: 16),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  _shortTime(stop.arrivalTime),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isEndpoint ? FontWeight.w600 : FontWeight.w400,
                    color: isEndpoint
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontFeatures: _tabular,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 노선 줄과 정류장 점
              SizedBox(
                width: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isFirst
                                ? Colors.transparent
                                : accent.withValues(alpha: 0.32),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isLast
                                ? Colors.transparent
                                : accent.withValues(alpha: 0.32),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: isEndpoint ? 12 : 10,
                      height: isEndpoint ? 12 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // 빈 점 안쪽은 화면 바탕색으로 채워 노선 줄만 가린다.
                        color: isEndpoint
                            ? accent
                            : theme.scaffoldBackgroundColor,
                        border: isEndpoint
                            ? null
                            : Border.all(color: accent, width: 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // 앱 공통 누름 효과(살짝 작아짐 + 햅틱)
                child: ScaleButton(
                  onTap: onTap,
                  child: Container(
                    // 글자 사이 빈 곳을 눌러도 효과가 나도록 투명 바탕을 깐다.
                    color: Colors.transparent,
                    height: 60,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isEndpoint ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // 정류장 상세 정보가 없을 때 안내 팝업 표시
  void _showNoStationDetailAlert(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('정보 없음'),
          content: Text('이 정류장의 상세 정보가 없어요'),
          actions: [
            CupertinoDialogAction(
              child: Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('정보 없음'),
          content: Text('이 정류장의 상세 정보가 없어요'),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
}
