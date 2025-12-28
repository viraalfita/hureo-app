class Attendance {
  final String id;
  final String userId;
  final String type;
  final DateTime time;
  final Location location; // wajib ada
  final bool late; // baru

  Attendance({
    required this.id,
    required this.userId,
    required this.type,
    required this.time,
    required this.location,
    this.late = false, // default false
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    if (json['location'] == null) {
      throw Exception(
        "Attendance.fromJson error: 'location' is null. Data: $json",
      );
    }

    return Attendance(
      id: json['_id'],
      userId: json['userId'],
      type: json['type'],
      time: DateTime.parse(json['time']),
      location: Location.fromJson(json['location']),
      late: json['late'] ?? false, // ambil dari API, default false
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    if (json['latitude'] == null || json['longitude'] == null) {
      throw Exception(
        "Location.fromJson error: latitude/longitude missing. Data: $json",
      );
    }

    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
