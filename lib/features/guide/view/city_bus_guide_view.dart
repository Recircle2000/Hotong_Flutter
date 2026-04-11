import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/grouped_bus_view.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class CityBusGuideView extends StatefulWidget {
  const CityBusGuideView({super.key});

  @override
  State<CityBusGuideView> createState() => _CityBusGuideViewState();
}

class _CityBusGuideViewState extends State<CityBusGuideView> {
  // 0: 천안캠퍼스, 1: 아산캠퍼스
  int _selectedCampusIndex = 0;

  // 네이버 맵 컨트롤러
  NaverMapController? _mapController;

  // 캠퍼스 좌표
  final NLatLng _cheonanLoc =
      const NLatLng(36.830589281815676, 127.17974684136121);
  final NLatLng _asanLoc = const NLatLng(36.73846886386694, 127.07697982680475);

  @override
  void initState() {
    super.initState();
    // 설정값 반영
    try {
      final settings = Get.find<SettingsViewModel>();
      _selectedCampusIndex = settings.selectedCampus.value == '천안' ? 0 : 1;
    } catch (e) {
      // SettingsViewModel을 찾지 못한 경우 기본값(0: 천안) 사용
      _selectedCampusIndex = 0;
    }
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  // 위치 권한 요청
  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('위치 권한 확인 중 오류 발생: $e');
    }
  }

  // 캠퍼스 변경 시 지도 이동
  void _moveMapToCampus(int index) {
    if (_mapController == null) return;

    final targetLoc = index == 0 ? _cheonanLoc : _asanLoc;
    final cameraUpdate = NCameraUpdate.withParams(
      target: targetLoc,
      zoom: 16,
    );
    cameraUpdate.setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 1500));

    _mapController!.updateCamera(cameraUpdate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    const primaryColor = Colors.blue; // HomeView 스타일의 파란색

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _selectedCampusIndex == 0 ? '천안캠퍼스 시내버스' : '아산캠퍼스 시내버스',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: ScaleButton(
          onTap: () => Get.back(),
          child: Icon(
            Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // 캠퍼스 선택 토글 (천안/아산)
              _buildCampusToggle(isDarkMode, primaryColor),
              const SizedBox(height: 24),

              // 섹션 제목 (시내버스 핵심 정리)
              Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    _selectedCampusIndex == 0 ? '천안시 시내버스' : '아산시 시내버스',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 시내버스 정보 카드
              if (_selectedCampusIndex == 0)
                _buildCheonanContent(isDarkMode, primaryColor)
              else
                _buildAsanContent(isDarkMode, primaryColor),

              const SizedBox(height: 24),

              // 시내버스 요금 안내
              _buildCityBusFareCard(isDarkMode, primaryColor),

              const SizedBox(height: 32),

              // 정류장 지도
              _buildMapSection(isDarkMode),

              const SizedBox(height: 32),

              // 환승 혜택 카드
              _buildTransferBenefitSection(isDarkMode, primaryColor),
            ],
          ),

          // 하단 고정 버튼 (실시간 버스 위치 확인)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor.withOpacity(0.9),
                    theme.scaffoldBackgroundColor.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: ScaleButton(
                onTap: () => Get.to(() => CityBusGroupedView(
                      forcedCampus: _selectedCampusIndex == 0 ? '천안' : '아산',
                    )),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.place_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '자세한 정보 확인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 캠퍼스 선택 토글 위젯 빌더
  Widget _buildCampusToggle(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              title: '천안캠퍼스',
              isSelected: _selectedCampusIndex == 0,
              isDarkMode: isDarkMode,
              primaryColor: primaryColor,
              onTap: () {
                setState(() => _selectedCampusIndex = 0);
                _moveMapToCampus(0);
              },
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              title: '아산캠퍼스',
              isSelected: _selectedCampusIndex == 1,
              isDarkMode: isDarkMode,
              primaryColor: primaryColor,
              onTap: () {
                setState(() => _selectedCampusIndex = 1);
                _moveMapToCampus(1);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 토글 내 개별 버튼 위젯 빌더
  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required bool isDarkMode,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? Colors.grey[700] : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDarkMode ? Colors.white : primaryColor)
                : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  /// 천안캠퍼스 시내버스 정보 콘텐츠 빌더
  Widget _buildCheonanContent(bool isDarkMode, Color primaryColor) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  isDarkMode,
                  primaryColor,
                  number: '24',
                  numberSuffix: '번',
                  title: '천안역 경유',
                  description: '차암2통 방면',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  isDarkMode,
                  primaryColor,
                  number: '81',
                  numberSuffix: '번',
                  title: '두정동 경유',
                  description: '동우아파트 방면',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildGlowCard(isDarkMode, primaryColor),
      ],
    );
  }

  /// 아산캠퍼스 시내버스 정보 콘텐츠 빌더
  Widget _buildAsanContent(bool isDarkMode, Color primaryColor) {
    return Column(
      children: [
        _buildInfoCard(
          isDarkMode,
          primaryColor,
          number: '5',
          numberPrev: '순환',
          numberSuffix: '번',
          title: '천안아산역행',
          description: '배방역 - 지중해마을 경유\n약 50분 소요',
          fullWidth: true,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          isDarkMode,
          primaryColor,
          number: '1000',
          numberSuffix: '번',
          title: '천안아산역 경유',
          description: '천안아산역까지 평균 25분 소요\n탕정역-지중해마을 종점',
          fullWidth: true,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          isDarkMode,
          primaryColor,
          number: '800번대',
          numberSuffix: '버스',
          title: '배방 / 아산터미널 방면',
          description: '배방역인근 - 온양온천역 - 아산터미널',
          fullWidth: true,
        ),
      ],
    );
  }

  /// 시내버스 요금 안내 카드
  Widget _buildCityBusFareCard(bool isDarkMode, Color primaryColor) {
    final labelColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '시내버스 요금 안내',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? primaryColor.withOpacity(0.2)
                  : primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '카드',
                        style: TextStyle(
                          fontSize: 12,
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1,500원',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: primaryColor.withOpacity(0.25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현금',
                        style: TextStyle(
                          fontSize: 12,
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1,600원',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 시내버스 노선 정보 카드 위젯 빌더
  Widget _buildInfoCard(
    bool isDarkMode,
    Color primaryColor, {
    String? numberPrev,
    required String number,
    required String numberSuffix,
    required String title,
    required String description,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (numberPrev != null)
                Text(
                  numberPrev,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              if (numberPrev != null) const SizedBox(width: 4),
              Text(
                number,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                numberSuffix,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[100]!,
                ),
              ),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 터미널행 버스 강조 카드 위젯 빌더 (천안캠퍼스)
  Widget _buildGlowCard(bool isDarkMode, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '천안종합터미널',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
                fontFamily: 'Noto Sans KR',
              ),
              children: [
                TextSpan(text: '24번', style: TextStyle(color: primaryColor)),
                const TextSpan(text: ' / '),
                TextSpan(text: '81번', style: TextStyle(color: primaryColor)),
                const TextSpan(text: ' 모두 경유'),
              ],
            ),
          ),
          // const SizedBox(height: 8),
          // Text(
          //   '먼저 오는 버스가 정답!',
          //   style: TextStyle(
          //     fontSize: 14,
          //     fontWeight: FontWeight.w500,
          //     color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
          //   ),
          // ),
        ],
      ),
    );
  }

  /// 정류장 지도 위젯 빌더
  Widget _buildMapSection(bool isDarkMode) {
    final targetLoc = _selectedCampusIndex == 0 ? _cheonanLoc : _asanLoc;

    return Column(
      children: [
        Row(
          children: [
            //const Text('📍', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Text(
              '정류장 위치',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              children: [
                NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: targetLoc,
                      zoom: 16,
                    ),
                    mapType: NMapType.basic,
                    nightModeEnable: isDarkMode,
                    liteModeEnable: false,
                    //consumeSymbolTapEvents: true,
                    logoClickEnable: true,
                    contentPadding: const EdgeInsets.only(bottom: 0, left: 0),
                    // locationButtonEnable: false, // Deprecated in 1.4.0
                    rotationGesturesEnable: false, // 회전 제스처 비활성화
                    maxZoom: 18,
                    minZoom: 10,
                  ),
                  forceGesture: true,
                  onMapReady: (controller) {
                    _mapController = controller;

                    // 마커 추가
                    _mapController!.addOverlayAll({
                      // 천안캠퍼스 마커
                      NMarker(
                        id: 'cheonan_station',
                        position: _cheonanLoc,
                      ),
                      // 아산캠퍼스 마커
                      NMarker(
                        id: 'asan_station',
                        position: _asanLoc,
                      ),
                    });
                  },
                ),
                // 정류장 위치 보기 버튼 (및 내 위치 버튼)
                Positioned(
                  right: 10,
                  bottom: 50, // 네이버 로고 높이 고려
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withOpacity(1),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ScaleButton(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          onTap: () {
                            if (_mapController != null) {
                              _mapController!.setLocationTrackingMode(
                                  NLocationTrackingMode.follow);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withOpacity(1),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ScaleButton(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: const Icon(
                              Icons.directions_bus,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          onTap: () => _moveMapToCampus(_selectedCampusIndex),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 환승 혜택 안내 섹션 위젯 빌더
  Widget _buildTransferBenefitSection(bool isDarkMode, Color primaryColor) {
    final isCheonan = _selectedCampusIndex == 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            Color.lerp(primaryColor, Colors.black, 0.2)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.currency_exchange,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '환승 혜택 안내',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '1호선',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isCheonan) ...[
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                        fontFamily: 'Noto Sans KR',
                      ),
                      children: [
                        TextSpan(text: '전용 카드 필요 없이 '),
                        TextSpan(
                          text: '기존 카드 그대로',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                        ),
                        TextSpan(text: ',\n수도권 환승과 동일하게 적용됩니다.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '수도권 전철 1호선 평택역~신창역 구간에서 승하차 시 혜택 적용',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                        fontFamily: 'Noto Sans KR',
                      ),
                      children: [
                        TextSpan(text: 'K-패스 등록카드로 충청남도 주소지 검증을 받은 '),
                        TextSpan(
                          text: '충남 도민만',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline),
                        ),
                        TextSpan(text: '\n추후 환급 방식으로 적용됩니다.'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
