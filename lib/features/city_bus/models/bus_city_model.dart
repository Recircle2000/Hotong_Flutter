class Bus {
  final String vehicleNo;
  final double latitude;
  final double longitude;
  final String stationName;

  /// BIS 기준 정류장 순번 (TAGO nodeord). 없으면 null.
  final int? nodeOrd;

  Bus({
    required this.vehicleNo,
    required this.latitude,
    required this.longitude,
    required this.stationName,
    this.nodeOrd,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      vehicleNo: json["vehicleno"]?.toString() ?? "",
      latitude: double.tryParse(json["gpslati"]?.toString() ?? "0") ?? 0.0,
      longitude: double.tryParse(json["gpslong"]?.toString() ?? "0") ?? 0.0,
      stationName: json["nodenm"]?.toString() ?? "정류장",
      nodeOrd: int.tryParse(json["nodeord"]?.toString() ?? ""),
    );
  }
}
