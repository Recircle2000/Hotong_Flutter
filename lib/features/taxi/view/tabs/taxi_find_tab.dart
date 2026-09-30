import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_home_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_notice.dart';
import 'package:hsro/features/taxi/widgets/taxi_party_card.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:intl/intl.dart';

/// 택시팟 홈의 팟 검색 탭. 검색 카드가 가려지면 상단에 조건 요약 바를 띄운다.
class TaxiFindPartiesTab extends StatefulWidget {
  const TaxiFindPartiesTab({
    super.key,
    required this.controller,
    required this.onPartyTap,
  });
  final TaxiHomeViewModel controller;
  final Future<void> Function(TaxiPartySummary party) onPartyTap;

  @override
  State<TaxiFindPartiesTab> createState() => _TaxiFindPartiesTabState();
}

class _TaxiFindPartiesTabState extends State<TaxiFindPartiesTab> {
  final _scrollController = ScrollController();
  final _searchCardKey = GlobalKey();
  bool _showCompactBar = false;

  TaxiHomeViewModel get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCompactBar);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateCompactBar);
    _scrollController.dispose();
    super.dispose();
  }

  /// 검색 카드가 화면 위로 완전히 가려지면 요약 바를 보여준다.
  void _updateCompactBar() {
    final card =
        _searchCardKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = _scrollController.offset;
    bool hidden;
    if (card == null || !card.attached) {
      // 멀리 스크롤되어 카드가 목록에서 해제된 경우다.
      hidden = offset > 0;
    } else {
      // 카드 윗면이 화면 맨 위에 오는 스크롤 위치에 카드 높이를 더하면
      // 카드가 완전히 가려지는 지점이 된다.
      final viewport = RenderAbstractViewport.of(card);
      final cardTop = viewport.getOffsetToReveal(card, 0).offset;
      hidden = offset >= cardTop + card.size.height;
    }
    if (hidden != _showCompactBar) setState(() => _showCompactBar = hidden);
  }

  void _scrollToSearchCard() {
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  String _locationName(int? id) {
    if (id == null) return '전체';
    for (final location in controller.locations) {
      if (location.id == id) return location.name;
    }
    return '전체';
  }

  Widget _buildCompactBar(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final now = DateTime.now();
      final selected = controller.selectedDate.value;
      final isToday =
          selected.year == now.year &&
          selected.month == now.month &&
          selected.day == now.day;
      final date =
          '${DateFormat('M/d (E)', 'ko').format(selected)}'
          '${isToday ? ' · 오늘' : ''}';
      return Material(
        color: theme.scaffoldBackgroundColor,
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: _scrollToSearchCard,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_locationName(controller.departureLocationId.value)} → '
                    '${_locationName(controller.destinationLocationId.value)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  date,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: taxiAccentText(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildList(context),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showCompactBar,
            child: AnimatedSlide(
              offset: _showCompactBar ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                key: const ValueKey('search-compact-bar'),
                opacity: _showCompactBar ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Semantics(
                  button: true,
                  label: '검색 조건 바꾸기',
                  child: _buildCompactBar(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => RefreshIndicator(
        color: taxiAccentText(context),
        onRefresh: controller.refreshAll,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (controller.errorMessage.isNotEmpty)
              TaxiErrorCard(message: controller.errorMessage.value),
            Container(
              key: _searchCardKey,
              decoration: taxiCardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: taxiTint(context),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_taxi_outlined,
                          color: taxiAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '어디로 가시나요?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '같은 방향의 택시팟을 찾아보세요',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _LocationDropdown(
                          label: '출발지',
                          value: controller.departureLocationId.value,
                          locations: controller.locations,
                          onChanged: controller.setDeparture,
                        ),
                      ),
                      IconButton(
                        tooltip: '출발지와 도착지 바꾸기',
                        onPressed: controller.swapLocations,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 22),
                        color: taxiAccentText(context),
                      ),
                      Expanded(
                        child: _LocationDropdown(
                          label: '도착지',
                          value: controller.destinationLocationId.value,
                          locations: controller.locations,
                          onChanged: controller.setDestination,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DateSelector(controller: controller),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '택시팟 목록',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('마감된 방 보기', style: theme.textTheme.bodySmall),
                const SizedBox(width: 4),
                Switch.adaptive(
                  activeTrackColor: taxiAccent,
                  activeThumbColor: const Color(0xFF30210A),
                  value: controller.includeUnavailable.value,
                  onChanged: controller.toggleUnavailable,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (controller.isLoading.value && controller.parties.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
                  ),
                ),
              )
            else if (controller.parties.isEmpty)
              const _EmptyParties()
            else
              ...controller.parties.map(
                (party) => TaxiPartyCard(
                  party: party,
                  onTap: () => widget.onPartyTap(party),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.controller});

  final TaxiHomeViewModel controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDate.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(selected.year, selected.month, selected.day);
    final last = taxiLastSelectableDay(now: now);
    return Container(
      decoration: BoxDecoration(
        color: taxiTint(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '이전 날짜',
            onPressed: date.isAfter(today)
                ? () => controller.changeDate(-1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${DateFormat('M월 d일 (E)', 'ko').format(selected)}${date == today ? ' · 오늘' : ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: taxiAccentText(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: '다음 날짜',
            onPressed: date.isBefore(last)
                ? () => controller.changeDate(1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyParties extends StatelessWidget {
  const _EmptyParties();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: taxiCardDecoration(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: taxiTint(context),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_taxi_outlined,
              size: 32,
              color: taxiAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '조건에 맞는 택시팟이 없어요',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 경로나 날짜를 선택하거나\n새로운 택시팟을 만들어보세요.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.locations,
    required this.onChanged,
  });
  final String label;
  final int? value;
  final List<TaxiLocation> locations;
  final ValueChanged<int?> onChanged;

  // "전체" 선택지를 네이티브 메뉴에서 구분하기 위한 값. 실제 거점 id와 겹치지 않는다.
  static const _allLocationsId = 0x7fffffff;

  InputDecoration _decoration(BuildContext context) => InputDecoration(
    labelText: label,
    floatingLabelStyle: TextStyle(color: taxiAccentText(context)),
    filled: true,
    fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: taxiAccent, width: 1.5),
    ),
  );

  TextStyle? _valueStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  @override
  Widget build(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS
      ? _buildIOS(context)
      : _buildMaterial(context);

  /// iOS는 필드 모양은 유지하고 네이티브 메뉴로 거점을 고른다.
  Widget _buildIOS(BuildContext context) {
    final selected = locations.where((l) => l.id == value).firstOrNull;
    return Stack(
      children: [
        InputDecorator(
          decoration: _decoration(context).copyWith(
            suffixIcon: const Icon(Icons.expand_more_rounded, size: 20),
          ),
          child: Text(
            selected?.name ?? '전체',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _valueStyle(context),
          ),
        ),
        Positioned.fill(
          child: IOSPopupMenuOverlay(
            options: [
              const IOSPopupMenuOption(id: _allLocationsId, title: '전체'),
              for (final location in locations)
                IOSPopupMenuOption(id: location.id, title: location.name),
            ],
            selectedId: value ?? _allLocationsId,
            onChanged: (id) => onChanged(id == _allLocationsId ? null : id),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterial(BuildContext context) => DropdownButtonFormField<int?>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    icon: const Icon(Icons.expand_more_rounded, size: 20),
    borderRadius: BorderRadius.circular(16),
    dropdownColor: Theme.of(context).cardColor,
    style: _valueStyle(context),
    decoration: _decoration(context),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('전체')),
      ...locations.map(
        (location) => DropdownMenuItem<int?>(
          value: location.id,
          child: Text(
            location.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
    onChanged: onChanged,
  );
}
