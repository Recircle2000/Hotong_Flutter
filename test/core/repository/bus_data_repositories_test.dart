import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hsro/core/repository/app_config_repository.dart';
import 'package:hsro/core/repository/bus_static_data_repository.dart';
import 'package:hsro/core/repository/bus_times_repository.dart';

const _baseUrl = 'http://test';

const _fullConfig = {
  'taxi_enabled': true,
  'bus_data': {
    'timetable': {
      'version': '2026.11.04',
      'download_url': '/bus-timetable',
      'effective_from': null,
      'sha256': null,
    },
    'static': {
      'version': '2026.09.14',
      'download_url': 'https://storage.test/bus-data/bus-static/2026.09.14.json',
      'effective_from': '2026-09-13T15:42:00Z',
      'sha256': 'abc',
    },
  },
};

http.Response _json(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      // Storage처럼 charset 없이 내려와도 한글을 읽어야 한다.
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('AppConfigRepository', () {
    test('버스 데이터 버전을 읽고 상대 경로를 서버 주소로 바꾼다', () async {
      final repository = AppConfigRepository(
        client: MockClient((request) async => _json(_fullConfig)),
        baseUrl: '$_baseUrl/',
      );
      final config = await repository.fetch();

      expect(config?.taxiEnabled, isTrue);
      expect(config?.busTimetable?.version, '2026.11.04');
      expect(
        repository.resolveUrl(config!.busTimetable!.downloadUrl),
        '$_baseUrl/bus-timetable',
      );
      expect(config.busStatic?.effectiveFrom, DateTime.utc(2026, 9, 13, 15, 42));
      expect(
        repository.resolveUrl(config.busStatic!.downloadUrl),
        startsWith('https://storage.test/'),
      );
    });

    test('구버전 서버 응답(bus_data 없음)도 받는다', () async {
      final repository = AppConfigRepository(
        client: MockClient((request) async => _json({'taxi_enabled': false})),
        baseUrl: _baseUrl,
      );
      final config = await repository.fetch();
      expect(config?.taxiEnabled, isFalse);
      expect(config?.busTimetable, isNull);
      expect(config?.busStatic, isNull);
    });

    test('동시에 들어온 요청은 한 번만 보낸다', () async {
      var calls = 0;
      final repository = AppConfigRepository(
        client: MockClient((request) async {
          calls++;
          return _json(_fullConfig);
        }),
        baseUrl: _baseUrl,
      );
      await Future.wait([repository.fetch(), repository.fetch()]);
      await repository.fetch();
      expect(calls, 1);
    });

    test('실패하면 null을 돌려주고 다음 호출에서 다시 시도한다', () async {
      var calls = 0;
      final repository = AppConfigRepository(
        client: MockClient((request) async {
          calls++;
          return http.Response('error', 500);
        }),
        baseUrl: _baseUrl,
      );
      expect(await repository.fetch(), isNull);
      expect(await repository.fetch(), isNull);
      expect(calls, 2);
    });
  });

  group('BusTimesRepository', () {
    test('app-config의 시간표 버전과 서버 주소를 쓴다', () async {
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/api/app-config':
            return _json(_fullConfig);
          case '/bus-timetable':
            return _json({
              'version': '2026.11.04',
              '810_UP': {'출발지': '아산터미널', '종점': '호서대', '시간표': ['07:10']},
            });
        }
        fail('예상하지 못한 요청: ${request.url}');
      });
      final repository = BusTimesRepository(
        client: client,
        appConfig: AppConfigRepository(client: client, baseUrl: _baseUrl),
      );

      final remote = await repository.fetchRemoteInfo();
      expect(remote?.version, '2026.11.04');
      expect(remote?.downloadUrl, '$_baseUrl/bus-timetable');

      final body = await repository.downloadBusTimesJson(remote!.downloadUrl);
      expect(jsonDecode(body!)['810_UP']['출발지'], '아산터미널');
    });

    test('app-config에 시간표가 없으면 예전 버전 API와 깃허브 주소를 쓴다', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.path == '/api/app-config') {
          return _json({'taxi_enabled': true});
        }
        return _json({'version': '2026.11.01'});
      });
      final repository = BusTimesRepository(
        client: client,
        appConfig: AppConfigRepository(client: client, baseUrl: _baseUrl),
      );

      final remote = await repository.fetchRemoteInfo();
      expect(remote?.version, '2026.11.01');
      expect(remote?.downloadUrl, BusTimesRepository.legacyDownloadUrl);
      expect(requested.last, '/bus-timetable/version');
    });
  });

  group('BusStaticDataRepository', () {
    test('app-config의 노선도 정보로 매니페스트를 만든다', () async {
      final client = MockClient((request) async => _json(_fullConfig));
      final repository = BusStaticDataRepository(
        client: client,
        appConfig: AppConfigRepository(client: client, baseUrl: _baseUrl),
      );
      final manifest = await repository.fetchRemoteManifest();
      expect(manifest?.version, '2026.09.14');
      expect(manifest?.downloadUrl, endsWith('/bus-static/2026.09.14.json'));
      expect(manifest?.effectiveFrom, DateTime.utc(2026, 9, 13, 15, 42));
    });

    test('app-config에 노선도가 없으면 깃허브 매니페스트를 읽는다', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/app-config') {
          return _json({'taxi_enabled': true});
        }
        expect(request.url.toString(), BusStaticDataRepository.manifestUrl);
        return _json({'version': '2026.09.14'});
      });
      final repository = BusStaticDataRepository(
        client: client,
        appConfig: AppConfigRepository(client: client, baseUrl: _baseUrl),
      );
      final manifest = await repository.fetchRemoteManifest();
      expect(manifest?.downloadUrl, BusStaticDataRepository.defaultDownloadUrl);
    });

    test('charset 없는 노선도 파일도 한글을 그대로 읽는다', () async {
      final client = MockClient(
        (request) async => _json({'version': '1', 'stops': {'810_UP': '호서대학교'}}),
      );
      final repository = BusStaticDataRepository(client: client);
      final body = await repository.downloadBusStaticData('https://storage.test/x.json');
      expect(body, contains('호서대학교'));
    });
  });
}
