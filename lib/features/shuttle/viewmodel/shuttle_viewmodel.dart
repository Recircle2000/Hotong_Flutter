import 'dart:convert';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:hsro/core/services/preferences_service.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';

class ShuttleViewModel extends GetxController {
  static const String _favoriteJourneysKey = 'shuttle_favorite_journeys';
  static const String _favoriteStationsKey = 'shuttle_favorite_station_ids';
  static final RegExp _stationDirectionSuffixPattern = RegExp(
    r'\s*[\[(]\s*(?:천캠|아캠|천안|아산)방향\s*[\])]\s*$',
  );
  static const Map<String, String> _stationLogicalNameAliases = {
    '아산캠퍼스 [출발]': '아산캠퍼스',
    '아산캠퍼스 [도착]': '아산캠퍼스',
    '천안캠퍼스 [출발]': '천안캠퍼스',
    '천안캠퍼스 [도착]': '천안캠퍼스',
    '천안 충무병원': '천안 충무병원',
    '천안 충무병원 맞은편': '천안 충무병원',
  };
  static const Set<String> _campusStationNames = {
    '아산캠퍼스',
    '천안캠퍼스',
  };
  static const List<String> _journeyStationPriority = [
    '아산캠퍼스',
    '천안캠퍼스',
    '천안아산역',
    '천안역',
    '천안터미널',
    '쌍용2동',
    '쌍용3동',
    '천안충무병원',
  ];
  static final RegExp _whitespacePattern = RegExp(r'\s+');

  ShuttleViewModel({
    ShuttleRepository? shuttleRepository,
    PreferencesService? preferencesService,
  })  : _shuttleRepository = shuttleRepository ?? ShuttleRepository(),
        _preferencesService = preferencesService ?? PreferencesService();

  final ShuttleRepository _shuttleRepository;
  final PreferencesService _preferencesService;

  // 셔틀 화면 전반에서 공유하는 데이터 목록
  final RxList<ShuttleRoute> routes = <ShuttleRoute>[].obs;
  final RxList<Schedule> schedules = <Schedule>[].obs;
  final RxList<ScheduleStop> scheduleStops = <ScheduleStop>[].obs;
  final RxList<ShuttleStation> stations = <ShuttleStation>[].obs;
  final RxList<JourneyDestination> journeyDestinations =
      <JourneyDestination>[].obs;
  final RxList<FavoriteShuttleJourney> favoriteJourneys =
      <FavoriteShuttleJourney>[].obs;
  final RxList<int> favoriteStationIds = <int>[].obs;

  // 현재 선택 상태
  final RxInt selectedRouteId = (-1).obs;
  final RxString selectedDate = ''.obs;
  final RxInt selectedScheduleId = (-1).obs;
  final RxString scheduleTypeName = ''.obs; // 응답에서 받은 스케줄 타입 이름
  final Rxn<ShuttleStation> selectedOriginStation = Rxn<ShuttleStation>();
  final Rxn<ShuttleStation> selectedDestinationStation = Rxn<ShuttleStation>();
  final Rxn<ShuttleJourneySearchResult> journeySearchResult =
      Rxn<ShuttleJourneySearchResult>();

  // 화면별 로딩 상태
  final RxBool isLoadingRoutes = false.obs;
  final RxBool isLoadingSchedules = false.obs;
  final RxBool isLoadingStops = false.obs;
  final RxBool isLoadingStations = false.obs;
  final RxBool isLoadingScheduleType = false.obs;
  final RxBool isLoadingJourneyDestinations = false.obs;
  final RxBool isLoadingJourneys = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString journeyDestinationUnavailableDate = RxnString();

  // 운행 유형 표시명 매핑
  final Map<String, String> scheduleTypeNames = {
    'Weekday': '평일',
    'Saturday': '토요일',
    'Holiday': '일요일/공휴일'
  };

  // 기본값 자동 적용 여부
  final RxBool useDefaultValues = true.obs;
  String _latestScheduleTypeRequestDate = '';
  String _latestJourneyDestinationRequest = '';
  String _latestJourneyRequest = '';

