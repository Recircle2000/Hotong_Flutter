import 'package:flutter/widgets.dart'; // Change to widgets.dart or material.dart for WidgetsBindingObserver
import 'dart:convert';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/subway_arrival_model.dart';
import '../utils/env_config.dart';

class SubwayViewModel extends GetxController with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  final RxMap<String, List<SubwayArrival>> arrivalInfo = <String, List<SubwayArrival>>{}.obs;
  final RxBool isConnected = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    connectWebSocket();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnectWebSocket();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState changed to: $state');
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
    if (isConnected.value) return; // Avoid multiple connections

    try {
      final baseUrl = EnvConfig.baseUrl;
      // Replace https:// or http:// with wss:// or ws://
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
            final decodedMessage = jsonDecode(message) as Map<String, dynamic>;
            final Map<String, List<SubwayArrival>> parsedData = {};

            decodedMessage.forEach((station, list) {
              if (list is List) {
                parsedData[station] = list.map((e) => SubwayArrival.fromJson(e)).toList();
              }
            });

            arrivalInfo.value = parsedData;
          } catch (e) {
            print('Error parsing subway data: $e');
          }
        },
        onError: (e) {
          isConnected.value = false;
          error.value = 'WebSocket Error: $e';
          print('WebSocket Error: $e');
        },
        onDone: () {
          // Only update status if we didn't intentionally close it (checked via _channel null check or similar logic if needed,
          // but here we just mark as disconnected. If it was intentional, isConnected is likely already false)
          isConnected.value = false; 
          print('WebSocket Connection Closed');
        },
      );
    } catch (e) {
      isConnected.value = false;
      error.value = 'Connection failed: $e';
      print('Connection failed: $e');
    }
  }
}
