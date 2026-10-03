import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/taxi/models/taxi_models.dart';
import 'package:intl/intl.dart';

class TaxiApiException implements Exception {
  const TaxiApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;
}

/// 동의받는 이용약관 버전. 서버의 TAXI_TERMS_VERSION과 맞춘다.
const taxiTermsVersion = 1;

class TaxiRepository {
  TaxiRepository({required http.Client client, String? baseUrl})
    : _client = client,
      _baseUrl = (baseUrl ?? EnvConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<List<TaxiLocation>> getLocations() async {
    final data = await _request('GET', '/api/taxi/locations') as List<dynamic>;
    return data
        .map((item) => TaxiLocation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaxiPartySummary>> getParties({
    required DateTime date,
    int? departureLocationId,
    int? destinationLocationId,
    bool includeUnavailable = false,
  }) async {
    final query = <String, String>{
      'date': DateFormat('yyyy-MM-dd').format(date),
      'include_unavailable': '$includeUnavailable',
    };
    if (departureLocationId != null) {
      query['departure_location_id'] = '$departureLocationId';
    }
    if (destinationLocationId != null) {
      query['destination_location_id'] = '$destinationLocationId';
    }
    final data =
        await _request('GET', '/api/taxi/parties', query: query)
            as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((item) => TaxiPartySummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 화면 진입·복귀 때 필요한 목록과 이용 제한을 요청 하나로 받는다.
  Future<TaxiHome> getHome({
    required DateTime date,
    int? departureLocationId,
    int? destinationLocationId,
    bool includeUnavailable = false,
    bool includeLocations = false,
    bool includeHistory = false,
  }) async {
    final include = [
      if (includeLocations) 'locations',
      if (includeHistory) 'history',
    ];
    final query = <String, String>{
      'date': DateFormat('yyyy-MM-dd').format(date),
      'include_unavailable': '$includeUnavailable',
      if (include.isNotEmpty) 'include': include.join(','),
    };
    if (departureLocationId != null) {
      query['departure_location_id'] = '$departureLocationId';
    }
    if (destinationLocationId != null) {
      query['destination_location_id'] = '$destinationLocationId';
    }
    return TaxiHome.fromJson(
      await _request('GET', '/api/taxi/home', query: query)
          as Map<String, dynamic>,
    );
  }

  Future<List<TaxiPartySummary>> getMyParties({String scope = 'active'}) async {
    final data =
        await _request('GET', '/api/taxi/my-parties', query: {'scope': scope})
            as List<dynamic>;
    return data
        .map((item) => TaxiPartySummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaxiPartyDetail> getParty(String id) async => TaxiPartyDetail.fromJson(
    await _request('GET', '/api/taxi/parties/$id') as Map<String, dynamic>,
  );

  Future<TaxiPartyDetail> createParty({
    required String clientRequestId,
    required int departureLocationId,
    required int destinationLocationId,
    required String departureSummary,
    String? destinationSummary,
    String? memberNote,
    required DateTime departureAt,
    required int maxMembers,
  }) async {
    final data = await _request(
      'POST',
      '/api/taxi/parties',
      body: {
        'client_request_id': clientRequestId,
        'departure_location_id': departureLocationId,
        'destination_location_id': destinationLocationId,
        'departure_summary': departureSummary,
        'destination_summary': destinationSummary,
        'member_note': memberNote,
        'departure_at': departureAt.toUtc().toIso8601String(),
        'max_members': maxMembers,
      },
    );
    return TaxiPartyDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<TaxiPartyDetail> joinParty(String id) async =>
      TaxiPartyDetail.fromJson(
        await _request('POST', '/api/taxi/parties/$id/join')
            as Map<String, dynamic>,
      );

  Future<TaxiPartyDetail> updateParty(
    String id, {
    required String departureSummary,
    String? destinationSummary,
    String? memberNote,
    int? departureLocationId,
    int? destinationLocationId,
    DateTime? departureAt,
    int? maxMembers,
  }) async {
    final body = <String, dynamic>{
      'departure_summary': departureSummary,
      'destination_summary': destinationSummary,
      'member_note': memberNote,
    };
    if (departureLocationId != null) {
      body['departure_location_id'] = departureLocationId;
    }
    if (destinationLocationId != null) {
      body['destination_location_id'] = destinationLocationId;
    }
    if (departureAt != null) {
      body['departure_at'] = departureAt.toUtc().toIso8601String();
    }
    if (maxMembers != null) {
      body['max_members'] = maxMembers;
    }
    return TaxiPartyDetail.fromJson(
      await _request('PATCH', '/api/taxi/parties/$id', body: body)
          as Map<String, dynamic>,
    );
  }

  Future<void> leaveParty(String id) =>
      _request('DELETE', '/api/taxi/parties/$id/members/me');

  Future<void> cancelParty(String id, {String? reason}) => _request(
    'POST',
    '/api/taxi/parties/$id/cancel',
    body: {'reason': reason},
  );

  Future<void> setRecruitment(String id, bool isOpen) => _request(
    'PUT',
    '/api/taxi/parties/$id/recruitment',
    body: {'is_open': isOpen},
  );

  Future<List<TaxiMessage>> getMessages(
    String partyId, {
    int? beforeId,
  }) async => (await getMessagePage(partyId, beforeId: beforeId)).items;

  /// 최근 메시지 한 쪽. [nextBeforeId]가 있으면 그 앞에 더 오래된 메시지가 남아 있다.
  Future<({List<TaxiMessage> items, int? nextBeforeId})> getMessagePage(
    String partyId, {
    int? beforeId,
  }) async {
    final data =
        await _request(
              'GET',
              '/api/taxi/parties/$partyId/messages',
              query: beforeId == null ? null : {'before_id': '$beforeId'},
            )
            as Map<String, dynamic>;
    return (
      items: (data['items'] as List<dynamic>)
          .map((item) => TaxiMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextBeforeId: data['next_before_id'] as int?,
    );
  }

  Future<void> markRead(String partyId, int lastMessageId) => _request(
    'PUT',
    '/api/taxi/parties/$partyId/messages/read',
    body: {'last_message_id': lastMessageId},
  );

  /// 신고 대상은 앱에 보이는 익명 라벨(방장 / 참여자 N)로 보낸다.
  Future<void> reportMember(
    String partyId, {
    required String targetLabel,
    required TaxiReportReason reason,
    String? detail,
    int? messageId,
  }) => _request(
    'POST',
    '/api/taxi/parties/$partyId/reports',
    body: {
      'target_label': targetLabel,
      'reason': reason.code,
      'detail': detail,
      'message_id': messageId,
    },
  );

  Future<TaxiRestriction> getRestriction() async => TaxiRestriction.fromJson(
    await _request('GET', '/api/taxi/me/restriction') as Map<String, dynamic>,
  );

  Future<void> acknowledgeSanction(int id) =>
      _request('POST', '/api/taxi/me/sanctions/$id/ack');

  /// 택시팟 이용약관에 동의한다.
  Future<void> agreeTerms() =>
      _request('PUT', '/api/taxi/me/terms', body: {'version': taxiTermsVersion});

  /// 같은 팟의 참여자를 익명 라벨로 차단한다. 상대에게는 알리지 않는다.
  Future<void> blockMember({
    required String partyId,
    required String targetLabel,
  }) => _request(
    'POST',
    '/api/taxi/parties/$partyId/blocks',
    body: {'target_label': targetLabel},
  );

  Future<List<TaxiBlock>> getBlocks() async {
    final data = await _request('GET', '/api/taxi/me/blocks') as List<dynamic>;
    return data
        .map((item) => TaxiBlock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> unblock(int id) => _request('DELETE', '/api/taxi/me/blocks/$id');

  /// 이 기기를 현재 계정의 알림 수신 기기로 등록한다.
  Future<void> registerPushToken(String token, {required String platform}) =>
      _request(
        'PUT',
        '/api/taxi/me/push-token',
        body: {'token': token, 'platform': platform},
      );

  Future<void> removePushToken(String token) =>
      _request('DELETE', '/api/taxi/me/push-token', body: {'token': token});

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    late http.Response response;
    switch (method) {
      case 'POST':
        response = await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        );
        break;
      case 'PUT':
        response = await _client.put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        );
        break;
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        );
        break;
      case 'DELETE':
        response = await _client.delete(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
        break;
      default:
        response = await _client.get(uri, headers: headers);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    String code = 'TAXI_API_ERROR';
    String message = '요청을 처리하지 못했습니다.';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = decoded['detail'];
      if (detail is Map<String, dynamic>) {
        code = detail['code'] as String? ?? code;
        message = detail['message'] as String? ?? message;
      } else if (detail is String) {
        message = detail;
      }
    } catch (_) {}
    throw TaxiApiException(response.statusCode, code, message);
  }

  void close() => _client.close();
}
