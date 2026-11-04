import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/features/notice/models/emergency_notice_model.dart';
import 'package:hsro/features/notice/widgets/emergency_notice_banner.dart';
import 'package:hsro/features/subway/models/subway_arrival_model.dart';
import 'package:hsro/features/subway/view/subway_schedule_view.dart';
import 'package:hsro/features/subway/viewmodel/subway_viewmodel.dart';
import 'package:hsro/features/subway/widgets/subway_segmented_control.dart';

class SubwayView extends StatefulWidget {
  final String stationName;

  const SubwayView({Key? key, required this.stationName}) : super(key: key);

  @override
  State<SubwayView> createState() => _SubwayViewState();
}

class _SubwayViewState extends State<SubwayView> {
  final SubwayViewModel controller = Get.put(SubwayViewModel());
  final PreferencesService _preferencesService = PreferencesService();
  late PageController _pageController;
  late RxString _selectedStation;

  @override
  void initState() {
    super.initState();
    // 전달받은 역명에 맞춰 초기 페이지와 선택값 설정
    final initialIndex = widget.stationName == '아산' ? 1 : 0;
    _selectedStation = (widget.stationName == '아산' ? '아산' : '천안').obs;
    _pageController = PageController(initialPage: initialIndex);

    // 첫 프레임 이후 좌우 스와이프 튜토리얼 노출
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSwipeTutorial());
  }

  void _showSwipeTutorial() async {
    // 이미 본 튜토리얼이면 다시 띄우지 않음
    final hasSeenTutorial = await _preferencesService.getBoolOrDefault(
      'has_seen_subway_swipe_tutorial',
      false,
    );

    if (hasSeenTutorial) return;

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swipe_rounded,
                  size: 32, color: Theme.of(context).hintColor),
              const SizedBox(height: 16),
              Text(
                '화면을 좌우로 밀면\n천안역과 아산역을 바꿔 볼 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    Get.back();
                    await _preferencesService.setBool(
                      'has_seen_subway_swipe_tutorial',
                      true,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: subwayLineColor(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    // 바깥 영역으로 닫아도 본 것으로 저장
    final isNowSeen = await _preferencesService.getBoolOrDefault(
      'has_seen_subway_swipe_tutorial',
      false,
    );
    if (!isNowSeen) {
      await _preferencesService.setBool('has_seen_subway_swipe_tutorial', true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onStationTapped(String station) {
    // 상단 토글 탭 시 해당 페이지로 전환
    if (_selectedStation.value == station) return;
    final pageIndex = station == '천안' ? 0 : 1;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // 선택 상태는 onPageChanged에서 최종 반영
  }

  void _onPageChanged(int index) {
    // 좌우 스와이프와 상단 토글 상태 동기화
    _selectedStation.value = index == 0 ? '천안' : '아산';
  }

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // 급행 표시 빨강
  Color _expressColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFF7A6E)
          : const Color(0xFFD23F31);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '지하철 도착 정보',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // 지하철 긴급 공지 배너
          const EmergencyNoticeBanner(
            category: EmergencyNoticeCategory.subway,
          ),
          // 역 선택 토글
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Obx(
              () => SubwaySegmentedControl(
                labels: const ['천안역', '아산역'],
                selectedIndex: _selectedStation.value == '천안' ? 0 : 1,
                onChanged: (i) => _onStationTapped(i == 0 ? '천안' : '아산'),
              ),
            ),
          ),
          // 실시간 상태와 시간표 이동 버튼
          _buildStatusBar(context),
          // 천안역/아산역 페이지 전환
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildStationContent(context, '천안'),
                _buildStationContent(context, '아산'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationContent(BuildContext context, String station) {
    // 역별 실시간 도착 정보와 하단 안내 구성
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        children: [
          Obx(() => _buildArrivalContent(context, station)),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    // 연결 상태 표시와 시간표 화면 이동 버튼
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
      child: Row(
        children: [
          Obx(() {
            final connected = controller.isConnected.value;
            return Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected
                        ? const Color(0xFF2E9E5B)
                        : hintColor.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connected ? '실시간 운행 정보' : '연결 중',
                  style: TextStyle(fontSize: 13, color: hintColor),
                ),
              ],
            );
          }),
          const Spacer(),
          TextButton.icon(
            // 시간표 화면으로 이동
            onPressed: () => Get.to(() =>
                SubwayScheduleView(initialStationName: _selectedStation.value)),
            icon: Icon(Icons.schedule_rounded, size: 18, color: hintColor),
            label: Text(
              '시간표 보기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalContent(BuildContext context, String station) {
    final hintColor = Theme.of(context).hintColor;
    if (!controller.isConnected.value &&
        (controller.arrivalInfo[station]?.isEmpty ?? true)) {
      return Padding(
        padding: const EdgeInsets.only(top: 96),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 16),
              Text('연결 중', style: TextStyle(color: hintColor)),
            ],
          ),
        ),
      );
    }

    final arrivals = controller.arrivalInfo[station] ?? [];

    if (arrivals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 96),
        child: Center(
          child: Text('도착 정보가 없어요', style: TextStyle(color: hintColor)),
        ),
      );
    }

    // 상행/하행으로 나눠 표시
    final upLine = arrivals.where((a) => a.updnLine.contains('상행')).toList();
    final downLine = arrivals.where((a) => a.updnLine.contains('하행')).toList();

    return Column(
      children: [
        _buildSection(context, '상행', '서울·청량리 방면', upLine),
        if (upLine.isNotEmpty && downLine.isNotEmpty)
          const SizedBox(height: 24),
        _buildSection(context, '하행', '신창·아산 방면', downLine),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String subTitle,
      List<SubwayArrival> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final hairline =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              const SubwayLineMark(),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                subTitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
        // 방향별로 한 장의 카드에 열차를 행으로 묶는다
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: hairline,
                  ),
                _buildArrivalRow(context, items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // "[6]번째 전역 (온양온천)"을 "6개 역 전"과 현재 위치로 나눈다
  (String, String?) _splitArrivalMessage(String raw) {
    var message = raw.trim();
    String? location;
    final match = RegExp(r'^(.*?)\s*\((.+)\)$').firstMatch(message);
    if (match != null) {
      message = match.group(1)!;
      location = match.group(2);
    }
    message = message
        .replaceAllMapped(
            RegExp(r'\[(\d+)\]번째 전역'), (m) => '${m.group(1)}개 역 전')
        .replaceAllMapped(RegExp(r'\[(\d+)\]'), (m) => m.group(1)!);
    return (message, location);
  }

  // 곧 도착하는 열차인지 판단
  bool _isImminent(String message) =>
      message.contains('진입') ||
      message.contains('도착') ||
      message.contains('전역 출발');

  Widget _buildArrivalRow(BuildContext context, SubwayArrival arrival) {
    // 열차번호 자릿수로 급행 구분
    final String digits =
        arrival.btrainNo?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final isExpress = digits.length == 4;
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    final (message, location) = _splitArrivalMessage(arrival.arvlMsg2);
    final imminent = _isImminent(message);
    final expressColor = _expressColor(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 행선지와 열차 번호
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${arrival.bstatnNm}행',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isExpress) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: expressColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '급행',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: expressColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((arrival.btrainNo ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      arrival.btrainNo!,
                      style: TextStyle(
                        fontSize: 12,
                        color: hintColor,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 도착 상태는 오른쪽 한 열에 맞춘다
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: imminent
                        ? subwayLineColor(context)
                        : theme.colorScheme.onSurface,
                    fontFeatures: _tabular,
                  ),
                ),
                if (location != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: TextStyle(fontSize: 12, color: hintColor),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        '실시간 정보는 실제 운행과 다를 수 있어요',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
      ),
    );
  }
}
