import 'dart:async';
import 'dart:io' show Platform;

import 'package:hsro/features/city_bus/models/city_bus_share.dart';
import 'package:hsro/shared/widgets/link_share_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';
import 'package:hsro/features/city_bus/view/components/route_title.dart';
import 'package:hsro/features/city_bus/view/components/station_item.dart'
    show cityBusAccent, cityBusAccentOnDark;
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class NaverBusMapDetailView extends StatefulWidget {
  final String routeName;

  const NaverBusMapDetailView({super.key, required this.routeName});

  @override
  State<NaverBusMapDetailView> createState() => _NaverBusMapDetailViewState();
}

class _NaverBusMapDetailViewState extends State<NaverBusMapDetailView> {
  final BusMapViewModel controller = Get.find<BusMapViewModel>();
  final SettingsViewModel settingsViewModel = Get.find<SettingsViewModel>();

  final List<Worker> _workers = [];
  // 정류장 마커와 정류장 상세 정보 매칭용 메타데이터
  List<_StationMetadata> _stationMetadata = const [];

  NaverMapController? _mapController;
  bool _isMapReady = false;
  // 오버레이 중복 갱신 방지용 상태값
  bool _isRefreshingOverlays = false;
  bool _overlayRefreshQueued = false;
  bool _isPreparingBusIcon = false;
  bool _isPreparingStationIcon = false;
  bool _isPreparingArrowIcon = false;
  Brightness? _overlayBrightness;

  NOverlayImage? _busMarkerIcon;
  NOverlayImage? _stationMarkerIcon;
  NOverlayImage? _routeArrowIcon;

  // 노선 전체가 보이도록 카메라를 맞춘 노선. 같은 노선은 한 번만 맞춘다.
  String? _fittedRoute;

  static const double _busIconCanvas = 36;
  static const double _stationIconSize = 12;
  static const double _arrowIconSize = 12;
  // 기본 마커(200000)보다 위에 그려 버스가 정류장 원에 가리지 않게 한다
  static const int _busGlobalZIndex = 210000;

