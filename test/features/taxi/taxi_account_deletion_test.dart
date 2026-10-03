import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/auth/repository/auth_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:hsro/features/taxi/view/tabs/taxi_profile_tab.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'taxi_test_api.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  tearDown(Get.reset);

  Future<void> openProfile(
    WidgetTester tester,
    Future<void> Function() onDeleteAccount,
  ) async {
    Get.testMode = true;
    final auth = AuthService.unavailable();
    Get.put<AuthService>(auth);
    final api = TaxiTestApi();
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TaxiHomeView(
                    onLogout: () async {},
                    onDeleteAccount: onDeleteAccount,
                    viewModel: TaxiHomeViewModel(
                      repository: api.repository,
                      realtime: TaxiRealtimeService(auth),
                    ),
                  ),
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
    await tester.tap(
      find
          .descendant(of: find.byType(TaxiTabBar), matching: find.text('내정보'))
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmDeletion(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('delete-account'));
    // 내정보 목록 맨 아래에 있어 처음에는 화면 밖이다.
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find
          .descendant(
            of: find.byType(TaxiProfileTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('탈퇴할까요?'), findsOneWidget);
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();
  }

  testWidgets('탈퇴를 확인하면 계정을 지우고 앱 첫 화면으로 돌아간다', (tester) async {
    var deleted = 0;
    await openProfile(tester, () async => deleted++);

    await confirmDeletion(tester);

    expect(deleted, 1);
    expect(find.text('택시 열기'), findsOneWidget);
    expect(find.text('탈퇴가 완료됐어요.'), findsOneWidget);
  });

  testWidgets('진행 중인 팟이 있어 거절되면 안내하고 화면에 남는다', (tester) async {
    await openProfile(
      tester,
      () async =>
          throw const AppAuthApiException(409, '진행 중인 택시팟을 먼저 나가거나 취소해주세요.'),
    );

    await confirmDeletion(tester);

    expect(find.text('진행 중인 택시팟을 먼저 나가거나 취소해주세요.'), findsOneWidget);
    expect(find.text('택시 열기'), findsNothing);
    expect(find.byType(TaxiTabBar), findsOneWidget);
  });
}