  @override
  void onInit() {
    super.onInit();
    _loadJourneyPreferences();
    Future.wait<void>([
      fetchStations(),
      fetchRoutes(),
    ]).then((_) async {
      // 노선과 정류장을 모두 로드한 뒤 기본값을 적용한다.
      if (useDefaultValues.value) {
        setDefaultValues();
        await applyCampusJourneyDefaults();
      }
    });
  }

  ShuttleStation? stationById(int stationId) {
    for (final station in stations) {
      if (station.id == stationId) return station;
    }
    return null;
  }

  String logicalStationName(String name) {
    final trimmedName = name.trim();
    return _stationLogicalNameAliases[trimmedName] ??
        trimmedName.replaceFirst(_stationDirectionSuffixPattern, '').trim();
  }

  bool isCampusStationName(String name) {
    return _campusStationNames.contains(logicalStationName(name));
  }

  bool isJourneyPairAllowed(
    ShuttleStation origin,
    ShuttleStation destination,
  ) {
    final originName = logicalStationName(origin.name);
    final destinationName = logicalStationName(destination.name);
    if (originName == destinationName) return false;
    return _campusStationNames.contains(originName) ||
        _campusStationNames.contains(destinationName);
  }

  ShuttleStation logicalJourneyStationFor(ShuttleStation station) {
    final logicalName = logicalStationName(station.name);
    if (logicalName == station.name.trim()) return station;
    final candidates = stations
        .where((item) => logicalStationName(item.name) == logicalName)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final representative = candidates.isEmpty ? station : candidates.first;
    return ShuttleStation(
      id: representative.id,
      name: logicalName,
      latitude: representative.latitude,
      longitude: representative.longitude,
      description: representative.description,
      imageUrl: representative.imageUrl,
    );
  }

  List<ShuttleStation> get logicalJourneyStations {
    final groupedStations = <String, ShuttleStation>{};
    for (final station in stations) {
      final logicalStation = logicalJourneyStationFor(station);
      final existing = groupedStations[logicalStation.name];
      if (existing == null || logicalStation.id < existing.id) {
        groupedStations[logicalStation.name] = logicalStation;
      }
    }
    return sortJourneyStationsForPicker(groupedStations.values);
  }

  List<ShuttleStation> sortJourneyStationsForPicker(
    Iterable<ShuttleStation> source,
  ) {
    final values = source.toList(growable: false);
    values.sort((a, b) {
      final aName = logicalStationName(a.name);
      final bName = logicalStationName(b.name);
      final aPriority = _journeyStationPriority.indexOf(
        aName.replaceAll(_whitespacePattern, ''),
      );
      final bPriority = _journeyStationPriority.indexOf(
        bName.replaceAll(_whitespacePattern, ''),
      );
      final normalizedAPriority = aPriority < 0 ? 1 << 30 : aPriority;
      final normalizedBPriority = bPriority < 0 ? 1 << 30 : bPriority;
      final priorityComparison =
          normalizedAPriority.compareTo(normalizedBPriority);
      if (priorityComparison != 0) return priorityComparison;
      return aName.compareTo(bName);
    });
    return values;
  }

  Set<int> stationIdsForLogicalName(String name) {
    return stationsForLogicalName(name).map((station) => station.id).toSet();
  }

  List<ShuttleStation> stationsForLogicalName(String name) {
    final logicalName = logicalStationName(name);
    return stations
        .where((station) => logicalStationName(station.name) == logicalName)
        .toList(growable: false);
  }

  List<ShuttleStation> get favoriteStations {
    final values = <ShuttleStation>[];
    final seenNames = <String>{};
    for (final stationId in favoriteStationIds) {
      final station = stationById(stationId);
      if (station == null) continue;
      final logicalStation = logicalJourneyStationFor(station);
      if (seenNames.add(logicalStation.name)) values.add(logicalStation);
    }
    return values;
  }

