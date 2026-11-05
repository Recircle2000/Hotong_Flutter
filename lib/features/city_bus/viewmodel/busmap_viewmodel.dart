import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';
import 'package:hsro/core/utils/bus_times_loader.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/city_bus/models/bus_city_model.dart';
import 'package:hsro/features/city_bus/utils/route_progress.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// 버스 위치 정보를 저장하는 클래스
class BusPosition {
  final String vehicleNo;
  final int nearestStationIndex;
  final double progressToNext; // 다음 정류장까지의 진행률 (0.0 ~ 1.0)
  final double distanceToStation; // 가장 가까운 정류장까지의 거리(미터)

  BusPosition({
    required this.vehicleNo,
    required this.nearestStationIndex,
    required this.progressToNext,
    required this.distanceToStation,
  });
}

class BusMarkerInfo {
  final LatLng position;
  final String vehicleNo;

  const BusMarkerInfo({
    required this.position,
    required this.vehicleNo,
  });
}

class StationMarkerInfo {
  final LatLng position;
  final String name;
  final String nodeId;
  final String nodeNo;
  final String nodeOrd;

  const StationMarkerInfo({
    required this.position,
    required this.name,
    required this.nodeId,
    required this.nodeNo,
    required this.nodeOrd,
  });
}

class BusMapViewModel extends GetxController with WidgetsBindingObserver {
  BusMapViewModel({this.initialRouteOverride});

  final String? initialRouteOverride;
  final markers = RxList<BusMarkerInfo>([]);
  final stationMarkers = RxList<StationMarkerInfo>([]);
  final selectedRoute = "순환5_DOWN".obs;
  final currentPositions = RxList<int>([]); // 여러 버스의 위치를 저장하는 리스트
  final detailedBusPositions = RxList<BusPosition>([]); // 상세 버스 위치 정보
  final routePolylinePoints = RxList<LatLng>([]); // GeoJSON 폴리라인 포인트들
  final stationNames = RxList<String>([]); // 정류장 이름 목록
  final stationNumbers = RxList<String>([]); // 정류장 번호 목록
  late WebSocketChannel channel;

  // 현재 위치 관련 변수
  final Rx<LatLng?> currentLocation = Rx<LatLng?>(null);
  final isLocationEnabled = false.obs;
  final isLocationLoading = false.obs;
  final selectedTab = 0.obs;

  // 웹소켓 데이터 수신 상태 추가
  final hasReceivedWebSocketData = false.obs;

  // 다음 출발시간 저장 (노선별)
  final RxMap<String, String> nextDepartureTimes = <String, String>{}.obs;

  // 모든 노선의 버스 데이터 저장 (grouped_bus_view에서 사용)
  final RxMap<String, List<Bus>> allRoutesBusData = <String, List<Bus>>{}.obs;

  // 지금 지도선과 정류장 목록이 어느 노선 것인지. 둘이 같은 노선일 때만 트랙을 만든다.
  String? _polylineRoute;
  String? _stationsRoute;

  // 지도선을 따라 정류장·버스 위치를 계산하는 트랙 (선택 노선용)
  RouteTrack? _routeTrack;

  // 차량별 직전 노선 거리(m). GPS가 조금 뒤로 튀어도 버스가 뒤로 가 보이지 않게 한다.
  final Map<String, double> _lastBusS = {};

  /// 노선을 변경하고 데이터를 새로고침하는 함수 (웹소켓 재연결 없이)
  void updateSelectedRoute(String route) {
    // 이미 같은 노선이면 무시
    if (selectedRoute.value == route) return;

    selectedRoute.value = route;

    // 이전 노선의 데이터 초기화
    markers.clear();
    currentPositions.clear();
    detailedBusPositions.clear();
    routePolylinePoints.clear();
    _polylineRoute = null;
    _routeTrack = null;
    _lastBusS.clear();

    // 데이터 새로고침
    fetchRouteData(route);
    fetchStationData(route);

    // 🚀 최적화: 이미 수신된 데이터가 있다면 즉시 표시
    if (allRoutesBusData.containsKey(route) &&
        allRoutesBusData[route]!.isNotEmpty) {
      final busList = allRoutesBusData[route]!;
      updateBusMarkers(busList);
      _updateCurrentPosition(busList);
      update();
    }

    // 웹소켓에 새 노선 정보 전송
    try {
      channel.sink.add(jsonEncode({"route": selectedRoute.value}));
      print("Updated WebSocket route preference: ${selectedRoute.value}");
    } catch (e) {
      print("Failed to send route update to WebSocket: $e");
    }
  }

