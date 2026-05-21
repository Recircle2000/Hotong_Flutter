import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:hsro/core/repository/bus_static_data_repository.dart';

typedef BusStaticAssetLoader = Future<String> Function(String assetPath);
typedef BusStaticDirectoryProvider = Future<Directory> Function();
typedef BusStaticNowProvider = DateTime Function();

class BusStaticDataLoader {
  BusStaticDataLoader({
    BusStaticDataRemoteSource? repository,
    BusStaticDirectoryProvider? documentsDirectoryProvider,
    BusStaticAssetLoader? assetLoader,
    BusStaticNowProvider? nowProvider,
  })  : _repository = repository ?? BusStaticDataRepository(),
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        _assetLoader = assetLoader ?? rootBundle.loadString,
        _nowProvider = nowProvider ?? DateTime.now;

  static const String manifestAssetPath = 'assets/bus_static_manifest.json';
  static const String localFileName = 'bus_static_data.json';

  static final BusStaticDataLoader _shared = BusStaticDataLoader();

  final BusStaticDataRemoteSource _repository;
  final BusStaticDirectoryProvider _documentsDirectoryProvider;
  final BusStaticAssetLoader _assetLoader;
  final BusStaticNowProvider _nowProvider;

  Map<String, dynamic>? _cachedLocalData;
  BusStaticDataManifest? _cachedAssetManifest;

  static Future<void> updateIfNeeded() => _shared.updateFromRemoteIfNeeded();

  static Future<Map<String, dynamic>> loadRouteGeoJson(String routeKey) =>
      _shared.loadRoute(routeKey);

  static Future<Map<String, dynamic>> loadStopJson(String routeKey) =>
      _shared.loadStop(routeKey);

  static Future<String?> loadActiveVersion() => _shared.activeVersion();

  Future<void> updateFromRemoteIfNeeded() async {
    try {
      final remoteManifest = await _repository.fetchRemoteManifest();
      if (remoteManifest == null) {
        _log('원격 manifest 조회 실패');
        return;
      }

      final effectiveFrom = remoteManifest.effectiveFrom;
      if (effectiveFrom != null &&
          effectiveFrom.toUtc().isAfter(_nowProvider().toUtc())) {
        _log('예약된 정적 버스 데이터 대기 중: ${effectiveFrom.toIso8601String()}');
        return;
      }

      final currentVersion = await _currentVersion();
      if (currentVersion != null &&
          _compareVersions(currentVersion, remoteManifest.version) >= 0) {
        _log('최신 정적 버스 데이터 사용 중: $currentVersion');
        return;
      }

      final downloadedJson =
          await _repository.downloadBusStaticData(remoteManifest.downloadUrl);
      if (downloadedJson == null) {
        _log('bus_static_data.json 다운로드 실패');
        return;
      }

      final downloadedData = _decodeStaticData(downloadedJson);
      if (downloadedData == null ||
          downloadedData['version']?.toString() != remoteManifest.version) {
        _log('다운로드 데이터 검증 실패');
        return;
      }

      await _replaceLocalData(downloadedJson);
      _cachedLocalData = downloadedData;
      _log('정적 버스 데이터 업데이트 완료');
    } catch (e) {
      _log('정적 버스 데이터 업데이트 오류: $e');
    }
  }

  Future<Map<String, dynamic>> loadRoute(String routeKey) async {
    final localData = await _loadUsableLocalData();
    final localRoute = _nestedMap(localData, 'routes', routeKey);
    if (localRoute != null) {
      return localRoute;
    }

    return _loadAssetJson('assets/bus_routes/$routeKey.json');
  }

  Future<Map<String, dynamic>> loadStop(String routeKey) async {
    final localData = await _loadUsableLocalData();
    final localStop = _nestedMap(localData, 'stops', routeKey);
    if (localStop != null) {
      return localStop;
    }

    return _loadAssetJson('assets/bus_stops/$routeKey.json');
  }

