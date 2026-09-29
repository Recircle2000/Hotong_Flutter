import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

/// iOS 네이티브 메뉴 선택지 하나.
class IOSPopupMenuOption {
  final int id;
  final String title;

  const IOSPopupMenuOption({required this.id, required this.title});
}

/// 화면은 Flutter가 그리고, 탭하면 iOS 네이티브 메뉴(iOS 26+는 리퀴드 글라스)를
/// 여는 투명 터치 영역이다. 선택 필드 위에 [Positioned.fill]로 겹쳐 쓴다.
class IOSPopupMenuOverlay extends StatefulWidget {
  final List<IOSPopupMenuOption> options;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  const IOSPopupMenuOverlay({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<IOSPopupMenuOverlay> createState() => _IOSPopupMenuOverlayState();
}

class _IOSPopupMenuOverlayState extends State<IOSPopupMenuOverlay> {
  MethodChannel? _channel;

  // 스크롤 중에도 탭을 바로 네이티브 버튼으로 넘겨 메뉴가 늦게 열리지 않게 한다.
  static final _gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
  };

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      // 선택값이나 목록이 바뀌면 네이티브 메뉴의 체크 표시를 새로 만든다.
      key: ValueKey(
        '${widget.selectedId}|${widget.options.map((o) => o.id).join(',')}',
      ),
      viewType: 'hsro/ios_route_popup_button',
      creationParams: {
        'selectedRouteId': widget.selectedId ?? -1,
        'hidesTitle': true,
        'routes': widget.options
            .map((option) => {'id': option.id, 'title': option.title})
            .toList(growable: false),
      },
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: _gestureRecognizers,
      onPlatformViewCreated: _handlePlatformViewCreated,
    );
  }

  void _handlePlatformViewCreated(int viewId) {
    _channel = MethodChannel('hsro/ios_route_popup_button_$viewId');
    _channel!.setMethodCallHandler((call) async {
      if (call.method != 'onChanged' || call.arguments == null) {
        return;
      }
      widget.onChanged(call.arguments as int);
    });
  }
}
