import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:hsro/features/shuttle/utils/shuttle_station_map_logic.dart';
import 'package:hsro/features/shuttle/view/nearby_stops_view.dart';
import 'package:hsro/features/shuttle/view/naver_map_station_detail_view.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class ShuttleStationMapView extends StatefulWidget {
  final String? initialDate;

  const ShuttleStationMapView({
    super.key,
    this.initialDate,
  });

  @override
  State<ShuttleStationMapView> createState() => _ShuttleStationMapViewState();
}

class _ShuttleStationMapViewState extends State<ShuttleStationMapView> {
  static const Color _shuttleColor = Color(0xFFB83227);
  static const Color _bottomSheetBarrierColor = Color(0x26000000);
  static const NLatLng _fallbackCenter = NLatLng(36.7841, 127.1291);
  static const NLatLng _initialFallbackCenter = NLatLng(36.7841, 127.1328);
  static const Size _markerSize = Size(30, 30);
  static const double _markerCaptionMinZoom = 15;
  static const EdgeInsets _mapContentPadding = EdgeInsets.only(
    left: 16,
    right: 16,
    bottom: 260,
  );
  static const EdgeInsets _logoMargin = EdgeInsets.fromLTRB(
    -4,
    16,
    12,
    -244,
  );
  static const EdgeInsets _initialBoundsPadding = EdgeInsets.fromLTRB(
    28,
    24,
    4,
    64,
  );
  static const List<_RouteOverlayDefinition> _routeOverlayDefinitions = [
    _RouteOverlayDefinition(
      id: 'asan_cheonan',
      title: '아산-천안',
      assetPath: 'assets/shuttle_routes/shuttle_asan-cheonan.json',
      color: Color(0xFFC62828),
      routeIds: {1, 2},
    ),
    _RouteOverlayDefinition(
      id: 'ktx',
      title: 'KTX 순환',
      assetPath: 'assets/shuttle_routes/shuttle_KTX.json',
      color: Color(0xFF1565C0),
      routeIds: {4},
    ),
    _RouteOverlayDefinition(
      id: 'onyang',
      title: '온양 방향',
      assetPath: 'assets/shuttle_routes/shuttle_온양방향.json',
      color: Color(0xFFF9A825),
      routeIds: {3},
    ),
    _RouteOverlayDefinition(
      id: 'dongnam_school',
      title: '동남구 등교',
      assetPath: 'assets/shuttle_routes/shuttle_동남구 등교.json',
      color: Color(0xFF6D4C41),
      routeIds: {7},
    ),
    _RouteOverlayDefinition(
      id: 'seobuk_school',
      title: '서북구 등교',
      assetPath: 'assets/shuttle_routes/shuttle_서북구 등교.json',
      color: Color(0xFF8D6E63),
      routeIds: {6},
    ),
  ];

//인접 정류장 묶음
  static const Map<String, List<String>> _groupedStationNames = {
    '롯데캐슬': ['롯데캐슬 [아캠방향]', '롯데캐슬 [천캠방향]'],
    '천안아산역': ['천안아산역 [아캠방향]', '천안아산역 [천캠방향]'],
    '배방역': ['배방역', '배방역 건너'],
    '천안 충무병원': ['천안 충무병원 맞은편', '천안 충무병원'],
    '천안역': ['천안역 [아캠방향]', '천안역 [천캠방향]'],
    '아산캠퍼스': ['아산캠퍼스 [출발]', '아산캠퍼스 [도착]'],
    '천안캠퍼스': ['천안캠퍼스 [출발]', '천안캠퍼스 [도착]'],
  };
//방향 혼동 방지
  static const Map<String, String> _customDirectionLabels = {
    '배방역': '배방역 - 온양온천역 방향',
    '배방역 건너': '배방역 건너 - 아캠방향',
    '천안 충무병원 맞은편': '천안충무병원 맞은편 - 아캠방향',
    '천안 충무병원': '천안충무병원 - 천캠방향',
  };

  final ShuttleRepository _repository = ShuttleRepository();
  final List<_StationMarkerGroup> _markerGroups = [];
  final List<_RouteOverlayData> _routeOverlays = [];
  final Map<int, String> _routeNameById = {};
  final Map<int, Set<int>> _stationRouteIdsByStationId = {};
  final Set<String> _selectedRouteIds = {};
  String? _expandedGroupId;
  int? _expandedStationId;
  NCameraPosition? _cameraPositionBeforeMarkerFocus;

