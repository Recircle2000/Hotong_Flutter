import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/widgets/taxi_confirm_dialog.dart';
import 'package:hsro/features/taxi/widgets/taxi_notice.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:intl/intl.dart';

/// 내가 차단한 참여자 목록. 익명이라 차단 당시의 팟과 라벨로 보여주고 해제할 수 있다.
class TaxiBlockListView extends StatefulWidget {
  const TaxiBlockListView({super.key, required this.repository});

  final TaxiRepository repository;

  @override
  State<TaxiBlockListView> createState() => _TaxiBlockListViewState();
}

class _TaxiBlockListViewState extends State<TaxiBlockListView> {
  List<TaxiBlock>? _blocks;
  String? _error;
  final _removing = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final blocks = await widget.repository.getBlocks();
      if (mounted) setState(() => _blocks = blocks);
    } on TaxiApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '차단 목록을 불러오지 못했어요.');
    }
  }

  Future<void> _unblock(TaxiBlock block) async {
    final confirmed = await showTaxiDestructiveConfirm(
      context,
      title: '차단을 해제할까요?',
      message: '서로의 택시팟이 다시 보이고 같은 팟에 참여할 수 있게 돼요.',
      action: '해제',
    );
    if (!confirmed || !mounted) return;
    setState(() => _removing.add(block.id));
    try {
      await widget.repository.unblock(block.id);
      if (!mounted) return;
      setState(() => _blocks?.removeWhere((item) => item.id == block.id));
    } on TaxiApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _removing.remove(block.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = _blocks;
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('차단 목록')),
      body: _error != null
          ? TaxiNotice(message: _error!, showRetry: true, onRetry: _load)
          : blocks == null
          ? const Center(
              child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
              ),
            )
          : blocks.isEmpty
          ? Center(
              child: Text(
                '차단한 참여자가 없어요',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
                  child: Text(
                    '익명이라 차단할 때 함께 있던 팟으로 보여드려요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final block in blocks)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: Text(
                        block.targetLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${DateFormat('M월 d일 HH:mm').format(block.departureAt)} · '
                        '${block.departureLocation} → ${block.destinationLocation}',
                      ),
                      trailing: TextButton(
                        onPressed: _removing.contains(block.id)
                            ? null
                            : () => _unblock(block),
                        child: const Text('해제'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