  Future<String?> activeVersion() => _currentVersion();

  Future<String?> _currentVersion() async {
    final localData = await _loadUsableLocalData();
    final localVersion = localData?['version']?.toString();
    if (localVersion != null && localVersion.isNotEmpty) {
      return localVersion;
    }

    final assetManifest = await _loadAssetManifest();
    return assetManifest?.version;
  }

  Future<Map<String, dynamic>?> _loadUsableLocalData() async {
    final cached = _cachedLocalData;
    if (cached != null && await _isLocalVersionUsable(cached)) {
      return cached;
    }

    final file = await _localDataFile();
    if (!await file.exists()) {
      return null;
    }

    try {
      final data = _decodeStaticData(await file.readAsString());
      if (data == null || !await _isLocalVersionUsable(data)) {
        return null;
      }

      _cachedLocalData = data;
      return data;
    } catch (e) {
      _log('로컬 정적 데이터 로드 실패: $e');
      return null;
    }
  }

  Future<bool> _isLocalVersionUsable(Map<String, dynamic> localData) async {
    final localVersion = localData['version']?.toString();
    if (localVersion == null || localVersion.isEmpty) {
      return false;
    }

    final assetVersion = (await _loadAssetManifest())?.version;
    if (assetVersion == null || assetVersion.isEmpty) {
      return true;
    }

    return _compareVersions(localVersion, assetVersion) >= 0;
  }

  Future<BusStaticDataManifest?> _loadAssetManifest() async {
    final cached = _cachedAssetManifest;
    if (cached != null) {
      return cached;
    }

    try {
      final jsonString = await _assetLoader(manifestAssetPath);
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      final manifest = BusStaticDataManifest.fromJson(
        decoded,
        fallbackDownloadUrl: BusStaticDataRepository.defaultDownloadUrl,
      );
      _cachedAssetManifest = manifest;
      return manifest;
    } catch (e) {
      _log('asset manifest 로드 실패: $e');
      return null;
    }
  }

  void _log(String message) {
    developer.log(message, name: 'BusStaticDataLoader');
  }

  Future<Map<String, dynamic>> _loadAssetJson(String assetPath) async {
    final jsonString = await _assetLoader(assetPath);
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  Future<File> _localDataFile() async {
    final directory = await _documentsDirectoryProvider();
    return File(_joinPath(directory.path, localFileName));
  }

  Future<void> _replaceLocalData(String jsonString) async {
    final file = await _localDataFile();
    final tempFile = File('${file.path}.tmp');

    await tempFile.writeAsString(jsonString, encoding: utf8, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Map<String, dynamic>? _decodeStaticData(String jsonString) {
    try {
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      final version = decoded['version']?.toString();
      final routes = decoded['routes'];
      final stops = decoded['stops'];

      if (version == null ||
          version.isEmpty ||
          routes is! Map ||
          stops is! Map) {
        return null;
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _nestedMap(
    Map<String, dynamic>? data,
    String section,
    String routeKey,
  ) {
    final sectionData = data?[section];
    if (sectionData is! Map) {
      return null;
    }

    final routeData = sectionData[routeKey];
    if (routeData is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(routeData);
  }

  int _compareVersions(String left, String right) {
    final leftParts = _parseDateVersion(left);
    final rightParts = _parseDateVersion(right);

    if (leftParts != null && rightParts != null) {
      for (var i = 0; i < leftParts.length; i++) {
        final difference = leftParts[i].compareTo(rightParts[i]);
        if (difference != 0) {
          return difference;
        }
      }
      return 0;
    }

    return left.compareTo(right);
  }

  List<int>? _parseDateVersion(String version) {
    final match = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})$').firstMatch(version);
    if (match == null) {
      return null;
    }

    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  String _joinPath(String directoryPath, String fileName) {
    if (directoryPath.endsWith(Platform.pathSeparator)) {
      return '$directoryPath$fileName';
    }

    return '$directoryPath${Platform.pathSeparator}$fileName';
  }
}
