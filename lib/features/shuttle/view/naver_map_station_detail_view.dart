import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

class NaverMapStationDetailView extends StatefulWidget {
  final int stationId;

  const NaverMapStationDetailView({
    Key? key,
    required this.stationId,
  }) : super(key: key);

  @override
  _NaverMapStationDetailViewState createState() =>
      _NaverMapStationDetailViewState();
}

class _NaverMapStationDetailViewState extends State<NaverMapStationDetailView> {
  static const Color _shuttleColor = Color(0xFFB83227);

  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();
  final RxBool isLoading = true.obs;
  final Rx<ShuttleStation?> station = Rx<ShuttleStation?>(null);
  final RxBool isLoadingLocation = false.obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);

  // 네이버 맵 컨트롤러
  NaverMapController? mapController;

  @override
  void initState() {
    super.initState();
    // 정류장 상세와 내 위치 정보 준비
    _loadStationDetail();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    mapController = null;
    super.dispose();
  }

  // 위치 권한 요청
  Future<void> _requestLocationPermission() async {
    try {
      // 위치 서비스 활성화 여부 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationMessage('위치 서비스가 꺼져 있어요', '켜면 내 위치를 지도에 표시할 수 있어요');
        return;
      }

      // 권한이 없으면 한 번 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationMessage('위치 권한이 없어요', '내 위치 기능을 사용할 수 없어요');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage('위치 권한이 꺼져 있어요', '설정에서 위치 권한을 허용해주세요');
        return;
      }

      // 권한이 있으면 현재 위치 조회
      _getCurrentLocation();
    } catch (e) {
      print('위치 권한 확인 중 오류 발생: $e');
    }
  }

  void _showLocationMessage(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentPosition.value = position;
    } catch (e) {
      print('현재 위치를 가져오는데 실패했습니다: $e');
      _showLocationMessage('위치를 찾지 못했어요', '잠시 후 다시 시도해주세요');
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> _loadStationDetail() async {
    // stationId 기준 정류장 상세 조회
    isLoading.value = true;
    final result = await viewModel.fetchStationDetail(widget.stationId);
    station.value = result;
    isLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('정류장 정보'),
      ),
      body: Obx(() {
        if (isLoading.value) {
          // 정류장 상세 로딩 상태
          return const Center(
            child: CircularProgressIndicator.adaptive(),
          );
        }

        final stationInfo = station.value;
        if (stationInfo == null) {
          return _buildErrorState(context);
        }

        // 지도가 화면 위를 채우고, 아래 패널에 정류장 이름·방향·사진을 둔다.
        return Column(
          children: [
            Expanded(child: _buildMapSection(context, stationInfo)),
            _buildStationPanel(context, stationInfo),
          ],
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wrong_location_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            const Text('정류장 정보를 불러오지 못했어요'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadStationDetail,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(BuildContext context, ShuttleStation stationInfo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stationPosition = NLatLng(stationInfo.latitude, stationInfo.longitude);

    // 정류장 위치를 네이버 지도에 표시
    return Stack(
      children: [
        Positioned.fill(
          child: NaverMap(
            key: ValueKey(isDark),
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: stationPosition,
                zoom: 16,
              ),
              mapType: NMapType.basic,
              nightModeEnable: isDark,
              maxZoom: 18,
              minZoom: 10,
              contentPadding: EdgeInsets.zero,
              rotationGesturesEnable: false, // 회전 제스처 비활성화
            ),
            onMapReady: (controller) async {
              mapController = controller;

              // 지도 준비 후 정류장 마커 추가. 셔틀 노선선의 승차 점처럼 흰 테두리의 빨간 점으로 그린다.
              final markerIcon = await NOverlayImage.fromWidget(
                widget: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _shuttleColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
                size: const Size(24, 24),
                context: context,
              );
              if (!mounted || mapController != controller) return;
              controller.addOverlay(
                NMarker(
                  id: 'station_marker',
                  position: stationPosition,
                  isFlat: false,
                  icon: markerIcon,
                  anchor: const NPoint(0.5, 0.5), // 점의 가운데가 정류장 위치를 가리키도록 설정
                  caption: NOverlayCaption(
                    text: stationInfo.name,
                    textSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF16181D),
                    haloColor: isDark ? Colors.black : Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
        // 내 위치/정류장 위치 빠른 이동 버튼
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              _buildMapButton(
                context,
                icon: Icons.my_location_rounded,
                tooltip: '내 위치 보기',
                onTap: () {
                  mapController?.setLocationTrackingMode(
                    NLocationTrackingMode.follow,
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMapButton(
                context,
                icon: Icons.place_outlined,
                tooltip: '정류장 위치 보기',
                onTap: () {
                  mapController?.setLocationTrackingMode(
                    NLocationTrackingMode.none,
                  );
                  mapController?.updateCamera(
                    NCameraUpdate.withParams(target: stationPosition, zoom: 16)
                      ..setAnimation(duration: const Duration(milliseconds: 300)),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: ScaleButton(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              // 지도 위에 떠 있는 버튼이라 옅은 중립 그림자만 둔다.
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 22,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationPanel(BuildContext context, ShuttleStation stationInfo) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (kind, direction) = _splitDescription(stationInfo.description);
    final meta = [?kind, ?direction].join(' · ');
    final imageUrl = stationInfo.imageUrl;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 정류장 이름: 노선선의 승차 점과 같은 빨간 점을 앞에 둔다.
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.redAccent : _shuttleColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stationInfo.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    meta,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ),
              ],
              Obx(() {
                final distance = _distanceLabel(stationInfo);
                if (distance == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 24, top: 4),
                  child: Text(
                    distance,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              if (imageUrl != null)
                _buildPhotoPreview(context, imageUrl)
              else
                Text(
                  '등록된 정류장 사진이 없어요',
                  style: TextStyle(fontSize: 13, color: theme.hintColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // "시내버스정류장[천캠방향]" → ("시내버스정류장", "천캠 방향")
  (String?, String?) _splitDescription(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return (null, null);
    final match = RegExp(r'^(.*?)\s*\[([^\]]+)\]\s*$').firstMatch(text);
    if (match == null) return (text, null);
    final kind = match.group(1)!.trim();
    final direction = match
        .group(2)!
        .trim()
        .replaceAllMapped(RegExp(r'(\S)방향$'), (m) => '${m[1]} 방향');
    return (kind.isEmpty ? null : kind, direction);
  }

  // 내 위치에서 정류장까지 직선거리
  String? _distanceLabel(ShuttleStation stationInfo) {
    final position = currentPosition.value;
    if (position == null) return null;
    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      stationInfo.latitude,
      stationInfo.longitude,
    );
    if (meters >= 1000) {
      return '내 위치에서 ${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '내 위치에서 ${(meters / 10).round() * 10}m';
  }

  Widget _buildPhotoPreview(BuildContext context, String imageUrl) {
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.06,
    );

    return Semantics(
      button: true,
      label: '정류장 사진 크게 보기',
      excludeSemantics: true,
      child: ScaleButton(
        onTap: () => _showImageViewer(imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  // 사진 위쪽(정류장 표지판·건물)이 잘리지 않게 위에 맞춘다.
                  alignment: Alignment.topCenter,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return ColoredBox(
                      color: placeholderColor,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: placeholderColor,
                    child: Center(
                      child: Text(
                        '사진을 불러오지 못했어요',
                        style: TextStyle(fontSize: 13, color: theme.hintColor),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageViewer(String imageUrl) {
    // 사진은 검은 배경 전체 화면에서 확대해 본다.
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
      pageBuilder: (context, _, __) => Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Text(
                        '사진을 불러오지 못했어요',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 16,
                right: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        station.value?.name ?? '정류장 사진',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
