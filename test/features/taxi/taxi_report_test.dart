import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_tab_bar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'taxi_test_api.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));
  tearDown(Get.reset);

  final joinedAt = DateTime.now().toUtc().toIso8601String();
  Map<String, Object?> member(
    String label, {
    bool owner = false,
    bool me = false,
  }) => {'label': label, 'is_owner': owner, 'is_me': me, 'joined_at': joinedAt};

  Future<void> pumpApp(WidgetTester tester, Widget Function() page) async {
    Get.testMode = true;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page())),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Future<void> openCurrentParty(WidgetTester tester, TaxiTestApi api) async {
    final auth = AuthService.unavailable();
    Get.put<AuthService>(auth);
    await pumpApp(
      tester,
      () => TaxiHomeView(
        onLogout: () async {},
        viewModel: TaxiHomeViewModel(
          repository: api.repository,
          realtime: TaxiRealtimeService(auth),
        ),
      ),
    );
    await tester.tap(
      find
          .descendant(of: find.byType(TaxiTabBar), matching: find.text('현재팟'))
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapMember(WidgetTester tester, String label) async {
    // 참여자 카드는 목록 아래쪽에 있어 스크롤해야 만들어진다.
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('current-party-pane')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submit = find.byKey(const ValueKey('report-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    // 버튼은 ScaleButton 안의 AbsorbPointer 아래에 있어 탭은 ScaleButton이 받는다.
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> submitReport(
    WidgetTester tester,
    TaxiReportReason reason,
  ) async {
    await tester.tap(find.byKey(ValueKey('report-reason-${reason.code}')));
    await tester.pumpAndSettle();
    await tapSubmit(tester);
  }

  testWidgets('팟 상세에서 다른 참여자를 신고한다', (tester) async {
    final api = TaxiTestApi()
      ..activeIds.add('p1')
      ..members = [member('방장', owner: true, me: true), member('참여자 1')];
    await openCurrentParty(tester, api);

    // 내 카드는 눌러도 아무 메뉴가 뜨지 않는다.
    await tapMember(tester, '방장');
    expect(find.text('신고하기'), findsNothing);

    await tapMember(tester, '참여자 1');
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    expect(find.text('참여자 1 신고'), findsOneWidget);

    await submitReport(tester, TaxiReportReason.noShow);

    expect(api.reports, [
      {
        'target_label': '참여자 1',
        'reason': 'no_show',
        'detail': null,
        'message_id': null,
      },
    ]);
    expect(find.text('참여자 1 신고'), findsNothing);
    expect(find.text('신고가 접수됐어요. 운영진이 확인할게요.'), findsOneWidget);
  });

  testWidgets('기타는 내용이 있어야 보내고, 서버 오류는 시트에 보여준다', (tester) async {
    final api = TaxiTestApi()
      ..activeIds.add('p1')
      ..members = [member('방장', owner: true), member('참여자 1', me: true)]
      ..reportError = (
        status: 409,
        code: 'ALREADY_REPORTED',
        message: '이미 신고한 참여자예요.',
      );
    await openCurrentParty(tester, api);
    await tapMember(tester, '방장');
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();

    await submitReport(tester, TaxiReportReason.other);
    expect(api.reports, isEmpty);
    expect(find.text('방장 신고'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('report-detail')),
      '연락이 안 돼요',
    );
    await tester.pumpAndSettle();
    await tapSubmit(tester);

    expect(find.text('이미 신고한 참여자예요.'), findsOneWidget);
    expect(find.text('방장 신고'), findsOneWidget);
  });

  testWidgets('채팅에서 다른 참여자 메시지를 길게 눌러 신고하고, 내 메시지는 바로 복사한다', (tester) async {
    final api = TaxiTestApi()..activeIds.add('p1');
    final sentAt = DateTime.now().toUtc().toIso8601String();
    api.messages = [
      {
        'id': 11,
        'party_id': 'p1',
        'message_type': 'chat',
        'sender_label': '참여자 1',
        'is_mine': false,
        'content': '안 갈게요',
        'created_at': sentAt,
      },
      {
        'id': 12,
        'party_id': 'p1',
        'message_type': 'chat',
        'sender_label': '방장',
        'is_mine': true,
        'content': '어디세요?',
        'created_at': sentAt,
      },
    ];
    final auth = AuthService.unavailable();
    Get.put<AuthService>(auth);
    final party = TaxiPartyDetail.fromJson(api.party('p1'));
    await pumpApp(
      tester,
      () => TaxiChatView(
        party: party,
        repository: api.repository,
        realtime: TaxiRealtimeService(auth),
      ),
    );

    await tester.longPress(find.text('어디세요?'));
    await tester.pumpAndSettle();
    expect(find.text('신고하기'), findsNothing);
    expect(find.text('메시지를 복사했어요.'), findsOneWidget);

    await tester.longPress(find.text('안 갈게요'));
    await tester.pumpAndSettle();
    expect(find.text('복사'), findsOneWidget);
    await tester.tap(find.text('신고하기'));
    await tester.pumpAndSettle();
    await submitReport(tester, TaxiReportReason.abuse);

    expect(api.reports.single['target_label'], '참여자 1');
    expect(api.reports.single['reason'], 'abuse');
    expect(api.reports.single['message_id'], 11);
  });
}
