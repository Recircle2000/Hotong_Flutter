import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';

class _FakePreferencesService extends PreferencesService {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FakeShuttleRepository extends ShuttleRepository {
  @override
  Future<List<JourneyDestination>> fetchJourneyDestinations({
    required int originStationId,
    required String date,
  }) async {
    if (originStationId == 11) {
      return const [
        JourneyDestination(stationId: 12, stationName: '천안아산역'),
      ];
    }
    if (originStationId == 1) {
      return const [
        JourneyDestination(stationId: 2, stationName: '도착'),
      ];
    }
    if (originStationId == 3) {
      return const [
        JourneyDestination(stationId: 2, stationName: '중간 목적지'),
        JourneyDestination(stationId: 1, stationName: '아산캠퍼스'),
      ];
    }
    if (originStationId == 4) return const [];
    return const [
      JourneyDestination(stationId: 1, stationName: '아산캠퍼스'),
    ];
  }

  @override
  Future<ShuttleJourneySearchResult> fetchJourneys({
    required int originStationId,
    required int destinationStationId,
    required String date,
  }) async {
    return ShuttleJourneySearchResult(
      scheduleType: 'Weekday',
      scheduleTypeName: '평일',
      date: date,
      originStationId: originStationId,
      originStationName: '출발',
      destinationStationId: destinationStationId,
      destinationStationName: '도착',
      journeys: const [
        ShuttleJourney(
          scheduleId: 10,
          routeId: 4,
          routeName: 'KTX 순환',
          originArrivalTime: '08:10:00',
          destinationArrivalTime: '08:35:00',
          originStopOrder: 1,
          destinationStopOrder: 3,
          durationMinutes: 25,
          intermediateStopCount: 1,
        ),
      ],
    );
  }
}

void main() {
  late _FakePreferencesService preferences;
  late ShuttleViewModel viewModel;
  final origin = ShuttleStation(
    id: 1,
    name: '아산캠퍼스',
    latitude: 36,
    longitude: 127,
  );
  final destination = ShuttleStation(
    id: 2,
    name: '도착',
    latitude: 36.1,
    longitude: 127.1,
  );

  setUp(() {
    preferences = _FakePreferencesService();
    viewModel = ShuttleViewModel(
      shuttleRepository: _FakeShuttleRepository(),
      preferencesService: preferences,
    );
    viewModel.stations.value = [origin, destination];
    viewModel.selectedDate.value = '2026-08-24';
  });

  test('origin selection loads only reachable destinations', () async {
    await viewModel.selectOriginStation(origin);

    expect(viewModel.selectedOriginStation.value, origin);
    expect(viewModel.journeyDestinations.single.stationId, destination.id);
    expect(viewModel.favoriteStationIds, isEmpty);
  });

  test('intermediate origin keeps campuses and auto-selects a single result',
      () async {
    final intermediateOrigin = ShuttleStation(
      id: 3,
      name: '중간 정류장',
      latitude: 36.05,
      longitude: 127.05,
    );
    viewModel.stations.add(intermediateOrigin);

    await viewModel.selectOriginStation(intermediateOrigin);

    expect(viewModel.journeyDestinations, hasLength(1));
    expect(viewModel.journeyDestinations.single.stationName, '아산캠퍼스');
    expect(viewModel.selectedDestinationStation.value!.id, origin.id);
  });

  test('empty destination result exposes the unavailable boarding date',
      () async {
    final unavailableOrigin = ShuttleStation(
      id: 4,
      name: '운행 없는 정류장',
      latitude: 36.04,
      longitude: 127.04,
    );
    viewModel.stations.add(unavailableOrigin);

    await viewModel.selectOriginStation(unavailableOrigin);

    expect(viewModel.journeyDestinations, isEmpty);
    expect(viewModel.selectedDestinationStation.value, isNull);
    expect(
      viewModel.journeyDestinationUnavailableDate.value,
      viewModel.selectedDate.value,
    );
  });

  test('station favorite is local, unique, and toggleable', () async {
    await viewModel.toggleStationFavorite(origin);
    await viewModel.toggleStationFavorite(origin);

    expect(viewModel.favoriteStationIds, isEmpty);

    await viewModel.toggleStationFavorite(origin);

    expect(viewModel.favoriteStationIds, [origin.id]);
    expect(viewModel.favoriteStations, [origin]);
    expect(viewModel.isStationFavorite(origin), isTrue);
    expect(
      preferences.values['shuttle_favorite_station_ids'],
      '[${origin.id}]',
    );
  });

  test('swap validates the reverse direction', () async {
    await viewModel.selectOriginStation(origin);
    await viewModel.selectDestinationStation(destination);

    await viewModel.swapJourneyStations();

    expect(viewModel.selectedOriginStation.value!.id, destination.id);
    expect(viewModel.selectedDestinationStation.value!.id, origin.id);
  });

  test('favorite is directional, unique, renameable, and removable', () async {
    await viewModel.selectOriginStation(origin);
    await viewModel.selectDestinationStation(destination);

    await viewModel.toggleSelectedJourneyFavorite();
    expect(viewModel.favoriteJourneys, hasLength(1));
    expect(viewModel.isSelectedJourneyFavorite, isTrue);

    final favorite = viewModel.favoriteJourneys.single;
    await viewModel.renameFavoriteJourney(favorite, '등교');
    expect(viewModel.favoriteJourneys.single.customName, '등교');

    await viewModel.removeFavoriteJourney(viewModel.favoriteJourneys.single);
    expect(viewModel.favoriteJourneys, isEmpty);
  });

  test('intermediate-to-intermediate journey favorite is hidden', () {
    final intermediateOrigin = ShuttleStation(
      id: 3,
      name: '중간 출발지',
      latitude: 36.05,
      longitude: 127.05,
    );
    final intermediateDestination = ShuttleStation(
      id: 4,
      name: '중간 도착지',
      latitude: 36.06,
      longitude: 127.06,
    );
    viewModel.stations.addAll([intermediateOrigin, intermediateDestination]);
    viewModel.favoriteJourneys.add(
      FavoriteShuttleJourney(
        originStationId: intermediateOrigin.id,
        destinationStationId: intermediateDestination.id,
        createdAt: DateTime(2026, 8, 24),
      ),
    );

    expect(viewModel.validFavoriteJourneys, isEmpty);
  });

  test('journey search stores parsed result', () async {
    await viewModel.selectOriginStation(origin);
    await viewModel.selectDestinationStation(destination);

    final result = await viewModel.searchJourneys();

    expect(result, isNotNull);
    expect(result!.journeys.single.durationMinutes, 25);
    expect(viewModel.journeySearchResult.value, same(result));
  });

  test('Asan departure uses a unified Cheonan-Asan station label', () async {
    final asanDeparture = ShuttleStation(
      id: 11,
      name: '아산캠퍼스 [출발]',
      latitude: 36.7,
      longitude: 127,
    );
    final cheonanDirection = ShuttleStation(
      id: 12,
      name: '천안아산역 [천캠방향]',
      latitude: 36.8,
      longitude: 127.1,
    );
    viewModel.stations.value = [asanDeparture, cheonanDirection];

    await viewModel.selectOriginStation(asanDeparture);
    final unifiedDestination = viewModel.stationForJourneyDestination(
      viewModel.journeyDestinations.single,
    );
    await viewModel.selectDestinationStation(unifiedDestination);
    await viewModel.toggleSelectedJourneyFavorite();

    expect(unifiedDestination.name, '천안아산역');
    expect(
      viewModel.favoriteDisplayName(viewModel.favoriteJourneys.single),
      '아산캠퍼스 → 천안아산역',
    );
  });

  test('direction suffix station pairs are unified for selection', () async {
    final terminalToCheonan = ShuttleStation(
      id: 20,
      name: '천안터미널 [천캠방향]',
      latitude: 36.81,
      longitude: 127.15,
    );
    final terminalToAsan = ShuttleStation(
      id: 21,
      name: '천안터미널 [아캠방향]',
      latitude: 36.82,
      longitude: 127.16,
    );
    viewModel.stations.value = [terminalToCheonan, terminalToAsan];

    expect(viewModel.logicalJourneyStations, hasLength(1));
    expect(viewModel.logicalJourneyStations.single.name, '천안터미널');
    expect(
      viewModel.stationIdsForLogicalName('천안터미널'),
      unorderedEquals([20, 21]),
    );

    await viewModel.selectOriginStation(terminalToAsan);

    expect(viewModel.selectedOriginStation.value!.id, 20);
    expect(viewModel.selectedOriginStation.value!.name, '천안터미널');
  });

  test('Chungmu Hospital opposite stops are unified for selection', () async {
    final hospitalToCheonan = ShuttleStation(
      id: 5,
      name: '천안 충무병원',
      latitude: 36.798219,
      longitude: 127.133672,
    );
    final hospitalToAsan = ShuttleStation(
      id: 10,
      name: '천안 충무병원 맞은편',
      latitude: 36.798257,
      longitude: 127.132494,
    );
    viewModel.stations.value = [hospitalToCheonan, hospitalToAsan];

    expect(viewModel.logicalJourneyStations, hasLength(1));
    expect(viewModel.logicalJourneyStations.single.name, '천안 충무병원');
    expect(
      viewModel.stationIdsForLogicalName('천안 충무병원'),
      unorderedEquals([5, 10]),
    );

    await viewModel.selectOriginStation(hospitalToAsan);

    expect(viewModel.selectedOriginStation.value!.id, 5);
    expect(viewModel.selectedOriginStation.value!.name, '천안 충무병원');
  });

  test('campus departure and arrival stops are unified for selection',
      () async {
    viewModel.stations.value = [
      ShuttleStation(
        id: 1,
        name: '아산캠퍼스 [출발]',
        latitude: 36.738529,
        longitude: 127.077037,
      ),
      ShuttleStation(
        id: 13,
        name: '아산캠퍼스 [도착]',
        latitude: 36.73861,
        longitude: 127.076775,
      ),
      ShuttleStation(
        id: 14,
        name: '천안캠퍼스 [출발]',
        latitude: 36.829613,
        longitude: 127.181358,
      ),
      ShuttleStation(
        id: 8,
        name: '천안캠퍼스 [도착]',
        latitude: 36.829601,
        longitude: 127.181351,
      ),
    ];

    expect(
      viewModel.logicalJourneyStations.map((station) => station.name),
      unorderedEquals(['아산캠퍼스', '천안캠퍼스']),
    );
    expect(
      viewModel.stationIdsForLogicalName('아산캠퍼스'),
      unorderedEquals([1, 13]),
    );
    expect(
      viewModel.stationIdsForLogicalName('천안캠퍼스'),
      unorderedEquals([8, 14]),
    );

    await viewModel.toggleStationFavorite(viewModel.stations.first);

    expect(viewModel.isStationFavorite(viewModel.stations[1]), isTrue);
    expect(viewModel.favoriteStations.single.name, '아산캠퍼스');
  });
}
