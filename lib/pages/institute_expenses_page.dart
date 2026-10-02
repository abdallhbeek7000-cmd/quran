import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class InstituteExpensesPage extends StatefulWidget {
  final String? activeCycleId; // 👈 نمرر معرف الدورة النشطة

  const InstituteExpensesPage({super.key, this.activeCycleId});

  @override
  State<InstituteExpensesPage> createState() => _InstituteExpensesPageState();
}

class _InstituteExpensesPageState extends State<InstituteExpensesPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedCategory = 'مستلزمات ومطبوعات 📚';

  final List<String> categories = [
    'مستلزمات ومطبوعات 📚',
    'ضيافة وتكريم ☕🎂',
    'أنشطة ورحلات 🚌⚽',
    'صيانة وتجهيزات 🛠️',
    'فواتير وخدمات 💡',
    'مصاريف أخرى 📦',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog(bool isDark) {
    _titleController.clear();
    _amountController.clear();
    _notesController.clear();
    _selectedCategory = categories.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.5),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_card_rounded, color: Colors.redAccent, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "تسجيل مصروف جديد",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // بند المصروف
                          TextField(
                            controller: _titleController,
                            style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: "بند المصروف (مثلاً: شراء أقلام وأوراق)",
                              labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                              prefixIcon: Icon(Icons.edit_note_rounded, color: isDark ? accentGold : primaryColor),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // المبلغ
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: "المبلغ المصروف",
                              labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                              prefixIcon: Icon(Icons.attach_money_rounded, color: isDark ? accentGold : primaryColor),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // التصنيف
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xff1e293b) : Colors.white,
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => _selectedCategory = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ملاحظات إضافية
                          TextField(
                            controller: _notesController,
                            style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: "ملاحظات أو تفاصيل إضافية (اختياري)",
                              labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                              prefixIcon: Icon(Icons.notes_rounded, color: isDark ? accentGold : primaryColor),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 22),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () async {
                                    String title = _titleController.text.trim();
                                    double? amount = double.tryParse(_amountController.text.trim());

                                    if (title.isEmpty || amount == null || amount <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("يرجى إدخال اسم البند والمبلغ بشكل صحيح", style: TextStyle(fontFamily: 'Cairo'))),
                                      );
                                      return;
                                    }

                                    // 👈 إضافة cycleId للمستند الجديد
                                    await FirebaseFirestore.instance.collection('expenses').add({
                                      'title': title,
                                      'amount': amount,
                                      'category': _selectedCategory,
                                      'notes': _notesController.text.trim(),
                                      'timestamp': FieldValue.serverTimestamp(),
                                      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                      'cycleId': widget.activeCycleId ?? '', // حفظ معرف الدورة الحالية
                                    });

                                    if (!mounted) return;
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text("إضافة المصروف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "المعاملات المالية والمصروفات 💳",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('expenses').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                // 🔹 تجميع المصروفات وحساب المجموعات
                List<QueryDocumentSnapshot> currentCycleDocs = [];
                List<QueryDocumentSnapshot> previousCycleDocs = [];

                double currentCycleTotal = 0;
                double previousCyclesTotal = 0;

                for (var doc in docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  double amount = (data['amount'] as num? ?? 0).toDouble();
                  String docCycleId = data['cycleId'] ?? '';

                  // التمييز بناءً على معرف الدورة النشطة
                  if (widget.activeCycleId != null && widget.activeCycleId!.isNotEmpty && docCycleId == widget.activeCycleId) {
                    currentCycleDocs.add(doc);
                    currentCycleTotal += amount;
                  } else if (widget.activeCycleId == null || widget.activeCycleId!.isEmpty) {
                    // في حال عدم تمرير cycleId يعتبر كل شيء ضمن الحالية
                    currentCycleDocs.add(doc);
                    currentCycleTotal += amount;
                  } else {
                    previousCycleDocs.add(doc);
                    previousCyclesTotal += amount;
                  }
                }

                return Column(
                  children: [
                    // 🔴 كارت إجمالي إنفاق الدورة الحالية فقط
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.redAccent.withOpacity(0.12) : Colors.redAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.redAccent, size: 28),
                                    ),
                                    const SizedBox(width: 15),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("إنفاق الدورة الحالية 📍", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                                        Text(
                                          "${currentCycleTotal.toStringAsFixed(0)} ل.س",
                                          style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                FloatingActionButton.small(
                                  backgroundColor: primaryColor,
                                  onPressed: () => _showAddExpenseDialog(isDark),
                                  child: const Icon(Icons.add, color: Colors.white),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 📝 قائمة المصروفات (الحالية أولاً ثم الخط الفاصل ثم السابقة)
                    Expanded(
                      child: docs.isEmpty
                          ? Center(
                              child: Text(
                                "لا توجد مصروفات مسجلة حتى الآن 📝",
                                style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            )
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                              children: [
                                // 1️⃣ عرض مصروفات الدورة الحالية
                                ...currentCycleDocs.map((doc) => _buildExpenseCard(doc, isDark, isCurrent: true)),

                                if (currentCycleDocs.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        "لا توجد مصروفات مسجلة في الدورة الحالية",
                                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                                      ),
                                    ),
                                  ),

                                // 2️⃣ الخط الفاصل المكتوب عليه مجموع الدورات السابقة
                                if (previousCycleDocs.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade400, thickness: 1)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                                        ),
                                        child: Text(
                                          "مصروفات الدورات السابقة: ${previousCyclesTotal.toStringAsFixed(0)} ل.س 🏛️",
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? accentGold : primaryColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey.shade400, thickness: 1)),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  // 3️⃣ عرض مصروفات الدورات السابقة
                                  ...previousCycleDocs.map((doc) => _buildExpenseCard(doc, isDark, isCurrent: false)),
                                ],
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 📇 كارت عرض المصروف
  Widget _buildExpenseCard(QueryDocumentSnapshot doc, bool isDark, {required bool isCurrent}) {
    var expense = doc.data() as Map<String, dynamic>;
    String id = doc.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrent
                  ? (isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.65))
                  : (isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade100.withOpacity(0.5)), // تمييز الدورات السابقة بشفافية أقل
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white12 : Colors.white.withOpacity(0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense['title'] ?? 'مصروف',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isCurrent
                              ? (isDark ? Colors.white : primaryColor)
                              : (isDark ? Colors.white60 : Colors.black54), // لون أهفت للدورات السابقة
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${expense['category']} • ${expense['date'] ?? ''}",
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                      if (expense['notes'] != null && expense['notes'].toString().isNotEmpty)
                        Text(
                          "ملاحظة: ${expense['notes']}",
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? accentGold : primaryColor.withOpacity(0.8)),
                        ),
                    ],
                  ),
                ),
                Text(
                  "-${expense['amount']} ل.س",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isCurrent ? Colors.redAccent : Colors.redAccent.withOpacity(0.6),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('expenses').doc(id).delete();
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}