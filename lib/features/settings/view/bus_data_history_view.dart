import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hsro/core/repository/bus_data_history_repository.dart';
import 'package:hsro/shared/widgets/scale_button.dart';

/// 설정 > 앱 정보에서 시내버스 시간표·노선 줄을 누르면 여는 변경이력 표.
class BusDataHistoryView extends StatefulWidget {
  const BusDataHistoryView({
    super.key,
    required this.kind,
    this.currentVersion,
    this.repository,
  });

  final BusDataHistoryKind kind;

  /// 지금 기기에 있는 버전. 표에서 "사용 중"으로 표시한다.
  final String? currentVersion;
  final BusDataHistoryRepository? repository;

  @override
  State<BusDataHistoryView> createState() => _BusDataHistoryViewState();
}

class _BusDataHistoryViewState extends State<BusDataHistoryView> {
  late final BusDataHistoryRepository _repository =
      widget.repository ?? BusDataHistoryRepository();
  late Future<List<BusDataHistoryItem>> _future = _repository.fetch(widget.kind);

  String get _title => widget.kind == BusDataHistoryKind.timetable
      ? '시내버스 시간표 변경이력'
      : '시내버스 노선 변경이력';

  void _retry() {
    setState(() => _future = _repository.fetch(widget.kind));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: ScaleButton(
          onTap: () => Get.back(),
          child: Icon(Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back),
        ),
      ),
      body: FutureBuilder<List<BusDataHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageView(
              message: '변경이력을 불러오지 못했습니다.',
              actionLabel: '다시 시도',
              onAction: _retry,
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const _MessageView(message: '아직 변경이력이 없습니다.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HistoryTable(items: items, currentVersion: widget.currentVersion),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.items, this.currentVersion});

  final List<BusDataHistoryItem> items;
  final String? currentVersion;

  static const _versionWidth = 92.0;
  static const _dateWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(color: theme.hintColor);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                SizedBox(width: _versionWidth, child: Text('버전', style: headerStyle)),
                SizedBox(width: _dateWidth, child: Text('적용일', style: headerStyle)),
                Expanded(child: Text('변경 내용', style: headerStyle)),
              ],
            ),
          ),
          for (final (index, item) in items.indexed) ...[
            Divider(height: 1, thickness: 1, color: divider),
            _HistoryRow(
              item: item,
              isCurrent: item.version == currentVersion,
              // 비교할 이전 버전이 없는 건 가장 오래된 버전뿐이다. 나머지의 빈 요약은 기록 이전 게시본이다.
              isFirst: index == items.length - 1,
              versionWidth: _versionWidth,
              dateWidth: _dateWidth,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.item,
    required this.isCurrent,
    required this.isFirst,
    required this.versionWidth,
    required this.dateWidth,
  });

  final BusDataHistoryItem item;
  final bool isCurrent;
  final bool isFirst;
  final double versionWidth;
  final double dateWidth;

  String get _date {
    final date = item.effectiveAtKst;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year % 100}.${two(date.month)}.${two(date.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodySmall;
    final muted = body?.copyWith(color: theme.hintColor);
    final tabular = const [FontFeature.tabularFigures()];
    final changes = item.changes;

    final lines = <Widget>[
      if (item.note != null)
        Text(
          item.note!,
          style: body?.copyWith(fontWeight: FontWeight.w600),
        ),
      if (changes != null)
        for (final line in changes)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line, style: body?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.72))),
          ),
      if (changes == null && item.note == null)
        Text(isFirst ? '최초 등록' : '기록 없음', style: muted),
      if (changes != null && changes.isEmpty && item.note == null)
        Text('노선별 변경 없음', style: muted),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: versionWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.version,
                  style: body?.copyWith(fontWeight: FontWeight.w600, fontFeatures: tabular),
                ),
                if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.24)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('사용 중', style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: dateWidth,
            child: Text(_date, style: muted?.copyWith(fontFeatures: tabular)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
