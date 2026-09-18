import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/widgets/shuttle_station_picker.dart';

void main() {
  final station = ShuttleStation(
    id: 1,
    name: '아산캠퍼스',
    latitude: 36.769,
    longitude: 127.075,
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '정류장 선택 화면이 ${platform.name}에서 열리고 선택된다',
      (tester) async {
        ShuttleStation? selectedStation;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    selectedStation = await showShuttleStationPicker(
                      context: context,
                      title: '출발 정류장 선택',
                      stations: [station],
                      favoriteStationsProvider: () => const [],
                      isStationFavorite: (_) => false,
                      onToggleFavorite: (_) async {},
                    );
                  },
                  child: const Text('정류장 선택'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('정류장 선택'));
        await tester.pumpAndSettle();

        expect(find.text('출발 정류장 선택'), findsOneWidget);
        expect(find.text('정류장 이름 검색'), findsOneWidget);
        expect(find.text('아산캠퍼스'), findsOneWidget);
        expect(find.byTooltip('정류장 정보'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('아산캠퍼스'));
        await tester.pumpAndSettle();

        expect(selectedStation?.id, station.id);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('역 정류장에 교통수단 배지를 표시한다', (tester) async {
    final transportStations = [
      ShuttleStation(
        id: 10,
        name: '천안아산역',
        latitude: 36.79,
        longitude: 127.1,
      ),
      ShuttleStation(
        id: 11,
        name: '천안역',
        latitude: 36.8,
        longitude: 127.15,
      ),
      ShuttleStation(
        id: 12,
        name: '온양온천역',
        latitude: 36.78,
        longitude: 127.0,
      ),
      ShuttleStation(
        id: 13,
        name: '배방역',
        latitude: 36.77,
        longitude: 127.05,
      ),
      ShuttleStation(
        id: 14,
        name: '배방역 건너',
        latitude: 36.77,
        longitude: 127.06,
      ),
      ShuttleStation(
        id: 15,
        name: '천안터미널',
        latitude: 36.81,
        longitude: 127.15,
      ),
      ShuttleStation(
        id: 16,
        name: '아산터미널',
        latitude: 36.78,
        longitude: 127.01,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showShuttleStationPicker(
                context: context,
                title: '출발 정류장 선택',
                stations: transportStations,
                favoriteStationsProvider: () => const [],
                isStationFavorite: (_) => false,
                onToggleFavorite: (_) async {},
              ),
              child: const Text('정류장 선택'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('정류장 선택'));
    await tester.pumpAndSettle();

    expect(find.text('KTX'), findsOneWidget);
    expect(find.text('1호선'), findsNWidgets(5));
    expect(find.text('일반열차'), findsNWidgets(2));

    final onyangTile = find.ancestor(
      of: find.text('온양온천역'),
      matching: find.byType(ListTile),
    );
    final regularTrainBadge = find.descendant(
      of: onyangTile,
      matching: find.text('일반열차'),
    );
    final lineOneBadge = find.descendant(
      of: onyangTile,
      matching: find.text('1호선'),
    );
    expect(
      tester.getTopLeft(regularTrainBadge).dx,
      lessThan(tester.getTopLeft(lineOneBadge).dx),
    );

    await tester.scrollUntilVisible(
      find.text('아산터미널'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('시외버스'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('통합된 정류장의 정보 버튼은 ${platform.name}에서 원본 정류장을 묻는다',
        (tester) async {
      if (platform == TargetPlatform.iOS) {
        const channel = MethodChannel('hsro/ios_station_info_menu');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
      }

      final logicalStation = ShuttleStation(
        id: 20,
        name: '천안터미널',
        latitude: 36.81,
        longitude: 127.15,
      );
      final detailStations = [
        ShuttleStation(
          id: 20,
          name: '천안터미널 [천캠방향]',
          latitude: 36.81,
          longitude: 127.15,
        ),
        ShuttleStation(
          id: 21,
          name: '천안터미널 [아캠방향]',
          latitude: 36.82,
          longitude: 127.16,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showShuttleStationPicker(
                  context: context,
                  title: '출발 정류장 선택',
                  stations: [logicalStation],
                  favoriteStationsProvider: () => const [],
                  isStationFavorite: (_) => false,
                  onToggleFavorite: (_) async {},
                  detailStationsProvider: (_) => detailStations,
                ),
                child: const Text('정류장 선택'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('정류장 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('정류장 정보'));
      await tester.pumpAndSettle();

      expect(find.text('어떤 정류장 정보를 볼까요?'), findsOneWidget);
      expect(find.text('천안터미널 [천캠방향]'), findsOneWidget);
      expect(find.text('천안터미널 [아캠방향]'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
