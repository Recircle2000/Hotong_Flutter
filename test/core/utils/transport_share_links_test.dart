import 'package:flutter_test/flutter_test.dart';
import 'package:hsro/core/utils/transport_share_links.dart';
import 'package:hsro/features/city_bus/models/city_bus_share.dart';

void main() {
  for (final route in ['순환5', '1000', '810', '820', '821', '822', '24', '81']) {
    for (final direction in ['UP', 'DOWN']) {
      test('$route $direction preserves API key and shares canonical web URL',
          () {
        final key = '${route}_$direction';
        final content = CityBusShare.content(key);
        final campus = ['24', '81'].contains(route) ? 'cheonan' : 'asan';
        final webRoute = route == '순환5' ? '5' : route;
        expect(content.uri.toString(),
            'https://hotong.vercel.app/city-bus?campus=$campus&route=${webRoute}_$direction');
        expect(content.title, contains(route));
        expect(content.title, contains('→'));
        expect(CityBusShare.displayNames.containsKey(key), isTrue);
        expect(CityBusShare.displayNames.containsKey('5_$direction'), isFalse);
      });
    }
  }

  test('shuttle uses IDs and exact non-today date', () {
    expect(
      TransportShareLinks.shuttleJourney(
        originStationId: 101,
        destinationStationId: 904,
        date: '2024-02-29',
      ).toString(),
      'https://hotong.vercel.app/shuttle/journey?from=101&to=904&date=2024-02-29',
    );
  });
}
