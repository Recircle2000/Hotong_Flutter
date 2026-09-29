import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/utils/taxi_ids.dart';
import 'package:hsro/features/taxi/widgets/taxi_departure_time_picker.dart';
import 'package:hsro/shared/widgets/ios_platform_fields.dart';
import 'package:hsro/shared/widgets/scale_button.dart';
import 'package:intl/intl.dart';

const _taxiAccent = Color(0xFFF5A623);
const _taxiAccentForeground = Color(0xFF30210A);

Color _taxiTint(BuildContext context, [double? alpha]) =>
    _taxiAccent.withValues(
      alpha:
          alpha ??
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
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelStyle: TextStyle(color: _taxiAccentText(context)),
    filled: true,
    fillColor: colors.onSurface.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

/// 10분 단위로 올림된 출발 시각이 지금부터 실제로 얼마 뒤인지 알려준다.
String _relativeDepartureLabel(DateTime departureAt, DateTime now) {
  final seconds = departureAt.difference(now).inSeconds;
  if (seconds <= 0) return '출발 시각이 지났어요';
  final minutes = (seconds / 60).ceil();
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final text = hours == 0
      ? '$minutes분'
      : rest == 0
      ? '$hours시간'
      : '$hours시간 $rest분';
  return '지금부터 $text 후 출발';
}

class TaxiPartyCreateView extends StatefulWidget {
  const TaxiPartyCreateView({
    super.key,
    required this.locations,
    required this.repository,
    this.embedded = false,
    this.onCreated,
    this.onBusyChanged,
    this.onStepChanged,
    this.canSubmit,
    this.onConflict,
  });

  final List<TaxiLocation> locations;
  final TaxiRepository repository;
  final bool embedded;
  final Future<void> Function(TaxiPartyDetail)? onCreated;
  final ValueChanged<bool>? onBusyChanged;
  final VoidCallback? onStepChanged;
  final Future<bool> Function()? canSubmit;
  final Future<void> Function()? onConflict;

  @override
  State<TaxiPartyCreateView> createState() => TaxiPartyCreateViewState();
}

class TaxiPartyCreateViewState extends State<TaxiPartyCreateView> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _departureSummary = TextEditingController();
  final _destinationSummary = TextEditingController();
  final _memberNote = TextEditingController();

  int _currentStep = 0;
  bool get canGoBack => _currentStep > 0;
  void previousStep() {
    if (!_saving && canGoBack) unawaited(_goToStep(_currentStep - 1));
  }

  int? _departureId;
  int? _destinationId;
  int _maxMembers = 4;
  late DateTime _departureAt;
  // 출발까지 남은 시간 문구가 실제 시간과 어긋나지 않도록 주기적으로 다시 그린다.
  Timer? _clockTimer;
  bool _saving = false;

  TaxiLocation? get _departureLocation => _locationForId(_departureId);
  TaxiLocation? get _destinationLocation => _locationForId(_destinationId);

  TaxiLocation? _locationForId(int? id) {
    if (id == null) return null;
    for (final location in widget.locations) {
      if (location.id == id) return location;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _departureAt = normalizeTaxiDepartureInitial(
      DateTime.now().add(const Duration(minutes: 20)),
    );
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
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

  bool _validateRoute() {
    if (_departureId == null || _destinationId == null) {
      _showMessage('출발지와 도착지를 모두 선택해주세요.');
      return false;
    }
    if (_departureId == _destinationId) {
      _showMessage('출발지와 도착지는 달라야 합니다.');
      return false;
    }
    return true;
  }

  bool _validateDepartureDetails({bool showMissingMessage = false}) {
    if (_departureSummary.text.trim().isEmpty) {
      _detailsFormKey.currentState?.validate();
      if (showMissingMessage) {
        _showMessage('출발 장소를 입력해주세요.');
      }
      return false;
    }
    final formState = _detailsFormKey.currentState;
    if (formState != null && !formState.validate()) return false;
    final error = validateTaxiDepartureTime(_departureAt);
    if (error != null) {
      _showMessage(error);
      return false;
    }
    return true;
  }

  Future<void> _pickDateTime() async {
    final selected = await showTaxiDepartureTimePicker(
      context,
      initialDateTime: _departureAt,
    );
    if (selected == null || !mounted) return;
    setState(() => _departureAt = selected);
  }

  void _setDepartureAfter(Duration offset) {
    setState(() {
      _departureAt = normalizeTaxiDepartureInitial(DateTime.now().add(offset));
    });
  }

  void _setDeparture(int? value) {
    setState(() {
      _departureId = value;
      if (_destinationId == value) _destinationId = null;
    });
  }

  void _setDestination(int? value) {
    setState(() {
      _destinationId = value;
      if (_departureId == value) _departureId = null;
    });
  }

  void _swapLocations() {
    setState(() {
      final departure = _departureId;
      _departureId = _destinationId;
      _destinationId = departure;
    });
  }

  Future<void> _goToStep(int step) async {
    if (step < 0 || step > 1 || step == _currentStep) return;
    setState(() => _currentStep = step);
    widget.onStepChanged?.call();
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _next() async {
    _dismissKeyboard();
    final valid = switch (_currentStep) {
      0 => _validateRoute() && _validateDepartureDetails(),
      _ => true,
    };
    if (valid) await _goToStep(_currentStep + 1);
  }

  Future<void> _submit() async {
    _dismissKeyboard();
    if (_saving) return;
    if (!_validateRoute()) {
      if (_currentStep != 0) unawaited(_goToStep(0));
      return;
    }
    if (!_validateDepartureDetails(showMissingMessage: true)) {
      if (_currentStep != 0) unawaited(_goToStep(0));
      return;
    }
    setState(() => _saving = true);
    widget.onBusyChanged?.call(true);
    try {
      if (widget.canSubmit != null && !await widget.canSubmit!()) return;
      final party = await widget.repository.createParty(
        clientRequestId: newTaxiUuid(),
        departureLocationId: _departureId!,
        destinationLocationId: _destinationId!,
        departureSummary: _departureSummary.text.trim(),
        destinationSummary: _destinationSummary.text.trim().isEmpty
            ? null
            : _destinationSummary.text.trim(),
        memberNote: _memberNote.text.trim().isEmpty
            ? null
            : _memberNote.text.trim(),
        departureAt: _departureAt,
        maxMembers: _maxMembers,
      );
      if (!mounted) return;
      if (widget.onCreated != null) {
        await widget.onCreated!(party);
      } else {
        Navigator.of(context).pop(party);
      }
    } on TaxiApiException catch (error) {
      if (error.code == 'ACTIVE_PARTY_EXISTS') await widget.onConflict?.call();
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('택시팟을 만들지 못했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.embedded || (_currentStep == 0 && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!widget.embedded && !didPop && _currentStep > 0 && !_saving) {
          _goToStep(_currentStep - 1);
        }
      },
      child: Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                centerTitle: true,
                title: const Text('택시팟 만들기'),
                leading: IconButton(
                  tooltip: _currentStep == 0 ? '닫기' : '이전 단계',
                  onPressed: _saving
                      ? null
                      : () {
                          if (_currentStep == 0) {
                            Navigator.of(context).pop();
                          } else {
                            _goToStep(_currentStep - 1);
                          }
                        },
                  icon: Icon(
                    _currentStep == 0
                        ? Icons.close_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    size: 21,
                  ),
                ),
              ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: Column(
            children: [
              _StepProgress(currentStep: _currentStep),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _RouteStep(
                      formKey: _detailsFormKey,
                      locations: widget.locations,
                      departureId: _departureId,
                      destinationId: _destinationId,
                      onDepartureChanged: _setDeparture,
                      onDestinationChanged: _setDestination,
                      onSwap: _swapLocations,
                      departureAt: _departureAt,
                      departureSummary: _departureSummary,
                      destinationSummary: _destinationSummary,
                      onPickDateTime: _pickDateTime,
                      onQuickDeparture: _setDepartureAfter,
                      onSubmitted: _next,
                    ),
                    _PartyOptionsStep(
                      departure: _departureLocation,
                      destination: _destinationLocation,
                      departureSummary: _departureSummary.text.trim(),
                      destinationSummary: _destinationSummary.text.trim(),
                      departureAt: _departureAt,
                      maxMembers: _maxMembers,
                      memberNote: _memberNote,
                      onMaxMembersChanged: (value) =>
                          setState(() => _maxMembers = value),
                      onEditRoute: _saving ? null : () => _goToStep(0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomActions(
          isLastStep: _currentStep == 1,
          saving: _saving,
          onNext: _currentStep == 1 ? _submit : _next,
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep});

  final int currentStep;
  static const _titles = ['경로 · 출발 정보', '모집 설정'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_titles.length, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index == _titles.length - 1 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: index <= currentStep
                        ? _taxiAccent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${currentStep + 1}/${_titles.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _taxiAccentText(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _titles[currentStep],
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({
    required this.formKey,
    required this.locations,
    required this.departureId,
    required this.destinationId,
    required this.onDepartureChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    required this.departureAt,
    required this.departureSummary,
    required this.destinationSummary,
    required this.onPickDateTime,
    required this.onQuickDeparture,
    required this.onSubmitted,
  });

  static const _quickOffsets = [
    (label: '20분 후', offset: Duration(minutes: 20)),
    (label: '30분 후', offset: Duration(minutes: 30)),
    (label: '1시간 후', offset: Duration(hours: 1)),
  ];

  final GlobalKey<FormState> formKey;
  final List<TaxiLocation> locations;
  final int? departureId;
  final int? destinationId;
  final ValueChanged<int?> onDepartureChanged;
  final ValueChanged<int?> onDestinationChanged;
  final VoidCallback onSwap;
  final DateTime departureAt;
  final TextEditingController departureSummary;
  final TextEditingController destinationSummary;
  final VoidCallback onPickDateTime;
  final ValueChanged<Duration> onQuickDeparture;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepIntro(
              title: '어디로, 언제 출발하나요?',
              description: '경로와 만날 장소를 알려주면 같은 방향 사람들이 쉽게 찾을 수 있어요.',
            ),
            const SizedBox(height: 28),
            Container(
              decoration: _cardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _LocationDropdown(
                    key: ValueKey('departure-$departureId'),
                    label: '출발 거점',
                    value: departureId,
                    locations: locations,
                    onChanged: onDepartureChanged,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: IconButton.filledTonal(
                            tooltip: '출발지와 도착지 바꾸기',
                            onPressed: onSwap,
                            style: IconButton.styleFrom(
                              backgroundColor: _taxiTint(context),
                              foregroundColor: _taxiAccentText(context),
                            ),
                            icon: const Icon(Icons.swap_vert_rounded),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  _LocationDropdown(
                    key: ValueKey('destination-$destinationId'),
                    label: '도착 거점',
                    value: destinationId,
                    locations: locations,
                    onChanged: onDestinationChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: _taxiTint(context),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onPickDateTime,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '출발 시각',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _taxiAccentText(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'M월 d일 (E) HH:mm',
                                'ko',
                              ).format(departureAt),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _relativeDepartureLabel(departureAt, now),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _taxiAccentText(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _taxiAccentText(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (index, quick) in _quickOffsets.indexed) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _QuickTimeChip(
                      label: quick.label,
                      selected:
                          departureAt ==
                          normalizeTaxiDepartureInitial(
                            now.add(quick.offset),
                            now: now,
                          ),
                      onTap: () => onQuickDeparture(quick.offset),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: _cardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '만남 장소',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '거점 안에서 정확히 만날 위치를 적어주세요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: departureSummary,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      context,
                      label: '출발 장소',
                      hint: '예: 정문 택시승강장',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '출발 장소를 입력해주세요.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: destinationSummary,
                    maxLength: 80,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => onSubmitted(),
                    decoration: _inputDecoration(
                      context,
                      label: '도착 장소 (선택)',
                      hint: '예: 3번 출구',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _InfoNotice(
              icon: Icons.schedule_outlined,
              text: '출발 시각은 오늘 또는 내일, 10분 단위로 선택할 수 있어요.',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTimeChip extends StatelessWidget {
  const _QuickTimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? _taxiAccent
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? _taxiAccentText(context) : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.locations,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<TaxiLocation> locations;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _buildIOS(context);
    }
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      borderRadius: BorderRadius.circular(16),
      dropdownColor: Theme.of(context).cardColor,
      decoration: _inputDecoration(context, label: label),
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
      onChanged: onChanged,
    );
  }

  /// iOS는 필드 모양은 유지하고 네이티브 메뉴로 거점을 고른다.
  Widget _buildIOS(BuildContext context) {
    final selected = locations.where((l) => l.id == value).firstOrNull;
    return Stack(
      children: [
        InputDecorator(
          decoration: _inputDecoration(
            context,
            label: label,
          ).copyWith(suffixIcon: const Icon(Icons.expand_more_rounded)),
          isEmpty: selected == null,
          child: Text(
            selected?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Positioned.fill(
          child: IOSPopupMenuOverlay(
            options: [
              for (final location in locations)
                IOSPopupMenuOption(id: location.id, title: location.name),
            ],
            selectedId: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PartyOptionsStep extends StatelessWidget {
  const _PartyOptionsStep({
    required this.departure,
    required this.destination,
    required this.departureSummary,
    required this.destinationSummary,
    required this.departureAt,
    required this.maxMembers,
    required this.memberNote,
    required this.onMaxMembersChanged,
    required this.onEditRoute,
  });

  final TaxiLocation? departure;
  final TaxiLocation? destination;
  final String departureSummary;
  final String destinationSummary;
  final DateTime departureAt;
  final int maxMembers;
  final TextEditingController memberNote;
  final ValueChanged<int> onMaxMembersChanged;
  final VoidCallback? onEditRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepIntro(
            title: '몇 명을 모집할까요?',
            description: '방장을 포함한 총 인원과 참여자에게 보여줄 안내를 설정하세요.',
          ),
          const SizedBox(height: 28),
          Container(
            decoration: _cardDecoration(context),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '총 인원',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '방장인 나를 포함한 인원이에요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final count in const [2, 3, 4]) ...[
                      if (count > 2) const SizedBox(width: 10),
                      Expanded(
                        child: _MemberCountButton(
                          count: count,
                          selected: count == maxMembers,
                          onTap: () => onMaxMembersChanged(count),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: memberNote,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration:
                      _inputDecoration(
                        context,
                        label: '참여자 안내 (선택)',
                        hint: '예: 검은색 우산을 들고 있을게요.',
                      ).copyWith(
                        alignLabelWithHint: true,
                        helperText: '택시팟에 참여한 사용자에게만 보여요.',
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CreationSummary(
            departure: departure,
            destination: destination,
            departureSummary: departureSummary,
            destinationSummary: destinationSummary,
            departureAt: departureAt,
            maxMembers: maxMembers,
            onEdit: onEditRoute,
          ),
          const SizedBox(height: 18),
          const _InfoNotice(
            icon: Icons.info_outline_rounded,
            text: '방을 만든 뒤에도 참여자가 없다면 경로와 시간을 수정할 수 있어요.',
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                '$count명',
                style: theme.textTheme.titleSmall?.copyWith(
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

class _CreationSummary extends StatelessWidget {
  const _CreationSummary({
    required this.departure,
    required this.destination,
    required this.departureSummary,
    required this.destinationSummary,
    required this.departureAt,
    required this.maxMembers,
    required this.onEdit,
  });

  final TaxiLocation? departure;
  final TaxiLocation? destination;
  final String departureSummary;
  final String destinationSummary;
  final DateTime departureAt;
  final int maxMembers;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meetingPlace = destinationSummary.isEmpty
        ? '$departureSummary에서 만나요'
        : '$departureSummary 출발 · $destinationSummary 도착';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _taxiTint(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _taxiAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '만들 방 미리보기',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _taxiAccentText(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: _taxiAccentText(context),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('수정'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            icon: Icons.route_rounded,
            text: '${departure?.name ?? '-'} → ${destination?.name ?? '-'}',
          ),
          const SizedBox(height: 10),
          _SummaryLine(icon: Icons.place_outlined, text: meetingPlace),
          const SizedBox(height: 10),
          _SummaryLine(
            icon: Icons.schedule_rounded,
            text: DateFormat('M월 d일 (E) HH:mm', 'ko').format(departureAt),
          ),
          const SizedBox(height: 10),
          _SummaryLine(
            icon: Icons.people_outline_rounded,
            text: '나 포함 1/$maxMembers명',
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _taxiAccentText(context)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isLastStep,
    required this.saving,
    required this.onNext,
  });

  final bool isLastStep;
  final bool saving;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: ScaleButton(
                  onTap: saving ? null : onNext,
                  child: AbsorbPointer(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: saving ? null : onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: _taxiAccent,
                          foregroundColor: _taxiAccentForeground,
                          disabledBackgroundColor: _taxiAccent.withValues(
                            alpha: 0.45,
                          ),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: saving
                            ? const SizedBox.square(
                                dimension: 21,
                                child: CircularProgressIndicator.adaptive(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _taxiAccentForeground,
                                  ),
                                  strokeWidth: 2.3,
                                ),
                              )
                            : Text(isLastStep ? '택시팟 만들기' : '다음'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
