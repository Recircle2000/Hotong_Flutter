import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/features/city_bus/models/city_bus_share.dart';
import 'package:hsro/shared/widgets/link_share_button.dart';

void main() {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  for (final response in ['', 'dev.fluttercommunity.plus/share/unavailable']) {
    testWidgets('shares latest selection and handles "$response" silently',
        (tester) async {
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        calls.add(call);
        return response;
      });
      var route = '순환5_DOWN';
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              appBar: AppBar(actions: [
        LinkShareButton(content: () => CityBusShare.content(route)),
      ]))));
      route = '24_UP';
      await tester.tap(find.byTooltip('링크 공유'));
      await tester.pumpAndSettle();
      final args = calls.single.arguments as Map;
      expect(args['uri'],
          'https://hotong.vercel.app/city-bus?campus=cheonan&route=24_UP');
      expect(args.containsKey('text'), isFalse);
      expect(args['title'], contains('24'));
      expect(args['subject'], args['title']);
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
      expect(find.byType(SnackBar), findsNothing);
    });
  }

  testWidgets('blocks duplicate taps and reports actual platform errors',
      (tester) async {
    var calls = 0;
    final pending = Completer<String>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) {
      calls++;
      return pending.future;
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(actions: [
      LinkShareButton(content: () => CityBusShare.content('1000_UP')),
    ]))));
    await tester.tap(find.byTooltip('링크 공유'));
    await tester.pump();
    await tester.tap(find.byTooltip('링크 공유'));
    expect(calls, 1);
    pending.completeError(PlatformException(code: 'share_failed'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull);
  });
}
