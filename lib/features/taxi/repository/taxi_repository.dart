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

class TaxiRepository {
  TaxiRepository({required http.Client client, String? baseUrl})
      : _client = client,
        _baseUrl =
            (baseUrl ?? EnvConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');

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
    final data = await _request('GET', '/api/taxi/parties', query: query)
        as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((item) => TaxiPartySummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaxiPartySummary>> getMyParties({bool history = false}) async {
    final data = await _request('GET', '/api/taxi/my-parties', query: {
      'scope': history ? 'history' : 'active',
    }) as List<dynamic>;
    return data
        .map((item) => TaxiPartySummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaxiPartyDetail> getParty(String id) async => TaxiPartyDetail.fromJson(
      await _request('GET', '/api/taxi/parties/$id') as Map<String, dynamic>);

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
    final data = await _request('POST', '/api/taxi/parties', body: {
      'client_request_id': clientRequestId,
      'departure_location_id': departureLocationId,
      'destination_location_id': destinationLocationId,
      'departure_summary': departureSummary,
      'destination_summary': destinationSummary,
      'member_note': memberNote,
      'departure_at': departureAt.toUtc().toIso8601String(),
      'max_members': maxMembers,
    });
    return TaxiPartyDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<TaxiPartyDetail> joinParty(String id) async =>
      TaxiPartyDetail.fromJson(
          await _request('POST', '/api/taxi/parties/$id/join')
              as Map<String, dynamic>);

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

  Future<void> cancelParty(String id, {String? reason}) =>
      _request('POST', '/api/taxi/parties/$id/cancel',
          body: {'reason': reason});

  Future<void> setRecruitment(String id, bool isOpen) =>
      _request('PUT', '/api/taxi/parties/$id/recruitment',
          body: {'is_open': isOpen});

  Future<List<TaxiMessage>> getMessages(String partyId, {int? beforeId}) async {
    final data = await _request('GET', '/api/taxi/parties/$partyId/messages',
            query: beforeId == null ? null : {'before_id': '$beforeId'})
        as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((item) => TaxiMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String partyId, int lastMessageId) => _request(
        'PUT',
        '/api/taxi/parties/$partyId/messages/read',
        body: {'last_message_id': lastMessageId},
      );

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
        response =
            await _client.post(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'PUT':
        response =
            await _client.put(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'PATCH':
        response =
            await _client.patch(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
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
