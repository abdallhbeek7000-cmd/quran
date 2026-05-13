import 'package:cloud_firestore/cloud_firestore.dart';

class ExamService {
  final exams =
      FirebaseFirestore.instance
          .collection('exams');

  Future addExam({
    required String studentId,
    required String studentName,
    required String supervisorId,
    required String supervisorName,
    required String title,
    required String type,
    required int score,
    required bool passed,
    required String notes,
  }) async {
    await exams.add({
      'studentId': studentId,
      'studentName': studentName,
      'supervisorId': supervisorId,
      'supervisorName':
          supervisorName,
      'title': title,
      'type': type,
      'score': score,
      'passed': passed,
      'notes': notes,
      'createdAt':
          Timestamp.now(),
    });
  }
}