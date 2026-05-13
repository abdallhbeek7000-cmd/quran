import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSupervisorPage extends StatefulWidget {
  const AddSupervisorPage({super.key});

  @override
  State<AddSupervisorPage> createState() =>
      _AddSupervisorPageState();
}

class _AddSupervisorPageState
    extends State<AddSupervisorPage> {

  final TextEditingController
      nameController =
      TextEditingController();

  final TextEditingController
      emailController =
      TextEditingController();

  final TextEditingController
      passwordController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "إضافة مشرف",
        ),
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller:
                  nameController,

              decoration:
                  const InputDecoration(
                labelText:
                    "اسم المشرف",
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            TextField(
              controller:
                  emailController,

              decoration:
                  const InputDecoration(
                labelText:
                    "الإيميل",
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            TextField(
              controller:
                  passwordController,

              obscureText: true,

              decoration:
                  const InputDecoration(
                labelText:
                    "كلمة السر",
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            ElevatedButton(
              onPressed: () async {

  try {

    final credential =

        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(

      email:
          emailController.text.trim(),

      password:
          passwordController.text.trim(),
    );

    await FirebaseFirestore.instance
        .collection('supervisors')
        .doc(credential.user!.uid)
        .set({

      'name':
          nameController.text.trim(),

      'email':
          emailController.text.trim(),

      'uid':
          credential.user!.uid,

      'role': 'supervisor',
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(
        content: Text(
          "تمت إضافة المشرف",
        ),
      ),
    );

    Navigator.pop(context);

  } catch (e) {

    ScaffoldMessenger.of(context)
        .showSnackBar(

      SnackBar(
        content: Text(
          e.toString(),
        ),
      ),
    );
  }
},

              child: const Text(
                "إضافة المشرف",
              ),
            ),
          ],
        ),
      ),
    );
  }
}