class Report {
  final String id;
  final String userId;
  final DateTime date;
  final String title;
  final String narrative;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Report({
    required this.id,
    required this.userId,
    required this.date,
    required this.title,
    required this.narrative,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      narrative: json['narrative'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'title': title,
      'narrative': narrative,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
