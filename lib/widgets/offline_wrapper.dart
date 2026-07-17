import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineWrapper extends StatefulWidget {
  final Widget child;
  const OfflineWrapper({super.key, required this.child});

  @override
  State<OfflineWrapper> createState() => _OfflineWrapperState();
}

class _OfflineWrapperState extends State<OfflineWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    // 🚀 التنصت النشط والديناميكي على حالة الشبكة لايف فور تشغيل التطبيق
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final bool isOffline = results.contains(ConnectivityResult.none);

      if (isOffline) {
        _wasOffline = true;
        print("ℹ️ [OfflineWrapper] تم قطع الاتصال بالشبكة، التطبيق يعمل في الوضع المحلي (Cache Mode).");
      } else {
        // 🔥 إذا كان التطبيق أوفلاين وعاد الإنترنت الآن، نطلق نبضة الدفع القسري فوراً
        if (_wasOffline) {
          _wasOffline = false;
          print("🚀 [OfflineWrapper] لقط الإنترنت! جاري إيقاظ الفايربيز وتفريغ الكاش قسرياً وراء الكواليس...");
          try {
            // إجبار الفايربيز على تفريغ البيانات المعلقة بالخلفية فوراً
            await FirebaseFirestore.instance.waitForPendingWrites().timeout(
              const Duration(seconds: 10),
              onTimeout: () => print("⚠️ [OfflineWrapper] استغرق تفريغ البيانات وقتاً طويلاً بسبب ضعف الشبكة."),
            );
            print("✅ [OfflineWrapper] تم مزامنة ورفع كافة الجلسات المتراكمة بنجاح لايف!");
          } catch (e) {
            print("❌ [OfflineWrapper] خطأ أثناء تفريغ الكاش التلقائي: $e");
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel(); // إغلاق التنصت تفادياً لتسريب الذاكرة (Memory Leak)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          Positioned(
            top: 40,
            right: 10,
            child: StreamBuilder<List<ConnectivityResult>>(
              stream: Connectivity().onConnectivityChanged,
              builder: (context, snapshot) {
                final results = snapshot.data ?? [];
                final isOffline = results.contains(ConnectivityResult.none);
                
                if (!isOffline) return const SizedBox();
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.9), 
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        "يعمل بدون إنترنت (محلي)", 
                        style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}