import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/viewmodel/taxi_party_detail_viewmodel.dart';
import 'package:hsro/features/taxi/widgets/taxi_departure_time_picker.dart';
import 'package:intl/intl.dart';

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

  Future<void> _pickDateTime() async {
    final selected = await showTaxiDepartureTimePicker(
      context,
      initialDateTime: _departureAt,
    );
    if (selected == null || !mounted) return;
    setState(() => _departureAt = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departureId == _destinationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 도착지는 달라야 합니다.')),
      );
      return;
    }
    setState(() => _saving = true);
    final departureChanged =
        !_departureAt.isAtSameMomentAs(widget.party.departureAt);
    if (!_coreFieldsLocked && departureChanged) {
      final departureError = validateTaxiDepartureTime(_departureAt);
      if (departureError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(departureError)),
        );
        return;
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage.value)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('택시팟 정보 수정')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_coreFieldsLocked)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '참여자가 있어 거점·출발 시각·정원은 변경할 수 없습니다.',
                  ),
                ),
              DropdownButtonFormField<int>(
                initialValue: _departureId,
                decoration: const InputDecoration(
                  labelText: '출발 거점',
                  border: OutlineInputBorder(),
                ),
                items: widget.locations
                    .map((location) => DropdownMenuItem(
                          value: location.id,
                          child: Text(location.name),
                        ))
                    .toList(),
                onChanged: _coreFieldsLocked
                    ? null
                    : (value) => setState(() => _departureId = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _destinationId,
                decoration: const InputDecoration(
                  labelText: '도착 거점',
                  border: OutlineInputBorder(),
                ),
                items: widget.locations
                    .map((location) => DropdownMenuItem(
                          value: location.id,
                          child: Text(location.name),
                        ))
                    .toList(),
                onChanged: _coreFieldsLocked
                    ? null
                    : (value) => setState(() => _destinationId = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departureSummary,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '출발 장소 요약',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '출발 장소를 입력해주세요.'
                    : null,
              ),
              TextFormField(
                controller: _destinationSummary,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '도착 장소 요약 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              TextFormField(
                controller: _memberNote,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '참여자 전용 상세 안내 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              ListTile(
                enabled: !_coreFieldsLocked,
                contentPadding: EdgeInsets.zero,
                title: const Text('출발 시각'),
                subtitle: Text(
                  '${DateFormat('M월 d일 HH:mm').format(_departureAt)} · 10분 단위',
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: _coreFieldsLocked ? null : _pickDateTime,
              ),
              DropdownButtonFormField<int>(
                initialValue: _maxMembers,
                decoration: const InputDecoration(
                  labelText: '총 인원',
                  border: OutlineInputBorder(),
                ),
                items: [2, 3, 4]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value명 (방장 포함)'),
                        ))
                    .toList(),
                onChanged: _coreFieldsLocked
                    ? null
                    : (value) => setState(() => _maxMembers = value!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ],
          ),
        ),
      );
}
