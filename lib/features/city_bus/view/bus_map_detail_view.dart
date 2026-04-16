import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';
import 'package:hsro/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:latlong2/latlong.dart';

class BusMapDetailView extends StatefulWidget {
  const BusMapDetailView({super.key, required this.routeName});

  final String routeName;

  @override
  State<BusMapDetailView> createState() => _BusMapDetailViewState();
}

class _BusMapDetailViewState extends State<BusMapDetailView> {
  final BusMapViewModel controller = Get.find<BusMapViewModel>();
  final SettingsViewModel settingsViewModel = Get.find<SettingsViewModel>();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // 현재 위치가 없을 때만 권한 확인 및 위치 요청
    if (controller.currentLocation.value == null) {
      await controller.checkLocationPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    // 위치 정보가 없으면 먼저 요청
    if (controller.currentLocation.value == null) {
      await controller.checkLocationPermission();
    }

    final location = controller.currentLocation.value;
    if (location != null) {
      // 현재 위치로 지도 중심 이동
      _mapController.move(location, 15);
    }
  }

  void _showStationInfo(StationMarkerInfo station) {
    // 정류장 상세 정보 다이얼로그 표시
    Get.dialog(
      AlertDialog(
        title: Text(station.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정류장 ID: ${station.nodeId}'),
            const SizedBox(height: 8),
            Text('정류장 번호: ${station.nodeNo}'),
            const SizedBox(height: 8),
            Text('정류장 순서: ${station.nodeOrd}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  List<Polyline> _buildPolylines() {
    final points = controller.routePolylinePoints.toList();
    if (points.isEmpty) {
      return const [];
    }

    // 노선 경로를 폴리라인으로 변환
    return [
      Polyline(
        points: points,
        strokeWidth: 4.0,
        color: Colors.blueAccent,
      ),
    ];
  }

  List<Marker> _buildStationMarkers() {
    // 정류장 목록을 지도 마커로 변환
    return controller.stationMarkers
        .map(
          (station) => Marker(
            width: 30.0,
            height: 30.0,
            point: station.position,
            child: GestureDetector(
              onTap: () => _showStationInfo(station),
              child: Transform.translate(
                offset: const Offset(0, -13),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildBusMarkers() {
    // 실시간 버스 위치를 지도 마커로 변환
    return controller.markers
        .map(
          (bus) => Marker(
            width: 80.0,
            height: 80.0,
            point: bus.position,
            child: Column(
              children: [
                const Icon(Icons.directions_bus,
                    color: Colors.indigo, size: 40),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bus.vehicleNo,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: Get.back,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: GetBuilder<BusMapViewModel>(
        builder: (controller) => Stack(
          children: [
            Obx(() {
              final campus = settingsViewModel.selectedCampus.value;
              // 캠퍼스별 기본 지도 중심점 설정
              final defaultCenter = campus == "천안"
                  ? LatLng(36.8299, 127.1814)
                  : LatLng(36.769423, 127.08);

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: defaultCenter,
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.flingAnimation,
                  ),
                ),
                children: [
                  // 기본 타일 지도
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jw.hoseotransport',
                  ),
                  // 노선, 정류장, 버스, 내 위치 레이어 순서대로 표시
                  PolylineLayer(polylines: _buildPolylines()),
                  MarkerLayer(markers: _buildStationMarkers()),
                  MarkerLayer(markers: _buildBusMarkers()),
                  if (controller.currentLocation.value != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40.0,
                          height: 40.0,
                          point: controller.currentLocation.value!,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                ],
              );
            }),
            Positioned(
              right: 16,
              bottom: 16,
              child: Obx(
                () => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      // 현재 위치 버튼
                      onTap: _moveToCurrentLocation,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          controller.isLocationLoading.value
                              ? Icons.hourglass_empty
                              : Icons.my_location,
                          color: controller.isLocationEnabled.value
                              ? Colors.blue
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
