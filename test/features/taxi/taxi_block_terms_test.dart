import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/view/tabs/taxi_profile_tab.dart';
import 'package:hsro/features/taxi/view/taxi_block_list_view.dart';
import 'package:hsro/features/taxi/view/taxi_chat_view.dart';
import 'package:hsro/features/taxi/view/taxi_home_view.dart';
import 'package:hsro/features/taxi/view/taxi_terms_view.dart';
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

  Future<void> openHome(WidgetTester tester, TaxiTestApi api) async {
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
  }

  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(
      find
          .descendant(of: find.byType(TaxiTabBar), matching: find.text(name))
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

  group('이용약관 동의', () {
    testWidgets('동의가 필요하면 택시 화면에 들어올 때 받고, 체크해야 동의할 수 있다', (tester) async {
      final api = TaxiTestApi()..termsRequired = true;
      await openHome(tester, api);

      expect(find.byType(TaxiTermsView), findsOneWidget);
      final agree = find.byKey(const ValueKey('taxi-terms-agree'));
      expect(tester.widget<FilledButton>(agree).onPressed, isNull);
      expect(api.termsAgreements, 0);

      await tester.tap(find.byKey(const ValueKey('taxi-terms-check')));
      await tester.pumpAndSettle();
      await tester.tap(agree);
      await tester.pumpAndSettle();

      expect(api.termsAgreements, 1);
      expect(find.byType(TaxiTermsView), findsNothing);
      expect(find.byType(TaxiHomeView), findsOneWidget);

      // 다음 새로고침에서 다시 묻지 않는다.
      await tab(tester, '현재팟');
      expect(find.byType(TaxiTermsView), findsNothing);
    });

    testWidgets('동의하지 않고 나가면 택시 화면도 닫힌다', (tester) async {
      final api = TaxiTestApi()..termsRequired = true;
      await openHome(tester, api);

      await tester.tap(find.byTooltip('나가기'));
      await tester.pumpAndSettle();

      expect(api.termsAgreements, 0);
      expect(find.byType(TaxiTermsView), findsNothing);
      expect(find.byType(TaxiHomeView), findsNothing);
      expect(find.text('열기'), findsOneWidget);
    });

    testWidgets('이미 동의했으면 묻지 않고, 내정보에서 다시 읽을 수 있다', (tester) async {
      final api = TaxiTestApi();
      await openHome(tester, api);
      expect(find.byType(TaxiTermsView), findsNothing);

      await tab(tester, '내정보');
      await tester.tap(find.text('이용약관'));
      await tester.pumpAndSettle();

      expect(find.byType(TaxiTermsView), findsOneWidget);
      // 읽기만 하는 화면이라 동의 버튼이 없다.
      expect(find.byKey(const ValueKey('taxi-terms-agree')), findsNothing);
    });
  });

  group('참여자 차단', () {
    testWidgets('팟 상세에서 참여자를 차단하면 차단함으로 표시되고 다시 차단할 수 없다', (tester) async {
      final api = TaxiTestApi()
        ..activeIds.add('p1')
        ..members = [member('방장', owner: true, me: true), member('참여자 1')];
      await openHome(tester, api);
      await tab(tester, '현재팟');

      await tapMember(tester, '참여자 1');
      await tester.tap(find.text('차단하기'));
      await tester.pumpAndSettle();
      expect(find.text('참여자 1님을 차단할까요?'), findsOneWidget);
      expect(api.blocks, isEmpty);

      await tester.tap(find.text('차단'));
      await tester.pumpAndSettle();

      expect(api.blocks.single['target_label'], '참여자 1');
      expect(find.text('차단함'), findsOneWidget);
      expect(find.textContaining('차단했어요'), findsOneWidget);

      await tapMember(tester, '참여자 1');
      expect(find.text('차단하기'), findsNothing);
      expect(find.text('신고하기'), findsOneWidget);
    });

    testWidgets('확인창을 닫으면 차단하지 않는다', (tester) async {
      final api = TaxiTestApi()
        ..activeIds.add('p1')
        ..members = [member('방장', owner: true, me: true), member('참여자 1')];
      await openHome(tester, api);
      await tab(tester, '현재팟');

      await tapMember(tester, '참여자 1');
      await tester.tap(find.text('차단하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();

      expect(api.blocks, isEmpty);
      expect(find.text('차단함'), findsNothing);
    });

    testWidgets('채팅에서 차단하면 그 사람 메시지가 접히고, 누르면 펼쳐진다', (tester) async {
      final api = TaxiTestApi()..activeIds.add('p1');
      final sentAt = DateTime.now().toUtc().toIso8601String();
      Map<String, Object?> chat(int id, String label, String content) => {
        'id': id,
        'party_id': 'p1',
        'message_type': 'chat',
        'sender_label': label,
        'is_mine': false,
        'content': content,
        'created_at': sentAt,
      };
      api.messages = [
        chat(11, '참여자 1', '안 갈게요'),
        chat(12, '참여자 2', '저는 가요'),
        // 서버가 이미 차단한 사람의 메시지라고 알려준 경우
        {...chat(13, '참여자 3', '예전에 차단한 사람'), 'sender_blocked': true},
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
      final collapsed = find.textContaining(
        '차단한 참여자의 메시지예요',
        findRichText: true,
      );
      expect(collapsed, findsOneWidget);
      expect(find.text('예전에 차단한 사람'), findsNothing);

      await tester.longPress(find.text('안 갈게요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('차단하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('차단'));
      await tester.pumpAndSettle();

      expect(api.blocks.single['target_label'], '참여자 1');
      expect(find.text('안 갈게요'), findsNothing);
      expect(find.text('저는 가요'), findsOneWidget);
      expect(collapsed, findsNWidgets(2));

      // 접힌 메시지를 누르면 그 메시지만 펼쳐진다.
      await tester.tap(collapsed.first);
      await tester.pumpAndSettle();
      expect(find.text('안 갈게요'), findsOneWidget);
      expect(collapsed, findsOneWidget);
    });

    testWidgets('내정보의 차단 목록에서 해제한다', (tester) async {
      final api = TaxiTestApi();
      api.blocks.add({
        'id': 7,
        'target_label': '참여자 2',
        'departure_location': '아산캠퍼스',
        'destination_location': '천안아산역',
        'departure_at': DateTime(2026, 10, 3, 10, 40).toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await openHome(tester, api);
      await tab(tester, '내정보');
      final entry = find.byKey(const ValueKey('taxi-block-list'));
      await tester.scrollUntilVisible(
        entry,
        200,
        scrollable: find
            .descendant(
              of: find.byType(TaxiProfileTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(TaxiBlockListView), findsOneWidget);
      expect(find.text('참여자 2'), findsOneWidget);
      expect(find.text('10월 3일 10:40 · 아산캠퍼스 → 천안아산역'), findsOneWidget);

      await tester.tap(find.text('해제'));
      await tester.pumpAndSettle();
      expect(find.text('차단을 해제할까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '해제'));
      await tester.pumpAndSettle();

      expect(api.blocks, isEmpty);
      expect(find.text('참여자 2'), findsNothing);
      expect(find.text('차단한 참여자가 없어요'), findsOneWidget);
    });
  });
}