  bool isStationFavorite(ShuttleStation station) {
    final logicalName = logicalStationName(station.name);
    return favoriteStationIds.any((stationId) {
      final favoriteStation = stationById(stationId);
      return favoriteStation != null &&
          logicalStationName(favoriteStation.name) == logicalName;
    });
  }

  Future<void> toggleStationFavorite(ShuttleStation station) async {
    final logicalStation = logicalJourneyStationFor(station);
    final matchingIds = favoriteStationIds.where((stationId) {
      final favoriteStation = stationById(stationId);
      return favoriteStation != null &&
          logicalStationName(favoriteStation.name) == logicalStation.name;
    }).toList(growable: false);
    if (matchingIds.isNotEmpty) {
      favoriteStationIds.removeWhere(matchingIds.contains);
    } else {
      favoriteStationIds.insert(0, logicalStation.id);
    }
    await _preferencesService.setString(
      _favoriteStationsKey,
      jsonEncode(favoriteStationIds.toList()),
    );
  }

  List<FavoriteShuttleJourney> get validFavoriteJourneys {
    return favoriteJourneys.where((favorite) {
      final origin = stationById(favorite.originStationId);
      final destination = stationById(favorite.destinationStationId);
      return origin != null &&
          destination != null &&
          isJourneyPairAllowed(origin, destination);
    }).toList(growable: false);
  }

  String favoriteDisplayName(FavoriteShuttleJourney favorite) {
    final customName = favorite.customName?.trim();
    if (customName != null && customName.isNotEmpty) return customName;
    final rawOrigin = stationById(favorite.originStationId)?.name ?? '출발지';
    final rawDestination =
        stationById(favorite.destinationStationId)?.name ?? '도착지';
    final origin = logicalStationName(rawOrigin);
    final destination = logicalStationName(rawDestination);
    return '$origin → $destination';
  }

  ShuttleStation stationForJourneyDestination(
    JourneyDestination destination,
  ) {
    final station = stationById(destination.stationId);
    if (station == null) {
      return ShuttleStation(
        id: destination.stationId,
        name: destination.stationName,
        latitude: 0,
        longitude: 0,
      );
    }
    return ShuttleStation(
      id: station.id,
      name: destination.stationName,
      latitude: station.latitude,
      longitude: station.longitude,
      description: station.description,
      imageUrl: station.imageUrl,
    );
  }

  bool get isSelectedJourneyFavorite {
    final origin = selectedOriginStation.value;
    final destination = selectedDestinationStation.value;
    if (origin == null || destination == null) return false;
    return favoriteJourneys.any(
      (favorite) {
        final favoriteOrigin = stationById(favorite.originStationId);
        final favoriteDestination = stationById(favorite.destinationStationId);
        return favoriteOrigin != null &&
            favoriteDestination != null &&
            logicalStationName(favoriteOrigin.name) == origin.name &&
            logicalStationName(favoriteDestination.name) == destination.name;
      },
    );
  }

  Future<void> selectOriginStation(ShuttleStation station) async {
    final logicalStation = logicalJourneyStationFor(station);
    selectedOriginStation.value = logicalStation;
    if (selectedDestinationStation.value?.name == logicalStation.name) {
      selectedDestinationStation.value = null;
    }
    journeySearchResult.value = null;
    await fetchJourneyDestinations();
    _clearUnreachableDestination();
  }

  Future<void> selectDestinationStation(ShuttleStation station) async {
    JourneyDestination? matchingDestination;
    for (final item in journeyDestinations) {
      if (item.stationId == station.id ||
          logicalStationName(item.stationName) ==
              logicalStationName(station.name)) {
        matchingDestination = item;
        break;
      }
    }
    if (matchingDestination == null) return;
    final logicalStation = stationForJourneyDestination(matchingDestination);
    if (selectedOriginStation.value?.name == logicalStation.name) return;
    selectedDestinationStation.value = logicalStation;
    journeySearchResult.value = null;
  }

