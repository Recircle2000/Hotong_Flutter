import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../../models/shuttle_models.dart';

class StationDetailView extends StatefulWidget {
  final int stationId;

  const StationDetailView({
    Key? key,
    required this.stationId,
  }) : super(key: key);

  @override
  _StationDetailViewState createState() => _StationDetailViewState();
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
    _loadStationDetail();
    mapController = MapController();
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
      // 위치 서비스가 활성화되어 있는지 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar(
          '위치 서비스 비활성화',
          '위치 서비스를 활성화해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
          duration: Duration(seconds: 3),
        );
        return;
      }

      // 위치 권한 상태 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // 권한이 거부된 경우
          Get.snackbar(
            '권한 거부',
            '위치 권한이 거부되었습니다. 내 위치 기능을 사용할 수 없습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: Duration(seconds: 3),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 권한이 영구적으로 거부된 경우
        Get.snackbar(
          '권한 설정 필요',
          '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: Duration(seconds: 5),
        );
        return;
      }

      // 권한이 허용된 경우 위치 가져오기
      _getCurrentLocation();

      // 위치 변경 리스너 설정 (실시간 업데이트)
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 10미터 이상 움직였을 때만 업데이트
        ),
      ).listen((Position position) {
        currentPosition.value = position;
      });
    } catch (e) {
      print('위치 권한 확인 중 오류 발생: $e');
    }
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentPosition.value = position;

      // 내 위치가 표시 모드이면 지도 이동
      if (showMyLocation.value && mapController != null) {
        mapController!.move(
          LatLng(position.latitude, position.longitude),
          mapController!.camera.zoom,
        );
      }
    } catch (e) {
      print('현재 위치를 가져오는데 실패했습니다: $e');
      Get.snackbar(
        '위치 오류',
        '현재 위치를 가져오는데 실패했습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        duration: Duration(seconds: 3),
      );
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> _loadStationDetail() async {
    isLoading.value = true;
    final result = await viewModel.fetchStationDetail(widget.stationId);
    station.value = result;
    isLoading.value = false;
  }

  // 지도 중심 전환
  void _toggleMapCenter() {
    if (currentPosition.value == null ||
        station.value == null ||
        mapController == null) {
      return;
    }

    showMyLocation.toggle();

    if (showMyLocation.value) {
      // 내 위치로 지도 이동
      mapController!.move(
        LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude),
        mapController!.camera.zoom,
      );
    } else {
      // 정류장 위치로 지도 이동
      mapController!.move(
        LatLng(station.value!.latitude, station.value!.longitude),
        mapController!.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('정류장 정보'),
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(
            child: CircularProgressIndicator.adaptive(),
          );
        }

        if (station.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text('정류장 정보를 불러올 수 없습니다.'),
                SizedBox(height: 16),
                _buildRetryButton(),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStationHeader(),
              SizedBox(height: 16),
              _buildStationDescription(),
              SizedBox(height: 24),
              _buildMapSection(),
              SizedBox(height: 24),
              _buildImageButton(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRetryButton() {
    if (Platform.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.blue,
        child: Text('다시 시도'),
        onPressed: _loadStationDetail,
      );
    } else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text('다시 시도'),
        onPressed: _loadStationDetail,
      );
    }
  }

  Widget _buildStationHeader() {
    final stationInfo = station.value!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stationInfo.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationDescription() {
    final stationInfo = station.value!;
    final description = stationInfo.description ?? '정류장 설명이 없습니다.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정류장 설명',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final stationInfo = station.value!;

    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.hsro.app',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    // 정류장 마커
                    Marker(
                      point:
                          LatLng(stationInfo.latitude, stationInfo.longitude),
                      width: 40,
                      height: 40,
                      child: Transform.translate(
                        offset: Offset(0, -20), // 마커를 위로 이동
                        child: Icon(
                          Icons.place, // place 아이콘은 더 정확한 핀 모양
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ),
                    // 내 위치 마커 (위치 권한이 있을 때만)
                    if (currentPosition.value != null)
                      Marker(
                        point: LatLng(
                          currentPosition.value!.latitude,
                          currentPosition.value!.longitude,
                        ),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // 위치 새로고침 버튼
            if (currentPosition.value != null)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, size: 20),
                    onPressed: _getCurrentLocation,
                    tooltip: '내 위치 새로고침',
                  ),
                ),
              ),
            // 위치 전환 버튼 (내 위치 <-> 정류장 위치)
            if (currentPosition.value != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      showMyLocation.value
                          ? Icons.directions_bus
                          : Icons.my_location,
                      color: showMyLocation.value
                          ? Theme.of(context).colorScheme.primary
                          : Colors.blue,
                      size: 24,
                    ),
                    onPressed: _toggleMapCenter,
                    tooltip: showMyLocation.value ? '정류장 위치 보기' : '내 위치 보기',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageButton() {
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.photo : Icons.photo_library_outlined,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Text(
            '정류장 사진 보기',
            style: TextStyle(
              fontSize: 16,
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
          borderRadius: BorderRadius.circular(12),
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
          title: Text('알림'),
          content: Text('이 정류장에 등록된 사진이 없습니다.'),
          actions: [
            CupertinoDialogAction(
              child: Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('알림'),
          content: Text('이 정류장에 등록된 사진이 없습니다.'),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
}