  // bus_times.json 캐시
  Map<String, dynamic>? _busTimesCache;

  /// bus_times.json을 한 번만 읽어서 캐싱
  Future<Map<String, dynamic>> loadBusTimesOnce() async {
    if (_busTimesCache != null) return _busTimesCache!;
    final data = await BusTimesLoader.loadBusTimes();
    _busTimesCache = data;
    return data;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this); // 앱 상태 감지 추가
    // Set selectedRoute based on campus
    final settingsViewModel = Get.find<SettingsViewModel>();
    final String? overrideRoute = initialRouteOverride;
    if (overrideRoute != null && overrideRoute.isNotEmpty) {
      selectedRoute.value = overrideRoute;
    } else {
      final campus = settingsViewModel.selectedCampus.value;
      if (campus == "천안") {
        selectedRoute.value = "24_DOWN";
      } else {
        selectedRoute.value = "순환5_DOWN";
      }
    }
    // Listen for campus changes
    ever(settingsViewModel.selectedCampus, (String newCampus) {
      if (initialRouteOverride != null && initialRouteOverride!.isNotEmpty) {
        return;
      }
      if (newCampus == "천안") {
        selectedRoute.value = "24_DOWN";
      } else {
        selectedRoute.value = "순환5_DOWN";
      }
      _routeTrack = null;
      _lastBusS.clear();
      fetchRouteData(selectedRoute.value);
      fetchStationData(selectedRoute.value);
    });
    _connectWebSocket();
    fetchRouteData(selectedRoute.value); // 초기 경로 데이터 로드
    fetchStationData(selectedRoute.value); // 초기 정류장 데이터 로드
    checkLocationPermission(); // 위치 권한 확인
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this); // 앱 상태 감지 제거
    _disconnectWebSocket();
    super.onClose();
  }

  /// 앱 상태 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      print("백그라운드로 이동 -> 웹소켓 연결 해제");
      _disconnectWebSocket();
    } else if (state == AppLifecycleState.resumed) {
      print("앱 활성화 -> 웹소켓 재연결");
      _connectWebSocket();
    }
  }

  /// 웹소켓 연결 함수
  // 노선별로 버스를 마지막으로 확인한 시각. 외부 API가 잠깐 비어도 바로 지우지 않는다.
  final Map<String, DateTime> _lastBusSeenAt = {};
  static const _busHoldDuration = Duration(seconds: 20);

  bool _isHoldingBuses(String routeKey, DateTime now) {
    final seenAt = _lastBusSeenAt[routeKey];
    return seenAt != null && now.difference(seenAt) < _busHoldDuration;
  }

  void _connectWebSocket() {
    _disconnectWebSocket(); // 기존 연결 초기화
    try {
      channel = WebSocketChannel.connect(Uri.parse(_getWebSocketUrl()));

      // 연결 즉시 데이터 요청 (선택적)
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          channel.sink.add(jsonEncode({"route": selectedRoute.value}));
        } catch (e) {
          print("웹소켓 데이터 요청 오류: $e");
        }
      });

      channel.stream.listen((event) {
        final data = jsonDecode(event);
        print('Current selected route: ${selectedRoute.value}');
        print('WebSocket received data: $data');

        // 웹소켓 데이터 수신 상태 업데이트
        hasReceivedWebSocketData.value = true;

        // 모든 노선의 데이터를 저장 (grouped_bus_view용)
        final now = DateTime.now();
        for (final entry in data.entries) {
          final routeKey = entry.key;
          final busDataList = entry.value as List;

          if (busDataList.isNotEmpty) {
            final busList = busDataList.map((e) => Bus.fromJson(e)).toList();
            allRoutesBusData[routeKey] = busList;
            _lastBusSeenAt[routeKey] = now;
          } else if (!_isHoldingBuses(routeKey, now)) {
            allRoutesBusData[routeKey] = [];
          }
        }

        // 선택된 노선에 버스가 있으면 마커 업데이트.
        // 방금 응답이 비었더라도 유예 시간 안이면 마지막 위치를 유지해 깜빡임을 막는다.
        final selected = selectedRoute.value;
        final incoming = data[selected];
        final List<Bus> busList = incoming is List && incoming.isNotEmpty
            ? incoming.map((e) => Bus.fromJson(e)).toList()
            : (_isHoldingBuses(selected, now)
                ? (allRoutesBusData[selected] ?? const <Bus>[])
                : const <Bus>[]);
        if (busList.isNotEmpty) {
          print('Found ${busList.length} buses for route $selected');
          updateBusMarkers(busList);
          _updateCurrentPosition(busList);
          update(); // UI 새로 고침
        } else {
          print(
              'No data found for route ${selectedRoute.value} - clearing markers');
          markers.clear();
          // 데이터가 없을 경우 버스 위치도 초기화 (정류장 목록의 버스 아이콘 포함)
          currentPositions.clear();
          detailedBusPositions.clear();
          update(); // UI 새로 고침
        }
      }, onError: (error) {
        print("WebSocket Error: $error");
        Fluttertoast.showToast(
          msg: "서버 연결 오류: $error",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }, onDone: () {
        print("WebSocket Closed");
      });
    } catch (e) {
      print("WebSocket Connection Error: $e");
    }
  }

  /// 웹소켓 연결 해제 함수
  void _disconnectWebSocket() {
    try {
      channel.sink.close();
      print("WebSocket Closed");
    } catch (e) {
      print("WebSocket Close Error: $e");
    }
  }

  /// 버스 경로 데이터 불러오기
  Future<void> fetchRouteData([String? routeKey]) async {
    final String targetRoute = routeKey ?? selectedRoute.value;
    try {
      final geoJson = await BusStaticDataLoader.loadRouteGeoJson(targetRoute);
      if (selectedRoute.value != targetRoute) {
        return;
      }

      final coordinates = geoJson['features'][0]['geometry']['coordinates'];
      final polylinePoints = coordinates
          .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
          .toList();

      // 폴리라인 데이터 저장
      routePolylinePoints.assignAll(polylinePoints);
      _polylineRoute = targetRoute;
      _rebuildRouteTrack(targetRoute);
    } catch (e) {
      if (selectedRoute.value != targetRoute) {
        return;
      }
      print("경로 데이터를 불러오는 중 오류 발생: $e");
      Fluttertoast.showToast(
        msg: "경로 데이터를 불러올 수 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      routePolylinePoints.clear();
      _polylineRoute = null;
      _rebuildRouteTrack(targetRoute);
    }
  }

  /// 지도선과 정류장 목록이 같은 노선으로 준비되면 트랙을 만들고,
  /// 받아 둔 버스 위치를 바로 다시 계산한다 (다음 웹소켓 메시지를 기다리지 않음).
  void _rebuildRouteTrack(String routeKey) {
    if (selectedRoute.value != routeKey) return;

    final ready = _polylineRoute == routeKey &&
        _stationsRoute == routeKey &&
        routePolylinePoints.isNotEmpty &&
        stationMarkers.isNotEmpty;
    _routeTrack = ready
        ? RouteTrack.build(
            routePolylinePoints.toList(),
            [for (final station in stationMarkers) station.position],
          )
        : null;

    final buses = allRoutesBusData[routeKey];
    if (stationMarkers.isNotEmpty && buses != null && buses.isNotEmpty) {
      updateBusMarkers(buses);
      _updateCurrentPosition(buses);
      update();
    }
  }

  /// 🚏 정류장 데이터 불러오기
  Future<void> fetchStationData([String? routeKey]) async {
    final String targetRoute = routeKey ?? selectedRoute.value;
    try {
      // 초기화
      stationMarkers.clear();
      stationNames.clear();
      stationNumbers.clear();
      currentPositions.clear();
      detailedBusPositions.clear();
      _stationsRoute = null;
      _routeTrack = null;

      final data = await BusStaticDataLoader.loadStopJson(targetRoute);
      if (selectedRoute.value != targetRoute) {
        return;
      }

      final stations = data['response']['body']['items']['item'] as List;

      // 정류장 이름과 번호 목록 업데이트
      final names = stations
          .map<String>((station) => station['nodenm']?.toString() ?? "정류장")
          .toList();
      final numbers = stations
          .map<String>((station) => station['nodeno']?.toString() ?? "")
          .toList();

      stationNames.assignAll(names);
      stationNumbers.assignAll(numbers);

      final stopMarkers = stations.map<StationMarkerInfo>((rawStation) {
        final station = Map<String, dynamic>.from(rawStation as Map);
        return StationMarkerInfo(
          position: LatLng(
            double.parse(station['gpslati'].toString()),
            double.parse(station['gpslong'].toString()),
          ),
          name: station['nodenm']?.toString() ?? 'Unknown station',
          nodeId: station['nodeid']?.toString() ?? 'N/A',
          nodeNo: station['nodeno']?.toString() ?? 'N/A',
          nodeOrd: station['nodeord']?.toString() ?? 'N/A',
        );
      }).toList();

      stationMarkers.assignAll(stopMarkers);
      _stationsRoute = targetRoute;

      // 노선을 바꾼 직후에는 정류장 목록이 아직 없어 버스가 어느 정류장에 있는지 계산하지 못했다.
      // 노선 정보 화면에서 이미 받아 둔 위치로 지금 다시 계산해, 다음 웹소켓 메시지(최대 5초)를 기다리지 않게 한다.
      _rebuildRouteTrack(targetRoute);
    } catch (e) {
      if (selectedRoute.value != targetRoute) {
        return;
      }
      print("정류장 데이터를 불러오는 중 오류 발생: $e");
      Fluttertoast.showToast(
        msg: "정류장 데이터를 불러올 수 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  /// 버스 마커 업데이트
  void updateBusMarkers(List<Bus> busList) {
    if (busList.isEmpty) {
      markers.clear(); // Clear all markers if no bus data
      return;
    }
    final newMarkers = busList
        .map(
          (bus) => BusMarkerInfo(
            position: LatLng(bus.latitude, bus.longitude),
            vehicleNo: bus.vehicleNo,
          ),
        )
        .toList();

    markers.assignAll(newMarkers);
  }

  void _updateCurrentPosition(List<Bus> busList) {
    if (busList.isEmpty || stationMarkers.isEmpty) {
      currentPositions.clear();
      detailedBusPositions.clear();
      return;
    }

    // 트랙이 지금 정류장 목록과 맞을 때만 쓴다 (노선 전환 중 어긋남 방지)
    final track = _routeTrack != null &&
            _routeTrack!.stationCount == stationMarkers.length
        ? _routeTrack
        : null;
    final stopRefs = [
      for (final station in stationMarkers)
        RouteStopRef(
          nodeOrd: int.tryParse(station.nodeOrd),
          name: station.name,
        ),
    ];

    final busPositions = <int>{};
    final detailedPositions = <BusPosition>[];

    for (final bus in busList) {
      final busLatLng = LatLng(bus.latitude, bus.longitude);

      // BIS 정류장 순번은 이름까지 맞을 때만 보조로 쓴다
      final nodeIndex =
          resolveStationIndex(stopRefs, bus.nodeOrd, bus.stationName);

      int stationIndex;
      double progressToNext;
      if (track != null) {
        // 지도선을 따라 버스가 실제로 지난 정류장과 진행률 계산
        final location = track.locate(
          busLatLng,
          nodeIndex: nodeIndex,
          previousS: _lastBusS[bus.vehicleNo],
        );
        stationIndex = location.index;
        progressToNext = location.progress;
        final s = location.s;
        if (s != null) _lastBusS[bus.vehicleNo] = s;
      } else {
        // 지도선이 아직 없으면 BIS 정류장(없으면 가장 가까운 정류장)에 둔다
        stationIndex = nodeIndex ?? _findNearestStationByDistance(busLatLng);
        progressToNext = 0;
      }

      detailedPositions.add(BusPosition(
        vehicleNo: bus.vehicleNo,
        nearestStationIndex: stationIndex,
        progressToNext: progressToNext,
        distanceToStation: const Distance().as(LengthUnit.Meter,
            stationMarkers[stationIndex].position, busLatLng),
      ));
      busPositions.add(stationIndex);
    }

    // 지금 목록에 없는 차량의 직전 위치는 버린다
    final vehicleNos = {for (final bus in busList) bus.vehicleNo};
    _lastBusS.removeWhere((vehicleNo, _) => !vehicleNos.contains(vehicleNo));

    currentPositions.assignAll(busPositions.toList()..sort());
    detailedBusPositions.assignAll(detailedPositions);
  }

  /// 단순 거리 기반으로 가장 가까운 정류장 찾기 (지도선이 없을 때 대체용)
  int _findNearestStationByDistance(LatLng busPosition) {
    double minDistance = double.infinity;
    int nearestStationIndex = 0;

    for (int i = 0; i < stationMarkers.length; i++) {
      final distance = const Distance()
          .as(LengthUnit.Meter, stationMarkers[i].position, busPosition);

      if (distance < minDistance) {
        minDistance = distance;
        nearestStationIndex = i;
      }
    }

    return nearestStationIndex;
  }

  /// 노선별 다음 출발시간 계산 (특히 _DOWN 노선)
  Future<void> updateNextDepartureTime(String routeKey) async {
    try {
      final busTimes = await loadBusTimesOnce();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final timetable = busTimes[routeKey]?['시간표'] as List<dynamic>?;
      if (timetable == null || timetable.isEmpty) {
        nextDepartureTimes[routeKey] = '시간표 없음';
        return;
      }
      // HH:mm 문자열을 DateTime으로 변환
      final times = timetable.map((t) {
        final parts = t.split(':');
        return DateTime(today.year, today.month, today.day, int.parse(parts[0]),
            int.parse(parts[1]));
      }).toList();
      // 현재 시간 이후의 첫 출발 찾기
      final next = times.firstWhereOrNull((t) => t.isAfter(now));
      if (next != null) {
        nextDepartureTimes[routeKey] =
            '출발: ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
      } else {
        nextDepartureTimes[routeKey] = '운행 종료';
      }
    } catch (e) {
      nextDepartureTimes[routeKey] = '시간표 오류';
    }
  }

  void resetConnection() {
    // 데이터 초기화
    markers.clear();
    currentPositions.clear();
    detailedBusPositions.clear();
    routePolylinePoints.clear();
    _polylineRoute = null;
    _routeTrack = null;
    _lastBusS.clear();

    // 웹소켓 데이터 수신 상태 초기화
    hasReceivedWebSocketData.value = false;

    // 연결 재설정
    _disconnectWebSocket();
    _connectWebSocket();
  }

  /// 위치 권한 확인 및 현재 위치 가져오기
  Future<void> checkLocationPermission() async {
    isLocationLoading.value = true;

    try {
      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        isLocationLoading.value = false;
        isLocationEnabled.value = false;
        Fluttertoast.showToast(
          msg: "위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // 권한이 거부된 경우, 사용자에게 권한 요청
        Fluttertoast.showToast(
          msg: "위치 권한을 요청합니다",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          isLocationLoading.value = false;
          isLocationEnabled.value = false;
          Fluttertoast.showToast(
            msg: "위치 권한이 거부되었습니다.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        isLocationLoading.value = false;
        isLocationEnabled.value = false;
        Fluttertoast.showToast(
          msg: "위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }

      // 권한이 있으면 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // 10초 타임아웃 설정
      );

      currentLocation.value = LatLng(position.latitude, position.longitude);
      isLocationEnabled.value = true;
      isLocationLoading.value = false;

      print("현재 위치: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("위치 정보를 가져오는 중 오류 발생: $e");
      isLocationLoading.value = false;
      isLocationEnabled.value = false;

      // 오류 메시지 구체화
      String errorMessage = "위치 정보를 가져올 수 없습니다.";
      if (e.toString().contains("timeout")) {
        errorMessage = "위치 정보를 가져오는 데 시간이 너무 오래 걸립니다.";
      } else if (e.toString().contains("permission")) {
        errorMessage = "위치 권한이 필요합니다. 설정에서 권한을 허용해주세요.";
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  /// 현재 위치를 실시간으로 추적
  void startLocationTracking() {
    if (!isLocationEnabled.value) {
      checkLocationPermission();
      return;
    }

    // 위치 변경 리스너 등록
    try {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 10미터마다 업데이트
        ),
      ).listen((Position position) {
        currentLocation.value = LatLng(position.latitude, position.longitude);
        print("위치 업데이트: ${position.latitude}, ${position.longitude}");
      });
    } catch (e) {
      print("위치 추적 중 오류 발생: $e");
      Fluttertoast.showToast(
        msg: "위치 추적을 시작할 수 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  /// 가장 가까운 정류장 찾기
  int? findNearestStation() {
    if (currentLocation.value == null || stationMarkers.isEmpty) {
      return null;
    }

    double minDistance = double.infinity;
    int nearestIndex = -1;

    for (int i = 0; i < stationMarkers.length; i++) {
      final station = stationMarkers[i];
      final distance = const Distance()
          .as(LengthUnit.Meter, currentLocation.value!, station.position);

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    if (nearestIndex != -1) {
      return nearestIndex;
    }

    return null;
  }
}

String _getWebSocketUrl() {
  return "wss://${EnvConfig.baseUrl.replaceAll('https://', '')}/ws/bus";
  //return "ws://10.0.2.2:8000/ws/bus";
}
