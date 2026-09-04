import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class QiblahPage extends StatefulWidget {
  const QiblahPage({super.key});

  @override
  State<QiblahPage> createState() => _QiblahPageState();
}

class _QiblahPageState extends State<QiblahPage> {
  double? qiblaDirection;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initQibla();
  }

  // 📐 دالة حساب اتجاه القبلة الرياضية بالنسبة لإحداثيات الكعبة
  double _calculateQibla(double lat, double lng) {
    const double meccaLat = 21.4225;
    const double meccaLng = 39.8262;

    double phiK = meccaLat * pi / 180.0;
    double lambdaK = meccaLng * pi / 180.0;
    double phi = lat * pi / 180.0;
    double lambda = lng * pi / 180.0;

    double qibla = atan2(
      sin(lambdaK - lambda),
      cos(phi) * tan(phiK) - sin(phi) * cos(lambdaK - lambda),
    );

    return (qibla * 180.0 / pi + 360.0) % 360.0;
  }

  Future<void> _initQibla() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          errorMessage = 'يرجى تفعيل خدمة الموقع (GPS)';
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            errorMessage = 'تم رفض الإذن للوصول للموقع';
            isLoading = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        qiblaDirection = _calculateQibla(position.latitude, position.longitude);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'حدث خطأ أثناء تحديد الموقع: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryColor = const Color(0xff425c75);
    final accentGold = const Color(0xffd4af37);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        title: const Text('اتجاه القبلة 🧭', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: const TextStyle(fontFamily: 'Cairo', color: Colors.redAccent)))
              : StreamBuilder<CompassEvent>(
                  stream: FlutterCompass.events,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('خطأ في قراءة الحساسات', style: TextStyle(fontFamily: 'Cairo')));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    double? heading = snapshot.data?.heading;

                    if (heading == null) {
                      return const Center(child: Text('جهازك لا يدعم بوصلة الاتجاهات', style: TextStyle(fontFamily: 'Cairo')));
                    }

                    // حساب زاوية دوران الإبرة نحو القبلة
                    double qiblaAngle = (qiblaDirection! - heading) * (pi / 180);

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'وجه الهاتف حتى تشير الإبرة للأعلى 🕋',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : primaryColor,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Transform.rotate(
                            angle: qiblaAngle,
                            child: Icon(
                              Icons.navigation_rounded,
                              size: 180,
                              color: accentGold,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'زاوية القبلة: ${qiblaDirection!.toStringAsFixed(1)}°',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}