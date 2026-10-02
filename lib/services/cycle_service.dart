import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cycle_model.dart';

class CycleService {
  final firestore = FirebaseFirestore.instance;

  // 1️⃣ إنشاء دورة جديدة مع تعطيل وأرشفة كافة الدورات السابقة تلقائياً
  Future<void> createCycle({
    required String type,
    required int year,
    required int cycleNumber,
    required String startDate,
    required String endDate,
  }) async {
    final name = "$type $year";

    // أرشفة أي دورة نشطة حالياً قبل فتح الجديدة
    final activeCycles = await firestore
        .collection('cycles')
        .where('active', isEqualTo: true)
        .get();

    WriteBatch batch = firestore.batch();

    for (var doc in activeCycles.docs) {
      batch.update(doc.reference, {
        'active': false,
        'archived': true,
      });
    }

    // إضافة الدورة الجديدة كدورة نشطة
    DocumentReference newCycleRef = firestore.collection('cycles').doc();
    batch.set(newCycleRef, {
      'name': name,
      'type': type,
      'year': year,
      'cycleNumber': cycleNumber,
      'startDate': startDate,
      'endDate': endDate,
      'active': true,
      'archived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 2️⃣ جلب الدورة النشطة الحالية (مرة واحدة)
  Future<CycleModel?> getCurrentCycle() async {
    final result = await firestore
        .collection('cycles')
        .where('active', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    return CycleModel.fromMap(doc.id, doc.data());
  }

  // 3️⃣ بث مباشر للدورة النشطة الحالية (لتحديث الواجهات فورياً عند التسكير/الفتح)
  Stream<CycleModel?> streamCurrentCycle() {
    return firestore
        .collection('cycles')
        .where('active', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CycleModel.fromMap(
        snapshot.docs.first.id,
        snapshot.docs.first.data(),
      );
    });
  }

  // 4️⃣ أرشفة وتسكير دورة محددة
  Future<void> archiveCycle(String id) async {
    // جلب إجمالي المصروفات للدورة قبل إغلاقها
    final expensesQuery = await firestore
        .collection('expenses')
        .where('cycleId', isEqualTo: id)
        .get();

    double totalExpenses = 0.0;
    for (var doc in expensesQuery.docs) {
      totalExpenses += (doc.data()['amount'] as num? ?? 0).toDouble();
    }

    await firestore.collection('cycles').doc(id).update({
      'active': false,
      'archived': true,
      'totalExpenses': totalExpenses, // حفظ المجموع المالي التراكمي للدورة
    });
  }

  // 5️⃣ تحديث تاريخ نهاية الدورة
  Future<void> updateCycleEndDate({
    required String id,
    required String endDate,
  }) async {
    await firestore.collection('cycles').doc(id).update({
      'endDate': endDate,
    });
  }
}