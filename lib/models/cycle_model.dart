class CycleModel {
  final String id;
  final String name;
  final String type;
  final int year;
  final int cycleNumber;
  final String startDate;
  final String endDate;
  final bool active;
  final bool archived;
  final double totalExpenses; // 👈 إضافة حقل لحفظ مجموع المصروفات عند الأرشفة

  CycleModel({
    required this.id,
    required this.name,
    required this.type,
    required this.year,
    required this.cycleNumber,
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.archived,
    this.totalExpenses = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'year': year,
      'cycleNumber': cycleNumber,
      'startDate': startDate,
      'endDate': endDate,
      'active': active,
      'archived': archived,
      'totalExpenses': totalExpenses,
    };
  }

  factory CycleModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return CycleModel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      year: map['year'] ?? 0,
      cycleNumber: map['cycleNumber'] ?? 0,
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      active: map['active'] ?? false,
      archived: map['archived'] ?? false,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // 🔄 دالة نسخت للتعديل السريع (تسهل إغلاق الدورة بأسلوب نظيف)
  CycleModel copyWith({
    bool? active,
    bool? archived,
    String? endDate,
    double? totalExpenses,
  }) {
    return CycleModel(
      id: id,
      name: name,
      type: type,
      year: year,
      cycleNumber: cycleNumber,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      archived: archived ?? this.archived,
      totalExpenses: totalExpenses ?? this.totalExpenses,
    );
  }
}