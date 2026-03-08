import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';

import '../../viewmodel/busmap_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';

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
  List<_StationMetadata> _stationMetadata = const [];

  NaverMapController? _mapController;
  bool _isMapReady = false;
  bool _isRefreshingOverlays = false;
  bool _overlayRefreshQueued = false;
  bool _isPreparingBusIcon = false;
  bool _isPreparingStationIcon = false;
  Brightness? _overlayBrightness;

  NOverlayImage? _busMarkerIcon;
  NOverlayImage? _stationMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadStationMetadata();

    _workers.addAll([
      ever(controller.selectedRoute, (_) {
        _loadStationMetadata();
        _queueOverlayRefresh();
      }),
      ever(controller.routePolylinePoints, (_) => _queueOverlayRefresh()),
      ever(controller.stationMarkers, (_) => _queueOverlayRefresh()),
      ever(controller.markers, (_) => _queueOverlayRefresh()),
      ever(controller.allRoutesBusData, (_) => _queueOverlayRefresh()),
    ]);
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get _stationMarkerColor =>
      _isDarkMode ? const Color(0xFF5F8DFF) : const Color(0xFF0B3D91);

  Color get _busMarkerColor =>
      _isDarkMode ? const Color(0xFF6A99FF) : const Color(0xFF0D47A1);

  Color get _busCaptionColor =>
      _isDarkMode ? const Color(0xFFEAF1FF) : const Color(0xFF0D47A1);

  Color get _busCaptionHaloColor =>
      _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _busMarkerBackgroundColor =>
      _isDarkMode ? const Color(0xFF111827) : Colors.white;

  Color get _busMarkerBorderColor =>
      _isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A);

  Color get _routePolylineColor =>
      _isDarkMode ? const Color(0xFF1E3A8A) : Colors.blueAccent;

  // 이 줌보다 작으면(더 멀리 보면) 정류장 마커를 숨깁니다.
  double get _stationMarkerMinZoom => 12.5;

  void _syncOverlayTheme() {
    final brightness = Theme.of(context).brightness;
    if (_overlayBrightness == brightness) {
      return;
    }

    _overlayBrightness = brightness;
    _busMarkerIcon = null;
    _stationMarkerIcon = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prepareBusMarkerIcon();
      _prepareStationMarkerIcon();
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
    final route = controller.selectedRoute.value;
    final jsonFile = 'assets/bus_stops/$route.json';

    try {
      final jsonData = await rootBundle.loadString(jsonFile);
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final rawItems = data['response']?['body']?['items']?['item'];
      final List<dynamic> items = rawItems is List
          ? rawItems
          : (rawItems == null ? <dynamic>[] : <dynamic>[rawItems]);

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
      _stationMetadata = const [];
    } finally {
      _queueOverlayRefresh();
    }
  }

  Future<void> _prepareBusMarkerIcon() async {
    if (_isPreparingBusIcon || _busMarkerIcon != null || !mounted) {
      return;
    }

    _isPreparingBusIcon = true;
    try {
      _busMarkerIcon = await NOverlayImage.fromWidget(
        context: context,
        size: const Size(32, 32),
        widget: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _busMarkerBackgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: _busMarkerBorderColor, width: 1.8),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.directions_bus_rounded,
            size: 17,
            color: _busMarkerColor,
          ),
        ),
      );
    } catch (_) {
      // 아이콘 생성 실패 시 기본 마커 색상으로 폴백합니다.
    } finally {
      _isPreparingBusIcon = false;
      if (mounted) {
        _queueOverlayRefresh();
      }
    }
  }

  Future<void> _prepareStationMarkerIcon() async {
    if (_isPreparingStationIcon || _stationMarkerIcon != null || !mounted) {
      return;
    }

    _isPreparingStationIcon = true;
    try {
      _stationMarkerIcon = await NOverlayImage.fromWidget(
        context: context,
        size: const Size(20, 20),
        widget: Icon(
          Icons.location_on_rounded,
          size: 20,
          color: _stationMarkerColor,
        ),
      );
    } catch (_) {
      // 아이콘 생성 실패 시 기본 마커 색상으로 폴백합니다.
    } finally {
      _isPreparingStationIcon = false;
      if (mounted) {
        _queueOverlayRefresh();
      }
    }
  }

  void _queueOverlayRefresh() {
    if (!_isMapReady || _mapController == null) {
      return;
    }

    if (_isRefreshingOverlays) {
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

      final overlays = <NAddableOverlay>{};
      overlays.addAll(_buildRouteOverlays());
      overlays.addAll(_buildStationOverlays());
      overlays.addAll(_buildBusOverlays());

      if (overlays.isNotEmpty) {
        await mapController.addOverlayAll(overlays);
      }
    } catch (_) {
      // 지도 전환 타이밍(재생성/해제)에는 오버레이 갱신이 실패할 수 있어 무시합니다.
    } finally {
      _isRefreshingOverlays = false;
      if (_overlayRefreshQueued) {
        _overlayRefreshQueued = false;
        _queueOverlayRefresh();
      }
    }
  }

  Set<NPathOverlay> _buildRouteOverlays() {
    final points = controller.routePolylinePoints.toList();
    if (points.isEmpty) {
      return const <NPathOverlay>{};
    }

    // flutter_naver_map의 payload 변환기는 Iterable이 아닌 List만 직렬화합니다.
    final coords = points
        .map((point) => NLatLng(point.latitude, point.longitude))
        .toList(growable: false);

    return {
      NPathOverlay(
        id: 'city_bus_route_path',
        coords: coords,
        width: 4.0,
        color: _routePolylineColor,
        outlineColor: Colors.transparent,
        outlineWidth: 0.0,
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
      final point = stationMarkers[i].position;
      final metadata = i < _stationMetadata.length ? _stationMetadata[i] : null;
      final hasCustomIcon = _stationMarkerIcon != null;

      final marker = NMarker(
        id: 'city_station_$i',
        position: NLatLng(point.latitude, point.longitude),
        icon: _stationMarkerIcon,
        iconTintColor: hasCustomIcon ? Colors.transparent : _stationMarkerColor,
        size: hasCustomIcon ? const Size(20, 20) : const Size(18, 18),
        anchor:
            hasCustomIcon ? const NPoint(0.5, 0.85) : const NPoint(0.5, 1.0),
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
    final hasCustomIcon = _busMarkerIcon != null;

    return NMarker(
      id: id,
      position: position,
      icon: _busMarkerIcon,
      size: hasCustomIcon ? const Size(32, 32) : const Size(20, 20),
      iconTintColor: hasCustomIcon ? Colors.transparent : _busMarkerColor,
      caption: vehicleNo.isEmpty
          ? null
          : NOverlayCaption(
              text: vehicleNo,
              textSize: 9.5,
              color: _busCaptionColor,
              haloColor: _busCaptionHaloColor,
            ),
      anchor: hasCustomIcon ? const NPoint(0.5, 0.5) : const NPoint(0.5, 1.0),
    );
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
    _syncOverlayTheme();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeName),
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
                _mapController = mapController;
                _isMapReady = true;
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
