import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

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

    return [
      Polyline(
        points: points,
        strokeWidth: 4.0,
        color: Colors.blueAccent,
      ),
    ];
  }

  List<Marker> _buildStationMarkers() {
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
    return controller.markers
        .map(
          (bus) => Marker(
            width: 80.0,
            height: 80.0,
            point: bus.position,
            child: Column(
              children: [
                const Icon(Icons.directions_bus, color: Colors.indigo, size: 40),
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
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jw.hoseotransport',
                  ),
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