  Future<void> applyCampusJourneyDefaults() async {
    if (selectedOriginStation.value != null ||
        selectedDestinationStation.value != null ||
        stations.isEmpty) {
      return;
    }

    try {
      final campusSetting =
          await _preferencesService.getString('campus') ?? '아산';

      // 설정을 읽는 동안 사용자가 직접 선택했다면 덮어쓰지 않는다.
      if (selectedOriginStation.value != null ||
          selectedDestinationStation.value != null) {
        return;
      }

      final originName = campusSetting == '천안' ? '천안캠퍼스' : '아산캠퍼스';
      final destinationName = campusSetting == '천안' ? '아산캠퍼스' : '천안캠퍼스';
      final origin = _logicalJourneyStationNamed(originName);
      final destination = _logicalJourneyStationNamed(destinationName);
      if (origin == null || destination == null) return;

      await selectOriginStation(origin);
      if (selectedOriginStation.value?.name != originName) return;
      await selectDestinationStation(destination);
    } catch (_) {}
  }

  ShuttleStation? _logicalJourneyStationNamed(String name) {
    for (final station in logicalJourneyStations) {
      if (station.name == name) return station;
    }
    return null;
  }

  Future<void> swapJourneyStations() async {
    final origin = selectedOriginStation.value;
    final destination = selectedDestinationStation.value;
    selectedOriginStation.value = destination;
    selectedDestinationStation.value = origin;
    journeySearchResult.value = null;
    if (destination != null) {
      await fetchJourneyDestinations();
      _clearUnreachableDestination();
    } else {
      journeyDestinations.clear();
    }
  }

  Future<void> applyFavoriteJourney(FavoriteShuttleJourney favorite) async {
    final origin = stationById(favorite.originStationId);
    final destination = stationById(favorite.destinationStationId);
    if (origin == null || destination == null) return;
    selectedOriginStation.value = logicalJourneyStationFor(origin);
    selectedDestinationStation.value = logicalJourneyStationFor(destination);
    journeySearchResult.value = null;
    await fetchJourneyDestinations();
    _clearUnreachableDestination();
  }

  Future<void> fetchJourneyDestinations() async {
    final origin = selectedOriginStation.value;
    final date = selectedDate.value;
    if (origin == null || date.isEmpty) {
      journeyDestinations.clear();
      return;
    }

    final requestKey = '${origin.id}:$date';
    _latestJourneyDestinationRequest = requestKey;
    isLoadingJourneyDestinations.value = true;
    try {
      final destinations = await _shuttleRepository.fetchJourneyDestinations(
        originStationId: origin.id,
        date: date,
      );
      if (_latestJourneyDestinationRequest == requestKey) {
        final filteredDestinations = isCampusStationName(origin.name)
            ? destinations
            : destinations
                .where(
                  (destination) => isCampusStationName(destination.stationName),
                )
                .toList(growable: false);
        journeyDestinations.assignAll(filteredDestinations);
        if (filteredDestinations.isEmpty) {
          selectedDestinationStation.value = null;
          journeyDestinationUnavailableDate.value = date;
        } else {
          // Keep the previous empty-state notice visible while a new date is
          // loading. Remove it only once this date has available journeys.
          journeyDestinationUnavailableDate.value = null;
        }
        if (filteredDestinations.length == 1) {
          final destination = stationForJourneyDestination(
            filteredDestinations.single,
          );
          if (logicalStationName(destination.name) !=
              logicalStationName(origin.name)) {
            selectedDestinationStation.value = destination;
          } else {
            selectedDestinationStation.value = null;
          }
        } else if (filteredDestinations.isNotEmpty) {
          _clearUnreachableDestination();
        }
      }
    } catch (e) {
      if (_latestJourneyDestinationRequest == requestKey) {
        journeyDestinations.clear();
        _emitError('이동 가능한 도착지를 불러오는데 실패했습니다.');
      }
    } finally {
      if (_latestJourneyDestinationRequest == requestKey) {
        isLoadingJourneyDestinations.value = false;
      }
    }
  }

