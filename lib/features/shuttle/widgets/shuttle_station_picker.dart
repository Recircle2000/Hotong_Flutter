import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/view/naver_map_station_detail_view.dart';
import 'package:hsro/features/shuttle/view/shuttle_station_map_view.dart';

Future<ShuttleStation?> showShuttleStationPicker({
  required BuildContext context,
  required String title,
  required List<ShuttleStation> stations,
  required List<ShuttleStation> Function() favoriteStationsProvider,
  required bool Function(ShuttleStation) isStationFavorite,
  required Future<void> Function(ShuttleStation) onToggleFavorite,
  List<ShuttleStation> Function(ShuttleStation)? detailStationsProvider,
  Set<int>? allowedStationIds,
}) {
  Widget builder(BuildContext sheetContext) => _ShuttleStationPicker(
        title: title,
        stations: stations,
        favoriteStationsProvider: favoriteStationsProvider,
        isStationFavorite: isStationFavorite,
        onToggleFavorite: onToggleFavorite,
        detailStationsProvider: detailStationsProvider,
        allowedStationIds: allowedStationIds,
      );

  if (Theme.of(context).platform == TargetPlatform.iOS) {
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
  final List<ShuttleStation> Function(ShuttleStation)? detailStationsProvider;
  final Set<int>? allowedStationIds;

  const _ShuttleStationPicker({
    required this.title,
    required this.stations,
    required this.favoriteStationsProvider,
    required this.isStationFavorite,
    required this.onToggleFavorite,
    this.detailStationsProvider,
    this.allowedStationIds,
  });

  @override
  State<_ShuttleStationPicker> createState() => _ShuttleStationPickerState();
}

class _ShuttleStationPickerState extends State<_ShuttleStationPicker> {
  static const Color _shuttleColor = Color(0xFFB83227);
  static const MethodChannel _iosStationInfoMenuChannel =
      MethodChannel('hsro/ios_station_info_menu');
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
    return Material(
      color: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
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
                        color: Colors.black.withValues(alpha: 0.08),
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
        side: BorderSide(color: _shuttleColor.withValues(alpha: 0.25)),
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
      title: _buildStationTitle(station),
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
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: '정류장 정보',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showStationInfoMenu(station, buttonContext),
              icon: Icon(
                Icons.info_outline,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ],
      ),
      onTap: () => Navigator.pop(context, station),
    );
  }

  Widget _buildStationTitle(ShuttleStation station) {
    final badges = _transportBadgesFor(station.name);
    return Row(
      children: [
        Flexible(
          child: Text(
            station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badges.isNotEmpty) const SizedBox(width: 7),
        for (var index = 0; index < badges.length; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          _buildTransportBadge(badges[index]),
        ],
      ],
    );
  }

  Future<void> _showStationInfoMenu(
    ShuttleStation station,
    BuildContext buttonContext,
  ) async {
    final detailStations =
        widget.detailStationsProvider?.call(station) ?? [station];
    if (detailStations.length <= 1) {
      _openStationInfo(detailStations.isEmpty ? station : detailStations.first);
      return;
    }

    final selectedStation = Theme.of(context).platform == TargetPlatform.iOS
        ? await _showIOSStationInfoMenu(detailStations, buttonContext)
        : await _showMaterialStationInfoMenu(detailStations, buttonContext);
    if (!mounted || selectedStation == null) return;
    _openStationInfo(selectedStation);
  }

  Future<ShuttleStation?> _showMaterialStationInfoMenu(
    List<ShuttleStation> detailStations,
    BuildContext buttonContext,
  ) async {
    final buttonBox = buttonContext.findRenderObject();
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (buttonBox is! RenderBox || overlayBox is! RenderBox) return null;

    final buttonOffset = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    return showMenu<ShuttleStation>(
      context: context,
      position: RelativeRect.fromRect(
        buttonOffset & buttonBox.size,
        Offset.zero & overlayBox.size,
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      items: [
        const PopupMenuItem<ShuttleStation>(
          enabled: false,
          height: 42,
          child: Text(
            '어떤 정류장 정보를 볼까요?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        ...detailStations.map(
          (detailStation) => PopupMenuItem<ShuttleStation>(
            value: detailStation,
            height: 50,
            child: Text(
              detailStation.name,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Future<ShuttleStation?> _showIOSStationInfoMenu(
    List<ShuttleStation> detailStations,
    BuildContext buttonContext,
  ) async {
    final renderBox = buttonContext.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return null;
    final origin = renderBox.localToGlobal(Offset.zero);

    try {
      final stationId = await _iosStationInfoMenuChannel.invokeMethod<int>(
        'show',
        <String, Object>{
          'title': '어떤 정류장 정보를 볼까요?',
          'cancelTitle': '취소',
          'stations': [
            for (final station in detailStations)
              <String, Object>{'id': station.id, 'title': station.name},
          ],
          'sourceX': origin.dx,
          'sourceY': origin.dy,
          'sourceWidth': renderBox.size.width,
          'sourceHeight': renderBox.size.height,
        },
      );
      if (stationId == null) return null;
      for (final station in detailStations) {
        if (station.id == stationId) return station;
      }
      return null;
    } on PlatformException {
      return _showCupertinoStationInfoMenu(detailStations);
    } on MissingPluginException {
      return _showCupertinoStationInfoMenu(detailStations);
    }
  }

  Future<ShuttleStation?> _showCupertinoStationInfoMenu(
    List<ShuttleStation> detailStations,
  ) {
    return showCupertinoModalPopup<ShuttleStation>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('어떤 정류장 정보를 볼까요?'),
        actions: [
          for (final station in detailStations)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(popupContext, station),
              child: Text(station.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('취소'),
        ),
      ),
    );
  }

  void _openStationInfo(ShuttleStation station) {
    Get.to(() => NaverMapStationDetailView(stationId: station.id));
  }

  List<_StationTransportBadge> _transportBadgesFor(String stationName) {
    final normalizedName = stationName.replaceAll(RegExp(r'\s+'), '');
    if (normalizedName.startsWith('천안아산역')) {
      return const [
        _StationTransportBadge('KTX', Color(0xFF183B70)),
        _StationTransportBadge('1호선', Color(0xFF0052A4)),
      ];
    }
    if (normalizedName.startsWith('천안역')) {
      return const [
        _StationTransportBadge('일반열차', Color(0xFF60717D)),
        _StationTransportBadge('1호선', Color(0xFF0052A4)),
      ];
    }
    if (normalizedName.startsWith('온양온천역')) {
      return const [
        _StationTransportBadge('일반열차', Color(0xFF60717D)),
        _StationTransportBadge('1호선', Color(0xFF0052A4)),
      ];
    }
    if (normalizedName.startsWith('배방역')) {
      return const [
        _StationTransportBadge('1호선', Color(0xFF0052A4)),
      ];
    }
    if (normalizedName.startsWith('천안터미널') ||
        normalizedName.startsWith('아산터미널')) {
      return const [
        _StationTransportBadge('시외버스', Color(0xFFE06427)),
      ];
    }
    return const [];
  }

  Widget _buildTransportBadge(_StationTransportBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: badge.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badge.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
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

class _StationTransportBadge {
  const _StationTransportBadge(this.label, this.color);

  final String label;
  final Color color;
}
