class Leave {
  final String id;
  final String userId;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;

  Leave({
    required this.id,
    required this.userId,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    return Leave(
      id: json["_id"],
      userId: json["userId"] is Map ? json["userId"]["_id"] : json["userId"],
      reason: json["reason"] ?? "",
      startDate: DateTime.parse(json["startDate"]),
      endDate: DateTime.parse(json["endDate"]),
      status: json["status"] ?? "waiting",
      createdAt: DateTime.parse(json["createdAt"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "userId": userId,
      "reason": reason,
      "startDate": startDate.toIso8601String(),
      "endDate": endDate.toIso8601String(),
      "status": status,
      "createdAt": createdAt.toIso8601String(),
    };
  }
}
