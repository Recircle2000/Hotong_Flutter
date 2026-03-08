import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/emergency_notice_model.dart';
import '../../viewmodel/subway_viewmodel.dart';
import '../../models/subway_arrival_model.dart';
import '../components/emergency_notice_banner.dart';
import 'subway_schedule_view.dart';
import 'dart:io' show Platform;
import '../../services/preferences_service.dart';
import '../../utils/responsive_layout.dart';

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
    final initialIndex = widget.stationName == '아산' ? 1 : 0;
    _selectedStation = (widget.stationName == '아산' ? '아산' : '천안').obs;
    _pageController = PageController(initialPage: initialIndex);

    // Show swipe tutorial after frame build
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSwipeTutorial());
  }

  void _showSwipeTutorial() async {
    final hasSeenTutorial = await _preferencesService.getBoolOrDefault(
      'has_seen_subway_swipe_tutorial',
      false,
    );

    if (hasSeenTutorial) return;

    await Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(builder: (context) {
              final layout = AppResponsive.of(context);
              return Container(
                padding: EdgeInsets.all(layout.space(24)),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(layout.radius(20)),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.swipe,
                      size: layout.icon(48),
                      color: Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFF0052A4)
                          : const Color(0xFF478ED1),
                    ),
                    SizedBox(height: layout.space(16)),
                    Text(
                      '화면을 좌우로 밀어서\n천안역과 아산역을 전환해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: layout.font(16),
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: layout.space(24)),
                    ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await _preferencesService.setBool(
                          'has_seen_subway_swipe_tutorial',
                          true,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(layout.radius(12)),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: layout.space(32),
                            vertical: layout.space(12)),
                      ),
                      child: Text('확인',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      barrierDismissible: true,
    );

    // Ensure it's marked as seen even if dismissed via barrier
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
    if (_selectedStation.value == station) return;
    final pageIndex = station == '천안' ? 0 : 1;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // _selectedStation will be updated by onPageChanged
  }

  void _onPageChanged(int index) {
    _selectedStation.value = index == 0 ? '천안' : '아산';
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const EmergencyNoticeBanner(
              category: EmergencyNoticeCategory.subway,
            ),
            _buildStationSelector(context),
            SizedBox(height: layout.space(16)),
            _buildStatusBar(context),
            SizedBox(height: layout.space(24)),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildStationContent(context, '천안'),
                  _buildStationContent(context, '아산'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationContent(BuildContext context, String station) {
    final layout = AppResponsive.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: AppPageFrame(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
          child: Column(
            children: [
              Obx(() => _buildArrivalContent(context, station)),
              _buildFooter(context),
              SizedBox(height: layout.space(24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.space(16),
        layout.space(16),
        layout.space(16),
        layout.space(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
                color: Theme.of(context).colorScheme.onBackground,
                size: layout.icon(24)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Text(
            '지하철 도착 정보',
            style: TextStyle(
              fontSize: layout.font(20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: layout.space(24)),
        ],
      ),
    );
  }

  Widget _buildStationSelector(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
      child: Obx(() {
        final isCheonan = _selectedStation.value == '천안';
        return Container(
          padding: EdgeInsets.all(layout.space(4)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(layout.radius(12)),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: layout.space(10),
                offset: Offset(0, layout.space(2)),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  context,
                  text: '천안역',
                  isSelected: isCheonan,
                  onTap: () => _onStationTapped('천안'),
                ),
              ),
              SizedBox(width: layout.space(4)),
              Expanded(
                child: _buildToggleButton(
                  context,
                  text: '아산역',
                  isSelected: !isCheonan,
                  onTap: () => _onStationTapped('아산'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildToggleButton(BuildContext context,
      {required String text,
      required bool isSelected,
      required VoidCallback onTap}) {
    final layout = AppResponsive.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: layout.space(10)),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0052A4)
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(layout.radius(8)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0052A4).withOpacity(0.3),
                    blurRadius: layout.space(8),
                    offset: Offset(0, layout.space(2)),
                  )
                ]
              : [],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: layout.font(14),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _PulsingDot(),
              SizedBox(width: layout.space(8)),
              Text(
                '실시간 운행 정보',
                style: TextStyle(
                  fontSize: layout.font(12),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Get.to(() =>
                SubwayScheduleView(initialStationName: _selectedStation.value)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: layout.space(10),
                vertical: layout.space(6),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(layout.radius(20)),
                border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: layout.space(4),
                    offset: Offset(0, layout.space(2)),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: layout.icon(14),
                      color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: layout.space(4)),
                  Text(
                    '시간표 보기',
                    style: TextStyle(
                      fontSize: layout.font(12),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalContent(BuildContext context, String station) {
    final layout = AppResponsive.of(context);
    if (!controller.isConnected.value &&
        (controller.arrivalInfo[station]?.isEmpty ?? true)) {
      return Padding(
        padding: EdgeInsets.only(top: layout.space(100, maxScale: 1.12)),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator.adaptive(),
              SizedBox(height: layout.space(16)),
              Text('연결 중...',
                  style: TextStyle(color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      );
    }

    final arrivals = controller.arrivalInfo[station] ?? [];

    if (arrivals.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: layout.space(100, maxScale: 1.12)),
        child: Center(
            child: Text('도착 정보가 없습니다.',
                style: TextStyle(color: Theme.of(context).hintColor))),
      );
    }

    // Filter Up (상행) and Down (하행)

    final upLine = arrivals.where((a) => a.updnLine.contains('상행')).toList();
    final downLine = arrivals.where((a) => a.updnLine.contains('하행')).toList();

    return Column(
      children: [
        _buildSection(
            context, '상행', '(서울/청량리 방면)', upLine, Icons.arrow_circle_up),
        SizedBox(height: layout.space(24)),
        _buildSection(
            context, '하행', '(신창/아산 방면)', downLine, Icons.arrow_circle_down),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String subTitle,
      List<SubwayArrival> items, IconData icon) {
    final layout = AppResponsive.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF0052A4), size: layout.icon(20)),
            SizedBox(width: layout.space(8)),
            Text(
              title,
              style: TextStyle(
                fontSize: layout.font(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: layout.space(4)),
            Expanded(
              child: Text(
                subTitle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: layout.font(14),
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: layout.space(12)),
        ...items.map((item) => _buildArrivalCard(context, item)).toList(),
      ],
    );
  }

  Widget _buildArrivalCard(BuildContext context, SubwayArrival arrival) {
    final layout = AppResponsive.of(context);
    // 열차번호 자릿수로 급행 구분
    final String digits =
        arrival.btrainNo?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final isExpress = digits.length == 4;

    return Container(
      margin: EdgeInsets.only(bottom: layout.space(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(layout.radius(16)),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: layout.space(10),
            offset: Offset(0, layout.space(2)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: layout.space(6, maxScale: 1.08),
              color: const Color(0xFF0052A4), // Line Color
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(layout.space(16)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: layout.space(6),
                                  vertical: layout.space(2)),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0052A4),
                                borderRadius:
                                    BorderRadius.circular(layout.radius(4)),
                              ),
                              child: Text(
                                '1호선',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: layout.font(10),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isExpress) ...[
                              SizedBox(width: layout.space(6)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: layout.space(6),
                                    vertical: layout.space(2)),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(layout.radius(4)),
                                ),
                                child: Text(
                                  '급행',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: layout.font(10),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          arrival.btrainNo ?? '', // Train Number e.g. 1023호
                          style: TextStyle(
                            fontSize: layout.font(12),
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: layout.space(8)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${arrival.bstatnNm}행',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: layout.font(18),
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: layout.space(12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              arrival.arvlMsg2,
                              style: TextStyle(
                                fontSize: layout.font(16),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6B6B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final layout = AppResponsive.of(context);
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(12),
          vertical: layout.space(6),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(layout.radius(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline,
                size: layout.icon(14), color: Theme.of(context).hintColor),
            SizedBox(width: layout.space(6)),
            Text(
              '실시간 정보는 상황에 따라 다를 수 있습니다',
              style: TextStyle(
                fontSize: layout.font(10),
                fontWeight: FontWeight.w500,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  _PulsingDotState createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: layout.space(8),
          height: layout.space(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(_animation.value),
          ),
        );
      },
    );
  }
}
