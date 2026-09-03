import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class QiblahPage extends StatefulWidget {
  const QiblahPage({super.key});

  @override
  State<QiblahPage> createState() => _QiblahPageState();
}

class _QiblahPageState extends State<QiblahPage> {
  bool _hasPermission = false;
  bool _isLoading = true;

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        await Geolocator.openLocationSettings();
      }
      setState(() {
        _hasPermission = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("اتجاه القبلة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _buildPermissionDeniedWidget()
              : StreamBuilder<QiblahDirection>(
                  stream: FlutterQiblah.qiblahStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "حدث خطأ أثناء تحديد الاتجاه: ${snapshot.error}",
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      );
                    }

                    final qiblahDirection = snapshot.data!;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "قم بفتل الهاتف حتى تتطابق الإبرة مع الاتجاه",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            color: isDark ? Colors.white70 : primaryColor,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: SizedBox(
                            height: 300,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // خلفية البوصلة (الأرقام والدرجات)
                                Transform.rotate(
                                  angle: (qiblahDirection.direction * (pi / 180) * -1),
                                  child: Container(
                                    width: 260,
                                    height: 260,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                      border: Border.all(color: accentGold, width: 2),
                                    ),
                                    child: Icon(Icons.navigation_outlined, size: 200, color: Colors.grey.withOpacity(0.2)),
                                  ),
                                ),
                                // إبرة اتجاه الكعبة المشرفة
                                Transform.rotate(
                                  angle: (qiblahDirection.qiblah * (pi / 180) * -1),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_rounded, size: 50, color: accentGold),
                                      Container(
                                        width: 6,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: accentGold,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          "${qiblahDirection.offset.toStringAsFixed(0)}°",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: accentGold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off_rounded, size: 60, color: Colors.redAccent),
          const SizedBox(height: 15),
          const Text(
            "يلزم تفعيل إذن الموقع لتحديد اتجاه القبلة بدقة",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _checkLocationPermission,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text("منح إذن الموقع", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}