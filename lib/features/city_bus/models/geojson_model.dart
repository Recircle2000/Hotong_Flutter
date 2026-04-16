class GeoJsonModel {
  final String routeName;
  final List<List<double>> coordinates;

  GeoJsonModel({required this.routeName, required this.coordinates});

  factory GeoJsonModel.fromJson(Map<String, dynamic> json) {
    final feature = json['features'][0];
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    return GeoJsonModel(
      routeName: properties['route_name'],
      coordinates: List<List<double>>.from(
        geometry['coordinates'].map((coord) => List<double>.from(coord)),
      ),
    );
  }
}
