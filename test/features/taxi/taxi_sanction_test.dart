import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'taxi_test_api.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  tearDown(Get.reset);

  final now = DateTime.now();
  Map<String, Object?> sanction(int id, String level, {Duration? length}) => {
    'id': id,
    'level': level,
    'reason': '약속 장소에 나오지 않았어요.',
    'starts_at': now.toUtc().toIso8601String(),
    'ends_at': length == null
        ? null
        : now.add(length).toUtc().toIso8601String(),
  };

  Future<TaxiHomeViewModel> launch(WidgetTester tester, TaxiTestApi api) async {
    Get.testMode = true;
    final auth = AuthService.unavailable();
    Get.put<AuthService>(auth);
    final viewModel = TaxiHomeViewModel(
      repository: api.repository,
      realtime: TaxiRealtimeService(auth),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      TaxiHomeView(onLogout: () async {}, viewModel: viewModel),
                ),
              ),
              child: const Text('택시 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('택시 열기'));
    await tester.pumpAndSettle();
    return viewModel;
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(
      find
          .descendant(of: find.byType(TaxiTabBar), matching: find.text(name))
          .last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('정지 안내는 한 번만 뜨고, 생성·참여를 막고 내정보에 표시한다', (tester) async {
    final suspended = sanction(
      7,
      'suspend_3d',
      length: const Duration(days: 3),
    );
    final api = TaxiTestApi()
      ..suspension = suspended
      ..notice = suspended;
    final viewModel = await launch(tester, api);

    expect(find.text('택시팟 이용이 제한됐어요'), findsOneWidget);
    expect(find.textContaining('고유번호(a1b2c3)'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(api.acknowledgedSanctions, [7]);

    // 다시 확인해도 이미 확인한 안내는 띄우지 않는다.
    await viewModel.refreshAll();
    await tester.pumpAndSettle();
    expect(find.text('택시팟 이용이 제한됐어요'), findsNothing);

    await tab(tester, '팟 생성');
    expect(find.textContaining('새 팟을 만들거나 참여할 수 없어요'), findsOneWidget);
    expect(find.textContaining('사유: 약속 장소에 나오지 않았어요.'), findsOneWidget);
    expect(find.text('이의제기'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);

    await tab(tester, '팟 검색');
    await tester.tap(find.text('아산캠퍼스 → 천안아산역').first);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '이용 제한 중이라 참여할 수 없어요'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('현재팟 확인하기'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tab(tester, '내정보');
    expect(find.textContaining('이용 제한 중 ·'), findsOneWidget);
    // 이의제기 때 알려줄 고유번호를 내정보에서 볼 수 있다.
    expect(find.text('a1b2c3'), findsOneWidget);
    expect(api.joins, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('경고는 안내만 하고 생성은 막지 않는다', (tester) async {
    final api = TaxiTestApi()..notice = sanction(3, 'warning');
    await launch(tester, api);

    expect(find.text('경고를 받았어요'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(api.acknowledgedSanctions, [3]);

    await tab(tester, '팟 생성');
    expect(find.textContaining('새 팟을 만들거나 참여할 수 없어요'), findsNothing);
    expect(find.text('어디로, 언제 출발하나요?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
