class SessionModel {
  final String id;

  final String studentId;

  final String studentName;

  final String supervisorId;

  final String supervisorName;

  final String date;

  final bool absent;

  final String newMemorization;

  final String review;

  final String homework;

  final String rating;

  final String studentStatus;

  final String religiousActivities;

  final String notes;

  SessionModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
    required this.date,
    required this.absent,
    required this.newMemorization,
    required this.review,
    required this.homework,
    required this.rating,
    required this.studentStatus,
    required this.religiousActivities,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'date': date,
      'absent': absent,
      'newMemorization': newMemorization,
      'review': review,
      'homework': homework,
      'rating': rating,
      'studentStatus': studentStatus,
      'religiousActivities':
          religiousActivities,
      'notes': notes,
    };
  }

  factory SessionModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return SessionModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName:
          map['studentName'] ?? '',
      supervisorId:
          map['supervisorId'] ?? '',
      supervisorName:
          map['supervisorName'] ?? '',
      date: map['date'] ?? '',
      absent: map['absent'] ?? false,
      newMemorization:
          map['newMemorization'] ?? '',
      review: map['review'] ?? '',
      homework: map['homework'] ?? '',
      rating: map['rating'] ?? '',
      studentStatus:
          map['studentStatus'] ?? '',
      religiousActivities:
          map['religiousActivities'] ??
              '',
      notes: map['notes'] ?? '',
    );
  }
}