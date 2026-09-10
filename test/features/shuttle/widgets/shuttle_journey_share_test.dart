import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/shuttle_journey_result_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';

class _ViewModel extends ShuttleViewModel {
  Completer<ShuttleJourneySearchResult?> pending = Completer();
  // Skip network and preferences initialization in this screen test.
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<ShuttleJourneySearchResult?> searchJourneys() => pending.future;
}

ShuttleJourneySearchResult result(String date) => ShuttleJourneySearchResult(
      scheduleType: 'Weekday',
      scheduleTypeName: '평일',
      date: date,
      originStationId: 101,
      originStationName: '아산캠퍼스',
      destinationStationId: 904,
      destinationStationName: '천안역',
      journeys: [],
    );

void main() {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    Get.reset();
  });

  testWidgets(
      'empty result shares displayed date; reload disables sharing and failure retains date',
      (tester) async {
    Get.testMode = true;
    final vm = Get.put<ShuttleViewModel>(_ViewModel()) as _ViewModel;
    final links = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      final args = call.arguments as Map;
      links.add(args['uri'] as String);
      expect(args.containsKey('text'), isFalse);
      expect(args['title'], contains('아산캠퍼스 → 천안역'));
      return '';
    });
    await tester.pumpWidget(GetMaterialApp(
        home: ShuttleJourneyResultView(
      initialResult: result('2024-02-29'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('링크 공유'));
    await tester.pumpAndSettle();
    expect(links.last,
        'https://hotong.vercel.app/shuttle/journey?from=101&to=904&date=2024-02-29');

    vm.selectedDate.value = '2026-09-11';
    var reload = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '링크 공유',
            ))
            .onPressed,
        isNull);
    vm.pending.complete(result('2026-09-11'));
    await reload;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('링크 공유'));
    await tester.pumpAndSettle();
    expect(links.last, contains('date=2026-09-11'));

    vm.pending = Completer();
    vm.selectedDate.value = '2026-09-12';
    reload = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    vm.pending.complete(null);
    await reload;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('링크 공유'));
    await tester.pumpAndSettle();
    expect(links.last, contains('date=2026-09-11'));
    await tester.pumpWidget(const SizedBox());
  });
}
