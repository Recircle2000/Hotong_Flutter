import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:latlong2/latlong.dart';

import '../../models/shuttle_models.dart';
import '../../utils/responsive_layout.dart';
import '../../viewmodel/shuttle_viewmodel.dart';

class StationDetailView extends StatefulWidget {
  final int stationId;

  const StationDetailView({
    super.key,
    required this.stationId,
  });

  @override
  State<StationDetailView> createState() => _StationDetailViewState();
}

class _StationDetailViewState extends State<StationDetailView> {
  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();
  final RxBool isLoading = true.obs;
  final Rx<ShuttleStation?> station = Rx<ShuttleStation?>(null);
  final RxBool isLoadingLocation = false.obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxBool showMyLocation = false.obs;
  MapController? mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _loadStationDetail();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    mapController = null;
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar(
          '위치 서비스 비활성화',
          '위치 서비스를 활성화해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            '권한 거부',
            '위치 권한이 거부되었습니다. 내 위치 기능을 사용할 수 없습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          '권한 설정 필요',
          '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: const Duration(seconds: 5),
        );
        return;
      }

      await _getCurrentLocation();
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        currentPosition.value = position;
      });
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentPosition.value = position;

      if (showMyLocation.value && mapController != null) {
        mapController!.move(
          LatLng(position.latitude, position.longitude),
          mapController!.camera.zoom,
        );
      }
    } catch (_) {
      Get.snackbar(
        '위치 오류',
        '현재 위치를 가져오는데 실패했습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> _loadStationDetail() async {
    isLoading.value = true;
    station.value = await viewModel.fetchStationDetail(widget.stationId);
    isLoading.value = false;
  }

  void _toggleMapCenter() {
    if (currentPosition.value == null ||
        station.value == null ||
        mapController == null) {
      return;
    }

    showMyLocation.toggle();

    if (showMyLocation.value) {
      mapController!.move(
        LatLng(
          currentPosition.value!.latitude,
          currentPosition.value!.longitude,
        ),
        mapController!.camera.zoom,
      );
      return;
    }

    mapController!.move(
      LatLng(station.value!.latitude, station.value!.longitude),
      mapController!.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '정류장 정보',
          style:
              TextStyle(fontSize: layout.font(20), fontWeight: FontWeight.w700),
        ),
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (station.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: layout.icon(64, maxScale: 1.12),
                  color: Colors.grey,
                ),
                SizedBox(height: layout.space(16)),
                Text(
                  '정류장 정보를 불러올 수 없습니다.',
                  style: TextStyle(fontSize: layout.font(14)),
                ),
                SizedBox(height: layout.space(16)),
                _buildRetryButton(context),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: AppPageFrame(
            child: Padding(
              padding: EdgeInsets.all(layout.space(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStationHeader(context),
                  SizedBox(height: layout.space(16)),
                  _buildStationDescription(context),
                  SizedBox(height: layout.space(24)),
                  _buildMapSection(context),
                  SizedBox(height: layout.space(24)),
                  _buildImageButton(context),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    final layout = AppResponsive.of(context);

    if (Platform.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(16),
          vertical: layout.space(8),
        ),
        color: Colors.blue,
        child: Text('다시 시도', style: TextStyle(fontSize: layout.font(14))),
        onPressed: _loadStationDetail,
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(16),
          vertical: layout.space(8),
        ),
      ),
      onPressed: _loadStationDetail,
      child: Text('다시 시도', style: TextStyle(fontSize: layout.font(14))),
    );
  }

  Widget _buildStationHeader(BuildContext context) {
    final layout = AppResponsive.of(context);
    final stationInfo = station.value!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(layout.radius(16)),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
        ),
      ),
      child: Text(
        stationInfo.name,
        style: TextStyle(
          fontSize: layout.font(22, maxScale: 1.12),
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStationDescription(BuildContext context) {
    final layout = AppResponsive.of(context);
    final stationInfo = station.value!;
    final description = stationInfo.description ?? '정류장 설명이 없습니다.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(layout.radius(14)),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정류장 설명',
            style: TextStyle(
              fontSize: layout.font(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: layout.space(8)),
          Text(
            description,
            style: TextStyle(
              fontSize: layout.font(15),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    final layout = AppResponsive.of(context);
    final stationInfo = station.value!;

    return Obx(() {
      return Container(
        width: double.infinity,
        height: layout.space(300, maxScale: 1.12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(layout.radius(14)),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(layout.radius(14)),
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter:
                      LatLng(stationInfo.latitude, stationInfo.longitude),
                  initialZoom: 15,
                  minZoom: 13,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.hsro.app',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point:
                            LatLng(stationInfo.latitude, stationInfo.longitude),
                        width: layout.space(40, maxScale: 1.10),
                        height: layout.space(40, maxScale: 1.10),
                        child: Transform.translate(
                          offset: Offset(0, -layout.space(20, maxScale: 1.10)),
                          child: Icon(
                            Icons.place,
                            color: Colors.red,
                            size: layout.icon(40, maxScale: 1.12),
                          ),
                        ),
                      ),
                      if (currentPosition.value != null)
                        Marker(
                          point: LatLng(
                            currentPosition.value!.latitude,
                            currentPosition.value!.longitude,
                          ),
                          width: layout.space(40, maxScale: 1.10),
                          height: layout.space(40, maxScale: 1.10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: layout.icon(28),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (currentPosition.value != null)
                Positioned(
                  right: layout.space(10),
                  top: layout.space(10),
                  child: _buildMapActionButton(
                    context,
                    icon: Icons.refresh,
                    tooltip: '내 위치 새로고침',
                    onPressed: _getCurrentLocation,
                  ),
                ),
              if (currentPosition.value != null)
                Positioned(
                  right: layout.space(10),
                  bottom: layout.space(10),
                  child: _buildMapActionButton(
                    context,
                    icon: showMyLocation.value
                        ? Icons.directions_bus
                        : Icons.my_location,
                    color: showMyLocation.value
                        ? Theme.of(context).colorScheme.primary
                        : Colors.blue,
                    tooltip: showMyLocation.value ? '정류장 위치 보기' : '내 위치 보기',
                    onPressed: _toggleMapCenter,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMapActionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final layout = AppResponsive.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.88),
        borderRadius: BorderRadius.circular(layout.radius(10)),
      ),
      child: IconButton(
        icon: Icon(icon, size: layout.icon(20), color: color),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildImageButton(BuildContext context) {
    final layout = AppResponsive.of(context);
    final stationInfo = station.value!;
    final hasImage = stationInfo.imageUrl != null;
    final brightness = Theme.of(context).brightness;
    final accentColor = hasImage
        ? (brightness == Brightness.dark ? Colors.blue : Colors.blue.shade700)
        : Colors.grey;
    final backgroundColor = hasImage
        ? (brightness == Brightness.dark
            ? Colors.blue.withOpacity(0.2)
            : Colors.blue.withOpacity(0.1))
        : (brightness == Brightness.dark
            ? Colors.grey.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1));
    final borderColor = hasImage
        ? (brightness == Brightness.dark
            ? Colors.blue.withOpacity(0.5)
            : Colors.blue.withOpacity(0.3))
        : (brightness == Brightness.dark
            ? Colors.grey.withOpacity(0.5)
            : Colors.grey.withOpacity(0.3));

    final buttonChild = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: layout.space(14)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(layout.radius(14)),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.photo : Icons.photo_library_outlined,
            color: accentColor,
            size: layout.icon(22),
          ),
          SizedBox(width: layout.space(8)),
          Text(
            '정류장 사진 보기',
            style: TextStyle(
              fontSize: layout.font(16),
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );

    if (!hasImage) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(layout.radius(14)),
          onTap: _showNoImageAlert,
          child: buttonChild,
        ),
      );
    }

    return InstaImageViewer(
      imageUrl: stationInfo.imageUrl!,
      backgroundColor: Colors.black,
      backgroundIsTransparent: false,
      child: buttonChild,
    );
  }

  void _showNoImageAlert() {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('알림'),
          content: const Text('이 정류장에 등록된 사진이 없습니다.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: const Text('이 정류장에 등록된 사진이 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
