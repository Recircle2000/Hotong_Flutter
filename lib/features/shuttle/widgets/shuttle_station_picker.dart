import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/shuttle_station_map_view.dart';

Future<ShuttleStation?> showShuttleStationPicker({
  required BuildContext context,
  required String title,
  required List<ShuttleStation> stations,
  required List<ShuttleStation> Function() favoriteStationsProvider,
  required bool Function(ShuttleStation) isStationFavorite,
  required Future<void> Function(ShuttleStation) onToggleFavorite,
  Set<int>? allowedStationIds,
}) {
  Widget builder(BuildContext sheetContext) => _ShuttleStationPicker(
        title: title,
        stations: stations,
        favoriteStationsProvider: favoriteStationsProvider,
        isStationFavorite: isStationFavorite,
        onToggleFavorite: onToggleFavorite,
        allowedStationIds: allowedStationIds,
      );

  if (Platform.isIOS) {
    return showCupertinoModalPopup<ShuttleStation>(
      context: context,
      builder: builder,
    );
  }
  return showModalBottomSheet<ShuttleStation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

class _ShuttleStationPicker extends StatefulWidget {
  final String title;
  final List<ShuttleStation> stations;
  final List<ShuttleStation> Function() favoriteStationsProvider;
  final bool Function(ShuttleStation) isStationFavorite;
  final Future<void> Function(ShuttleStation) onToggleFavorite;
  final Set<int>? allowedStationIds;

  const _ShuttleStationPicker({
    required this.title,
    required this.stations,
    required this.favoriteStationsProvider,
    required this.isStationFavorite,
    required this.onToggleFavorite,
    this.allowedStationIds,
  });

  @override
  State<_ShuttleStationPicker> createState() => _ShuttleStationPickerState();
}

class _ShuttleStationPickerState extends State<_ShuttleStationPicker> {
  static const Color _shuttleColor = Color(0xFFB83227);
  final TextEditingController _searchController = TextEditingController();
  Position? _position;
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ShuttleStation> get _availableStations {
    final allowedIds = widget.allowedStationIds;
    final query = _searchController.text.trim().toLowerCase();
    final values = widget.stations.where((station) {
      if (allowedIds != null && !allowedIds.contains(station.id)) return false;
      return query.isEmpty || station.name.toLowerCase().contains(query);
    }).toList();
    if (_position != null) {
      values.sort((a, b) => _distance(a).compareTo(_distance(b)));
    }
    return values;
  }

  List<ShuttleStation> get _favoriteStations {
    final allowedIds = widget.allowedStationIds;
    return widget.favoriteStationsProvider().where((station) {
      return allowedIds == null || allowedIds.contains(station.id);
    }).toList(growable: false);
  }

  double _distance(ShuttleStation station) {
    final position = _position;
    if (position == null) return 0;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      station.latitude,
      station.longitude,
    );
  }

  String _distanceLabel(ShuttleStation station) {
    final meters = _distance(station);
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '정류장 이름 검색',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickButton(
                      icon: Icons.my_location,
                      label: _isLoadingLocation ? '확인 중' : '내 주변',
                      onTap: _isLoadingLocation ? null : _loadLocation,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickButton(
                      icon: Icons.map_outlined,
                      label: '지도에서 선택',
                      onTap: _selectFromMap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _availableStations.isEmpty
                  ? Center(
                      child: Text(
                        widget.allowedStationIds != null
                            ? '이동 가능한 정류장이 없습니다.'
                            : '검색 결과가 없습니다.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        if (_favoriteStations.isNotEmpty &&
                            _searchController.text.isEmpty) ...[
                          _buildSectionTitle('즐겨찾는 정류장'),
                          ..._favoriteStations.map(_buildStationTile),
                          const SizedBox(height: 8),
                        ],
                        _buildSectionTitle(
                          _position == null ? '전체 정류장' : '가까운 정류장',
                        ),
                        ..._availableStations.map(_buildStationTile),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _shuttleColor,
        side: BorderSide(color: _shuttleColor.withOpacity(0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 11),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildStationTile(ShuttleStation station) {
    final isFavorite = widget.isStationFavorite(station);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(station.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_position != null) ...[
            Text(
              _distanceLabel(station),
              style: const TextStyle(color: _shuttleColor, fontSize: 12),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await widget.onToggleFavorite(station);
              if (mounted) setState(() {});
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite
                  ? Colors.amber.shade700
                  : Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
      onTap: () => Navigator.pop(context, station),
    );
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('위치 서비스를 활성화해주세요.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('위치 권한 없이 전체 정류장을 표시합니다.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      _showMessage('현재 위치를 확인하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectFromMap() async {
    final station = await Get.to<ShuttleStation>(
      () => const ShuttleStationMapView(selectionMode: true),
    );
    if (!mounted || station == null) return;
    final allowedIds = widget.allowedStationIds;
    if (allowedIds != null && !allowedIds.contains(station.id)) {
      _showMessage('이 출발지에서 이동할 수 없는 정류장입니다.');
      return;
    }
    Navigator.pop(context, station);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
