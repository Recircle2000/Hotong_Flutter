import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_chat_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_app_bar_leading.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:intl/intl.dart';

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
  bool _didInitialScroll = false;
  int _lastMessageCount = 0;
  final _unseenCount = 0.obs;

  static const _nearBottomThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
    _tag = 'taxi-chat-${widget.party.id}-${identityHashCode(this)}';
    controller = Get.put(
      TaxiChatViewModel(
        partyId: widget.party.id,
        readOnlyAt: widget.party.chatWritableUntil,
        expiresAt: widget.party.chatVisibleUntil,
        initiallyReadOnly: widget.party.chatStatus != 'writable',
        initiallyExpired: widget.party.chatStatus == 'expired',
        repository: widget.repository,
        realtime: widget.realtime,
      ),
      tag: _tag,
    );
    _scrollController.addListener(_handleScroll);
    _messageWorker = ever(controller.messages, _handleMessagesChanged);
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < _nearBottomThreshold;
  }

  void _handleScroll() {
    if (_unseenCount.value > 0 && _isNearBottom) _unseenCount.value = 0;
  }

  void _handleMessagesChanged(List<TaxiMessage> messages) {
    final added = messages.length - _lastMessageCount;
    _lastMessageCount = messages.length;
    if (messages.isEmpty) {
      _didInitialScroll = false;
      _unseenCount.value = 0;
      return;
    }
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      _scrollToBottom(animate: false);
      return;
    }
    if (added <= 0) return;
    // 내가 보냈거나 이미 맨 아래를 보고 있을 때만 따라 내려가고,
    // 이전 대화를 읽는 중이면 위치를 유지한 채 새 메시지 개수만 알린다.
    if (messages.last.isMine || _isNearBottom) {
      _scrollToBottom();
    } else {
      _unseenCount.value += added;
    }
  }

  void _handleTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _scrollToBottom({bool animate = true}) {
    _unseenCount.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          ),
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _copyMessage(TaxiMessage message) {
    unawaited(Clipboard.setData(ClipboardData(text: message.content)));
    unawaited(HapticFeedback.selectionClick());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('메시지를 복사했어요.'),
          duration: Duration(seconds: 2),
        ),
      );
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
    _scrollController.removeListener(_handleScroll);
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
        leadingWidth: TaxiAppBarLeading.width,
        leading: const TaxiAppBarLeading(),
        title: Row(
          children: [
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
                      letterSpacing: widget.party.meetingCode == null
                          ? null
                          : 0.7,
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
            Obx(
              () => _ChatLifecycleNotice(
                readOnly: controller.isReadOnly.value,
                expired: controller.isExpired.value,
                writableUntil: controller.writableUntil.value,
                visibleUntil: controller.visibleUntil.value,
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: _buildMessages(),
              ),
            ),
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
      if (controller.isExpired.value) {
        return const Center(child: Text('보관 기간이 지나 삭제된 채팅입니다.'));
      }
      if (controller.isLoading.value && controller.messages.isEmpty) {
        return const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(taxiAccent),
          ),
        );
      }
      if (controller.messages.isEmpty) {
        return const _EmptyChat();
      }
      final messages = controller.messages;
      return Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final previous = index > 0 ? messages[index - 1] : null;
              final next = index + 1 < messages.length
                  ? messages[index + 1]
                  : null;
              final showDate =
                  previous == null ||
                  !_isSameDay(previous.createdAt, message.createdAt);
              return Column(
                children: [
                  if (showDate) _DateSeparator(date: message.createdAt),
                  _MessageBubble(
                    message: message,
                    isFirstInGroup:
                        showDate || !_isContinuation(previous, message),
                    isLastInGroup:
                        next == null || !_isContinuation(message, next),
                    onLongPress: () => _copyMessage(message),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: Obx(
                () => _unseenCount.value == 0
                    ? const SizedBox.shrink()
                    : _NewMessagesButton(
                        count: _unseenCount.value,
                        onTap: _scrollToBottom,
                      ),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// 같은 사람이 같은 분에 이어서 보낸 메시지는 하나의 묶음으로 보여준다.
  bool _isContinuation(TaxiMessage previous, TaxiMessage current) =>
      !previous.isSystem &&
      !current.isSystem &&
      previous.isMine == current.isMine &&
      previous.senderLabel == current.senderLabel &&
      _isSameDay(previous.createdAt, current.createdAt) &&
      previous.createdAt.hour == current.createdAt.hour &&
      previous.createdAt.minute == current.createdAt.minute;

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _ChatLifecycleNotice extends StatelessWidget {
  const _ChatLifecycleNotice({
    required this.readOnly,
    required this.expired,
    required this.writableUntil,
    required this.visibleUntil,
  });

  final bool readOnly;
  final bool expired;
  final DateTime writableUntil;
  final DateTime visibleUntil;

  @override
  Widget build(BuildContext context) {
    final text = expired
        ? '보관 기간이 지나 삭제된 채팅입니다.'
        : readOnly
        ? '대화가 종료됐어요. ${DateFormat('M월 d일 HH:mm').format(visibleUntil)}까지 기록을 볼 수 있어요.'
        : '${DateFormat('M월 d일 HH:mm').format(writableUntil)}까지 대화할 수 있어요.';
    return Container(
      width: double.infinity,
      color: taxiTint(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: taxiAccentText(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onLongPress,
  });

  final TaxiMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback onLongPress;

  static const _outerRadius = Radius.circular(19);
  static const _joinedRadius = Radius.circular(6);
  static const _tailRadius = Radius.circular(5);

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _SystemMessage(message: message);
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isMine = message.isMine;
    final time = Text(
      DateFormat('HH:mm').format(message.createdAt),
      style: theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
        fontSize: 10,
      ),
    );

    // 묶음 안쪽 모서리는 작게 깎아 풍선이 이어져 보이게 하고,
    // 마지막 풍선에만 꼬리 모서리를 남긴다.
    final senderSideTop = isFirstInGroup ? _outerRadius : _joinedRadius;
    final senderSideBottom = isLastInGroup ? _tailRadius : _joinedRadius;
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.68,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: isMine
              ? taxiAccent
              : colors.onSurface.withValues(alpha: 0.055),
          borderRadius: BorderRadius.only(
            topLeft: isMine ? _outerRadius : senderSideTop,
            topRight: isMine ? senderSideTop : _outerRadius,
            bottomLeft: isMine ? _outerRadius : senderSideBottom,
            bottomRight: isMine ? senderSideBottom : _outerRadius,
          ),
        ),
        child: Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMine ? taxiAccentForeground : colors.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );

    final bubbleRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isMine && isLastInGroup) ...[time, const SizedBox(width: 6)],
        Flexible(child: bubble),
        if (!isMine && isLastInGroup) ...[const SizedBox(width: 6), time],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLastInGroup ? 14 : 4),
      // 목록 항목 Column이 자식을 가운데 정렬하므로 폭을 채워야
      // 내 메시지는 오른쪽, 상대 메시지는 왼쪽 끝에 붙는다.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine && isFirstInGroup)
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
            bubbleRow,
          ],
        ),
      ),
    );
  }
}

class _NewMessagesButton extends StatelessWidget {
  const _NewMessagesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: taxiAccent,
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count > 99 ? '새 메시지 99+' : '새 메시지 $count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: taxiAccentForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: taxiAccentForeground,
              ),
            ],
          ),
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
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
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
                    color: taxiAccent.withValues(alpha: 0.65),
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
                  ? taxiAccent
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: '전송',
              onPressed: canSend ? onSend : null,
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: canSend
                    ? taxiAccentForeground
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
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
                color: taxiTint(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: taxiAccent,
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
