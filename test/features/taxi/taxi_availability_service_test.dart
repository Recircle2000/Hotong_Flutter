import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hsro/core/services/auth_service.dart';
import 'package:hsro/features/taxi/services/taxi_availability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaxiAvailabilityService _service(http.Client client) => TaxiAvailabilityService(
  authService: AuthService.unavailable(),
  client: client,
  baseUrl: 'http://test',
);

MockClient _config(bool? enabled, {int status = 200}) => MockClient(
  (request) async {
    expect(request.url.path, '/api/app-config');
    if (enabled == null) throw http.ClientException('offline');
    return http.Response('{"taxi_enabled": $enabled}', status);
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('처음 설치 후 서버에 닿지 못하면 택시 메뉴를 숨긴다', () async {
    final service = await _service(_config(null)).init();
    await service.refresh();
    expect(service.showTaxiMenu, isFalse);
  });

  test('서버 스위치를 따르고 마지막 값을 기억한다', () async {
    final online = await _service(_config(true)).init();
    await online.refresh();
    expect(online.showTaxiMenu, isTrue);

    // 다음 실행에서 오프라인이어도 저장된 값으로 시작한다.
    final offline = await _service(_config(null)).init();
    expect(offline.showTaxiMenu, isTrue);

    final stopped = await _service(_config(false)).init();
    await stopped.refresh();
    expect(stopped.taxiEnabled.value, isFalse);
    // 로그인하지 않은 사용자는 진행 중인 팟이 없으므로 메뉴를 숨긴다.
    expect(stopped.showTaxiMenu, isFalse);
  });

  test('서버 오류 응답은 무시하고 기존 값을 유지한다', () async {
    final online = await _service(_config(true)).init();
    await online.refresh();
    final broken = await _service(_config(false, status: 500)).init();
    await broken.refresh();
    expect(broken.taxiEnabled.value, isTrue);
  });
}
