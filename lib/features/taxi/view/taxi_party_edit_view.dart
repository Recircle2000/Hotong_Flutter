import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_party_detail_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_departure_time_picker.dart';
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

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );

InputDecoration _inputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  IconData? icon,
  bool enabled = true,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon:
        enabled ? null : const Icon(Icons.lock_outline_rounded, size: 18),
    floatingLabelStyle: TextStyle(color: _taxiAccentText(context)),
    filled: true,
    fillColor: colors.onSurface.withValues(alpha: enabled ? 0.04 : 0.025),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _taxiAccent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.error, width: 1.5),
    ),
  );
}

class TaxiPartyEditView extends StatefulWidget {
  const TaxiPartyEditView({
    super.key,
    required this.party,
    required this.locations,
    required this.controller,
  });

  final TaxiPartyDetail party;
  final List<TaxiLocation> locations;
  final TaxiPartyDetailViewModel controller;

  @override
  State<TaxiPartyEditView> createState() => _TaxiPartyEditViewState();
}

class _TaxiPartyEditViewState extends State<TaxiPartyEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _departureSummary;
  late final TextEditingController _destinationSummary;
  late final TextEditingController _memberNote;
  late int _departureId;
  late int _destinationId;
  late int _maxMembers;
  late DateTime _departureAt;
  bool _saving = false;

  bool get _coreFieldsLocked => widget.party.currentMembers > 1;

  @override
  void initState() {
    super.initState();
    _departureSummary =
        TextEditingController(text: widget.party.departureSummary);
    _destinationSummary =
        TextEditingController(text: widget.party.destinationSummary);
    _memberNote = TextEditingController(text: widget.party.memberNote);
    _departureId = widget.party.departureLocation.id;
    _destinationId = widget.party.destinationLocation.id;
    _maxMembers = widget.party.maxMembers;
    _departureAt = widget.party.departureAt;
  }

  @override
  void dispose() {
    _departureSummary.dispose();
    _destinationSummary.dispose();
    _memberNote.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setDeparture(int? value) {
    if (value == null) return;
    if (value == _destinationId) {
      _showMessage('출발지와 도착지는 달라야 합니다.');
      return;
    }
    setState(() => _departureId = value);
  }

  void _setDestination(int? value) {
    if (value == null) return;
    if (value == _departureId) {
      _showMessage('출발지와 도착지는 달라야 합니다.');
      return;
    }
    setState(() => _destinationId = value);
  }

  void _swapLocations() {
    if (_coreFieldsLocked) return;
    setState(() {
      final departure = _departureId;
      _departureId = _destinationId;
      _destinationId = departure;
    });
  }

  Future<void> _pickDateTime() async {
    if (_coreFieldsLocked) return;
    final selected = await showTaxiDepartureTimePicker(
      context,
      initialDateTime: _departureAt,
    );
    if (selected == null || !mounted) return;
    setState(() => _departureAt = selected);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_departureId == _destinationId) {
      _showMessage('출발지와 도착지는 달라야 합니다.');
      return;
    }

    final departureChanged =
        !_departureAt.isAtSameMomentAs(widget.party.departureAt);
    if (!_coreFieldsLocked && departureChanged) {
      final departureError = validateTaxiDepartureTime(_departureAt);
      if (departureError != null) {
        _showMessage(departureError);
        return;
      }
    }

    setState(() => _saving = true);
    final success = await widget.controller.updateDetails(
      departureSummary: _departureSummary.text.trim(),
      destinationSummary: _destinationSummary.text.trim().isEmpty
          ? null
          : _destinationSummary.text.trim(),
      memberNote:
          _memberNote.text.trim().isEmpty ? null : _memberNote.text.trim(),
      departureLocationId: !_coreFieldsLocked &&
              _departureId != widget.party.departureLocation.id
          ? _departureId
          : null,
      destinationLocationId: !_coreFieldsLocked &&
              _destinationId != widget.party.destinationLocation.id
          ? _destinationId
          : null,
      departureAt: !_coreFieldsLocked && departureChanged ? _departureAt : null,
      maxMembers: !_coreFieldsLocked && _maxMembers != widget.party.maxMembers
          ? _maxMembers
          : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      _showMessage(widget.controller.errorMessage.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('택시팟 정보 수정'),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (_coreFieldsLocked) ...[
                const _LockedNotice(),
                const SizedBox(height: 16),
              ],
              _RouteAndScheduleCard(
                locations: widget.locations,
                departureId: _departureId,
                destinationId: _destinationId,
                departureAt: _departureAt,
                maxMembers: _maxMembers,
                locked: _coreFieldsLocked,
                onDepartureChanged: _setDeparture,
                onDestinationChanged: _setDestination,
                onSwap: _swapLocations,
                onPickDateTime: _pickDateTime,
                onMaxMembersChanged: (value) =>
                    setState(() => _maxMembers = value),
              ),
              const SizedBox(height: 16),
              _LocationDetailsCard(
                departureSummary: _departureSummary,
                destinationSummary: _destinationSummary,
              ),
              const SizedBox(height: 16),
              _MemberNoteCard(controller: _memberNote),
            ],
          ),
        ),
        bottomNavigationBar: _SaveDock(
          saving: _saving,
          onSave: _submit,
        ),
      ),
    );
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '일부 정보가 잠겨 있어요',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '참여자가 있어 거점, 출발 시각, 정원은 변경할 수 없습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _taxiTint(context),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: _taxiAccent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteAndScheduleCard extends StatelessWidget {
  const _RouteAndScheduleCard({
    required this.locations,
    required this.departureId,
    required this.destinationId,
    required this.departureAt,
    required this.maxMembers,
    required this.locked,
    required this.onDepartureChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    required this.onPickDateTime,
    required this.onMaxMembersChanged,
  });

  final List<TaxiLocation> locations;
  final int departureId;
  final int destinationId;
  final DateTime departureAt;
  final int maxMembers;
  final bool locked;
  final ValueChanged<int?> onDepartureChanged;
  final ValueChanged<int?> onDestinationChanged;
  final VoidCallback onSwap;
  final VoidCallback onPickDateTime;
  final ValueChanged<int> onMaxMembersChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.route_rounded,
            title: '경로와 일정',
            subtitle: '이동 경로와 출발 조건을 확인하세요.',
          ),
          const SizedBox(height: 22),
          _LocationDropdown(
            key: ValueKey('departure-$departureId-$locked'),
            label: '출발 거점',
            icon: Icons.trip_origin_rounded,
            value: departureId,
            locations: locations,
            enabled: !locked,
            onChanged: onDepartureChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: IconButton.filledTonal(
                    tooltip: '출발지와 도착지 바꾸기',
                    onPressed: locked ? null : onSwap,
                    style: IconButton.styleFrom(
                      backgroundColor: locked
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.04)
                          : _taxiTint(context),
                      foregroundColor: locked
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : _taxiAccentText(context),
                    ),
                    icon: Icon(
                      locked
                          ? Icons.lock_outline_rounded
                          : Icons.swap_vert_rounded,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          _LocationDropdown(
            key: ValueKey('destination-$destinationId-$locked'),
            label: '도착 거점',
            icon: Icons.location_on_outlined,
            value: destinationId,
            locations: locations,
            enabled: !locked,
            onChanged: onDestinationChanged,
          ),
          const SizedBox(height: 16),
          _ScheduleTile(
            departureAt: departureAt,
            locked: locked,
            onTap: onPickDateTime,
          ),
          const SizedBox(height: 20),
          Text(
            '총 인원',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            '방장인 나를 포함한 인원이에요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 13),
          IgnorePointer(
            ignoring: locked,
            child: Opacity(
              opacity: locked ? 0.55 : 1,
              child: Row(
                children: [
                  for (final count in const [2, 3, 4]) ...[
                    if (count > 2) const SizedBox(width: 10),
                    Expanded(
                      child: _MemberCountButton(
                        count: count,
                        selected: maxMembers == count,
                        onTap: () => onMaxMembersChanged(count),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.locations,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int value;
  final List<TaxiLocation> locations;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      borderRadius: BorderRadius.circular(16),
      dropdownColor: Theme.of(context).cardColor,
      decoration: _inputDecoration(
        context,
        label: label,
        icon: icon,
        enabled: enabled,
      ),
      items: locations
          .map(
            (location) => DropdownMenuItem<int>(
              value: location.id,
              child: Text(
                location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.departureAt,
    required this.locked,
    required this.onTap,
  });

  final DateTime departureAt;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: locked
          ? theme.colorScheme.onSurface.withValues(alpha: 0.035)
          : _taxiTint(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: locked
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
                      : _taxiAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : Icons.calendar_month_rounded,
                  color: locked
                      ? theme.colorScheme.onSurfaceVariant
                      : _taxiAccentForeground,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '출발 시각',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: locked
                            ? theme.colorScheme.onSurfaceVariant
                            : _taxiAccentText(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('M월 d일 (E) HH:mm', 'ko').format(departureAt),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!locked)
                Icon(
                  Icons.chevron_right_rounded,
                  color: _taxiAccentText(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCountButton extends StatelessWidget {
  const _MemberCountButton({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? _taxiTint(context, 0.18)
          : theme.colorScheme.onSurface.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? _taxiAccent
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: selected
                    ? _taxiAccentText(context)
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                '$count명',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? _taxiAccentText(context) : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationDetailsCard extends StatelessWidget {
  const _LocationDetailsCard({
    required this.departureSummary,
    required this.destinationSummary,
  });

  final TextEditingController departureSummary;
  final TextEditingController destinationSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.place_outlined,
            title: '상세 장소',
            subtitle: '서로 찾기 쉬운 정확한 위치를 적어주세요.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: departureSummary,
            maxLength: 80,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              context,
              label: '출발 장소',
              hint: '예: 정문 택시승강장',
              icon: Icons.my_location_rounded,
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '출발 장소를 입력해주세요.' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: destinationSummary,
            maxLength: 80,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              context,
              label: '도착 장소 (선택)',
              hint: '예: 3번 출구',
              icon: Icons.flag_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberNoteCard extends StatelessWidget {
  const _MemberNoteCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.chat_bubble_outline_rounded,
            title: '참여자 안내',
            subtitle: '참여한 사용자에게만 보이는 안내입니다.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: controller,
            maxLength: 500,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration(
              context,
              label: '상세 안내 (선택)',
              hint: '예: 검은색 우산을 들고 있을게요.',
              icon: Icons.edit_note_rounded,
            ).copyWith(alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }
}

class _SaveDock extends StatelessWidget {
  const _SaveDock({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: _taxiAccent,
                foregroundColor: _taxiAccentForeground,
                disabledBackgroundColor: _taxiAccent.withValues(alpha: 0.45),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: _taxiAccentForeground,
                        strokeWidth: 2.3,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(saving ? '저장 중' : '변경사항 저장'),
            ),
          ),
        ),
      ),
    );
  }
}
