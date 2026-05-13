import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final firestore = FirebaseFirestore.instance;

  final searchController = TextEditingController();

  final nameController = TextEditingController();
  final fatherController = TextEditingController();
  final motherController = TextEditingController();
  final ageController = TextEditingController();
  final addressController = TextEditingController();
  final fatherJobController = TextEditingController();
  final phoneController = TextEditingController();

  final supervisorEmail = TextEditingController();
  final supervisorPassword = TextEditingController();

  DateTime? birthDate;

  String searchText = '';

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    Navigator.pop(context);
  }

  Future<String> generateStudentNumber() async {
    final settingsRef =
        firestore.collection('settings').doc('student_counter');

    final settingsDoc = await settingsRef.get();

    int current = 20260101;

    if (settingsDoc.exists) {
      current = settingsDoc['current'];
    }

    await settingsRef.set({
      'current': current + 1,
    });

    return current.toString();
  }

  Future<void> addSupervisor() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: supervisorEmail.text.trim(),
        password: supervisorPassword.text.trim(),
      );

      await firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'role': 'supervisor',
        'email': supervisorEmail.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إضافة المشرف"),
        ),
      );

      supervisorEmail.clear();
      supervisorPassword.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ: $e"),
        ),
      );
    }
  }

  Future<void> addStudent() async {
    try {
      final studentNumber = await generateStudentNumber();

      await firestore.collection('students').add({
        'student_number': studentNumber,
        'name': nameController.text,
        'father_name': fatherController.text,
        'mother_name': motherController.text,
        'age': ageController.text,
        'address': addressController.text,
        'father_job': fatherJobController.text,
        'phone': phoneController.text,
        'birth_date': birthDate.toString(),
        'supervisor_id': '',
        'created_at': DateTime.now().toString(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إضافة الطالب"),
        ),
      );

      nameController.clear();
      fatherController.clear();
      motherController.clear();
      ageController.clear();
      addressController.clear();
      fatherJobController.clear();
      phoneController.clear();

      setState(() {
        birthDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ: $e"),
        ),
      );
    }
  }

  Future<void> deleteStudent(String id) async {
    await firestore.collection('students').doc(id).delete();
  }

  Future<void> editStudent(
    String id,
    Map<String, dynamic> data,
  ) async {
    nameController.text = data['name'];
    fatherController.text = data['father_name'];
    motherController.text = data['mother_name'];
    ageController.text = data['age'];
    addressController.text = data['address'];
    fatherJobController.text = data['father_job'];
    phoneController.text = data['phone'];

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("تعديل الطالب"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                buildField("الاسم", nameController),
                buildField("اسم الأب", fatherController),
                buildField("اسم الأم", motherController),
                buildField("العمر", ageController),
                buildField("السكن", addressController),
                buildField("عمل الأب", fatherJobController),
                buildField("الهاتف", phoneController),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await firestore
                    .collection('students')
                    .doc(id)
                    .update({
                  'name': nameController.text,
                  'father_name': fatherController.text,
                  'mother_name': motherController.text,
                  'age': ageController.text,
                  'address': addressController.text,
                  'father_job': fatherJobController.text,
                  'phone': phoneController.text,
                });

                Navigator.pop(context);
              },
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );
  }

  Widget buildField(
    String title,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة المدير 👑"),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text(
              "إضافة مشرف",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            buildField(
              "إيميل المشرف",
              supervisorEmail,
            ),

            buildField(
              "كلمة المرور",
              supervisorPassword,
            ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: addSupervisor,
                child: const Text("إضافة مشرف"),
              ),
            ),

            const SizedBox(height: 40),

            const Divider(),

            const SizedBox(height: 40),

            const Text(
              "إضافة طالب",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            buildField("اسم الطالب", nameController),
            buildField("اسم الأب", fatherController),
            buildField("اسم الأم", motherController),
            buildField("العمر", ageController),
            buildField("مكان السكن", addressController),
            buildField("عمل الأب", fatherJobController),
            buildField("رقم الهاتف", phoneController),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                    initialDate: DateTime.now(),
                  );

                  if (pickedDate != null) {
                    setState(() {
                      birthDate = pickedDate;
                    });
                  }
                },
                child: Text(
                  birthDate == null
                      ? "اختر تاريخ الميلاد"
                      : birthDate.toString().split(' ')[0],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: addStudent,
                child: const Text("حفظ الطالب"),
              ),
            ),

            const SizedBox(height: 40),

            const Divider(),

            const SizedBox(height: 30),

            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "بحث عن طالب",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value.toLowerCase();
                });
              },
            ),

            const SizedBox(height: 30),

            StreamBuilder(
              stream: firestore
                  .collection('students')
                  .orderBy('student_number')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final students = snapshot.data!.docs.where((student) {
                  final name =
                      student['name'].toString().toLowerCase();

                  return name.contains(searchText);
                }).toList();

                if (students.isEmpty) {
                  return const Text("لا يوجد طلاب");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];

                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        title: Text(student['name']),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              "الرقم: ${student['student_number']}",
                            ),
                            Text(
                              "الهاتف: ${student['phone']}",
                            ),
                            Text(
                              "العمر: ${student['age']}",
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                editStudent(
                                  student.id,
                                  student.data(),
                                );
                              },
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                deleteStudent(student.id);
                              },
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}