  void _clearUnreachableDestination() {
    final destination = selectedDestinationStation.value;
    if (destination == null) return;

    JourneyDestination? matchingDestination;
    for (final item in journeyDestinations) {
      if (item.stationId == destination.id) {
        matchingDestination = item;
        break;
      }
    }
    if (matchingDestination == null) {
      for (final item in journeyDestinations) {
        if (logicalStationName(item.stationName) ==
            logicalStationName(destination.name)) {
          matchingDestination = item;
          break;
        }
      }
    }
    if (matchingDestination == null) {
      selectedDestinationStation.value = null;
      return;
    }
    if (destination.id != matchingDestination.stationId ||
        destination.name != matchingDestination.stationName) {
      selectedDestinationStation.value =
          stationForJourneyDestination(matchingDestination);
    }
  }

  Future<ShuttleJourneySearchResult?> searchJourneys() async {
    final origin = selectedOriginStation.value;
    final destination = selectedDestinationStation.value;
    final date = selectedDate.value;
    if (origin == null || destination == null || date.isEmpty) return null;
    if (!isJourneyPairAllowed(origin, destination)) {
      _emitError('중간 정류장에서는 캠퍼스행 셔틀만 이용할 수 있습니다.');
      return null;
    }

    final requestKey = '${origin.id}:${destination.id}:$date';
    _latestJourneyRequest = requestKey;
    isLoadingJourneys.value = true;
    try {
      final result = await _shuttleRepository.fetchJourneys(
        originStationId: origin.id,
        destinationStationId: destination.id,
        date: date,
      );
      if (_latestJourneyRequest != requestKey) return null;
      journeySearchResult.value = result;
      return result;
    } catch (e) {
      if (_latestJourneyRequest == requestKey) {
        journeySearchResult.value = null;
        _emitError('가는 셔틀을 불러오는데 실패했습니다.');
      }
      return null;
    } finally {
      if (_latestJourneyRequest == requestKey) {
        isLoadingJourneys.value = false;
      }
    }
  }

  Future<void> toggleSelectedJourneyFavorite() async {
    final origin = selectedOriginStation.value;
    final destination = selectedDestinationStation.value;
    if (origin == null || destination == null) return;
    final index = favoriteJourneys.indexWhere(
      (favorite) {
        final favoriteOrigin = stationById(favorite.originStationId);
        final favoriteDestination = stationById(favorite.destinationStationId);
        return favoriteOrigin != null &&
            favoriteDestination != null &&
            logicalStationName(favoriteOrigin.name) == origin.name &&
            logicalStationName(favoriteDestination.name) == destination.name;
      },
    );
    if (index >= 0) {
      favoriteJourneys.removeAt(index);
    } else {
      favoriteJourneys.insert(
        0,
        FavoriteShuttleJourney(
          originStationId: origin.id,
          destinationStationId: destination.id,
          createdAt: DateTime.now(),
        ),
      );
    }
    await _persistFavoriteJourneys();
  }

  Future<void> renameFavoriteJourney(
    FavoriteShuttleJourney favorite,
    String customName,
  ) async {
    final index =
        favoriteJourneys.indexWhere((item) => item.key == favorite.key);
    if (index < 0) return;
    favoriteJourneys[index] = favorite.copyWith(
      customName: customName.trim().isEmpty ? null : customName.trim(),
    );
    await _persistFavoriteJourneys();
  }

  Future<void> removeFavoriteJourney(FavoriteShuttleJourney favorite) async {
    favoriteJourneys.removeWhere((item) => item.key == favorite.key);
    await _persistFavoriteJourneys();
  }

