import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';
import 'package:hsro/features/shuttle/viewmodel/shuttle_viewmodel.dart';

// 즐겨찾는 경로의 순서·이름을 바꾸거나 삭제하는 편집 시트
Future<void> showFavoriteJourneyEditSheet({
  required BuildContext context,
  required ShuttleViewModel viewModel,
  required Color accentColor,
}) {
  Widget builder(BuildContext sheetContext) =>
      _FavoriteJourneyEditSheet(viewModel: viewModel, accentColor: accentColor);

  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<void>(context: context, builder: builder);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

class _FavoriteJourneyEditSheet extends StatefulWidget {
  final ShuttleViewModel viewModel;
  final Color accentColor;

  const _FavoriteJourneyEditSheet({
    required this.viewModel,
    required this.accentColor,
  });

  @override
  State<_FavoriteJourneyEditSheet> createState() =>
      _FavoriteJourneyEditSheetState();
}

class _FavoriteJourneyEditSheetState extends State<_FavoriteJourneyEditSheet> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String? _editingKey;
  bool _isClosing = false;

  ShuttleViewModel get viewModel => widget.viewModel;

  @override
  void dispose() {
    // 이름을 고치던 중 시트를 내려 닫아도 입력한 이름은 저장한다.
    _commitRename(updateState: false);
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startRename(FavoriteShuttleJourney favorite) {
    if (_editingKey == favorite.key) return;
    _commitRename();
    final customName = favorite.customName?.trim();
    final initialName = customName != null && customName.isNotEmpty
        ? customName
        : viewModel.favoriteDisplayName(favorite);
    _nameController.value = TextEditingValue(
      text: initialName,
      selection: TextSelection(baseOffset: 0, extentOffset: initialName.length),
    );
    setState(() => _editingKey = favorite.key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingKey == favorite.key) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  void _commitRename({bool updateState = true}) {
    final key = _editingKey;
    if (key == null) return;
    _editingKey = null;
    final favorite = viewModel.favoriteJourneys.firstWhereOrNull(
      (item) => item.key == key,
    );
    if (favorite != null) {
      viewModel.renameFavoriteJourney(favorite, _nameController.text);
    }
    if (updateState && mounted) {
      _nameFocusNode.unfocus();
      setState(() {});
    }
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    _commitRename();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Material(
      color: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.82),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '즐겨찾는 경로 편집',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _close,
                        style: TextButton.styleFrom(
                          foregroundColor: _accentForeground(context),
                          minimumSize: const Size(44, 44),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('완료'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '이름을 눌러 바꾸고, 오른쪽 손잡이를 끌어 순서를 바꿀 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                Flexible(
                  child: Obx(() {
                    final favorites = viewModel.validFavoriteJourneys;
                    if (favorites.isEmpty) {
                      // 마지막 경로까지 지우면 편집할 것이 없으니 시트를 닫는다.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _close();
                      });
                      return const SizedBox.shrink();
                    }
                    return ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: favorites.length,
                      onReorderStart: (_) => _commitRename(),
                      onReorderItem: viewModel.reorderFavoriteJourneys,
                      proxyDecorator: (child, _, __) => Material(
                        color: Colors.transparent,
                        elevation: 6,
                        borderRadius: BorderRadius.circular(16),
                        child: child,
                      ),
                      itemBuilder: (context, index) => _buildRow(
                        context,
                        favorite: favorites[index],
                        index: index,
                        canReorder: favorites.length > 1,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required FavoriteShuttleJourney favorite,
    required int index,
    required bool canReorder,
  }) {
    final isEditing = _editingKey == favorite.key;
    final displayName = viewModel.favoriteDisplayName(favorite);
    final routeLabel = viewModel.favoriteRouteLabel(favorite);
    final hasCustomName = displayName != routeLabel;
    final hintColor = Theme.of(context).hintColor;

    return Padding(
      key: ValueKey(favorite.key),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '삭제',
              onPressed: () {
                if (_editingKey == favorite.key) {
                  setState(() => _editingKey = null);
                }
                viewModel.removeFavoriteJourney(favorite);
              },
              icon: const Icon(Icons.remove_circle_rounded),
              color: Colors.red.shade600,
            ),
            Expanded(
              child: isEditing
                  ? TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      maxLength: 30,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: routeLabel,
                        helperText: routeLabel,
                        helperStyle: TextStyle(fontSize: 12, color: hintColor),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.accentColor.withValues(alpha: 0.45),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.accentColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _commitRename(),
                    )
                  : Semantics(
                      button: true,
                      label: '$displayName, 이름 변경',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => _startRename(favorite),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (hasCustomName) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        routeLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: hintColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: hintColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            if (isEditing)
              IconButton(
                tooltip: '이름 저장',
                onPressed: _commitRename,
                icon: Icon(Icons.check_rounded, color: widget.accentColor),
              )
            else if (canReorder)
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: '순서 변경',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.drag_handle_rounded, color: hintColor),
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Color _accentForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.redAccent
      : widget.accentColor;
}
