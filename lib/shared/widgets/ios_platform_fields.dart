import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hsro/features/shuttle/models/shuttle_models.dart';

/// iOS 네이티브 compact 날짜 선택기를 Flutter에서 재사용하기 위한 래퍼.
class IOSCompactDatePickerField extends StatefulWidget {
  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final ValueChanged<DateTime> onDateChanged;

  const IOSCompactDatePickerField({
    super.key,
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
    required this.onDateChanged,
  });

  @override
  State<IOSCompactDatePickerField> createState() =>
      _IOSCompactDatePickerFieldState();
}

class _IOSCompactDatePickerFieldState extends State<IOSCompactDatePickerField> {
  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: UiKitView(
        viewType: 'hsro/ios_compact_date_picker',
        // iOS 쪽에서 날짜 범위를 바로 적용할 수 있도록 초기값을 함께 넘긴다.
        creationParams: {
          'initialDate': widget.initialDate.millisecondsSinceEpoch,
          'minimumDate': widget.minimumDate.millisecondsSinceEpoch,
          'maximumDate': widget.maximumDate.millisecondsSinceEpoch,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _handlePlatformViewCreated,
      ),
    );
  }

  void _handlePlatformViewCreated(int viewId) {
    _channel = MethodChannel('hsro/ios_compact_date_picker_$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (call.method != 'onChanged' || call.arguments == null) {
        return;
      }

      final milliseconds = call.arguments as int;
      final selectedDate = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      widget.onDateChanged(
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
      );
    });
  }
}

/// iOS 메뉴형 노선 선택 버튼을 Flutter에서 쓰기 위한 래퍼다.
class IOSRoutePopupButtonField extends StatefulWidget {
  final List<ShuttleRoute> routes;
  final int selectedRouteId;
  final ValueChanged<int> onRouteChanged;

  const IOSRoutePopupButtonField({
    super.key,
    required this.routes,
    required this.selectedRouteId,
    required this.onRouteChanged,
  });

  @override
  State<IOSRoutePopupButtonField> createState() =>
      _IOSRoutePopupButtonFieldState();
}

class _IOSRoutePopupButtonFieldState extends State<IOSRoutePopupButtonField> {
  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'hsro/ios_route_popup_button',
      // iOS 메뉴를 만들 수 있게 route 목록과 현재 선택값을 같이 넘긴다.
      creationParams: {
        'selectedRouteId': widget.selectedRouteId,
        'routes': widget.routes
            .map((route) => {
                  'id': route.id,
                  'title': route.routeName,
                })
            .toList(growable: false),
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _handlePlatformViewCreated,
    );
  }

  void _handlePlatformViewCreated(int viewId) {
    _channel = MethodChannel('hsro/ios_route_popup_button_$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (call.method != 'onChanged' || call.arguments == null) {
        return;
      }

      widget.onRouteChanged(call.arguments as int);
    });
  }
}
