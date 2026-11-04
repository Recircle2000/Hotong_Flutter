import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/home/widgets/upcoming_departure_card.dart';

void main() {
  DateTime at(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds);

  test('시각 6초, 막차 1.5초씩 번갈아 보여 준다', () {
    expect(LastBusTimeLabel.phaseAt(at(0)), (
      true,
      const Duration(milliseconds: 6000),
    ));
    expect(LastBusTimeLabel.phaseAt(at(5999)), (
      true,
      const Duration(milliseconds: 1),
    ));
    expect(LastBusTimeLabel.phaseAt(at(6000)), (
      false,
      const Duration(milliseconds: 1500),
    ));
    expect(LastBusTimeLabel.phaseAt(at(7499)), (
      false,
      const Duration(milliseconds: 1),
    ));
    expect(LastBusTimeLabel.phaseAt(at(7500)), (
      true,
      const Duration(milliseconds: 6000),
    ));
  });

  Widget card({required bool disableAnimations}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: SizedBox(
          width: 170,
          child: UpcomingDepartureCard(
            primaryText: '1시간 1분',
            trailingText: '20:30',
            routeLabel: '순환5',
            description: '천안아산역 방면',
            isLastBus: true,
            scrollDescription: true,
            onTap: () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('막차는 시각 자리에 표시하고 둘째 줄 배지는 없앤다', (tester) async {
    await tester.pumpWidget(card(disableAnimations: false));

    // 시각과 '막차'를 겹쳐 두고 번갈아 보여 주므로 '막차' 글자는 한 곳에만 있다.
    expect(find.text('막차'), findsOneWidget);
    expect(find.text('20:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 번갈아 보여 주는 타이머를 정리한다.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('애니메이션 줄이기에서는 막차와 시각을 함께 고정해 보여 준다', (tester) async {
    await tester.pumpWidget(card(disableAnimations: true));

    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.text('막차'), findsOneWidget);
    expect(find.text('20:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 번갈아 보여 주는 타이머를 정리한다.
    await tester.pumpWidget(const SizedBox());
  });
}