  Future<void> _loadJourneyPreferences() async {
    try {
      final favoriteJson = await _preferencesService.getString(
        _favoriteJourneysKey,
      );
      if (favoriteJson != null && favoriteJson.isNotEmpty) {
        final values = jsonDecode(favoriteJson) as List<dynamic>;
        favoriteJourneys.assignAll(
          values.map(
            (value) => FavoriteShuttleJourney.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          ),
        );
      }
      final favoriteStationsJson =
          await _preferencesService.getString(_favoriteStationsKey);
      if (favoriteStationsJson != null && favoriteStationsJson.isNotEmpty) {
        favoriteStationIds.assignAll(
          (jsonDecode(favoriteStationsJson) as List<dynamic>).cast<int>(),
        );
      }
    } catch (e) {
      favoriteJourneys.clear();
      favoriteStationIds.clear();
    }
  }

  Future<void> _persistFavoriteJourneys() {
    return _preferencesService.setString(
      _favoriteJourneysKey,
      jsonEncode(favoriteJourneys.map((item) => item.toJson()).toList()),
    );
  }

  // 기본값 설정
  void setDefaultValues() {
    try {
      // 오늘 날짜를 기본 선택값으로 설정
      setDefaultDate();

      // 첫 번째 노선을 기본 선택값으로 설정
      if (routes.isNotEmpty && selectedRouteId.value == -1) {
        selectedRouteId.value = routes.first.id;
      }
    } catch (e) {
      print('기본값 설정 중 오류 발생: $e');
    }
  }

  // 현재 날짜를 기본값으로 설정
  void setDefaultDate() {
    try {
      final now = DateTime.now();
      final defaultDate = DateFormat('yyyy-MM-dd').format(now);

      // 날짜가 비어 있을 때만 기본값 적용
      if (selectedDate.value.isEmpty) {
        selectedDate.value = defaultDate;
        fetchScheduleTypeByDate(defaultDate);
      }
    } catch (e) {
      print('기본 날짜 설정 중 오류 발생: $e');
      // 오류가 나도 오늘 날짜로 fallback
      if (selectedDate.value.isEmpty) {
        final now = DateTime.now();
        final defaultDate = DateFormat('yyyy-MM-dd').format(now);
        selectedDate.value = defaultDate;
        fetchScheduleTypeByDate(defaultDate);
      }
    }
  }

  // 기본값 사용 여부 설정
  void setUseDefaultValues(bool value) {
    useDefaultValues.value = value;
    if (value) {
      setDefaultValues();
    }
  }

  void clearErrorMessage() {
    errorMessage.value = null;
  }

  void _emitError(String message) {
    // 동일 메시지도 다시 표시되게 한 번 비웠다가 재설정
    errorMessage.value = null;
    errorMessage.value = message;
  }

  // 노선 목록 조회
  Future<void> fetchRoutes() async {
    isLoadingRoutes.value = true;
    try {
      var routeList = await _shuttleRepository.fetchRoutes();

      // 천안 설정이면 노선 순서만 사용자 기준에 맞게 조정
      final campusSetting =
          await _preferencesService.getStringOrDefault('campus', '아산');
      if (campusSetting == '천안') {
        routeList = _reorderRoutesForCheonan(routeList);
      }

      routes.value = routeList;
    } catch (e) {
      print('노선 목록을 불러오는데 실패했습니다: $e');
      _emitError('노선 정보를 불러오는데 실패했습니다.');
    } finally {
      isLoadingRoutes.value = false;
    }
  }

  // 천안 설정일 때 노선 순서 조정
  List<ShuttleRoute> _reorderRoutesForCheonan(
      List<ShuttleRoute> originalRoutes) {
    List<ShuttleRoute> reorderedRoutes = List.from(originalRoutes);

    // 양방향 대표 노선 위치 찾기
    int asanToCheonanIndex = -1;
    int cheonanToAsanIndex = -1;

    for (int i = 0; i < reorderedRoutes.length; i++) {
      if (reorderedRoutes[i].routeName.contains('아캠 → 천캠')) {
        asanToCheonanIndex = i;
      } else if (reorderedRoutes[i].routeName.contains('천캠 → 아캠')) {
        cheonanToAsanIndex = i;
      }
    }

    // 천안 기준에서 더 자주 쓰는 방향이 먼저 보이도록 재정렬
    if (asanToCheonanIndex != -1 &&
        cheonanToAsanIndex != -1 &&
        cheonanToAsanIndex > asanToCheonanIndex) {
      // 천안→아산 노선을 아산→천안 노선 앞으로 이동
      ShuttleRoute cheonanToAsanRoute =
          reorderedRoutes.removeAt(cheonanToAsanIndex);
      reorderedRoutes.insert(asanToCheonanIndex, cheonanToAsanRoute);
    }

    return reorderedRoutes;
  }

