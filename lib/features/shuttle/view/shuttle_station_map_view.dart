import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/repository/shuttle_repository.dart';
import 'package:hsro/features/shuttle/view/nearby_stops_view.dart';

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
  static const NLatLng _fallbackCenter = NLatLng(36.7841, 127.1291);
  static const Size _markerSize = Size(30, 30);

  static const Map<String, List<String>> _groupedStationNames = {
    '롯데캐슬': ['롯데캐슬 [아캠방향]', '롯데캐슬 [천캠방향]'],
    '천안아산역': ['천안아산역 [아캠방향]', '천안아산역 [천캠방향]'],
    '배방역': ['배방역', '배방역 건너'],
    '천안 충무병원': ['천안 충무병원 맞은편', '천안 충무병원'],
    '천안역': ['천안역 [아캠방향]', '천안역 [천캠방향]'],
    '아산캠퍼스': ['아산캠퍼스 [출발]', '아산캠퍼스 [도착]'],
    '천안캠퍼스': ['천안캠퍼스 [출발]', '천안캠퍼스 [도착]'],
  };

  static const Map<String, String> _customDirectionLabels = {
    '배방역': '배방역 - 온양온천역 방향',
    '배방역 건너': '배방역 건너 - 아캠방향',
    '천안 충무병원 맞은편': '천안충무병원 맞은편 - 아캠방향',
    '천안 충무병원': '천안충무병원 - 천캠방향',
  };

  final ShuttleRepository _repository = ShuttleRepository();
  final List<_StationMarkerGroup> _markerGroups = [];
  final Map<int, String> _routeNameById = {};
  final Map<int, Future<_StationRouteSummary>> _routeSummaryCache = {};

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
      ]);

      if (!mounted) {
        return;
      }

      final stations = (results[0] as List<ShuttleStation>)
          .where((station) => station.latitude != 0 && station.longitude != 0)
          .toList(growable: false);
      final routes = results[1] as List<ShuttleRoute>;

      _routeNameById
        ..clear()
        ..addEntries(
          routes.map((route) => MapEntry(route.id, route.routeName)),
        );

      _markerGroups
        ..clear()
        ..addAll(_buildMarkerGroups(stations));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      await _prepareMarkerIcon();
      _queueOverlayRefresh();
      await _moveCameraToMarkerBounds();
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
      await mapController.clearOverlays(type: NOverlayType.marker);

      final overlays = <NAddableOverlay>{};
      for (final group in _markerGroups) {
        final marker = _markerIcon != null
            ? NMarker(
                id: group.id,
                position: group.position,
                icon: _markerIcon,
                size: _markerSize,
                anchor: const NPoint(0.5, 0.9),
              )
            : NMarker(
                id: group.id,
                position: group.position,
                iconTintColor: _shuttleColor,
                size: _markerSize,
                anchor: const NPoint(0.5, 1.0),
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

  Future<void> _moveCameraToMarkerBounds() async {
    final mapController = _mapController;
    if (!_isMapReady || mapController == null) {
      return;
    }

    try {
      if (_markerGroups.isEmpty) {
        await mapController.updateCamera(
          NCameraUpdate.withParams(
            target: _fallbackCenter,
            zoom: 11.8,
          ),
        );
        return;
      }

      final points =
          _markerGroups.map((group) => group.position).toList(growable: false);
      final update = points.length == 1
          ? NCameraUpdate.withParams(target: points.first, zoom: 15)
          : NCameraUpdate.fitBounds(
              NLatLngBounds.from(points),
              padding: const EdgeInsets.all(48),
            );

      update.setAnimation(
        duration: const Duration(milliseconds: 400),
      );
      await mapController.updateCamera(update);
    } catch (_) {
      await mapController.updateCamera(
        NCameraUpdate.withParams(
          target: _fallbackCenter,
          zoom: 11.8,
        ),
      );
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

  Future<_StationRouteSummary> _getRouteSummary(int stationId) {
    return _routeSummaryCache.putIfAbsent(stationId, () async {
      try {
        if (_routeNameById.isEmpty) {
          final routes = await _repository.fetchRoutes();
          _routeNameById.addEntries(
            routes.map((route) => MapEntry(route.id, route.routeName)),
          );
        }

        final schedules = await _repository.fetchStationSchedules(stationId);
        final routeIds = schedules
            .map((schedule) => schedule.routeId)
            .toSet()
            .toList(growable: false)
          ..sort();
        final routeNames = routeIds
            .map((routeId) => _routeNameById[routeId] ?? '노선 $routeId')
            .toList(growable: false);
        return _StationRouteSummary(routeNames: routeNames);
      } catch (_) {
        _routeSummaryCache.remove(stationId);
        return const _StationRouteSummary(
          errorMessage: '노선 정보를 불러오지 못했습니다.',
        );
      }
    });
  }

  Future<void> _handleMarkerTap(_StationMarkerGroup group) async {
    if (group.options.length == 1) {
      await _showStationDetailSheet(group.title, group.options.first);
      return;
    }

    final selectedOption = await _showDirectionPicker(group);
    if (!mounted || selectedOption == null) {
      return;
    }

    await _showStationDetailSheet(group.title, selectedOption);
  }

  Future<_StationDirectionOption?> _showDirectionPicker(
    _StationMarkerGroup group,
  ) {
    return showModalBottomSheet<_StationDirectionOption>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
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
                  (option) => ListTile(
                    contentPadding: EdgeInsets.zero,
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
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStationDetailSheet(
    String groupTitle,
    _StationDirectionOption option,
  ) {
    final station = option.station;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                      color: _shuttleColor.withOpacity(0.08),
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
                FutureBuilder<_StationRouteSummary>(
                  future: _getRouteSummary(station.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }

                    final summary = snapshot.data;
                    if (summary?.errorMessage != null) {
                      return Text(
                        summary!.errorMessage!,
                        style: TextStyle(color: Colors.red.shade400),
                      );
                    }

                    final routeNames = summary?.routeNames ?? const <String>[];
                    if (routeNames.isEmpty) {
                      return Text(
                        '운행 중인 노선 정보가 없습니다.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      );
                    }

                    return Wrap(
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
                                color: _shuttleColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _shuttleColor.withOpacity(0.2),
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
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
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
              ],
            ),
          ),
        );
      },
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
                target: _fallbackCenter,
                zoom: 11.8,
              ),
              mapType: NMapType.basic,
              nightModeEnable: Theme.of(context).brightness == Brightness.dark,
              maxZoom: 18,
              minZoom: 9,
              contentPadding: EdgeInsets.zero,
              rotationGesturesEnable: false,
              tiltGesturesEnable: false,
              scaleBarEnable: false,
              indoorEnable: false,
              indoorLevelPickerEnable: false,
              locationButtonEnable: true,
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              _isMapReady = true;
              controller.setLocationTrackingMode(
                NLocationTrackingMode.noFollow,
              );
              await _prepareMarkerIcon();
              _queueOverlayRefresh();
              await _moveCameraToMarkerBounds();
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.08),
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
                        color: Colors.black.withOpacity(0.12),
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
                        ElevatedButton(
                          onPressed: _loadMapData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _shuttleColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('다시 시도'),
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

class _StationRouteSummary {
  final List<String> routeNames;
  final String? errorMessage;

  const _StationRouteSummary({
    this.routeNames = const [],
    this.errorMessage,
  });
}
