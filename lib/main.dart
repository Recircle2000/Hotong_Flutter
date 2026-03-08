import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'view/home_view.dart';
import 'utils/env_config.dart';
import 'utils/location_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'viewmodel/settings_viewmodel.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hsro/utils/bus_times_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 먼저 로드
  await dotenv.load(fileName: 'assets/.env');
  await FlutterNaverMap().init(
      clientId: EnvConfig.naverMapClientId,
      onAuthFailed: (ex) => switch (ex) {
            NQuotaExceededException(:final message) =>
              print("사용량 초과 (message: $message)"),
            NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException() =>
              print("인증 실패: $ex"),
          });

  print("앱 시작");
  // 위치 서비스 초기화
  await LocationService().initLocationService();
  // 화면 자동 회전 비활성화 - 세로 모드만 허용
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Settings ViewModel 등록
  Get.put(SettingsViewModel(), permanent: true);

  // RouteObserver 등록
  Get.put(RouteObserver<PageRoute>(), permanent: true);

  await BusTimesLoader.updateBusTimesIfNeeded();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final routeObserver = Get.find<RouteObserver<PageRoute>>();

    return GetMaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', ''), // 한국어
        Locale('en', ''), // 영어
      ],
      debugShowCheckedModeBanner: false,
      title: 'University Transport App',
      // 라우트 옵저버 등록
      navigatorObservers: [routeObserver],
      // lib/main.dart의 theme 부분 수정
      theme: ThemeData(
        primaryColor: Colors.white, // 주요 브랜드 색상
        scaffoldBackgroundColor:
            const Color(0xFFF8F9FA), // 앱의 기본 배경색 (현재: 밝은 회색 계열)
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FA), // 앱바 배경색 (배경과 동일하게 설정하여 일체감)
          foregroundColor: Colors.black, // 앱바의 텍스트 및 아이콘 색상
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        cardTheme: CardThemeData(
          color: Colors.grey[100], // 카드 위젯 스타일 (메뉴 버튼, 공지사항 박스 등)
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey, // 테마 생성의 기준이 되는 색상
          background: Colors.white, // 기본적인 배경색
          surface: Colors.white, // 카드, 다이얼로그 등의 표면 색상
          surfaceVariant: Colors.grey[100]!, // 약간 구분되는 표면 색상
          onSurfaceVariant: Colors.grey[800]!, // surfaceVariant 위의 텍스트 색상
          primary: Colors.grey[800]!, // 주요 포인트 색상 (캠퍼스 선택 토글 선택됨 등)
          onPrimary: Colors.white, // primary 색상 위의 텍스트/아이콘 색상
          secondary: Colors.grey[600]!, // 보조 포인트 색상
          onSecondary: Colors.white, // secondary 색상 위의 텍스트 색상
          tertiary: Colors.grey[400]!, // 세 번째 포인트 색상
          onTertiary: Colors.black, // tertiary 색상 위의 텍스트 색상
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.black), // 버튼 배경색
            foregroundColor:
                MaterialStateProperty.all(Colors.white), // 버튼 텍스트 색상
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFF121212), // 다크모드 주요 브랜드 색상 (더 어둡게 변경)
        scaffoldBackgroundColor: const Color(0xFF121212), // 다크모드 배경색 (더 어둡게 변경)
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212), // 다크모드 앱바 배경색 (배경색과 일치)
          foregroundColor: Colors.white, // 다크모드 앱바 텍스트/아이콘 색상
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        cardTheme: CardThemeData(
          color: Colors.grey[900], // 다크모드 카드 배경색 (배경보다 약간 밝게)
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey[900]!, // 다크모드 테마 기준 색상
          background: const Color(0xFF121212), // 배경색
          surface: Colors.grey[900]!, // 표면 색상 (카드 등)
          surfaceVariant: const Color(0xFF1E1E1E),
          onSurfaceVariant: Colors.grey[300]!,
          primary: Colors.grey[300]!, // 주요 포인트 색상 (다크모드에서는 밝은 회색)
          onPrimary: const Color(0xFF121212)!, // primary 위 텍스트 (어두운 색)
          secondary: Colors.grey[500]!, // 보조 포인트 색상
          onSecondary: Colors.black,
          tertiary: Colors.grey[600]!,
          onTertiary: Colors.white,
          brightness: Brightness.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor:
                MaterialStateProperty.all(Colors.white), // 다크모드 버튼 배경 (흰색)
            foregroundColor:
                MaterialStateProperty.all(Colors.black), // 다크모드 버튼 텍스트 (검정)
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        textTheme: Typography.whiteMountainView, // 다크모드 텍스트 스타일
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // 시스템 설정에 따라 테마 변경
      home: const HomeView(),
    );
  }
}
