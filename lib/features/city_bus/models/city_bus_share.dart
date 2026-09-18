import 'package:hsro/core/services/link_share_service.dart';
import 'package:hsro/core/utils/transport_share_links.dart';

class CityBusShare {
  static const Map<String, String> displayNames = {
    // 노선 이름 표시용
    "순환5_DOWN": "순환5 (호서대학교 → 천안아산역)",
    "순환5_UP": "순환5 (천안아산역 → 호서대학교)",
    "1000_UP": "1000 (탕정면사무소 → 호서대학교)",
    "1000_DOWN": "1000 (호서대학교 → 탕정면사무소)",
    "810_UP": "810 (아산터미널 → 호서대학교)",
    "810_DOWN": "810 (호서대학교 → 아산터미널)",
    "820_UP": "820 (아산터미널 → 호서대학교)",
    "820_DOWN": "820 (호서대학교 → 아산터미널)",
    "821_UP": "821 (아산터미널 → 호서대학교)",
    "821_DOWN": "821 (호서대학교 → 아산터미널)",
    "822_UP": "822 (아산터미널 → 호서대학교)",
    "822_DOWN": "822 (호서대학교 → 아산터미널)",
    "24_DOWN": "24 (호서대천캠 → 동우아파트)",
    "24_UP": "24 (동우아파트 → 호서대천캠)",
    "81_DOWN": "81 (호서대천캠 → 차암2통)",
    "81_UP": "81 (차암2통 → 호서대천캠)",
  };

  static LinkShareContent content(String routeKey) => LinkShareContent(
        title: displayNames[routeKey] ?? routeKey,
        uri: TransportShareLinks.cityBus(
          campus: TransportShareLinks.campusForRoute(routeKey),
          routeKey: routeKey,
        ),
      );
}