  // 노선/날짜 기준 시간표 조회
  Future<bool> fetchSchedules(int routeId, String date) async {
    isLoadingSchedules.value = true;
    schedules.clear();
    selectedScheduleId.value = -1;
    scheduleStops.clear();
    String scheduleTypeName = '';

    try {
      final data = await _shuttleRepository.fetchSchedulesByDate(
        routeId: routeId,
        date: date,
      );

      if (data == null) {
        print('해당 날짜에 운행하는 셔틀노선이 없습니다 (404)');
        return false;
      }

      // 응답에 운행 유형명이 있으면 같이 저장
      if (data.containsKey('schedule_type_name')) {
        scheduleTypeName = data['schedule_type_name'];
        this.scheduleTypeName.value = scheduleTypeName;
      } else {
        this.scheduleTypeName.value = '';
      }

      // 시작 시각 기준으로 정렬 후 회차 번호 다시 매김
      final List<dynamic> scheduleData = data['schedules'];
      scheduleData.sort((a, b) {
        final aTime = a['start_time'];
        final bTime = b['start_time'];
        return aTime.compareTo(bTime);
      });

      for (int i = 0; i < scheduleData.length; i++) {
        scheduleData[i]['round'] = i + 1;
      }

      schedules.value =
          scheduleData.map((item) => Schedule.fromJson(item)).toList();

      if (useDefaultValues.value && schedules.isNotEmpty) {
        //selectNearestSchedule();
      }
      return true;
    } catch (e) {
      print('시간표를 불러오는데 실패했습니다: $e');
      _emitError('시간표를 불러오는데 실패했습니다.');
      return false;
    } finally {
      isLoadingSchedules.value = false;
    }
  }

