import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/app/theme/app_scroll_behavior.dart';

void main() {
  testWidgets(
    'Android content does not stretch and pull-to-refresh still works',
    (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refreshes++;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 1600)],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, position.maxScrollExtent);
    },
  );

  testWidgets('iOS keeps its default bouncing scroll physics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView(children: const [SizedBox(height: 1600)]),
        ),
      ),
    );
    final context = tester.element(find.byType(ListView));
    expect(
      ScrollConfiguration.of(context).getScrollPhysics(context),
      isA<BouncingScrollPhysics>(),
    );
  });
}
