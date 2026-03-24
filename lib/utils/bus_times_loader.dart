import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../repository/bus_times_repository.dart';

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
    // 서버에서 최신 버전 정보 조회
    print(
      '[BusTimesLoader] 서버에서 버전 정보 조회: ${BusTimesRepository.versionApiUrl}',
    );
    try {
      final serverVersion = await _busTimesRepository.fetchServerVersion();
      if (serverVersion != null) {
        print('[BusTimesLoader] 서버 버전: $serverVersion');
        if (localVersion != serverVersion) {
          print(
            '[BusTimesLoader] 버전 다름 → 파일 다운로드 시도: ${BusTimesRepository.downloadUrl}',
          );
          try {
            final downloadedJson =
                await _busTimesRepository.downloadBusTimesJson();
            if (downloadedJson != null) {
              await file.writeAsString(downloadedJson);
              print('[BusTimesLoader] bus_times.json 파일 다운로드 및 저장 완료');
            } else {
              print('[BusTimesLoader] bus_times.json 다운로드 실패');
            }
          } catch (e) {
            print('[BusTimesLoader] bus_times.json 다운로드 중 오류: $e');
          }
        } else {
          print('[BusTimesLoader] 버전 동일, 다운로드 생략');
        }
      } else {
        print('[BusTimesLoader] 서버 버전 정보 조회 실패');
      }
    } catch (e) {
      print('[BusTimesLoader] 서버 연결/버전 조회 오류: $e');
    }
  }
}
