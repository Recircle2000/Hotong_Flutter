/// Web URLs are independent of the API/development server configuration.
class TransportShareLinks {
  static const host = 'hotong.vercel.app';

  static String campusForRoute(String routeKey) {
    final route = routeKey.split('_').first;
    return const {'24', '81'}.contains(route) ? 'cheonan' : 'asan';
  }

  static Uri cityBus({required String campus, required String routeKey}) {
    final webRoute = routeKey.replaceFirst(RegExp(r'^순환5_'), '5_');
    return Uri.https(host, '/city-bus', {
      'campus': campus,
      'route': webRoute,
    });
  }

  static Uri shuttleJourney({
    required int originStationId,
    required int destinationStationId,
    required String date,
  }) =>
      Uri.https(host, '/shuttle/journey', {
        'from': originStationId.toString(),
        'to': destinationStationId.toString(),
        'date': date,
      });
}
