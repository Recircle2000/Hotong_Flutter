class Bus {
  final String vehicleNo;
  final double latitude;
  final double longitude;
  final String stationName;

  Bus({
    required this.vehicleNo,
    required this.latitude,
    required this.longitude,
    required this.stationName,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      vehicleNo: json["vehicleno"]?.toString() ?? "",
      latitude: double.tryParse(json["gpslati"]?.toString() ?? "0") ?? 0.0,
      longitude: double.tryParse(json["gpslong"]?.toString() ?? "0") ?? 0.0,
      stationName: json["nodenm"]?.toString() ?? "정류장",
    );
  }
}
