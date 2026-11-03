import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hsro/core/repository/bus_times_repository.dart';

class BusTimesLoader {
  static const String assetPath = 'assets/bus_times/bus_times.json';
  static const String fileName = 'bus_times.json';
  static final BusTimesRepository _busTimesRepository = BusTimesRepository();
  // bus_times.json을 Document 디렉토리에서 우선 읽고, 없으면 assets에서 읽음
  static Future<Map<String, dynamic>> loadBusTimes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      print('[BusTimesLoader] Document 디렉토리에서 bus_times.json 사용');
      final jsonString = await file.readAsString();
      return json.decode(jsonString);
    } else {
      print('[BusTimesLoader] assets에서 bus_times.json 사용');
      final jsonString = await rootBundle.loadString(assetPath);
      return json.decode(jsonString);
    }
  }

  // 서버에서 버전 체크 후 최신이면 다운로드하여 교체
  static Future<void> updateBusTimesIfNeeded() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    String? localVersion;
    if (await file.exists()) {
      try {
        final localJson = json.decode(await file.readAsString());
        localVersion = localJson['version']?.toString();
        print('[BusTimesLoader] 로컬 파일 버전: $localVersion');
      } catch (e) {
        print('[BusTimesLoader] 로컬 파일 파싱 오류: $e');
      }
    } else {
      // assets의 버전 확인
      try {
        final assetJson = json.decode(await rootBundle.loadString(assetPath));
        localVersion = assetJson['version']?.toString();
        print('[BusTimesLoader] assets 버전: $localVersion');
      } catch (e) {
        print('[BusTimesLoader] assets 파싱 오류: $e');
      }
    }
    // 서버에서 최신 버전 정보 조회 (app-config 우선, 없으면 예전 버전 API)
    try {
      final remote = await _busTimesRepository.fetchRemoteInfo();
      if (remote == null) {
        print('[BusTimesLoader] 서버 버전 정보 조회 실패');
        return;
      }
      print('[BusTimesLoader] 서버 버전: ${remote.version}');
      if (localVersion == remote.version) {
        print('[BusTimesLoader] 버전 동일, 다운로드 생략');
        return;
      }
      print('[BusTimesLoader] 버전 다름 → 파일 다운로드 시도: ${remote.downloadUrl}');
      final downloadedJson =
          await _busTimesRepository.downloadBusTimesJson(remote.downloadUrl);
      if (downloadedJson == null) {
        print('[BusTimesLoader] bus_times.json 다운로드 실패');
        return;
      }
      // 받은 파일이 서버가 알려준 버전과 다르면(깃허브 갱신 전 등) 저장하지 않는다.
      final downloadedVersion = _versionOf(downloadedJson);
      if (downloadedVersion != remote.version) {
        print(
          '[BusTimesLoader] 다운로드 버전 불일치(${downloadedVersion ?? '파싱 실패'}), 저장 생략',
        );
        return;
      }
      await _replaceFile(file, downloadedJson);
      print('[BusTimesLoader] bus_times.json 파일 다운로드 및 저장 완료');
    } catch (e) {
      print('[BusTimesLoader] 서버 연결/다운로드 오류: $e');
    }
  }

  static String? _versionOf(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      return decoded is Map<String, dynamic> ? decoded['version']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  // 쓰는 도중 앱이 꺼져도 깨진 파일이 남지 않게 임시 파일을 거쳐 바꾼다.
  static Future<void> _replaceFile(File file, String contents) async {
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(contents, encoding: utf8, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}
