import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  bool rememberMe = false;

  login() async {
    try {
      setState(() {
        loading = true;
      });

      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final uid = credential.user!.uid;

      DocumentSnapshot userDoc =
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

if (!userDoc.exists) {

  userDoc =
      await FirebaseFirestore.instance
          .collection('supervisors')
          .doc(uid)
          .get();
}

if (!userDoc.exists) {
  throw Exception("المستخدم غير موجود");
}

final role = userDoc['role'];
if (rememberMe) {

  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setBool(
    'isLoggedIn',
    true,
  );
}

      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'uid': uid,
          'role': role,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ: $e"),
        ),
      );
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تسجيل الدخول"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: "الإيميل",
              ),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "كلمة المرور",
              ),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(

  title: const Text(
    "البقاء مسجل الدخول",
  ),

  value: rememberMe,

  onChanged: (value) {

    setState(() {

      rememberMe = value!;
    });
  },
),
            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("دخول"),
            )
          ],
        ),
      ),
    );
  }
}