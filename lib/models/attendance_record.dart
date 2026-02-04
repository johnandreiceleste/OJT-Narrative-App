class AttendanceRecord {
  final String id;
  final String userId;
  final DateTime date;
  final String? timeInAm;
  final String? timeOutAm;
  final String? timeInPm;
  final String? timeOutPm;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
    this.timeInAm,
    this.timeOutAm,
    this.timeInPm,
    this.timeOutPm,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      timeInAm: json['time_in_am'],
      timeOutAm: json['time_out_am'],
      timeInPm: json['time_in_pm'],
      timeOutPm: json['time_out_pm'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'time_in_am': timeInAm,
      'time_out_am': timeOutAm,
      'time_in_pm': timeInPm,
      'time_out_pm': timeOutPm,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
