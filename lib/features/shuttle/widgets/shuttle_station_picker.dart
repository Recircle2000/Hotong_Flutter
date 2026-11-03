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
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  // 다크 모드에서는 셔틀 빨강을 밝은 톤으로 바꿔 대비를 맞춘다
  Color get _accentColor => Theme.of(context).brightness == Brightness.dark
      ? Colors.redAccent
      : _shuttleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final stations = _availableStations;
    final favorites = _searchController.text.isEmpty
        ? _favoriteStations
        : const <ShuttleStation>[];

    return Material(
      color: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSearchField(),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildQuickChip(
                      icon: Icons.near_me_outlined,
                      label: _isLoadingLocation ? '위치 확인 중' : '내 주변',
                      selected: _position != null,
                      onTap: _isLoadingLocation ? null : _loadLocation,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickChip(
                      icon: Icons.map_outlined,
                      label: '지도에서 선택',
                      onTap: _selectFromMap,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: onSurface.withValues(alpha: 0.08),
              ),
              Expanded(
                child: stations.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          if (favorites.isNotEmpty) ...[
                            _buildSectionTitle(
                              '즐겨찾는 정류장',
                              count: favorites.length,
                              icon: Icons.star_rounded,
                            ),
                            // 즐겨찾기만 옅은 면 위에 묶어 한눈에 구분되게 한다
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: onSurface.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children:
                                    _buildStationRows(favorites, inset: 8),
                              ),
                            ),
                          ],
                          _buildSectionTitle(
                            _position == null ? '전체 정류장' : '가까운 정류장',
                            count: stations.length,
                          ),
                          ..._buildStationRows(stations),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: '정류장 이름 검색',
          hintStyle: TextStyle(color: theme.hintColor),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: theme.hintColor,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '검색어 지우기',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: theme.hintColor,
                  ),
                ),
          filled: true,
          fillColor: onSurface.withValues(alpha: 0.05),
          contentPadding: EdgeInsets.zero,
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(onSurface.withValues(alpha: 0.16)),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final foreground =
        selected ? _accentColor : onSurface.withValues(alpha: 0.8);

    return Material(
      color: selected
          ? _accentColor.withValues(alpha: 0.1)
          : onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    required int count,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 4),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.32),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hintColor = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 32, color: hintColor),
          const SizedBox(height: 8),
          Text(
            widget.allowedStationIds != null && _searchController.text.isEmpty
                ? '이동 가능한 정류장이 없어요'
                : '검색 결과가 없어요',
            style: TextStyle(color: hintColor),
          ),
        ],
      ),
    );
  }

  // 같은 묶음 안의 정류장은 안쪽 들여쓴 헤어라인으로 나눈다
  List<Widget> _buildStationRows(
    List<ShuttleStation> stations, {
    double inset = 20,
  }) {
    final hairline =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return [
      for (var index = 0; index < stations.length; index++) ...[
        if (index > 0)
          Divider(
            height: 1,
            thickness: 1,
            indent: inset,
            endIndent: inset,
            color: hairline,
          ),
        _buildStationTile(stations[index], inset: inset),
      ],
    ];
  }

  Widget _buildStationTile(ShuttleStation station, {double inset = 20}) {
    final theme = Theme.of(context);
    final isFavorite = widget.isStationFavorite(station);

    return InkWell(
      onTap: () => Navigator.pop(context, station),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.only(left: inset, right: inset - 8),
          child: Row(
            children: [
              Expanded(child: _buildStationTitle(station)),
              if (_position != null) ...[
                const SizedBox(width: 8),
                Text(
                  _distanceLabel(station),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                tooltip: isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await widget.onToggleFavorite(station);
                  if (mounted) setState(() {});
                },
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 22,
                  color: isFavorite
                      ? Colors.amber.shade700
                      : theme.colorScheme.onSurface.withValues(alpha: 0.32),
                ),
              ),
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: '정류장 정보',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showStationInfoMenu(station, buttonContext),
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            style: const TextStyle(fontSize: 16),
          ),
        ),
        if (badges.isNotEmpty) const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badge.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('위치 서비스를 켜주세요');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('위치 권한이 없어 전체 정류장을 보여드려요');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      _showMessage('현재 위치를 확인하지 못했어요');
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
      _showMessage('이 출발지에서 갈 수 없는 정류장이에요');
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
