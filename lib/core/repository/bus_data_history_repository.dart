import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hsro/core/repository/app_config_repository.dart';

/// 변경이력 종류: 시간표 또는 노선(노선도·정류장)
enum BusDataHistoryKind {
  timetable('timetable'),
  route('static');

  const BusDataHistoryKind(this.apiValue);

  final String apiValue;
}

/// 앱에 적용된 시내버스 데이터 버전 한 건과 그때 바뀐 내용.
class BusDataHistoryItem {
  const BusDataHistoryItem({
    required this.version,
    required this.effectiveAt,
    this.note,
    this.changes,
  });

  final String version;

  /// UTC. 화면에는 버전 이름과 같은 한국 시간 날짜로 보여준다.
  final DateTime effectiveAt;

  DateTime get effectiveAtKst => effectiveAt.add(const Duration(hours: 9));

  /// 관리자가 배포할 때 쓴 한 줄 메모
  final String? note;

  /// 이전 버전과 비교한 자동 요약. 비교할 이전 버전이 없으면(최초 등록) null
  final List<String>? changes;

  static BusDataHistoryItem? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final version = json['version'];
    final effectiveAt = DateTime.tryParse(json['effective_at']?.toString() ?? '');
    if (version is! String || effectiveAt == null) return null;
    final note = json['note'];
    final changes = json['changes'];
    return BusDataHistoryItem(
      version: version,
      effectiveAt: effectiveAt.toUtc(),
      note: note is String && note.trim().isNotEmpty ? note : null,
      changes: changes is List ? changes.map((line) => line.toString()).toList() : null,
    );
  }
}

class BusDataHistoryRepository {
  BusDataHistoryRepository({http.Client? client, AppConfigRepository? appConfig})
      : _client = client ?? http.Client(),
        _appConfig = appConfig ?? AppConfigRepository.shared;

  static const String historyPath = '/api/bus-data/history';

  final http.Client _client;
  final AppConfigRepository _appConfig;

  /// 최신순 변경이력. 서버 오류나 연결 실패는 예외로 올려 화면이 다시 시도할 수 있게 한다.
  Future<List<BusDataHistoryItem>> fetch(BusDataHistoryKind kind) async {
    final url = _appConfig.resolveUrl('$historyPath?kind=${kind.apiValue}');
    final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw http.ClientException('변경이력 응답 ${response.statusCode}', Uri.parse(url));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const FormatException('변경이력 응답 형식이 올바르지 않습니다.');
    }
    return body.map(BusDataHistoryItem.tryParse).whereType<BusDataHistoryItem>().toList();
  }
}
