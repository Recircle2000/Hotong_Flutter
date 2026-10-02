import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:hsro/app/theme/app_theme.dart';
import 'package:hsro/app/theme/app_scroll_behavior.dart';
import 'package:hsro/features/home/view/home_view.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final routeObserver = Get.find<RouteObserver<PageRoute>>();

    return GetMaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', ''), Locale('en', '')],
      debugShowCheckedModeBanner: false,
      title: 'University Transport App',
      scrollBehavior: const AppScrollBehavior(),
      navigatorObservers: [
        routeObserver,
        // Firebase 초기화에 실패했으면 화면 조회 기록 없이 앱을 그대로 띄운다.
        if (Firebase.apps.isNotEmpty)
          FirebaseAnalyticsObserver(
            analytics: FirebaseAnalytics.instance,
            nameExtractor: _screenName,
          ),
        if (NativeLiquidGlassUtils.supportsLiquidGlass)
          LiquidGlassNavigatorObserver(),
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeView(),
    );
  }
}

/// Get.to(() => FooView())는 경로 이름을 '/FooView'로 만든다. 첫 화면은 '/'다.
String? _screenName(RouteSettings settings) {
  final name = settings.name;
  if (name == null) return null;
  if (name == '/') return 'HomeView';
  return name.startsWith('/') ? name.substring(1) : name;
}
