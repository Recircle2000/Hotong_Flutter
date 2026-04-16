import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hsro/core/utils/env_config.dart';
import 'package:hsro/features/subway/models/subway_arrival_model.dart';

class SubwayViewModel extends GetxController with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  // 역명별 실시간 도착 정보 목록
  final RxMap<String, List<SubwayArrival>> arrivalInfo =
      <String, List<SubwayArrival>>{}.obs;
  final RxBool isConnected = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // 앱 생명주기 감지 등록 후 웹소켓 연결
    WidgetsBinding.instance.addObserver(this);
    connectWebSocket();
  }

  @override
  void onClose() {
    // 웹소켓 연결과 생명주기 옵저버 정리
    WidgetsBinding.instance.removeObserver(this);
    disconnectWebSocket();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState changed to: $state');
    // 백그라운드에서는 연결 종료, 복귀 시 재연결
    if (state == AppLifecycleState.paused) {
      disconnectWebSocket();
    } else if (state == AppLifecycleState.resumed) {
      connectWebSocket();
    }
  }

  void disconnectWebSocket() {
    if (_channel != null) {
      print('Disconnecting from Subway WebSocket');
      _channel!.sink.close();
      _channel = null;
    }
    isConnected.value = false;
  }

  void connectWebSocket() {
    // 중복 연결 방지
    if (isConnected.value) return;

    try {
      final baseUrl = EnvConfig.baseUrl;
      // HTTP 기반 baseUrl을 웹소켓 주소로 변환
      String wsUrl = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      if (!wsUrl.endsWith('/')) {
        wsUrl += '/';
      }
      wsUrl += 'subway/ws';
      print('Connecting to Subway WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      isConnected.value = true;

      _channel!.stream.listen(
        (message) {
          try {
            // 역별 실시간 도착 데이터를 모델 객체로 변환
            final decodedMessage = jsonDecode(message) as Map<String, dynamic>;
            final Map<String, List<SubwayArrival>> parsedData = {};

            decodedMessage.forEach((station, list) {
              if (list is List) {
                parsedData[station] =
                    list.map((e) => SubwayArrival.fromJson(e)).toList();
              }
            });

            arrivalInfo.value = parsedData;
          } catch (e) {
            print('Error parsing subway data: $e');
          }
        },
        onError: (e) {
          // 연결 오류 상태 반영
          isConnected.value = false;
          error.value = 'WebSocket Error: $e';
          print('WebSocket Error: $e');
        },
        onDone: () {
          // 연결 종료 시 상태만 갱신
          isConnected.value = false;
          print('WebSocket Connection Closed');
        },
      );
    } catch (e) {
      // 초기 연결 실패 상태 반영
      isConnected.value = false;
      error.value = 'Connection failed: $e';
      print('Connection failed: $e');
    }
  }
}
