import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/core/repository/bus_static_data_repository.dart';
import 'package:hsro/core/utils/bus_static_data_loader.dart';

void main() {
  group('BusStaticDataLoader', () {
    test('downloads newer remote data and uses it for routes and stops',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('bus_static_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final remote = _FakeRemoteSource(
        manifest: const BusStaticDataManifest(
          version: '2026.05.21',
          downloadUrl: 'https://example.com/bus_static_data.json',
        ),
        data: _staticData(
          version: '2026.05.21',
          routes: {
            '24_UP': {'source': 'remote-route'},
          },
          stops: {
            '24_UP': {'source': 'remote-stop'},
          },
        ),
      );
      final loader = _loader(
        tempDir,
        remote,
        assets: _assetMap(assetVersion: '2026.05.20'),
      );

      await loader.updateFromRemoteIfNeeded();

      expect(await loader.activeVersion(), '2026.05.21');
      expect(await loader.loadRoute('24_UP'), {'source': 'remote-route'});
      expect(await loader.loadStop('24_UP'), {'source': 'remote-stop'});
    });

    test('does not download future effective remote data', () async {
      final tempDir = await Directory.systemTemp.createTemp('bus_static_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final remote = _FakeRemoteSource(
        manifest: BusStaticDataManifest(
          version: '2026.05.22',
          downloadUrl: 'https://example.com/bus_static_data.json',
          effectiveFrom: DateTime.parse('2026-05-22T00:00:00+09:00'),
        ),
        data: _staticData(
          version: '2026.05.22',
          routes: {
            '24_UP': {'source': 'future-route'},
          },
          stops: {
            '24_UP': {'source': 'future-stop'},
          },
        ),
      );
      final loader = _loader(
        tempDir,
        remote,
        assets: _assetMap(assetVersion: '2026.05.20'),
        nowProvider: () => DateTime.parse('2026-05-21T23:59:59+09:00'),
      );

      await loader.updateFromRemoteIfNeeded();

      expect(remote.downloadCount, 0);
      expect(await loader.activeVersion(), '2026.05.20');
      expect(await loader.loadRoute('24_UP'), {'source': 'asset-route'});
      expect(await loader.loadStop('24_UP'), {'source': 'asset-stop'});
    });

    test('falls back to bundled assets when remote manifest is unavailable',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('bus_static_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final loader = _loader(
        tempDir,
        _FakeRemoteSource(),
        assets: _assetMap(assetVersion: '2026.05.20'),
      );

      await loader.updateFromRemoteIfNeeded();

      expect(await loader.activeVersion(), '2026.05.20');
      expect(await loader.loadRoute('24_UP'), {'source': 'asset-route'});
      expect(await loader.loadStop('24_UP'), {'source': 'asset-stop'});
    });

    test('ignores a corrupted local file and falls back to bundled assets',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('bus_static_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File('${tempDir.path}${Platform.pathSeparator}bus_static_data.json')
          .writeAsString('{broken');
      final loader = _loader(
        tempDir,
        _FakeRemoteSource(),
        assets: _assetMap(assetVersion: '2026.05.20'),
      );

      expect(await loader.loadRoute('24_UP'), {'source': 'asset-route'});
      expect(await loader.loadStop('24_UP'), {'source': 'asset-stop'});
    });

    test('falls back to bundled asset when local data misses a route key',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('bus_static_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File('${tempDir.path}${Platform.pathSeparator}bus_static_data.json')
          .writeAsString(
        _staticData(
          version: '2026.05.21',
          routes: {
            '81_UP': {'source': 'remote-route'},
          },
          stops: {
            '81_UP': {'source': 'remote-stop'},
          },
        ),
      );
      final loader = _loader(
        tempDir,
        _FakeRemoteSource(),
        assets: _assetMap(assetVersion: '2026.05.20'),
      );

      expect(await loader.loadRoute('24_UP'), {'source': 'asset-route'});
      expect(await loader.loadStop('24_UP'), {'source': 'asset-stop'});
    });

    test('does not prefer local data when bundled asset version is newer',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('bus_static_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File('${tempDir.path}${Platform.pathSeparator}bus_static_data.json')
          .writeAsString(
        _staticData(
          version: '2026.05.19',
          routes: {
            '24_UP': {'source': 'old-local-route'},
          },
          stops: {
            '24_UP': {'source': 'old-local-stop'},
          },
        ),
      );
      final loader = _loader(
        tempDir,
        _FakeRemoteSource(),
        assets: _assetMap(assetVersion: '2026.05.20'),
      );

      expect(await loader.activeVersion(), '2026.05.20');
      expect(await loader.loadRoute('24_UP'), {'source': 'asset-route'});
      expect(await loader.loadStop('24_UP'), {'source': 'asset-stop'});
    });
  });
}

BusStaticDataLoader _loader(
  Directory tempDir,
  BusStaticDataRemoteSource remoteSource, {
  required Map<String, String> assets,
  BusStaticNowProvider? nowProvider,
}) {
  return BusStaticDataLoader(
    repository: remoteSource,
    documentsDirectoryProvider: () async => tempDir,
    nowProvider: nowProvider,
    assetLoader: (assetPath) async {
      final asset = assets[assetPath];
      if (asset == null) {
        throw StateError('Missing test asset: $assetPath');
      }
      return asset;
    },
  );
}

Map<String, String> _assetMap({required String assetVersion}) {
  return {
    BusStaticDataLoader.manifestAssetPath: jsonEncode({
      'version': assetVersion,
      'downloadUrl': 'https://example.com/bus_static_data.json',
    }),
    'assets/bus_routes/24_UP.json': jsonEncode({'source': 'asset-route'}),
    'assets/bus_stops/24_UP.json': jsonEncode({'source': 'asset-stop'}),
  };
}

String _staticData({
  required String version,
  required Map<String, dynamic> routes,
  required Map<String, dynamic> stops,
}) {
  return jsonEncode({
    'version': version,
    'routes': routes,
    'stops': stops,
  });
}

class _FakeRemoteSource implements BusStaticDataRemoteSource {
  _FakeRemoteSource({
    this.manifest,
    this.data,
  });

  final BusStaticDataManifest? manifest;
  final String? data;
  int downloadCount = 0;

  @override
  Future<BusStaticDataManifest?> fetchRemoteManifest() async => manifest;

  @override
  Future<String?> downloadBusStaticData(String downloadUrl) async {
    downloadCount++;
    return data;
  }
}
