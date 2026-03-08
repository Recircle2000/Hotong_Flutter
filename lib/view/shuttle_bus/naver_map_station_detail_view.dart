import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../../viewmodel/shuttle_viewmodel.dart';
import '../../models/shuttle_models.dart';
import '../components/scale_button.dart';

class NaverMapStationDetailView extends StatefulWidget {
  final int stationId;
  
  const NaverMapStationDetailView({
    Key? key,
    required this.stationId,
  }) : super(key: key);

  @override
  _NaverMapStationDetailViewState createState() => _NaverMapStationDetailViewState();
}

class _NaverMapStationDetailViewState extends State<NaverMapStationDetailView> {
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
    } catch (e) {
      print('위치 권한 확인 중 오류 발생: $e');
    }
  }
  
  // 현재 위치 가져오기 - 초기 한 번만 호출
  Future<void> _getCurrentLocation() async {
    isLoadingLocation.value = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentPosition.value = position;
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
  
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
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
              // _buildStationDescription(),
              // SizedBox(height: 24),
              _buildMapSection(),
              SizedBox(height: 16),
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
    final description = stationInfo.description ?? '정류장 설명이 없습니다.';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black.withOpacity(0.1),
        //     blurRadius: 10,
        //     offset: const Offset(0, 0),
        //   ),
        // ],
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
  
  // Widget _buildStationDescription() {
  //   final stationInfo = station.value!;
  //   final description = stationInfo.description ?? '정류장 설명이 없습니다.';
  //
  //   return Container(
  //     width: double.infinity,
  //     padding: EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Theme.of(context).colorScheme.surface,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: Colors.grey.withOpacity(0.3),
  //         width: 1,
  //       ),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           '정류장 설명',
  //           style: TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         SizedBox(height: 8),
  //         Text(
  //           description,
  //           style: TextStyle(
  //             fontSize: 15,
  //             height: 1.5,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  
  Widget _buildMapSection() {
    final stationInfo = station.value!;
    
    return Container(
      width: double.infinity,
      height: 450,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            NaverMap(
              key: ValueKey(Theme.of(context).brightness),
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(
                    stationInfo.latitude, 
                    stationInfo.longitude
                  ),
                  zoom: 16,
                ),
                mapType: NMapType.basic,
                nightModeEnable: Theme.of(context).brightness == Brightness.dark,
                maxZoom: 18,
                minZoom: 10,
                contentPadding: EdgeInsets.zero,
                rotationGesturesEnable: false, // 회전 제스처 비활성화
                // locationButtonEnable: false, // Deprecated in 1.4.0: Use NMyLocationButtonWidget or omit if not needed

            
              ),
              onMapReady: (controller) {
                mapController = controller;
                
                // 정류장 마커 추가
                controller.addOverlay(
                  NMarker(
                    id: 'station_marker',
                    position: NLatLng(
                      stationInfo.latitude, 
                      stationInfo.longitude
                    ),
                    isFlat: false,
                    anchor: NPoint(0.5, 1.0), // 마커의 하단 중앙이 위치를 가리키도록 설정
                  ),
                );
              },
            ),
            // 정류장 위치 보기 버튼
            Positioned(
              right: 10,
              bottom: 42,
              child: Column(
                children: [
                   Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(1),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.my_location,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        if (mapController != null) {
                           mapController!.setLocationTrackingMode(NLocationTrackingMode.follow);
                        }
                      },
                      tooltip: '내 위치 보기',
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(1),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.directions_bus,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        if (mapController != null && station.value != null) {
                          // 정류장 위치로 지도 이동
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
                      tooltip: '정류장 위치 보기',
                    ),
                  ),
                ],
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
    
    if (Platform.isIOS) {
      return ScaleButton(
        onTap: hasImage
            ? () {

                _showImageViewer(stationInfo.imageUrl!);
              }
            : () {

                _showNoImageAlert();
              },
        child: Container( 
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: hasImage
                ? (brightness == Brightness.dark
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.blue.withOpacity(0.1))
                : (brightness == Brightness.dark
                    ? Colors.grey.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasImage ? CupertinoIcons.photo : CupertinoIcons.photo_fill_on_rectangle_fill,
                color: hasImage
                    ? (brightness == Brightness.dark ? Colors.blue : Colors.blue.shade700)
                    : Colors.grey,
              ),
              SizedBox(width: 8),
              Text(
                '정류장 사진 보기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasImage
                      ? (brightness == Brightness.dark ? Colors.blue : Colors.blue.shade700)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return ScaleButton(
        onTap: hasImage ? () => _showImageViewer(stationInfo.imageUrl!) : _showNoImageAlert,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: hasImage
                ? (brightness == Brightness.dark
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.blue.withOpacity(0.1))
                : (brightness == Brightness.dark
                    ? Colors.grey.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasImage ? Icons.photo : Icons.photo_library_outlined,
                color: hasImage
                    ? (brightness == Brightness.dark ? Colors.blue : Colors.blue.shade700)
                    : Colors.grey,
              ),
              SizedBox(width: 8),
              Text(
                '정류장 사진 보기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasImage
                      ? (brightness == Brightness.dark ? Colors.blue : Colors.blue.shade700)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
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
        builder: (context) => CupertinoPageScaffold(
          backgroundColor: Colors.transparent,
          child: Material(
            color: brightness == Brightness.dark
                ? CupertinoColors.systemBackground.darkColor 
                : CupertinoColors.systemBackground.color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 드래그 핸들
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '정류장 사진',
                          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(CupertinoIcons.xmark_circle_fill, 
                            color: CupertinoColors.systemGrey.resolveFrom(context)),
                          onPressed: () => Navigator.pop(context),
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
                                    size: 50,
                                    color: CupertinoColors.destructiveRed,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '이미지를 불러올 수 없습니다.',
                                    style: CupertinoTheme.of(context).textTheme.textStyle,
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
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: brightness == Brightness.dark ? Colors.black : Colors.white,
          insetPadding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '정류장 사진',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
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
                      return Container(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator.adaptive(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 50,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Text('이미지를 불러올 수 없습니다.'),
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
        ),
      );
    }
  }
} 