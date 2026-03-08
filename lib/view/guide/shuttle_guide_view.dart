import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/responsive_layout.dart';
import '../shuttle_bus/shuttle_route_selection_view.dart';
import '../components/scale_button.dart';

class ShuttleGuideView extends StatelessWidget {
  const ShuttleGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final layout = AppResponsive.of(context);
    const shuttleThemeColor = Color(0xFFB83227);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '셔틀버스 탑승 가이드',
          style: TextStyle(
            fontSize: layout.font(20),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: ScaleButton(
          onTap: () => Get.back(),
          child: Icon(
            Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
            color: theme.iconTheme.color,
            size: layout.icon(24),
          ),
        ),
      ),
      body: Stack(
        children: [
          AppPageFrame(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                layout.space(20),
                layout.space(24),
                layout.space(20),
                layout.space(100, maxScale: 1.10),
              ),
              children: [
                _buildInfoBox(isDarkMode, shuttleThemeColor),
                SizedBox(height: layout.space(24)),
                _buildShuttleFareBox(isDarkMode, shuttleThemeColor),
                SizedBox(height: layout.space(24)),
                _buildUniversityBusSection(isDarkMode, shuttleThemeColor),
                SizedBox(height: layout.space(24)),
                _buildTouristBusSection(isDarkMode, shuttleThemeColor),
                SizedBox(height: layout.space(24)),
                _buildDestinationCheckSection(shuttleThemeColor),
              ],
            ),
          ),

