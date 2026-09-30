import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/services/taxi_availability_service.dart';
import 'package:hsro/features/taxi/view/taxi_party_create_view.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_notice.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';

/// 택시팟 홈의 팟 생성 탭. 새 팟을 만들 수 없는 상황이면 안내 문구로 가린다.
class TaxiCreateTab extends StatelessWidget {
  const TaxiCreateTab({
    super.key,
    required this.controller,
    required this.createKey,
    required this.busy,
    required this.onCreated,
    required this.canSubmit,
    required this.onBusyChanged,
    required this.onStepChanged,
    required this.onShowCurrent,
  });

  final TaxiHomeViewModel controller;
  final GlobalKey<TaxiPartyCreateViewState> createKey;
  final bool busy;
  final Future<void> Function(TaxiPartyDetail party) onCreated;
  final Future<bool> Function() canSubmit;
  final ValueChanged<bool> onBusyChanged;
  final VoidCallback onStepChanged;
  final VoidCallback onShowCurrent;

  @override
  Widget build(BuildContext context) => Obx(() {
    final ready =
        controller.hasLoaded.value && controller.locations.length >= 2;
    // 서버에서 택시 서비스를 끄면 새 팟은 만들 수 없고 진행 중인 팟만 이용한다.
    final serviceStopped =
        Get.isRegistered<TaxiAvailabilityService>() &&
        !Get.find<TaxiAvailabilityService>().taxiEnabled.value;
    String? blocked;
    if (serviceStopped) {
      blocked = '현재 택시팟 서비스를 운영하지 않아요.\n진행 중인 팟의 채팅은 계속 이용할 수 있어요.';
    } else if (controller.myParties.isNotEmpty) {
      blocked = '이미 모집 중인 택시팟이 있어요.\n모집 종료 후 새로운 팟을 만들 수 있습니다.';
    } else if (controller.errorMessage.isNotEmpty) {
      blocked = controller.errorMessage.value;
    } else if (!controller.hasLoaded.value || controller.isLoading.value) {
      blocked = '택시팟 정보를 확인하고 있어요.';
    } else if (!ready) {
      blocked = '등록된 택시 거점이 부족합니다.';
    }
    return Stack(
      children: [
        if (ready)
          TaxiPartyCreateView(
            key: createKey,
            embedded: true,
            locations: controller.locations.toList(),
            repository: controller.repository,
            onCreated: onCreated,
            canSubmit: canSubmit,
            onConflict: controller.refreshAll,
            onBusyChanged: onBusyChanged,
            onStepChanged: onStepChanged,
          ),
        if (blocked != null && !busy)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: controller.isLoading.value && controller.myParties.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator.adaptive(
                        valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
                      ),
                    )
                  : TaxiNotice(
                      message: blocked,
                      showRetry:
                          !serviceStopped && controller.myParties.isEmpty,
                      onRetry: controller.isLoading.value
                          ? null
                          : controller.refreshAll,
                      onShowCurrent: controller.myParties.isNotEmpty
                          ? onShowCurrent
                          : null,
                    ),
            ),
          ),
      ],
    );
  });
}