  @override
  void initState() {
    super.initState();
    _loadStationMetadata();

    _workers.addAll([
      // 노선이 바뀌면 정류장 메타데이터와 오버레이 다시 갱신
      ever(controller.selectedRoute, (_) {
        _loadStationMetadata();
        _queueOverlayRefresh();
      }),
      // 지도 표시 데이터가 바뀌는 경우 오버레이 다시 그리기
      ever(controller.routePolylinePoints, (_) => _queueOverlayRefresh()),
      ever(controller.stationMarkers, (_) => _queueOverlayRefresh()),
      ever(controller.markers, (_) => _queueOverlayRefresh()),
      ever(controller.allRoutesBusData, (_) => _queueOverlayRefresh()),
    ]);
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  // 정류장 목록 화면과 같은 시내버스 색 하나로 라인·정류장·버스를 그린다
  Color get _accent => _isDarkMode ? cityBusAccentOnDark : cityBusAccent;

  // 지도 바탕과 떨어지게 하는 색. 라인 테두리, 정류장 원 안쪽, 강조색 위 아이콘에 쓴다.
  Color get _mapSurface =>
      _isDarkMode ? const Color(0xFF14161A) : Colors.white;

  Color get _busCaptionColor =>
      _isDarkMode ? const Color(0xFFEAF1FF) : const Color(0xFF1F2937);

  // 이 줌보다 작으면(더 멀리 보면) 정류장 마커를 숨깁니다.
  double get _stationMarkerMinZoom => 12.5;

  void _syncOverlayTheme() {
    // 테마가 바뀌면 위젯 기반 마커 아이콘 다시 생성
    final brightness = Theme.of(context).brightness;
    if (_overlayBrightness == brightness) {
      return;
    }

    _overlayBrightness = brightness;
    _busMarkerIcon = null;
    _stationMarkerIcon = null;
    _routeArrowIcon = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prepareBusMarkerIcon();
      _prepareStationMarkerIcon();
      _prepareRouteArrowIcon();
      _queueOverlayRefresh();
    });
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _mapController = null;
    super.dispose();
  }

  Future<void> _loadStationMetadata() async {
    // 선택된 노선에 맞는 정류장 메타데이터 JSON 불러옴
    final route = controller.selectedRoute.value;

    try {
      final data = await BusStaticDataLoader.loadStopJson(route);
      final rawItems = data['response']?['body']?['items']?['item'];
      final List<dynamic> items = rawItems is List
          ? rawItems
          : (rawItems == null ? <dynamic>[] : <dynamic>[rawItems]);

      // 비동기 로드 중 노선이 바뀐 경우 이전 결과 무시
      if (route != controller.selectedRoute.value) {
        return;
      }

      _stationMetadata = items.map((raw) {
        final station = raw as Map<String, dynamic>;
        return _StationMetadata(
          name: station['nodenm']?.toString() ?? '정류장',
          nodeId: station['nodeid']?.toString() ?? '없음',
          nodeNo: station['nodeno']?.toString() ?? '없음',
          nodeOrd: station['nodeord']?.toString() ?? '없음',
        );
      }).toList();
    } catch (_) {
      // 메타데이터 로드 실패 시 빈 목록으로 처리
      _stationMetadata = const [];
    } finally {
      _queueOverlayRefresh();
    }
  }

  Future<void> _prepareBusMarkerIcon() async {
    // 동일 아이콘 중복 생성 방지
    if (_isPreparingBusIcon || _busMarkerIcon != null || !mounted) {
      return;
    }

    _isPreparingBusIcon = true;
    try {
      // 정류장 목록의 버스 표시와 같은 모양: 시내버스 색으로 채운 원 + 버스 아이콘
      _busMarkerIcon = await NOverlayImage.fromWidget(
        context: context,
        size: const Size(_busIconCanvas, _busIconCanvas),
        widget: SizedBox.square(
          dimension: _busIconCanvas,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: _mapSurface, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsRegular.bus,
                size: 16,
                color: _mapSurface,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      // 아이콘 생성 실패 시 기본 마커 색상 사용
    } finally {
      _isPreparingBusIcon = false;
      if (mounted) {
        _queueOverlayRefresh();
      }
    }
  }

  Future<void> _prepareStationMarkerIcon() async {
    // 동일 아이콘 중복 생성 방지
    if (_isPreparingStationIcon || _stationMarkerIcon != null || !mounted) {
      return;
    }

    _isPreparingStationIcon = true;
    try {
      // 정류장 목록과 같은 속 빈 원. 중심을 좌표에 맞춰 라인 위에 얹는다.
      _stationMarkerIcon = await NOverlayImage.fromWidget(
        context: context,
        size: const Size(_stationIconSize, _stationIconSize),
        widget: Container(
          width: _stationIconSize,
          height: _stationIconSize,
          decoration: BoxDecoration(
            color: _mapSurface,
            shape: BoxShape.circle,
            border: Border.all(color: _accent, width: 2),
          ),
        ),
      );
    } catch (_) {
      // 아이콘 생성 실패 시 기본 마커 색상 사용
    } finally {
      _isPreparingStationIcon = false;
      if (mounted) {
        _queueOverlayRefresh();
      }
    }
  }

  Future<void> _prepareRouteArrowIcon() async {
    // 노선 라인 위 진행 방향 화살표 (이미지 위쪽이 진행 방향)
    if (_isPreparingArrowIcon || _routeArrowIcon != null || !mounted) {
      return;
    }

    _isPreparingArrowIcon = true;
    try {
      _routeArrowIcon = await NOverlayImage.fromWidget(
        context: context,
        size: const Size(_arrowIconSize, _arrowIconSize),
        widget: Icon(
          PhosphorIconsBold.caretUp,
          size: _arrowIconSize,
          color: _mapSurface,
        ),
      );
    } catch (_) {
      // 화살표 생성 실패 시 화살표 없이 라인만 표시
    } finally {
      _isPreparingArrowIcon = false;
      if (mounted) {
        _queueOverlayRefresh();
      }
    }
  }

  void _queueOverlayRefresh() {
    // 지도 준비 전에는 오버레이 갱신 생략
    if (!_isMapReady || _mapController == null) {
      return;
    }

    if (_isRefreshingOverlays) {
      // 갱신 중 추가 요청은 큐에만 표시
      _overlayRefreshQueued = true;
      return;
    }

    unawaited(_refreshOverlays());
  }

  Future<void> _refreshOverlays() async {
    final mapController = _mapController;
    if (!_isMapReady || mapController == null) {
      return;
    }

    _isRefreshingOverlays = true;
    try {
      await mapController.clearOverlays(type: NOverlayType.pathOverlay);
      await mapController.clearOverlays(type: NOverlayType.marker);

      // 현재 상태 기준으로 경로, 정류장, 버스 오버레이 다시 구성
      final overlays = <NAddableOverlay>{};
      overlays.addAll(_buildRouteOverlays());
      overlays.addAll(_buildStationOverlays());
      overlays.addAll(_buildBusOverlays());

      if (overlays.isNotEmpty) {
        await mapController.addOverlayAll(overlays);
      }
      await _fitRouteIfNeeded(mapController);
    } catch (_) {
      // 지도 전환 타이밍에는 오버레이 갱신 실패 가능, 무시
    } finally {
      _isRefreshingOverlays = false;
      if (_overlayRefreshQueued) {
        _overlayRefreshQueued = false;
        _queueOverlayRefresh();
      }
    }
  }

  Future<void> _fitRouteIfNeeded(NaverMapController mapController) async {
    // 노선을 처음 그릴 때 한 번, 노선 전체가 화면에 들어오게 맞춘다
    final route = controller.selectedRoute.value;
    final points = controller.routePolylinePoints.toList();
    if (points.length < 2 || _fittedRoute == route) {
      return;
    }

    _fittedRoute = route;
    await mapController.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds.from(
          points.map((point) => NLatLng(point.latitude, point.longitude)),
        ),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  Set<NPathOverlay> _buildRouteOverlays() {
    final points = controller.routePolylinePoints.toList();
    if (points.isEmpty) {
      return const <NPathOverlay>{};
    }

    // flutter_naver_map은 Iterable 대신 List 직렬화만 안정적으로 처리
    final coords = points
        .map((point) => NLatLng(point.latitude, point.longitude))
        .toList(growable: false);

    return {
      NPathOverlay(
        id: 'city_bus_route_path',
        coords: coords,
        width: 7,
        color: _accent,
        outlineColor: _mapSurface,
        outlineWidth: 1.5,
        patternImage: _routeArrowIcon,
        patternInterval: 64,
      ),
    };
  }

  Set<NMarker> _buildStationOverlays() {
    final stationMarkers = controller.stationMarkers.toList();
    if (stationMarkers.isEmpty) {
      return const <NMarker>{};
    }

    final overlays = <NMarker>{};
    for (int i = 0; i < stationMarkers.length; i++) {
      // 정류장 마커 순서 기준으로 메타데이터 매칭
      final point = stationMarkers[i].position;
      final metadata = i < _stationMetadata.length ? _stationMetadata[i] : null;
      // 아이콘이 준비되기 전에는 그리지 않는다 (기본 핀이 잠깐 보이지 않게)
      final icon = _stationMarkerIcon;
      if (icon == null) continue;

      final marker = NMarker(
        id: 'city_station_$i',
        position: NLatLng(point.latitude, point.longitude),
        icon: icon,
        size: const Size(_stationIconSize, _stationIconSize),
        anchor: const NPoint(0.5, 0.5),
      );
      marker.setMinZoom(_stationMarkerMinZoom);
      marker.setOnTapListener((_) => _showStationInfo(metadata, i));
      overlays.add(marker);
    }

    return overlays;
  }

  Set<NMarker> _buildBusOverlays() {
    final selectedRoute = controller.selectedRoute.value;
    final buses = controller.allRoutesBusData[selectedRoute] ?? const [];

    if (buses.isEmpty) {
      // 실시간 버스 데이터가 없으면 기존 마커 좌표만 사용
      final markerPoints = controller.markers.toList();
      return markerPoints.asMap().entries.map((entry) {
        final point = entry.value.position;
        return _createBusMarker(
          id: 'city_bus_${entry.key}',
          position: NLatLng(point.latitude, point.longitude),
        );
      }).toSet();
    }

    return buses.asMap().entries.map((entry) {
      final bus = entry.value;
      return _createBusMarker(
        id: 'city_bus_${bus.vehicleNo}_${entry.key}',
        position: NLatLng(bus.latitude, bus.longitude),
        vehicleNo: bus.vehicleNo,
      );
    }).toSet();
  }

  NMarker _createBusMarker({
    required String id,
    required NLatLng position,
    String vehicleNo = '',
  }) {
    // 커스텀 아이콘이 준비되면 사용하고, 아니면 기본 마커로 표시
    final hasCustomIcon = _busMarkerIcon != null;
    final busNumber = _shortVehicleNo(vehicleNo);
    final caption = busNumber.isEmpty
        ? null
        : NOverlayCaption(
            text: busNumber,
            textSize: 12,
            color: _busCaptionColor,
            haloColor: _mapSurface,
          );

    final marker = hasCustomIcon
        ? NMarker(
            id: id,
            position: position,
            icon: _busMarkerIcon,
            size: const Size(_busIconCanvas, _busIconCanvas),
            caption: caption,
            anchor: const NPoint(0.5, 0.5),
          )
        : NMarker(
            id: id,
            position: position,
            size: const Size(20, 20),
            iconTintColor: _accent,
            caption: caption,
            anchor: const NPoint(0.5, 1.0),
          );
    // 버스는 정류장 원보다 항상 위에 그린다
    marker.setGlobalZIndex(_busGlobalZIndex);
    return marker;
  }

  // "충남72자1070" → "1070" (정류장 목록의 차량 번호 배지와 같은 표기)
  String _shortVehicleNo(String vehicleNo) {
    final match = RegExp(r'(\d{4})$').firstMatch(vehicleNo.trim());
    return match?.group(1) ?? vehicleNo;
  }

  void _showStationInfo(_StationMetadata? station, int index) {
    Get.dialog(
      AlertDialog(
        title: Text(station?.name ?? '정류장'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정류장 ID: ${station?.nodeId ?? "없음"}'),
            const SizedBox(height: 8),
            Text('정류장 번호: ${station?.nodeNo ?? "없음"}'),
            const SizedBox(height: 8),
            Text('정류장 순서: ${station?.nodeOrd ?? "${index + 1}"}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('닫기')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // build 시점 테마와 오버레이 아이콘 상태 동기화
    _syncOverlayTheme();

    return Scaffold(
      appBar: AppBar(
        title: CityBusRouteTitle(displayName: widget.routeName),
        centerTitle: true,
        actions: [
          LinkShareButton(
            content: () => CityBusShare.content(controller.selectedRoute.value),
          ),
        ],
        leading: IconButton(
          icon: Icon(
            Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
          ),
          onPressed: () => Get.back(),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          Obx(() {
            final campus = settingsViewModel.selectedCampus.value;
            final defaultCenter = campus == '천안'
                ? const NLatLng(36.8299, 127.1814)
                : const NLatLng(36.769423, 127.08);

            return NaverMap(
              // 테마나 캠퍼스가 바뀌면 지도를 새로 생성해 스타일과 초기 위치 반영
              key: ValueKey('${Theme.of(context).brightness}_$campus'),
              forceGesture: true,
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: defaultCenter,
                  zoom: 13,
                ),
                mapType: NMapType.basic,
                nightModeEnable:
                    Theme.of(context).brightness == Brightness.dark,
                maxZoom: 18,
                minZoom: 10,
                contentPadding: EdgeInsets.zero,
                rotationGesturesEnable: false,
                tiltGesturesEnable: false,
                scaleBarEnable: false,
                indoorEnable: false,
                indoorLevelPickerEnable: false,
                locationButtonEnable: true,
              ),
              onMapReady: (mapController) {
                // 지도 준비 완료 후 컨트롤러 연결 및 오버레이 첫 갱신
                _mapController = mapController;
                _isMapReady = true;
                // 테마·캠퍼스 변경으로 지도를 새로 만들면 노선 전체 보기도 다시 맞춘다
                _fittedRoute = null;
                mapController.setLocationTrackingMode(
                  NLocationTrackingMode.noFollow,
                );
                _queueOverlayRefresh();
              },
            );
          }),
        ],
      ),
    );
  }
}

class _StationMetadata {
  final String name;
  final String nodeId;
  final String nodeNo;
  final String nodeOrd;

  const _StationMetadata({
    required this.name,
    required this.nodeId,
    required this.nodeNo,
    required this.nodeOrd,
  });
}
