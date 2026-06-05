import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class Parallax3DCard extends StatefulWidget {
  final Widget child;

  const Parallax3DCard({super.key, required this.child});

  @override
  State<Parallax3DCard> createState() => _Parallax3DCardState();
}

class _Parallax3DCardState extends State<Parallax3DCard> {
  double pitch = 0.0;
  double roll = 0.0;
  StreamSubscription<AccelerometerEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    // 🚀 الاستماع لحركة إيد المستخدم
    _subscription = accelerometerEventStream().listen((event) {
      if (mounted) {
        setState(() {
          // نقسم على 20 لحتى تكون الحركة ناعمة جداً وما تدوّخ العين
          // ونستخدم clamp لحتى ما تقلب البطاقة بشكل كامل إذا مال الجوال كتير
          pitch = (event.y / 20).clamp(-0.15, 0.15); // الميلان للأعلى والأسفل
          roll = -(event.x / 20).clamp(-0.15, 0.15); // الميلان لليمين واليسار
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel(); // إيقاف الاستماع عند الخروج من الصفحة لتوفير البطارية
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250), // سرعة الاستجابة للحركة
      curve: Curves.easeOutCubic,
      // 🚀 سحر الـ 3D كله بهالأسطر
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // تأثير المنظور والعمق (الرقم 0.001 هو الأفضل للزجاج)
        ..rotateX(pitch)
        ..rotateY(roll),
      alignment: FractionalOffset.center,
      child: widget.child, // البطاقة الحقيقية تبعك بتنحط هون
    );
  }
}