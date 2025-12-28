class CompanyLocation {
  final double? latitude;
  final double? longitude;
  final int? radius;

  const CompanyLocation({this.latitude, this.longitude, this.radius});

  factory CompanyLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CompanyLocation();
    return CompanyLocation(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radius: (json['radius'] as num?)?.toInt(),
    );
  }
}

class CompanyProfile {
  final String name;
  final String companyCode;
  final String address;
  final String? timeStart; // bisa "HH:mm" atau ISO string
  final String? timeEnd; // bisa "HH:mm" atau ISO string
  final CompanyLocation location;

  const CompanyProfile({
    required this.name,
    required this.companyCode,
    required this.address,
    required this.timeStart,
    required this.timeEnd,
    required this.location,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      name: (json['name'] ?? '-') as String,
      companyCode: (json['companyCode'] ?? '-') as String,
      address: (json['address'] ?? '-') as String,
      timeStart: (json['timeStart'] ?? json['time_start'])?.toString(),
      timeEnd: (json['timeEnd'] ?? json['time_end'])?.toString(),
      location: CompanyLocation.fromJson(
        json['location'] as Map<String, dynamic>?,
      ),
    );
  }
}
