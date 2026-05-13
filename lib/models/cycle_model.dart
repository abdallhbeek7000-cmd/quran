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
    );
  }
}