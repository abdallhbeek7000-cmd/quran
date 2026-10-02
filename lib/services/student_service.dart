import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';

class StudentService {
  final firestore = FirebaseFirestore.instance;

  // 1️⃣ توليد الرقم التسلسلي للطالب بناءً على السنة والدورة
  Future<String> generateStudentSerial({
    required int year,
    required int cycleNumber,
  }) async {
    final settingsRef = firestore.collection('settings').doc('serials');
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

    final studentNumber = current.toString().padLeft(2, '0');
    final cycle = cycleNumber.toString().padLeft(2, '0');

    return "$year$cycle$studentNumber";
  }

  // 2️⃣ إضافة طالب جديد مع إسناد الدورة التي سجل فيها لأول مرة
  Future<void> addStudent(StudentModel student) async {
    await firestore.collection('students').add(student.toMap());
  }

  // 3️⃣ أرشفة الطالب (عند مغادرته المعهد تماماً وليس عند نهاية الدورة)
  Future<void> archiveStudent(String id) async {
    await firestore.collection('students').doc(id).update({
      'archived': true,
    });
  }

  // 4️⃣ تعيين المشرف للطالب
  Future<void> assignSupervisor({
    required String studentId,
    required String supervisorId,
    required String supervisorName,
  }) async {
    await firestore.collection('students').doc(studentId).update({
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
    });
  }

  // 5️⃣ جلب الطلاب المعتمدين النشطين بالمعهد (الذين لم يتم أرشفتهم)
  // يظهر الطالب دائماً في الدورة الحالية وتستمر معه بياناته التراكمية
  Stream<QuerySnapshot> getActiveStudents() {
    return firestore
        .collection('students')
        .where('archived', isEqualTo: false)
        .snapshots();
  }

  // 6️⃣ جلب الطلاب الملتحقين بدورة محددة فقط (في حال استخدام نظام التسجيل لكل دورة)
  Stream<QuerySnapshot> getStudentsByCycle({required String cycleId}) {
    return firestore
        .collection('students')
        .where('enrolledCycleIds', arrayContains: cycleId)
        .where('archived', isEqualTo: false)
        .snapshots();
  }

  // 7️⃣ تسديد/إضافة دورة جديدة لقائمة دورات الطالب
  Future<void> enrollStudentInCycle({
    required String studentId,
    required String cycleId,
  }) async {
    await firestore.collection('students').doc(studentId).update({
      'enrolledCycleIds': FieldValue.arrayUnion([cycleId]),
    });
  }
}