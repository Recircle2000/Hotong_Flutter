import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../utils/responsive_layout.dart';
import '../../viewmodel/busmap_viewmodel.dart';
import '../../viewmodel/settings_viewmodel.dart';

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
    if (controller.currentLocation.value == null) {
      await controller.checkLocationPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (controller.currentLocation.value == null) {
      await controller.checkLocationPermission();
    }

    final location = controller.currentLocation.value;
    if (location != null) {
      _mapController.move(location, 15);
    }
  }

  void _showStationInfo(StationMarkerInfo station) {
    final layout = AppResponsive.of(context);
    Get.dialog(
      AlertDialog(
        title: Text(station.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정류장 ID: ${station.nodeId}'),
            SizedBox(height: layout.space(8)),
            Text('정류장 번호: ${station.nodeNo}'),
            SizedBox(height: layout.space(8)),
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

    return [
      Polyline(
        points: points,
        strokeWidth: 4.0,
        color: Colors.blueAccent,
      ),
    ];
  }

  List<Marker> _buildStationMarkers() {
    final layout = AppResponsive.of(context);
    return controller.stationMarkers
        .map(
          (station) => Marker(
            width: layout.space(30, maxScale: 1.10),
            height: layout.space(30, maxScale: 1.10),
            point: station.position,
            child: GestureDetector(
              onTap: () => _showStationInfo(station),
              child: Transform.translate(
                offset: Offset(0, -layout.space(13, maxScale: 1.10)),
                child: Icon(
                  Icons.location_on,
                  color: Colors.blueAccent,
                  size: layout.icon(30, maxScale: 1.10),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildBusMarkers() {
    final layout = AppResponsive.of(context);
    return controller.markers
        .map(
          (bus) => Marker(
            width: layout.space(80, maxScale: 1.10),
            height: layout.space(80, maxScale: 1.10),
            point: bus.position,
            child: Column(
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Colors.indigo,
                  size: layout.icon(40, maxScale: 1.10),
                ),
                Container(
                  padding: EdgeInsets.all(layout.space(5, maxScale: 1.05)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(layout.radius(4)),
                  ),
                  child: Text(
                    bus.vehicleNo,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: layout.font(10),
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
    final layout = AppResponsive.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routeName,
          style:
              TextStyle(fontSize: layout.font(20), fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: layout.icon(24)),
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
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jw.hoseotransport',
                  ),
                  PolylineLayer(polylines: _buildPolylines()),
                  MarkerLayer(markers: _buildStationMarkers()),
                  MarkerLayer(markers: _buildBusMarkers()),
                  if (controller.currentLocation.value != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: layout.space(40, maxScale: 1.10),
                          height: layout.space(40, maxScale: 1.10),
                          point: controller.currentLocation.value!,
                          child: Icon(
                            Icons.my_location,
                            color: Colors.red,
                            size: layout.icon(20),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            }),
            Positioned(
              right: layout.space(16),
              bottom: layout.space(16),
              child: Obx(
                () => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: layout.space(10, maxScale: 1.08),
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(layout.radius(50)),
                      onTap: _moveToCurrentLocation,
                      child: Padding(
                        padding: EdgeInsets.all(layout.space(12)),
                        child: Icon(
                          controller.isLocationLoading.value
                              ? Icons.hourglass_empty
                              : Icons.my_location,
                          color: controller.isLocationEnabled.value
                              ? Colors.blue
                              : Colors.grey,
                          size: layout.icon(24),
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