  // 현재 시간에 가장 가까운 스케줄 선택
  void selectNearestSchedule() {
    try {
      final now = DateTime.now();

      // 현재 시각 이후 회차만 후보로 사용
      final futureSchedules = schedules
          .where((schedule) => schedule.startTime.isAfter(now))
          .toList();

      if (futureSchedules.isNotEmpty) {
        // 가장 이른 회차를 선택
        futureSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));
        selectSchedule(futureSchedules.first.id);
      } else {
        selectedScheduleId.value = -1;
      }
    } catch (e) {
      print('가장 가까운 스케줄 선택 중 오류 발생: $e');
    }
  }

  // 회차별 정류장 목록 조회
  Future<bool> fetchScheduleStops(int scheduleId) async {
    isLoadingStops.value = true;
    scheduleStops.clear();

    try {
      final data = await _shuttleRepository.fetchScheduleStops(scheduleId);
      if (data == null) {
        print('해당 스케줄의 정류장 정보가 없습니다 (404)');
        return false;
      }

      scheduleStops.value = data;
      return true;
    } catch (e) {
      print('정류장 정보를 불러오는데 실패했습니다: $e');

      return false;
    } finally {
      isLoadingStops.value = false;
    }
  }

  // 인라인 확장용 정류장 목록 조회
  Future<List<ScheduleStop>?> fetchScheduleStopsForInline(
      int scheduleId) async {
    try {
      final data = await _shuttleRepository.fetchScheduleStops(scheduleId);
      if (data == null) {
        print('해당 스케줄의 정류장 정보가 없습니다 (404)');
        return null;
      }
      return data;
    } catch (e) {
      print('인라인 정류장 정보를 불러오는데 실패했습니다: $e');
      return null;
    }
  }

  Future<List<StationSchedule>?> fetchStationSchedulesByDateForRoute({
    required int stationId,
    required int routeId,
    required String date,
  }) async {
    try {
      final data = await _shuttleRepository.fetchStationSchedulesByDate(
        stationId: stationId,
        date: date,
      );
      final List<dynamic> rawSchedules = List<dynamic>.from(
        data['schedules'] as List<dynamic>? ?? <dynamic>[],
      );
      final schedules = rawSchedules
          .map(
            (item) => StationSchedule.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((schedule) => schedule.routeId == routeId)
          .toList()
        ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

      return schedules;
    } catch (e) {
      print('정류장 기준 도착 시간을 불러오는데 실패했습니다: $e');
      return null;
    }
  }

  Future<List<RouteStation>?> fetchStationsForRoute(int routeId) async {
    try {
      return await _shuttleRepository.fetchRouteStations(routeId);
    } catch (e) {
      print('노선별 정류장 목록을 불러오는데 실패했습니다: $e');
      return null;
    }
  }

  // 정류장 목록 조회
  Future<void> fetchStations() async {
    isLoadingStations.value = true;
    try {
      stations.value = await _shuttleRepository.fetchStations();
    } catch (e) {
      print('정류장 목록을 불러오는데 실패했습니다: $e');
      _emitError('정류장 목록을 불러오는데 실패했습니다.');
    } finally {
      isLoadingStations.value = false;
    }
  }

  // 노선 선택 처리
  void selectRoute(int routeId) {
    if (selectedRouteId.value == routeId) return;

    selectedRouteId.value = routeId;
    schedules.clear();
    selectedScheduleId.value = -1;
    scheduleStops.clear();

    // 조회 버튼을 누를 때만 API 호출
    // if (selectedScheduleType.value.isNotEmpty) {
    //   fetchSchedules(routeId, selectedScheduleType.value);
    // }
  }

  // 날짜 선택 처리
  void selectDate(String date) {
    if (selectedDate.value == date) return;

    selectedDate.value = date;
    schedules.clear();
    selectedScheduleId.value = -1;
    scheduleStops.clear();
    fetchScheduleTypeByDate(date);
    journeySearchResult.value = null;
    if (selectedOriginStation.value != null) {
      fetchJourneyDestinations().then((_) => _clearUnreachableDestination());
    }
  }

  // 날짜 기준 운행 유형 조회
  Future<void> fetchScheduleTypeByDate(String date) async {
    if (date.isEmpty) {
      scheduleTypeName.value = '';
      return;
    }

    _latestScheduleTypeRequestDate = date;
    isLoadingScheduleType.value = true;

    try {
      final data = await _shuttleRepository.fetchScheduleTypeByDate(date);

      // 빠르게 날짜를 바꾼 경우 이전 응답은 무시
      if (_latestScheduleTypeRequestDate != date) {
        return;
      }

      scheduleTypeName.value = data?['schedule_type_name'] ?? '';
    } catch (e) {
      print('날짜별 운행 유형을 불러오는데 실패했습니다: $e');
      if (_latestScheduleTypeRequestDate == date) {
        scheduleTypeName.value = '';
      }
    } finally {
      if (_latestScheduleTypeRequestDate == date) {
        isLoadingScheduleType.value = false;
      }
    }
  }

  // 시간표 선택 시 정류장 목록도 함께 조회
  void selectSchedule(int scheduleId) {
    selectedScheduleId.value = scheduleId;
    fetchScheduleStops(scheduleId);
  }

  // 특정 정류장 상세 정보 조회
  Future<ShuttleStation?> fetchStationDetail(int stationId) async {
    try {
      final stationList = await _shuttleRepository.fetchStations(
        stationId: stationId,
      );
      if (stationList.isNotEmpty) {
        return stationList.first;
      }
      throw Exception('정류장 정보가 없습니다.');
    } catch (e) {
      print('정류장 정보를 불러오는데 실패했습니다: $e');
      _emitError('정류장 정보를 불러오는데 실패했습니다.');
      return null;
    }
  }
}
