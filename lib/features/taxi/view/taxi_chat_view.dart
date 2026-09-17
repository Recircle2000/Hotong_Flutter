import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/services/taxi_realtime_service.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_chat_viewmodel.dart';
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

  @override
  void initState() {
    super.initState();
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
    _textController.dispose();
    _scrollController.dispose();
    Get.delete<TaxiChatViewModel>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.party.departureLocation.name} → ${widget.party.destinationLocation.name}',
              ),
              if (widget.party.meetingCode != null)
                Text(
                  '팟 ${widget.party.meetingCode}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Obx(() => controller.isReadOnly.value
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Text('종료된 택시팟의 채팅은 읽기만 가능합니다.',
                        textAlign: TextAlign.center),
                  )
                : const SizedBox.shrink()),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.messages.isEmpty) {
                  return const Center(child: Text('첫 메시지를 남겨보세요.'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: controller.messages[index]),
                );
              }),
            ),
            Obx(() => controller.errorMessage.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(controller.errorMessage.value,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  )),
            Obx(() => controller.isReadOnly.value
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 500,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                hintText: '메시지 입력',
                                counterText: '',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                              onPressed: _send,
                              icon: const Icon(Icons.send_rounded),
                              tooltip: '전송'),
                        ]),
                  )),
          ]),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final TaxiMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(message.content,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: message.isMine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!message.isMine)
            Text(message.senderLabel ?? '익명',
                style: Theme.of(context).textTheme.labelMedium),
          Text(message.content),
          const SizedBox(height: 3),
          Text(DateFormat('HH:mm').format(message.createdAt),
              style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}