          // 하단 버튼
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                layout.space(20),
                layout.space(16),
                layout.space(20),
                layout.space(32),
              ),
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
                onTap: () => Get.to(() => ShuttleRouteSelectionView()),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: layout.space(16)),
                  decoration: BoxDecoration(
                    color: shuttleThemeColor,
                    borderRadius: BorderRadius.circular(layout.radius(25)),
                    boxShadow: [
                      BoxShadow(
                        color: shuttleThemeColor.withOpacity(0.4),
                        blurRadius: layout.space(4, maxScale: 1.08),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.white,
                        size: layout.icon(20),
                      ),
                      SizedBox(width: layout.space(8)),
                      Text(
                        '셔틀버스 조회하러 가기',
                        style: TextStyle(
                          fontSize: layout.font(18),
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

  Widget _buildInfoBox(bool isDarkMode, Color primaryColor) {
    final layout = AppResponsive.of(Get.context!);
    return Container(
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
        borderRadius: BorderRadius.circular(layout.radius(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: layout.space(10, maxScale: 1.08),
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(layout.space(8)),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: primaryColor,
              size: layout.icon(24),
            ),
          ),
          SizedBox(width: layout.space(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: layout.space(4, maxScale: 1.05)),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: layout.font(12),
                      height: 1.5,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    children: [
                      const TextSpan(text: '셔틀버스는 '),
                      TextSpan(
                        text: '학교 자체 버스',
                        style: TextStyle(
                            color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '와 '),
                      TextSpan(
                        text: '\n관광 버스',
                        style: TextStyle(
                            color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                          text:
                              ' 두 가지 형태로 운영됩니다. \n탑승하시는 버스 종류에 따라 교통카드 태그 방식이 상이합니다.'),
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

  Widget _buildShuttleFareBox(bool isDarkMode, Color primaryColor) {
    final layout = AppResponsive.of(Get.context!);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
        borderRadius: BorderRadius.circular(layout.radius(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: layout.space(10, maxScale: 1.08),
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(layout.space(10)),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(layout.radius(12)),
            ),
            child: Icon(
              Icons.local_atm_rounded,
              color: primaryColor,
              size: layout.icon(24),
            ),
          ),
          SizedBox(width: layout.space(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '셔틀버스 요금',
                  style: TextStyle(
                    fontSize: layout.font(15),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: layout.space(6, maxScale: 1.08)),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: layout.font(13),
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    children: const [
                      TextSpan(text: '기본요금 '),
                      TextSpan(
                        text: '1,300원',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB83227),
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

  Widget _buildUniversityBusSection(bool isDarkMode, Color primaryColor) {
    final layout = AppResponsive.of(Get.context!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.directions_bus,
              color: primaryColor,
              size: layout.icon(20),
            ),
            SizedBox(width: layout.space(8)),
            Text(
              '학교 버스',
              style: TextStyle(
                fontSize: layout.font(18),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
            left: layout.space(28),
            top: layout.space(4, maxScale: 1.05),
          ),
          child: Text(
            '호서대 랩핑 적용된 버스',
            style: TextStyle(fontSize: layout.font(14), color: Colors.grey),
          ),
        ),
        SizedBox(height: layout.space(12)),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(Get.context!).cardColor,
            borderRadius: BorderRadius.circular(layout.radius(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: layout.space(10, maxScale: 1.08),
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Container(
              //   height: 8,
              //   width: double.infinity,
              //   decoration: const BoxDecoration(
              //     borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              //     color: Color(0xFFB83227),
              //   ),
              // ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: layout.space(32)),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(layout.radius(16)),
                      child: Image.asset(
                        'assets/tutorial_illustration/shttule_boarding_schoolbus.png',
                        width: layout.space(180, maxScale: 1.10),
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: layout.space(16)),
                    Text(
                      '탑승 시 태그',
                      style: TextStyle(
                        fontSize: layout.font(16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: layout.space(4, maxScale: 1.05)),
                    Text(
                      '버스 내부에 있는 단말기에\n교통카드를 태그하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: layout.font(12),
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTouristBusSection(bool isDarkMode, Color primaryColor) {
    final layout = AppResponsive.of(Get.context!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tour, color: primaryColor, size: layout.icon(20)),
            SizedBox(width: layout.space(8)),
            Text(
              '관광 버스',
              style: TextStyle(
                fontSize: layout.font(18),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
            left: layout.space(28),
            top: layout.space(4, maxScale: 1.05),
          ),
          child: Text(
            '여행사 관광버스',
            style: TextStyle(fontSize: layout.font(14), color: Colors.grey),
          ),
        ),
        SizedBox(height: layout.space(16)),

        // Case 1: 학교에서 탑승
        _buildTouristStepCard(
          isDarkMode,
          primaryColor,
          title: "학교에서 탑승할 때",
          imagePath:
              'assets/tutorial_illustration/shttule_boarding_fromschool_bigbus.png',
          imageLabel: "1. 태그",
          imageDesc: "외부 단말기 태그",
          nextStepIcon: Icons.directions_bus,
          nextStepLabel: "2. 탑승",
          nextStepDesc: "자유롭게 착석",
          isImageLeft: true,
          headerColor: const Color(0xFF374151),
        ),

        SizedBox(height: layout.space(16)),

        // Case 2: 학교 외 정류장에서 탑승
        _buildTouristStepCard(
          isDarkMode,
          primaryColor,
          title: "학교 외 정류장에서 탑승할 때",
          imagePath:
              'assets/tutorial_illustration/shttule_boarding_fromschool_bigbus.png',
          imageLabel: "2. 하차 시 태그",
          imageDesc: "외부 단말기 태그",
          nextStepIcon: Icons.login,
          nextStepLabel: "1. 탑승",
          nextStepDesc: "교통카드 없이 탑승",
          isImageLeft: false,
          headerColor: const Color(0xFF4B5563),
        ),
      ],
    );
  }

  Widget _buildTouristStepCard(
    bool isDarkMode,
    Color primaryColor, {
    required String title,
    required String imagePath,
    required String imageLabel,
    required String imageDesc,
    required IconData nextStepIcon,
    required String nextStepLabel,
    required String nextStepDesc,
    required bool isImageLeft,
    required Color headerColor,
  }) {
    final layout = AppResponsive.of(Get.context!);
    final imageWidget = Expanded(
      flex: 3,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: layout.space(140, maxScale: 1.10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(layout.radius(16)),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: layout.space(12)),
          Text(
            imageLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: layout.font(13),
            ),
          ),
          Text(
            imageDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: layout.font(10),
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );

    final infoWidget = Expanded(
      flex: 2,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: layout.space(140, maxScale: 1.10),
            child: Icon(
              nextStepIcon,
              size: layout.icon(50, maxScale: 1.12),
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          SizedBox(height: layout.space(12)),
          Text(
            nextStepLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: layout.font(13),
            ),
          ),
          Text(
            nextStepDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: layout.font(10),
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
        borderRadius: BorderRadius.circular(layout.radius(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: layout.space(10, maxScale: 1.08),
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: layout.space(20),
              vertical: layout.space(12),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(layout.radius(25)),
              ),
              color: headerColor,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: layout.icon(16),
                ),
                SizedBox(width: layout.space(8)),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: layout.font(14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(layout.space(16)),
            child: Row(
              children: isImageLeft
                  ? [
                      imageWidget,
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.space(8),
                        ),
                        child: Icon(Icons.east_rounded,
                            size: layout.icon(18),
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200]),
                      ),
                      infoWidget,
                    ]
                  : [
                      infoWidget,
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.space(8),
                        ),
                        child: Icon(Icons.east_rounded,
                            size: layout.icon(18),
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200]),
                      ),
                      imageWidget,
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCheckSection(Color primaryColor) {
    final layout = AppResponsive.of(Get.context!);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.space(20)),
      decoration: BoxDecoration(
        color: const Color(0xFFB83227),
        borderRadius: BorderRadius.circular(layout.radius(25)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: layout.space(10, maxScale: 1.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.signpost_rounded,
            color: Colors.white,
            size: layout.icon(32),
          ),
          SizedBox(width: layout.space(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '목적지 확인 방법',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: layout.font(18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: layout.space(8)),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: layout.font(13),
                      height: 1.5,
                      fontFamily: 'Noto Sans KR',
                    ),
                    children: const [
                      TextSpan(text: '버스 전면 유리창 '),
                      TextSpan(
                        text: '좌측 하단',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: '의 행선지 표지판을 반드시 확인해주세요.'),
                    ],
                  ),
                ),
                SizedBox(height: layout.space(12)),
                Wrap(
                  spacing: layout.space(8),
                  runSpacing: layout.space(8),
                  children: [
                    _buildChip('아산캠퍼스'),
                    _buildChip('천안캠퍼스'),
                    _buildChip('KTX 순환(KTX 캠퍼스)'),
                    _buildChip('온양방면'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final layout = AppResponsive.of(Get.context!);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.space(10),
        vertical: layout.space(4, maxScale: 1.05),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(layout.radius(8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: layout.font(12),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
