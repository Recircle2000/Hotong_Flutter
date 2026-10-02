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
