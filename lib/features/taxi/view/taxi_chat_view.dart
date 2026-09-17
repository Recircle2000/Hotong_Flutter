import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_chat_viewmodel.dart';
import 'package:intl/intl.dart';

const _taxiAccent = Color(0xFFF5A623);
const _taxiAccentForeground = Color(0xFF30210A);

Color _taxiTint(BuildContext context, [double? alpha]) =>
    _taxiAccent.withValues(
      alpha: alpha ??
          (Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.12),
    );

Color _taxiAccentText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFC766)
        : const Color(0xFF855300);

class TaxiChatView extends StatefulWidget {
  const TaxiChatView({
    super.key,
    required this.party,
    required this.repository,
    required this.realtime,
  });

  final TaxiPartyDetail party;
  final TaxiRepository repository;
  final TaxiRealtimeService realtime;

  @override
  State<TaxiChatView> createState() => _TaxiChatViewState();
}

class _TaxiChatViewState extends State<TaxiChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _tag;
  late final TaxiChatViewModel controller;
  Worker? _messageWorker;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
    _tag = 'taxi-chat-${widget.party.id}-${identityHashCode(this)}';
    controller = Get.put(
      TaxiChatViewModel(
        partyId: widget.party.id,
        readOnlyAt: widget.party.departureAt.add(const Duration(hours: 2)),
        initiallyReadOnly: widget.party.status == 'cancelled' ||
            widget.party.status == 'completed',
        repository: widget.repository,
        realtime: widget.realtime,
      ),
      tag: _tag,
    );
    _messageWorker = ever(controller.messages, (_) => _scrollToBottom());
  }

  void _handleTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(_scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ));
      }
    });
  }

  void _send() {
    if (controller.send(_textController.text)) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _messageWorker?.dispose();
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    Get.delete<TaxiChatViewModel>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (widget.party.meetingCode != null) widget.party.meetingCode!,
      '${DateFormat('M/d HH:mm').format(widget.party.departureAt)} 출발',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _taxiTint(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_taxi_outlined,
                color: _taxiAccent,
                size: 23,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.party.departureLocation.name} → '
                    '${widget.party.destinationLocation.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing:
                          widget.party.meetingCode == null ? null : 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildMessages()),
            Obx(
              () => controller.errorMessage.isEmpty
                  ? const SizedBox.shrink()
                  : _ChatError(message: controller.errorMessage.value),
            ),
            Obx(
              () => controller.isReadOnly.value
                  ? const _ReadOnlyComposer()
                  : _MessageComposer(
                      controller: _textController,
                      canSend: _hasText,
                      onSend: _send,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return Obx(() {
      if (controller.isLoading.value && controller.messages.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: _taxiAccent),
        );
      }
      if (controller.messages.isEmpty) {
        return const _EmptyChat();
      }
      return ListView.builder(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          final showDate = index == 0 ||
              !_isSameDay(
                controller.messages[index - 1].createdAt,
                message.createdAt,
              );
          return Column(
            children: [
              if (showDate) _DateSeparator(date: message.createdAt),
              _MessageBubble(message: message),
            ],
          );
        },
      );
    });
  }

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TaxiMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _SystemMessage(message: message);
    }

    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final time = Text(
      DateFormat('HH:mm').format(message.createdAt),
      style: theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
        fontSize: 10,
      ),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.68,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: message.isMine
            ? _taxiAccent
            : colors.onSurface.withValues(alpha: 0.055),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(19),
          topRight: const Radius.circular(19),
          bottomLeft: Radius.circular(message.isMine ? 19 : 5),
          bottomRight: Radius.circular(message.isMine ? 5 : 19),
        ),
      ),
      child: Text(
        message.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: message.isMine ? _taxiAccentForeground : colors.onSurface,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMine) ...[
            _SenderAvatar(label: message.senderLabel),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 5),
                    child: Text(
                      message.senderLabel ?? '익명',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: message.isMine
                      ? [time, const SizedBox(width: 6), bubble]
                      : [bubble, const SizedBox(width: 6), time],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label?.trim();
    final initial = text == null || text.isEmpty ? '?' : text.characters.first;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _taxiTint(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _taxiAccentText(context),
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final TaxiMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 2, 28, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message.content,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(date.year, date.month, date.day);
    final label = value == today
        ? '오늘'
        : DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 20),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                hintStyle: TextStyle(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                counterText: '',
                filled: true,
                fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(
                    color: _taxiAccent.withValues(alpha: 0.65),
                    width: 1.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: canSend
                  ? _taxiAccent
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: '전송',
              onPressed: canSend ? onSend : null,
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: canSend
                    ? _taxiAccentForeground
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyComposer extends StatelessWidget {
  const _ReadOnlyComposer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 17,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '종료된 택시팟의 채팅은 읽기만 가능해요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onErrorContainer,
            ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _taxiTint(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: _taxiAccent,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '첫 메시지를 남겨보세요',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '만남 장소나 택시 탑승 정보를\n참여자들과 미리 나눌 수 있어요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
