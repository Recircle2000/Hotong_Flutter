import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:hsro/features/city_bus/view/components/station_item.dart';
import 'package:hsro/features/city_bus/viewmodel/busmap_viewmodel.dart';

/// 위치 관련 헬퍼 기능 모음
class LocationHelper {
  /// 가장 가까운 정류장 찾기와 스크롤 처리
  static void findNearestStationAndScroll(
      BuildContext context, ScrollController scrollController) {
    final controller = Get.find<BusMapViewModel>();

    if (controller.currentLocation.value == null) {
      // 위치 정보가 없으면 먼저 위치 권한 요청
      controller.checkLocationPermission().then((_) {
        if (controller.currentLocation.value != null) {
          _processNearestStation(context, controller, scrollController);
        } else {
          Fluttertoast.showToast(
            msg: "위치 정보를 가져올 수 없습니다. 다시 시도해주세요.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      });
    } else {
      _processNearestStation(context, controller, scrollController);
    }
  }

  /// 가까운 정류장 찾고 스크롤 처리하는 내부 함수
  static void _processNearestStation(BuildContext context,
      BusMapViewModel controller, ScrollController scrollController) {
    final nearestStationIndex = controller.findNearestStation();

    if (nearestStationIndex == null) {
      Fluttertoast.showToast(
        msg: "가까운 정류장을 찾을 수 없습니다.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final stationName = controller.stationNames[nearestStationIndex];

    try {
      // 찾은 정류장 강조 표시
      StationHighlightManager.highlightedStation.value = nearestStationIndex;

      // 5초 후 강조 표시 해제
      Future.delayed(const Duration(seconds: 5), () {
        // 현재도 같은 정류장이 강조 중이면 해제
        if (StationHighlightManager.highlightedStation.value ==
            nearestStationIndex) {
          StationHighlightManager.highlightedStation.value = -1;
        }
      });

      // 스크롤 컨트롤러가 연결된 경우 목록 위치 이동
      if (scrollController.hasClients) {
        // 레이아웃 완료 후 실제 크기 기준으로 스크롤 계산
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 정류장 한 줄이 고정 높이라 인덱스만으로 목표 스크롤 위치 계산
          final double targetOffset =
              nearestStationIndex * StationItem.itemExtent;

          // 실제 스크롤 가능 범위 안으로 보정
          double safeOffset = targetOffset.clamp(
              0.0, scrollController.position.maxScrollExtent);

          debugPrint("스크롤 시도: 인덱스 $nearestStationIndex, 위치 $safeOffset");

          // 먼저 부드러운 스크롤 시도
          scrollController
              .animateTo(
            safeOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          )
              .catchError((error) {
            debugPrint("animateTo 실패, jumpTo 시도: $error");
            // 애니메이션 실패 시 즉시 이동
            scrollController.jumpTo(safeOffset);
          });
        });
      } else {
        // 스크롤 컨트롤러가 없거나 아직 준비되지 않은 경우
        debugPrint("스크롤 컨트롤러가 준비되지 않았습니다");
        Fluttertoast.showToast(
          msg: "가장 가까운 정류장: $stationName",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint("스크롤 처리 중 오류 발생: $e");
      // 오류가 나도 화면 흐름은 유지
    }
  }
}
