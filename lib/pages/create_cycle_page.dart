import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج والـ Blur
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة حالة المظهر
import '../services/cycle_service.dart';
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider

class CreateCyclePage extends StatefulWidget {
  const CreateCyclePage({super.key});

  @override
  State<CreateCyclePage> createState() => _CreateCyclePageState();
}

class _CreateCyclePageState extends State<CreateCyclePage> {
  final cycleService = CycleService();
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); // لون الانعكاس الزجاجي

  String type = "صيف";
  final year = TextEditingController();
  final cycleNumber = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool loading = false;

  // دالة لاختيار التاريخ بشكل أنيق ومتوافق مع المظهر
  Future<void> _selectDate(BuildContext context, bool isStart, bool isDarkMode) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDarkMode ? accentGold : primaryColor,
              onPrimary: Colors.white,
              surface: isDarkMode ? const Color(0xff1e293b) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
            dialogBackgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  createCycle() async {
    if (startDate == null || endDate == null || year.text.isEmpty || cycleNumber.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول واختيار التواريخ")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await cycleService.createCycle(
        type: type,
        year: int.parse(year.text),
        cycleNumber: int.parse(cycleNumber.text),
        startDate: startDate.toString(),
        endDate: endDate.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text("تم إنشاء الدورة بنجاح 🎉")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text("حدث خطأ: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف
        title: Text("إنشاء دورة جديدة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // 🧊 3. كرت إنشاء الدورة الزجاجي
                  _buildGlassContainer(
                    isDarkMode: isDarkMode,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        // نوع الدورة
                        DropdownButtonFormField<String>(
                          value: type,
                          dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          decoration: _glassInputDecoration("نوع الدورة", Icons.wb_sunny_outlined, isDarkMode),
                          items: const [
                            DropdownMenuItem(value: "صيف", child: Text("دورة صيفية")),
                            DropdownMenuItem(value: "شتاء", child: Text("دورة شتوية")),
                          ],
                          onChanged: (v) => setState(() => type = v!),
                        ),
                        const SizedBox(height: 16),

                        // السنة ورقم الدورة في صف واحد
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: year,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                decoration: _glassInputDecoration("السنة", Icons.calendar_today, isDarkMode),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: cycleNumber,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                decoration: _glassInputDecoration("رقم الدورة", Icons.numbers, isDarkMode),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // تاريخ البداية بستايل زجاجي
                        _buildDatePicker(
                          label: startDate == null ? "تاريخ البداية" : startDate.toString().split(" ")[0],
                          icon: Icons.date_range,
                          isDarkMode: isDarkMode,
                          onTap: () => _selectDate(context, true, isDarkMode),
                        ),
                        const SizedBox(height: 16),

                        // تاريخ النهاية بستايل زجاجي
                        _buildDatePicker(
                          label: endDate == null ? "تاريخ النهاية" : endDate.toString().split(" ")[0],
                          icon: Icons.event_available,
                          isDarkMode: isDarkMode,
                          onTap: () => _selectDate(context, false, isDarkMode),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // 🚀 زر الإنشاء الزجاجي
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : createCycle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: Colors.black38,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("تأكيد إنشاء الدورة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🧊 دالة الحاوية الزجاجية (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // 🧊 دالة حقول الإدخال الزجاجية
  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15), 
        borderSide: BorderSide(color: isDarkMode ? accentGold : primaryColor, width: 1.5),
      ),
    );
  }

  // 🧊 أداة اختيار التاريخ (بستايل زجاجي متناسق مع الحقول)
  Widget _buildDatePicker({required String label, required IconData icon, required bool isDarkMode, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
          border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDarkMode ? accentGold : primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label, 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white70 : Colors.black87), 
                overflow: TextOverflow.ellipsis
              )
            ),
          ],
        ),
      ),
    );
  }
}