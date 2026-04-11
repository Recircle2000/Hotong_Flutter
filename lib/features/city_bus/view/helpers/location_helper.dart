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
          // 목표 스크롤 위치 계산
          double targetOffset = 0.0;

          // 두 가지 방식으로 계산 시도
          // 1) 실제 렌더박스 높이 기반
          // 2) 고정 아이템 높이 기반

          // 먼저 렌더박스 기준 계산 시도
          try {
            final RenderBox? listBox = context.findRenderObject() as RenderBox?;
            if (listBox != null) {
              // 목록 높이와 대략적 가시 아이템 수로 평균 높이 계산
              double listHeight = listBox.size.height;
              int visibleItems = (listHeight / 81.0).ceil(); // 대략적인 아이템 수

              // 렌더박스 정보 기반으로 스크롤 위치 계산
              double itemHeight = listHeight / visibleItems;
              targetOffset = nearestStationIndex * itemHeight;
              debugPrint("렌더박스 기반 계산: 높이 $itemHeight, 오프셋 $targetOffset");
            } else {
              // 렌더박스를 못 구하면 고정 높이 기준 계산
              double itemHeight = 81.0; // 기본 StationItem 높이
              targetOffset = nearestStationIndex * itemHeight;
              debugPrint("고정 높이 기반 계산: $targetOffset");
            }
          } catch (e) {
            // 계산 중 예외가 나면 고정 높이 사용
            debugPrint("렌더박스 계산 오류, 고정 높이 사용: $e");
            targetOffset = nearestStationIndex * 81.0;
          }

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
