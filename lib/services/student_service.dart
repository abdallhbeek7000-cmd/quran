import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student_model.dart';

class StudentService {
  final firestore = FirebaseFirestore.instance;

  Future<String> generateStudentSerial({
    required int year,
    required int cycleNumber,
  }) async {
    final settingsRef = firestore
        .collection('settings')
        .doc('serials');

    final doc = await settingsRef.get();

    Map<String, dynamic> data = {};

    if (doc.exists) {
      data = doc.data()!;
    }

    final key = "${year}_$cycleNumber";

    int current = data[key] ?? 1;

    await settingsRef.set({
      key: current + 1,
    }, SetOptions(merge: true));

    final studentNumber =
        current.toString().padLeft(2, '0');

    final cycle =
        cycleNumber.toString().padLeft(2, '0');

    return "$year$cycle$studentNumber";
  }

  Future<void> addStudent(
    StudentModel student,
  ) async {
    await firestore
        .collection('students')
        .add(student.toMap());
  }

  Future<void> archiveStudent(
    String id,
  ) async {
    await firestore
        .collection('students')
        .doc(id)
        .update({
      'archived': true,
    });
  }

  Future<void> assignSupervisor({
    required String studentId,
    required String supervisorId,
    required String supervisorName,
  }) async {
    await firestore
        .collection('students')
        .doc(studentId)
        .update({
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
    });
  }

  Stream<QuerySnapshot> getStudents({
    required String cycleId,
  }) {
    return firestore
        .collection('students')
        .where('cycleId', isEqualTo: cycleId)
        .where('archived', isEqualTo: false)
        .snapshots();
  }
}