  NaverMapController? _mapController;
  NOverlayImage? _markerIcon;

  bool _isLoading = true;
  bool _isMapReady = false;
  bool _isRefreshingOverlays = false;
  bool _overlayRefreshQueued = false;
  bool _isPreparingMarkerIcon = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _repository.fetchStations(),
        _repository.fetchRoutes(),
        _repository.fetchStationRouteMemberships(),
        _loadRouteOverlays(),
      ]);

      if (!mounted) {
        return;
      }

      final stations = (results[0] as List<ShuttleStation>)
          .where((station) => station.latitude != 0 && station.longitude != 0)
          .toList(growable: false);
      final routes = results[1] as List<ShuttleRoute>;
      final stationRouteMemberships =
          results[2] as List<StationRouteMembership>;
      final routeOverlays = results[3] as List<_RouteOverlayData>;

      _routeNameById
        ..clear()
        ..addEntries(
          routes.map((route) => MapEntry(route.id, route.routeName)),
        );

      _markerGroups
        ..clear()
        ..addAll(_buildMarkerGroups(stations));

      _routeOverlays
        ..clear()
        ..addAll(routeOverlays);
      _stationRouteIdsByStationId
        ..clear()
        ..addAll(buildStationRouteIdMap(stationRouteMemberships));

      final availableRouteIds =
          _routeOverlays.map((routeOverlay) => routeOverlay.id).toSet();
      _selectedRouteIds.removeWhere(
        (routeId) => !availableRouteIds.contains(routeId),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      await _prepareMarkerIcon();
      _queueOverlayRefresh();
      await _moveCameraToVisibleBounds(initial: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '정류장 지도를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _prepareMarkerIcon() async {
    if (_markerIcon != null || _isPreparingMarkerIcon || !mounted) {
      return;
    }

    _isPreparingMarkerIcon = true;
    try {
      _markerIcon = await NOverlayImage.fromWidget(
        context: context,
        size: _markerSize,
        widget: const SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            Icons.location_on_rounded,
            size: 30,
            color: _shuttleColor,
          ),
        ),
      );
    } finally {
      _isPreparingMarkerIcon = false;
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
      await mapController.clearOverlays(
          type: NOverlayType.arrowheadPathOverlay);
      await mapController.clearOverlays(type: NOverlayType.marker);

      final visibleMarkerGroups = _resolveVisibleMarkerGroups();
      final overlays = <NAddableOverlay>{};
      overlays.addAll(_buildRouteOverlays());
      for (final group in visibleMarkerGroups) {
        final markerPosition = _resolveMarkerPosition(group);
        final markerCaption = NOverlayCaption(
          text: _resolveMarkerCaption(group),
          minZoom: _markerCaptionMinZoom,
          textSize: 14,
          color: Color(0xFF111111),
          haloColor: Color(0xFFFDFDFD),
          requestWidth: 72,
        );
        final marker = _markerIcon != null
            ? NMarker(
                id: group.id,
                position: markerPosition,
                icon: _markerIcon,
                size: _markerSize,
                anchor: const NPoint(0.5, 0.9),
                caption: markerCaption,
                captionOffset: 6,
                isHideCollidedCaptions: true,
              )
            : NMarker(
                id: group.id,
                position: markerPosition,
                iconTintColor: _shuttleColor,
                size: _markerSize,
                anchor: const NPoint(0.5, 1.0),
                caption: markerCaption,
                captionOffset: 6,
                isHideCollidedCaptions: true,
              );
        marker.setOnTapListener((_) => _handleMarkerTap(group));
        overlays.add(marker);
      }

      if (overlays.isNotEmpty) {
        await mapController.addOverlayAll(overlays);
      }
    } finally {
      _isRefreshingOverlays = false;
      if (_overlayRefreshQueued) {
        _overlayRefreshQueued = false;
        _queueOverlayRefresh();
      }
    }
  }

  Set<NAddableOverlay> _buildRouteOverlays() {
    if (_selectedRouteOverlays.isEmpty) {
      return const <NAddableOverlay>{};
    }

    final visibleRoutes = _selectedRouteOverlays
        .where((routeOverlay) => routeOverlay.coords.isNotEmpty)
        .toList(growable: false);

    final overlays = <NAddableOverlay>{};
    for (int index = 0; index < visibleRoutes.length; index++) {
      final routeOverlay = visibleRoutes[index];
      final pathOverlay = NArrowheadPathOverlay(
        id: 'shuttle_route_${routeOverlay.id}',
        coords: _buildDisplayRouteCoords(
          routeOverlay.coords,
          routeIndex: index,
          routeCount: visibleRoutes.length,
        ),
        width: 4,
        color: routeOverlay.color,
        outlineWidth: 1.8,
        outlineColor: Colors.white.withValues(alpha: 0.95),
        headSizeRatio: 2.2,
      );
      pathOverlay.setGlobalZIndex(-100000 + (visibleRoutes.length - index));
      overlays.add(pathOverlay);
    }

    return overlays;
  }

  List<NLatLng> _buildDisplayRouteCoords(
    List<NLatLng> coords, {
    required int routeIndex,
    required int routeCount,
  }) {
    if (coords.length < 2 || routeCount <= 1) {
      return coords;
    }

    final centeredIndex = routeIndex - ((routeCount - 1) / 2);
    if (centeredIndex == 0) {
      return coords;
    }

    const double laneSpacingMeters = 6;
    final offsetMeters = centeredIndex * laneSpacingMeters;

    return List<NLatLng>.generate(coords.length, (pointIndex) {
      final current = coords[pointIndex];
      final prev = pointIndex > 0 ? coords[pointIndex - 1] : coords[pointIndex];
      final next = pointIndex < coords.length - 1
          ? coords[pointIndex + 1]
          : coords[pointIndex];

      final dx = next.longitude - prev.longitude;
      final dy = next.latitude - prev.latitude;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length == 0) {
        return current;
      }

      final normalX = -dy / length;
      final normalY = dx / length;
      final latRadians = current.latitude * math.pi / 180;
      final metersPerLatDegree = 111320.0;
      final metersPerLngDegree =
          metersPerLatDegree * math.cos(latRadians).abs();
      if (metersPerLngDegree == 0) {
        return current;
      }

      return NLatLng(
        current.latitude + (normalY * offsetMeters / metersPerLatDegree),
        current.longitude + (normalX * offsetMeters / metersPerLngDegree),
      );
    });
  }

  Future<void> _moveCameraToVisibleBounds({bool initial = false}) async {
    final mapController = _mapController;
    if (!_isMapReady || mapController == null) {
      return;
    }

    try {
      final points = _collectVisibleMapPoints();
      if (points.isEmpty) {
        await mapController.updateCamera(
          NCameraUpdate.withParams(
            target: initial ? _initialFallbackCenter : _fallbackCenter,
            zoom: initial ? 17 : 11.8,
          ),
        );
        return;
      }

      final update = points.length == 1
          ? NCameraUpdate.withParams(
              target: points.first,
              zoom: initial ? 17.2 : 15,
            )
          : NCameraUpdate.fitBounds(
              NLatLngBounds.from(points),
              padding: initial
                  ? _initialBoundsPadding
                  : const EdgeInsets.fromLTRB(48, 96, 48, 96),
            );

      update.setAnimation(
        duration: const Duration(milliseconds: 400),
      );
      await mapController.updateCamera(update);
    } catch (_) {
      await mapController.updateCamera(
        NCameraUpdate.withParams(
          target: initial ? _initialFallbackCenter : _fallbackCenter,
          zoom: initial ? 17 : 11.8,
        ),
      );
    }
  }

  List<NLatLng> _collectVisibleMapPoints() {
    final visibleMarkerGroups = _resolveVisibleMarkerGroups();
    final points =
        visibleMarkerGroups.map(_resolveMarkerPosition).toList(growable: true);

    for (final routeOverlay in _selectedRouteOverlays) {
      points.addAll(routeOverlay.coords);
    }

    return points;
  }

  List<_RouteOverlayData> get _selectedRouteOverlays => _routeOverlays
      .where((routeOverlay) => _selectedRouteIds.contains(routeOverlay.id))
      .toList(growable: false);

  Set<int> get _selectedFilterRouteIds => _selectedRouteOverlays
      .expand((routeOverlay) => routeOverlay.definition.routeIds)
      .toSet();

  List<_StationMarkerGroup> _resolveVisibleMarkerGroups() {
    if (_selectedRouteIds.isEmpty) {
      return _markerGroups;
    }

    final selectedFilterRouteIds = _selectedFilterRouteIds;

    return _markerGroups.where((group) {
      return group.options.any((option) {
        final stationRouteIds =
            _stationRouteIdsByStationId[option.station.id] ?? const <int>{};
        return stationMatchesSelectedRouteIds(
          stationRouteIds: stationRouteIds,
          selectedRouteIds: selectedFilterRouteIds,
        );
      });
    }).toList(growable: false);
  }

  NLatLng _resolveMarkerPosition(_StationMarkerGroup group) {
    final selectedOption = _selectedOptionForGroup(group);
    if (selectedOption == null) {
      return group.position;
    }

    return NLatLng(
      selectedOption.station.latitude,
      selectedOption.station.longitude,
    );
  }

  String _resolveMarkerCaption(_StationMarkerGroup group) {
    final selectedOption = _selectedOptionForGroup(group);
    return selectedOption?.station.name ?? group.title;
  }

  _StationDirectionOption? _selectedOptionForGroup(_StationMarkerGroup group) {
    if (_expandedGroupId != group.id || _expandedStationId == null) {
      return null;
    }

    for (final option in group.options) {
      if (option.station.id == _expandedStationId) {
        return option;
      }
    }

    return null;
  }

  Future<List<_RouteOverlayData>> _loadRouteOverlays() async {
    final routeOverlays = <_RouteOverlayData>[];

    for (final definition in _routeOverlayDefinitions) {
      try {
        final rawJson = await rootBundle.loadString(definition.assetPath);
        final coords = _parseRouteCoords(rawJson);
        if (coords.isEmpty) {
          continue;
        }

        routeOverlays.add(
          _RouteOverlayData(
            definition: definition,
            coords: coords,
          ),
        );
      } catch (error) {
        debugPrint(
          'Failed to load shuttle route asset: ${definition.assetPath} ($error)',
        );
      }
    }

    return routeOverlays;
  }

  List<NLatLng> _parseRouteCoords(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return const <NLatLng>[];
    }

    final features = decoded['features'];
    if (features is! List) {
      return const <NLatLng>[];
    }

    final coords = <NLatLng>[];
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) {
        continue;
      }

      final type = geometry['type'];
      final rawCoordinates = geometry['coordinates'];
      if (type == 'LineString' && rawCoordinates is List) {
        _appendLineStringCoords(rawCoordinates, coords);
      } else if (type == 'MultiLineString' && rawCoordinates is List) {
        for (final segment in rawCoordinates) {
          if (segment is List) {
            _appendLineStringCoords(segment, coords);
          }
        }
      }
    }

    return coords;
  }

  void _appendLineStringCoords(List rawCoordinates, List<NLatLng> coords) {
    for (final entry in rawCoordinates) {
      if (entry is! List || entry.length < 2) {
        continue;
      }

      final lng = entry[0];
      final lat = entry[1];
      if (lng is! num || lat is! num) {
        continue;
      }

      final point = NLatLng(lat.toDouble(), lng.toDouble());
      if (coords.isNotEmpty) {
        final lastPoint = coords.last;
        if (lastPoint.latitude == point.latitude &&
            lastPoint.longitude == point.longitude) {
          continue;
        }
      }
      coords.add(point);
    }
  }

  List<_StationMarkerGroup> _buildMarkerGroups(List<ShuttleStation> stations) {
    final groupedStations = <String, List<ShuttleStation>>{};
    final groups = <_StationMarkerGroup>[];

    for (final station in stations) {
      final groupKey = _resolveGroupKey(station.name);
      if (groupKey == null) {
        groups.add(
          _StationMarkerGroup(
            id: 'station_${station.id}',
            title: station.name,
            position: NLatLng(station.latitude, station.longitude),
            options: [
              _StationDirectionOption(
                station: station,
                label: _resolveDirectionLabel(station),
                subtitle: _trimmedOrNull(station.description),
              ),
            ],
          ),
        );
        continue;
      }

      groupedStations
          .putIfAbsent(groupKey, () => <ShuttleStation>[])
          .add(station);
    }

    for (final entry in groupedStations.entries) {
      final options = entry.value
          .map(
            (station) => _StationDirectionOption(
              station: station,
              label: _resolveDirectionLabel(station),
              subtitle: _trimmedOrNull(station.description),
            ),
          )
          .toList(growable: false);
      final averageLat = entry.value
              .map((station) => station.latitude)
              .reduce((left, right) => left + right) /
          entry.value.length;
      final averageLng = entry.value
              .map((station) => station.longitude)
              .reduce((left, right) => left + right) /
          entry.value.length;

      groups.add(
        _StationMarkerGroup(
          id: 'group_${entry.key}',
          title: entry.key,
          position: NLatLng(averageLat, averageLng),
          options: options,
        ),
      );
    }

    return groups;
  }

  String? _resolveGroupKey(String stationName) {
    for (final entry in _groupedStationNames.entries) {
      if (entry.value.contains(stationName)) {
        return entry.key;
      }
    }
    return null;
  }

  String _resolveDirectionLabel(ShuttleStation station) {
    final customLabel = _customDirectionLabels[station.name];
    if (customLabel != null) {
      return customLabel;
    }

    final match = RegExp(r'\[(.*?)\]').firstMatch(station.name);
    if (match != null) {
      return match.group(1) ?? station.name;
    }

    final description = _trimmedOrNull(station.description);
    return description ?? station.name;
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  List<String> _routeNamesForStation(int stationId) {
    final routeIds = _stationRouteIdsByStationId[stationId] ?? const <int>{};
    return resolveStationRouteNames(
      routeIds: routeIds,
      routeNameById: _routeNameById,
    );
  }

  Future<void> _handleMarkerTap(_StationMarkerGroup group) async {
    if (group.options.length == 1) {
      await _captureCameraPositionBeforeMarkerFocus();
      await _focusMarkerForBottomSheet(group.position);
      final shouldRestoreCamera =
          await _showStationDetailSheet(group.title, group.options.first);
      if (shouldRestoreCamera) {
        await _restoreCameraAfterBottomSheet();
      }
      return;
    }

    final selectedOption = await _showDirectionPicker(group);
    if (!mounted || selectedOption == null) {
      return;
    }

    setState(() {
      _expandedGroupId = group.id;
      _expandedStationId = selectedOption.station.id;
    });
    _queueOverlayRefresh();
    await _captureCameraPositionBeforeMarkerFocus();
    await _focusMarkerForBottomSheet(
      NLatLng(
        selectedOption.station.latitude,
        selectedOption.station.longitude,
      ),
    );

    final shouldRestoreCamera =
        await _showStationDetailSheet(group.title, selectedOption);
    if (shouldRestoreCamera) {
      await _restoreCameraAfterBottomSheet();
    }

    if (!mounted) {
      return;
    }

    final shouldCollapse = _expandedGroupId == group.id &&
        _expandedStationId == selectedOption.station.id;
    if (shouldCollapse) {
      setState(() {
        _expandedGroupId = null;
        _expandedStationId = null;
      });
      _queueOverlayRefresh();
    }
  }

  Future<void> _captureCameraPositionBeforeMarkerFocus() async {
    final mapController = _mapController;
    if (!_isMapReady || mapController == null) {
      _cameraPositionBeforeMarkerFocus = null;
      return;
    }

    try {
      _cameraPositionBeforeMarkerFocus = await mapController.getCameraPosition();
    } catch (_) {
      _cameraPositionBeforeMarkerFocus = null;
    }
  }

  Future<void> _restoreCameraAfterBottomSheet() async {
    final mapController = _mapController;
    final previousCamera = _cameraPositionBeforeMarkerFocus;
    _cameraPositionBeforeMarkerFocus = null;

    if (!_isMapReady || mapController == null || previousCamera == null) {
      return;
    }

    try {
      final update = NCameraUpdate.fromCameraPosition(previousCamera);
      update.setAnimation(duration: const Duration(milliseconds: 320));
      await mapController.updateCamera(update);
    } catch (_) {
      // 카메라 복원 실패 시 현재 상태를 유지
    }
  }

  Future<void> _focusMarkerForBottomSheet(NLatLng markerPosition) async {
    final mapController = _mapController;
    if (!_isMapReady || mapController == null) {
      return;
    }

    try {
      final currentCamera = await mapController.getCameraPosition();
      final targetZoom = currentCamera.zoom < 15.5 ? 15.5 : currentCamera.zoom;

      final update = NCameraUpdate.withParams(
        target: markerPosition,
        zoom: targetZoom,
      );
      update.setAnimation(duration: const Duration(milliseconds: 320));
      await mapController.updateCamera(update);
    } catch (_) {
      // 카메라 이동 실패 시 시트 동작은 계속 진행
    }
  }

  Future<_StationDirectionOption?> _showDirectionPicker(
    _StationMarkerGroup group,
  ) {
    return showModalBottomSheet<_StationDirectionOption>(
      context: context,
      barrierColor: _bottomSheetBarrierColor,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final selectedOption = _selectedOptionForGroup(group);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '방향을 선택하세요.',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...group.options.map(
                  (option) {
                    final isSelected =
                        selectedOption?.station.id == option.station.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _shuttleColor.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? _shuttleColor.withValues(alpha: 0.22)
                              : Colors.transparent,
                        ),
                      ),
                      child: _buildScaledButton(
                        onTap: () => Navigator.of(sheetContext).pop(option),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text(
                            option.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: option.subtitle == null
                              ? null
                              : Text(
                                  option.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.chevron_right,
                            color: isSelected ? _shuttleColor : null,
                          ),
                          onTap: () => Navigator.of(sheetContext).pop(option),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showStationDetailSheet(
    String groupTitle,
    _StationDirectionOption option,
  ) {
    final station = option.station;
    final routeNames = _routeNamesForStation(station.id);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      barrierColor: _bottomSheetBarrierColor,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.of(sheetContext).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  station.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (groupTitle != station.name)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _shuttleColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        color: _shuttleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_trimmedOrNull(station.description) != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    station.description!.trim(),
                    style: const TextStyle(height: 1.45),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  '지나는 노선',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (routeNames.isEmpty)
                  Text(
                    '운행 중인 노선 정보가 없습니다.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: routeNames
                        .map(
                          (routeName) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _shuttleColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _shuttleColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              routeName,
                              style: const TextStyle(
                                color: _shuttleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _buildScaledButton(
                    onTap: () {
                      if (!Get.isRegistered<ShuttleViewModel>()) {
                        Get.put(ShuttleViewModel());
                      }
                      Navigator.of(sheetContext).pop(false);
                      Get.to(
                        () => NaverMapStationDetailView(
                          stationId: station.id,
                        ),
                      );
                    },
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (!Get.isRegistered<ShuttleViewModel>()) {
                          Get.put(ShuttleViewModel());
                        }
                        Navigator.of(sheetContext).pop(false);
                        Get.to(
                          () => NaverMapStationDetailView(
                            stationId: station.id,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _shuttleColor,
                        side: BorderSide(
                          color: _shuttleColor.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline),
                      label: const Text(
                        '자세한 정보 보기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildScaledButton(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Get.to(
                        () => NearbyStopsView(
                          initialStationId: station.id,
                          initialDate: widget.initialDate,
                        ),
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Get.to(
                          () => NearbyStopsView(
                            initialStationId: station.id,
                            initialDate: widget.initialDate,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _shuttleColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.schedule),
                      label: const Text(
                        '시간표 보기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) => value ?? true);
  }

  Future<void> _showRouteSelectionSheet() async {
    if (_routeOverlays.isEmpty) {
      return;
    }

    final initialSelection = Set<String>.from(_selectedRouteIds);
    final selectedRouteIds = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      barrierColor: _bottomSheetBarrierColor,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final tempSelectedIds = Set<String>.from(initialSelection);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allSelected = tempSelectedIds.length == _routeOverlays.length;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(sheetContext).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '노선도 필터링',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '중간 정류장 출발 - 도착 노선은 시간표를 확인해주세요.',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildScaledButton(
                          onTap: () {
                            setSheetState(() {
                              if (allSelected) {
                                tempSelectedIds.clear();
                              } else {
                                tempSelectedIds
                                  ..clear()
                                  ..addAll(
                                    _routeOverlays.map(
                                      (routeOverlay) => routeOverlay.id,
                                    ),
                                  );
                              }
                            });
                          },
                          child: TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (allSelected) {
                                  tempSelectedIds.clear();
                                } else {
                                  tempSelectedIds
                                    ..clear()
                                    ..addAll(
                                      _routeOverlays.map(
                                        (routeOverlay) => routeOverlay.id,
                                      ),
                                    );
                                }
                              });
                            },
                            child: Text(allSelected ? '모두 해제' : '전체 선택'),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${tempSelectedIds.length}/${_routeOverlays.length}개 표시',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._routeOverlays.map(
                      (routeOverlay) {
                        final isSelected =
                            tempSelectedIds.contains(routeOverlay.id);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? routeOverlay.color.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? routeOverlay.color.withValues(alpha: 0.35)
                                  : Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: _buildScaledButton(
                            onTap: () {
                              setSheetState(() {
                                if (isSelected) {
                                  tempSelectedIds.remove(routeOverlay.id);
                                } else {
                                  tempSelectedIds.add(routeOverlay.id);
                                }
                              });
                            },
                            child: CheckboxListTile(
                              value: isSelected,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              activeColor: routeOverlay.color,
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                              title: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: routeOverlay.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      routeOverlay.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onChanged: (_) {
                                setSheetState(() {
                                  if (isSelected) {
                                    tempSelectedIds.remove(routeOverlay.id);
                                  } else {
                                    tempSelectedIds.add(routeOverlay.id);
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _buildScaledButton(
                        onTap: () {
                          Navigator.of(sheetContext).pop(
                            Set<String>.from(tempSelectedIds),
                          );
                        },
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              Set<String>.from(tempSelectedIds),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _shuttleColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.alt_route),
                          label: Text(
                            tempSelectedIds.isEmpty ? '필터 해제' : '선택한 노선 적용',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedRouteIds == null) {
      return;
    }

    setState(() {
      _selectedRouteIds
        ..clear()
        ..addAll(selectedRouteIds);
    });

    _queueOverlayRefresh();
    await _moveCameraToVisibleBounds();
  }

  Widget _buildScaledButton({
    required VoidCallback onTap,
    required Widget child,
    bool enableFeedback = true,
  }) {
    return ScaleButton(
      onTap: onTap,
      enableFeedback: enableFeedback,
      child: AbsorbPointer(
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('정류장 지도'),
      ),
      body: Stack(
        children: [
          NaverMap(
            key: ValueKey(Theme.of(context).brightness),
            options: NaverMapViewOptions(
              initialCameraPosition: const NCameraPosition(
                target: _initialFallbackCenter,
                zoom: 17,
              ),
              mapType: NMapType.basic,
              nightModeEnable: Theme.of(context).brightness == Brightness.dark,
              maxZoom: 18,
              minZoom: 9,
              logoMargin: _logoMargin,
              contentPadding: _mapContentPadding,
              rotationGesturesEnable: false,
              tiltGesturesEnable: false,
              scaleBarEnable: false,
              indoorEnable: false,
              indoorLevelPickerEnable: false,
              locationButtonEnable: false,
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              _isMapReady = true;
              controller.setLocationTrackingMode(
                NLocationTrackingMode.noFollow,
              );
              await _prepareMarkerIcon();
              _queueOverlayRefresh();
              await _moveCameraToVisibleBounds(initial: true);
            },
          ),
          if (_routeOverlays.isNotEmpty && !_isLoading)
            Positioned(
              right: 16,
              bottom: 96,
              child: SafeArea(
                top: false,
                child: ScaleButton(
                  onTap: _showRouteSelectionSheet,
                  child: Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.alt_route,
                            color: _shuttleColor,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '노선 필터',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _selectedRouteIds.isEmpty
                                    ? '모든 정류장 표시 중'
                                    : '${_selectedRouteIds.length}개 노선 표시 중',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: NMyLocationButtonWidget(
                mapController: _mapController,
                nightMode: Theme.of(context).brightness == Brightness.dark,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                elevation: 6,
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
          if (_errorMessage != null && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 42,
                          color: _shuttleColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildScaledButton(
                          onTap: _loadMapData,
                          child: ElevatedButton(
                            onPressed: _loadMapData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _shuttleColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('다시 시도'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StationMarkerGroup {
  final String id;
  final String title;
  final NLatLng position;
  final List<_StationDirectionOption> options;

  const _StationMarkerGroup({
    required this.id,
    required this.title,
    required this.position,
    required this.options,
  });
}

class _StationDirectionOption {
  final ShuttleStation station;
  final String label;
  final String? subtitle;

  const _StationDirectionOption({
    required this.station,
    required this.label,
    this.subtitle,
  });
}

class _RouteOverlayDefinition {
  final String id;
  final String title;
  final String assetPath;
  final Color color;
  final Set<int> routeIds;

  const _RouteOverlayDefinition({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.color,
    this.routeIds = const <int>{},
  });
}

class _RouteOverlayData {
  final _RouteOverlayDefinition definition;
  final List<NLatLng> coords;

  const _RouteOverlayData({
    required this.definition,
    required this.coords,
  });

  String get id => definition.id;
  String get title => definition.title;
  Color get color => definition.color;
}
