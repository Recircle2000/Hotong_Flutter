import 'package:flutter/material.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:hsro/features/taxi/repository/taxi_repository.dart';
import 'package:hsro/features/taxi/utils/taxi_departure_time.dart';
import 'package:hsro/features/taxi/utils/taxi_ids.dart';
import 'package:hsro/features/taxi/widgets/taxi_departure_time_picker.dart';
import 'package:intl/intl.dart';

class TaxiPartyCreateView extends StatefulWidget {
  const TaxiPartyCreateView(
      {super.key, required this.locations, required this.repository});
  final List<TaxiLocation> locations;
  final TaxiRepository repository;

  @override
  State<TaxiPartyCreateView> createState() => _TaxiPartyCreateViewState();
}

class _TaxiPartyCreateViewState extends State<TaxiPartyCreateView> {
  final formKey = GlobalKey<FormState>();
  final departureSummary = TextEditingController();
  final destinationSummary = TextEditingController();
  final memberNote = TextEditingController();
  int? departureId;
  int? destinationId;
  int maxMembers = 4;
  late DateTime departureAt;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    departureAt = normalizeTaxiDepartureInitial(
      DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  void dispose() {
    departureSummary.dispose();
    destinationSummary.dispose();
    memberNote.dispose();
    super.dispose();
  }

  Future<void> pickDateTime() async {
    final selected = await showTaxiDepartureTimePicker(
      context,
      initialDateTime: departureAt,
    );
    if (selected == null || !mounted) return;
    setState(() => departureAt = selected);
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() ||
        departureId == null ||
        destinationId == null) {
      return;
    }
    if (departureId == destinationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 도착지는 달라야 합니다.')),
      );
      return;
    }
    final departureError = validateTaxiDepartureTime(departureAt);
    if (departureError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(departureError)),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final party = await widget.repository.createParty(
        clientRequestId: newTaxiUuid(),
        departureLocationId: departureId!,
        destinationLocationId: destinationId!,
        departureSummary: departureSummary.text.trim(),
        destinationSummary: destinationSummary.text.trim().isEmpty
            ? null
            : destinationSummary.text.trim(),
        memberNote:
            memberNote.text.trim().isEmpty ? null : memberNote.text.trim(),
        departureAt: departureAt,
        maxMembers: maxMembers,
      );
      if (mounted) Navigator.of(context).pop(party);
    } on TaxiApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('택시팟 만들기')),
        body: Form(
          key: formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: '출발 거점', border: OutlineInputBorder()),
                initialValue: departureId,
                items: widget.locations
                    .map((e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (value) => setState(() => departureId = value),
                validator: (value) => value == null ? '출발 거점을 선택해주세요.' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: '도착 거점', border: OutlineInputBorder()),
                initialValue: destinationId,
                items: widget.locations
                    .map((e) =>
                        DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (value) => setState(() => destinationId = value),
                validator: (value) => value == null ? '도착 거점을 선택해주세요.' : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: departureSummary,
                maxLength: 80,
                decoration: const InputDecoration(
                    labelText: '출발 장소 요약',
                    hintText: '예: 정문 택시승강장',
                    border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '출발 장소를 입력해주세요.'
                    : null),
            TextFormField(
                controller: destinationSummary,
                maxLength: 80,
                decoration: const InputDecoration(
                    labelText: '도착 장소 요약 (선택)',
                    hintText: '예: 3번 출구',
                    border: OutlineInputBorder())),
            TextFormField(
                controller: memberNote,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: '참여자 전용 상세 안내 (선택)',
                    hintText: '참여한 사용자에게만 보여요.',
                    border: OutlineInputBorder())),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('출발 시각'),
                subtitle: Text(
                  '${DateFormat('M월 d일 HH:mm').format(departureAt)} · 10분 단위',
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: pickDateTime),
            DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: '총 인원', border: OutlineInputBorder()),
                initialValue: maxMembers,
                items: [2, 3, 4]
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text('$value명 (방장 포함)')))
                    .toList(),
                onChanged: (value) => setState(() => maxMembers = value ?? 4)),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('택시팟 만들기')),
          ]),
        ),
      );
}
