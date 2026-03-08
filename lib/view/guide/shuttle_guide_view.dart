import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../shuttle_bus/shuttle_route_selection_view.dart';
import '../components/scale_button.dart';

class ShuttleGuideView extends StatelessWidget {
  const ShuttleGuideView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    const shuttleThemeColor = Color(0xFFB83227);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '셔틀버스 탑승 가이드',
          style: TextStyle(
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
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            children: [
              // 안내 사항
              _buildInfoBox(isDarkMode, shuttleThemeColor),
              const SizedBox(height: 24),

              // 셔틀버스 요금 안내
              _buildShuttleFareBox(isDarkMode, shuttleThemeColor),
              const SizedBox(height: 24),

              // 학교 자체 버스
              _buildUniversityBusSection(isDarkMode, shuttleThemeColor),
              const SizedBox(height: 24),

              // 관광 버스
              _buildTouristBusSection(isDarkMode, shuttleThemeColor),
              const SizedBox(height: 24),

              // 목적지 확인 방법
              _buildDestinationCheckSection(shuttleThemeColor),
            ],
          ),

          // 하단 버튼
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
                onTap: () => Get.to(() => ShuttleRouteSelectionView()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: shuttleThemeColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: shuttleThemeColor.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '셔틀버스 조회하러 가기',
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

  Widget _buildInfoBox(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_atm_rounded, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '셔틀버스 요금',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_bus, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              '학교 버스',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 28, top: 4),
          child: Text(
            '호서대 랩핑 적용된 버스',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(Get.context!).cardColor,
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
              // Container(
              //   height: 8,
              //   width: double.infinity,
              //   decoration: const BoxDecoration(
              //     borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              //     color: Color(0xFFB83227),
              //   ),
              // ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/tutorial_illustration/shttule_boarding_schoolbus.png',
                        width: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '탑승 시 태그',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '버스 내부에 있는 단말기에\n교통카드를 태그하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tour, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              '관광 버스',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 28, top: 4),
          child: Text(
            '여행사 관광버스',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),

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

        const SizedBox(height: 16),

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
    final imageWidget = Expanded(
      flex: 3,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            imageLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            imageDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
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
            height: 140,
            child: Icon(
              nextStepIcon,
              size: 50,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nextStepLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            nextStepDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).cardColor,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
              color: headerColor,
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: isImageLeft
                  ? [
                      imageWidget,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.east_rounded,
                            size: 18,
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200]),
                      ),
                      infoWidget,
                    ]
                  : [
                      infoWidget,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.east_rounded,
                            size: 18,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFB83227),
        borderRadius: BorderRadius.circular(25),
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
          const Icon(Icons.signpost_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '목적지 확인 방법',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                      fontFamily: 'Noto Sans KR',
                    ),
                    children: [
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
