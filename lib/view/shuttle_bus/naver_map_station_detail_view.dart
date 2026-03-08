import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../models/shuttle_models.dart';
import '../../utils/responsive_layout.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../components/scale_button.dart';

class NaverMapStationDetailView extends StatefulWidget {
  final int stationId;

  const NaverMapStationDetailView({
    super.key,
    required this.stationId,
  });

  @override
  State<NaverMapStationDetailView> createState() =>
      _NaverMapStationDetailViewState();
}

class _NaverMapStationDetailViewState extends State<NaverMapStationDetailView> {
  final ShuttleViewModel viewModel = Get.find<ShuttleViewModel>();
  final RxBool isLoading = true.obs;
  final Rx<ShuttleStation?> station = Rx<ShuttleStation?>(null);
  final RxBool isLoadingLocation = false.obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);

  NaverMapController? mapController;

  @override
  void initState() {
    super.initState();
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
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      currentPosition.value = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
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
                  _buildMapSection(context),
                  SizedBox(height: layout.space(16)),
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
    final description = stationInfo.description ?? '정류장 설명이 없습니다.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(layout.space(16)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(layout.radius(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stationInfo.name,
            style: TextStyle(
              fontSize: layout.font(22, maxScale: 1.12),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: layout.space(6, maxScale: 1.08)),
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

    return Container(
      width: double.infinity,
      height: layout.space(450, maxScale: 1.12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.radius(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: layout.space(10, maxScale: 1.08),
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(layout.radius(25)),
        child: Stack(
          children: [
            NaverMap(
              key: ValueKey(Theme.of(context).brightness),
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(stationInfo.latitude, stationInfo.longitude),
                  zoom: 16,
                ),
                mapType: NMapType.basic,
                nightModeEnable:
                    Theme.of(context).brightness == Brightness.dark,
                maxZoom: 18,
                minZoom: 10,
                contentPadding: EdgeInsets.zero,
                rotationGesturesEnable: false,
              ),
              onMapReady: (controller) {
                mapController = controller;
                controller.addOverlay(
                  NMarker(
                    id: 'station_marker',
                    position:
                        NLatLng(stationInfo.latitude, stationInfo.longitude),
                    isFlat: false,
                    anchor: const NPoint(0.5, 1.0),
                  ),
                );
              },
            ),
            Positioned(
              right: layout.space(10),
              bottom: layout.space(42, maxScale: 1.08),
              child: Column(
                children: [
                  _buildMapActionButton(
                    context,
                    icon: Icons.my_location,
                    onPressed: () {
                      if (mapController != null) {
                        mapController!.setLocationTrackingMode(
                          NLocationTrackingMode.follow,
                        );
                      }
                    },
                  ),
                  SizedBox(height: layout.space(8)),
                  _buildMapActionButton(
                    context,
                    icon: Icons.directions_bus,
                    onPressed: () {
                      if (mapController != null && station.value != null) {
                        mapController!.updateCamera(
                          NCameraUpdate.withParams(
                            target: NLatLng(
                              station.value!.latitude,
                              station.value!.longitude,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final layout = AppResponsive.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(1),
        borderRadius: BorderRadius.circular(layout.radius(6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: layout.space(4, maxScale: 1.08),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: layout.icon(24),
        ),
        onPressed: onPressed,
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

    return ScaleButton(
      onTap: hasImage
          ? () => _showImageViewer(stationInfo.imageUrl!)
          : _showNoImageAlert,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: layout.space(14)),
        decoration: BoxDecoration(
          color: hasImage
              ? (brightness == Brightness.dark
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.1))
              : (brightness == Brightness.dark
                  ? Colors.grey.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(
            layout.radius(Platform.isIOS ? 25 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: layout.space(10, maxScale: 1.08),
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasImage
                  ? (Platform.isIOS ? CupertinoIcons.photo : Icons.photo)
                  : (Platform.isIOS
                      ? CupertinoIcons.photo_fill_on_rectangle_fill
                      : Icons.photo_library_outlined),
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
      ),
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

  void _showImageViewer(String imageUrl) {
    final brightness = Theme.of(context).brightness;

    if (Platform.isIOS) {
      showCupertinoModalBottomSheet(
        context: context,
        expand: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        barrierColor: CupertinoColors.black.withOpacity(0.5),
        duration: const Duration(milliseconds: 300),
        builder: (context) {
          final modalLayout = AppResponsive.of(context);
          return CupertinoPageScaffold(
            backgroundColor: Colors.transparent,
            child: Material(
              color: brightness == Brightness.dark
                  ? CupertinoColors.systemBackground.darkColor
                  : CupertinoColors.systemBackground.color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(modalLayout.radius(12)),
                topRight: Radius.circular(modalLayout.radius(12)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(
                        vertical: modalLayout.space(10),
                      ),
                      width: modalLayout.space(40, maxScale: 1.08),
                      height: modalLayout.space(5, maxScale: 1.08),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3.resolveFrom(context),
                        borderRadius:
                            BorderRadius.circular(modalLayout.radius(2.5)),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: modalLayout.space(16),
                        vertical: modalLayout.space(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '정류장 사진',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .navTitleTextStyle,
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: CupertinoColors.systemGrey.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InteractiveViewer(
                        child: Center(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CupertinoActivityIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.exclamationmark_circle,
                                      size:
                                          modalLayout.icon(50, maxScale: 1.12),
                                      color: CupertinoColors.destructiveRed,
                                    ),
                                    SizedBox(height: modalLayout.space(16)),
                                    Text(
                                      '이미지를 불러올 수 없습니다.',
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final dialogLayout = AppResponsive.of(context);
        return Dialog(
          backgroundColor:
              brightness == Brightness.dark ? Colors.black : Colors.white,
          insetPadding: EdgeInsets.all(dialogLayout.space(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dialogLayout.space(16),
                  vertical: dialogLayout.space(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '정류장 사진',
                      style: TextStyle(
                        fontSize: dialogLayout.font(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: dialogLayout.icon(24)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: dialogLayout.space(300, maxScale: 1.12),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return SizedBox(
                        height: dialogLayout.space(300, maxScale: 1.12),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: dialogLayout.icon(50, maxScale: 1.12),
                                color: Colors.red,
                              ),
                              SizedBox(height: dialogLayout.space(16)),
                              Text(
                                '이미지를 불러올 수 없습니다.',
                                style:
                                    TextStyle(fontSize: dialogLayout.font(14)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
