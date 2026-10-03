import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/utils/taxi_ids.dart';
import 'package:hsro/features/taxi/widgets/taxi_app_bar_leading.dart';
import 'package:hsro/features/taxi/widgets/taxi_departure_time_card.dart';
import 'package:hsro/features/taxi/widgets/taxi_location_field.dart';
import 'package:hsro/features/taxi/widgets/taxi_theme.dart';
import 'package:hsro/shared/widgets/scale_button.dart';
import 'package:intl/intl.dart';

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
  // 출발 장소가 비어 있으면 화면 아래에 가려진 입력창으로 스크롤한다.
  final _departureSummaryKey = GlobalKey();
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

  bool _validateDepartureDetails() {
    if (_departureSummary.text.trim().isEmpty) {
      // 입력창 아래 오류 문구가 보이도록 스크롤한다. 키보드를 띄우면 문구가 가려져 포커스는 주지 않는다.
      _detailsFormKey.currentState?.validate();
      unawaited(_revealDepartureSummary());
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

  Future<void> _revealDepartureSummary() async {
    // 2단계에서 돌아오는 경우 페이지 이동이 끝난 뒤에 스크롤한다.
    await WidgetsBinding.instance.endOfFrame;
    final fieldContext = _departureSummaryKey.currentContext;
    if (!mounted || fieldContext == null || !fieldContext.mounted) return;
    await Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _setDepartureDay(int dayOffset) {
    final now = DateTime.now();
    // 날짜만 바꾸고 시각은 유지하되, 오늘로 옮겨 이미 지난 시각이면 가장 빠른 시각으로 맞춘다.
    final moved = DateTime(
      now.year,
      now.month,
      now.day + dayOffset,
      _departureAt.hour,
      _departureAt.minute,
    );
    setState(() {
      _departureAt = normalizeTaxiDepartureInitial(moved, now: now);
    });
  }

  void _setDepartureTime(DateTime value) {
    setState(() => _departureAt = normalizeTaxiDepartureInitial(value));
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
    if (_currentStep != 0 && _departureSummary.text.trim().isEmpty) {
      await _goToStep(0);
    }
    if (!_validateDepartureDetails()) {
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
                leadingWidth: TaxiAppBarLeading.width,
                leading: TaxiAppBarLeading(
                  enabled: !_saving,
                  back: IconButton(
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
                      departureSummaryKey: _departureSummaryKey,
                      destinationSummary: _destinationSummary,
                      onDepartureDayChanged: _setDepartureDay,
                      onDepartureTimeChanged: _setDepartureTime,
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
  static const _titles = ['경로와 출발 정보', '모집 설정'];

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
                    right: index == _titles.length - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: index <= currentStep
                        ? taxiAccent
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
                '${currentStep + 1} / ${_titles.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: taxiAccentText(context),
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
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
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
    required this.departureSummaryKey,
    required this.destinationSummary,
    required this.onDepartureDayChanged,
    required this.onDepartureTimeChanged,
    required this.onQuickDeparture,
    required this.onSubmitted,
  });

  static const _quickOffsets = [
    (label: '지금', offset: Duration.zero),
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
  final GlobalKey departureSummaryKey;
  final TextEditingController destinationSummary;
  final ValueChanged<int> onDepartureDayChanged;
  final ValueChanged<DateTime> onDepartureTimeChanged;
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
              description: '같은 방향 사람들이 쉽게 찾을 수 있어요.',
            ),
            const SizedBox(height: 24),
            Container(
              decoration: taxiCardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '경로',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // 출발(빈 원) → 도착(채운 원) 표시
                      const _RouteMarker(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            TaxiLocationField(
                              key: ValueKey('departure-$departureId'),
                              label: '출발 거점',
                              value: departureId,
                              locations: locations,
                              onChanged: onDepartureChanged,
                            ),
                            const SizedBox(height: 8),
                            TaxiLocationField(
                              key: ValueKey('destination-$destinationId'),
                              label: '도착 거점',
                              value: destinationId,
                              locations: locations,
                              onChanged: onDestinationChanged,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        tooltip: '출발지와 도착지 바꾸기',
                        onPressed: onSwap,
                        style: IconButton.styleFrom(
                          fixedSize: const Size(46, 46),
                          foregroundColor: taxiAccentText(context),
                          side: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.swap_vert_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TaxiDepartureTimeCard(
              departureAt: departureAt,
              now: now,
              onDayChanged: onDepartureDayChanged,
              onTimeChanged: onDepartureTimeChanged,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final (index, quick) in _quickOffsets.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: TaxiQuickTimeChip(
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
                  const SizedBox(height: 12),
                  Text(
                    '오늘과 내일, 5분 단위로 고를 수 있어요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: taxiCardDecoration(context),
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
                  const SizedBox(height: 14),
                  TextFormField(
                    key: departureSummaryKey,
                    controller: departureSummary,
                    // 오류가 뜬 뒤 입력하면 바로 지운다.
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    decoration: _placeholderDecoration(context, '출발 장소'),
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
                    decoration: _placeholderDecoration(context, '도착 장소 (선택)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 라벨을 자리 표시 문구처럼 쓰고 글자 수 카운터는 숨긴 입력창 스타일.
  InputDecoration _placeholderDecoration(BuildContext context, String label) =>
      taxiInputDecoration(context, label: label).copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.never,
        counterText: '',
      );
}

/// 경로 카드 왼쪽의 출발(빈 원) → 도착(채운 원) 표시.
class _RouteMarker extends StatelessWidget {
  const _RouteMarker();

  @override
  Widget build(BuildContext context) {
    final color = taxiAccentText(context);
    return SizedBox(
      width: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
          ),
          for (var i = 0; i < 7; i++)
            Container(
              width: 2,
              height: 3,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: color.withValues(alpha: 0.45),
            ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
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
            decoration: taxiCardDecoration(context),
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
                      taxiInputDecoration(
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
          ? taxiTint(context, 0.18)
          : theme.colorScheme.onSurface.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? taxiAccent
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
                  color: selected ? taxiAccentText(context) : null,
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
        color: taxiTint(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: taxiAccent.withValues(alpha: 0.25)),
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
                    color: taxiAccentText(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: taxiAccentText(context),
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
        Icon(icon, size: 18, color: taxiAccentText(context)),
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
                          backgroundColor: taxiAccent,
                          foregroundColor: taxiAccentForeground,
                          disabledBackgroundColor: taxiAccent.withValues(
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
                                    taxiAccentForeground,
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
