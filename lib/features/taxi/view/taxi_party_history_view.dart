import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_app_bar_leading.dart';
import 'package:hsro/features/taxi/widgets/taxi_party_card.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';

/// 최근 30일 동안 참여한 택시팟 목록.
class TaxiPartyHistoryView extends StatelessWidget {
  const TaxiPartyHistoryView({
    super.key,
    required this.controller,
    required this.onPartyTap,
  });

  final TaxiHomeViewModel controller;
  final Future<void> Function(TaxiPartySummary party) onPartyTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('파티 이용 기록'),
        centerTitle: true,
        leadingWidth: TaxiAppBarLeading.width,
        leading: const TaxiAppBarLeading(),
      ),
      body: Obx(
        () => RefreshIndicator(
          color: taxiAccentText(context),
          onRefresh: controller.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (controller.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: Text('최근 이용한 택시팟이 없습니다.')),
                )
              else
                ...controller.history.map(
                  (party) => TaxiPartyCard(
                    party: party,
                    isHistory: true,
                    onTap: () => onPartyTap(party),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
