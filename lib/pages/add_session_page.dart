import 'dart:io'; 
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; 
// 🚀 استيراد حزمة الجدولة بالخلفية المضافة
import 'package:workmanager/workmanager.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import '../services/theme_provider.dart'; 
import '../services/notification_service.dart'; 
import '../services/notification_queue_manager.dart'; 
import '../widgets/offline_wrapper.dart'; 
import '../widgets/glass_toast.dart'; 

class AddSessionPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String supervisorId;
  final String supervisorName;

  const AddSessionPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<AddSessionPage> createState() => _AddSessionPageState();
}

class _AddSessionPageState extends State<AddSessionPage> with SingleTickerProviderStateMixin {
  final sessionService = SessionService();
  
  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  TextEditingController? _activeController;
  String _initialText = '';

  final newMemoFrom = TextEditingController();
  final newMemoTo = TextEditingController();

  final newRevFrom = TextEditingController();
  final newRevTo = TextEditingController();

  List<Map<String, TextEditingController>> oldReviewRanges = [
    {'from': TextEditingController(), 'to': TextEditingController()}
  ];

  final readingFrom = TextEditingController();
  final readingTo = TextEditingController();

  final newHwFrom = TextEditingController();
  final newHwTo = TextEditingController();

  final newRevHwFrom = TextEditingController();
  final newRevHwTo = TextEditingController();

  List<Map<String, TextEditingController>> oldRevHwRanges = [
    {'from': TextEditingController(), 'to': TextEditingController()}
  ];

  final religiousActivities = TextEditingController();
  final notes = TextEditingController();
  final absenceReasonController = TextEditingController(); 
  final examScoreController = TextEditingController(); 
  final totalMemorizedPagesController = TextEditingController();

  bool loading = false;
  bool absent = false;
  bool isExam = false; 
  bool didNotRecite = false; 
  
  bool hasNewMemorization = true;
  bool hasReview = true;
  bool hasReading = false; 

  String absenceType = "بدون عذر"; 
  String memorizationRating = "جيد"; 
  String newReviewRating = "جيد"; 
  String oldReviewRating = "جيد";     
  String studentStatus = "مهذب";

  DateTime _selectedDate = DateTime.now();

  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  List<Map<String, String>> selectedSupervisors = [];

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 

  @override
  void initState() {
    super.initState();
    
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));

    _speech = stt.SpeechToText(); 

    selectedSupervisors.add({
      'id': widget.supervisorId,
      'name': widget.supervisorName
    });
    
    newMemoTo.addListener(_updateTotalPages);
    newMemoFrom.addListener(_updateTotalPages);

    _checkIfStudentIsCompleted();
    _loadPreviousSessionData(); 
  }

  @override
  void dispose() {
    _bgController.dispose(); 
    newMemoTo.removeListener(_updateTotalPages);
    newMemoFrom.removeListener(_updateTotalPages);
    
    newMemoFrom.dispose(); newMemoTo.dispose();
    newRevFrom.dispose(); newRevTo.dispose();
    readingFrom.dispose(); readingTo.dispose();
    newHwFrom.dispose(); newHwTo.dispose();
    newRevHwFrom.dispose(); newRevHwTo.dispose();
    
    for (var range in oldReviewRanges) {
      range['from']?.dispose(); range['to']?.dispose();
    }
    for (var range in oldRevHwRanges) {
      range['from']?.dispose(); range['to']?.dispose();
    }

    religiousActivities.dispose();
    notes.dispose();
    absenceReasonController.dispose();
    examScoreController.dispose();
    totalMemorizedPagesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isDarkMode) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentGold, 
              onPrimary: Colors.white, 
              onSurface: isDarkMode ? Colors.white : primaryColor, 
            ),
            dialogBackgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: accentGold),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _updateTotalPages() {
    if (isCompletedStudent || absent || isExam || didNotRecite) return;
    int from = int.tryParse(newMemoFrom.text) ?? 0;
    int to = int.tryParse(newMemoTo.text) ?? 0;
    int maxPage = from > to ? from : to;
    if (maxPage > 0 && maxPage <= 604) {
      totalMemorizedPagesController.text = maxPage.toString();
    }
  }

  String _buildRangeString(TextEditingController fromCtrl, TextEditingController toCtrl) {
    String from = fromCtrl.text.trim();
    String to = toCtrl.text.trim();
    if (from.isEmpty && to.isEmpty) return "";
    if (from.isNotEmpty && to.isEmpty) return from;
    if (from.isEmpty && to.isNotEmpty) return to;
    return "$from - $to"; 
  }

  String _buildMultiRangeString(List<Map<String, TextEditingController>> ranges) {
    List<String> parts = [];
    for (var range in ranges) {
      String val = _buildRangeString(range['from']!, range['to']!);
      if (val.isNotEmpty) parts.add(val);
    }
    return parts.join(" | ");
  }

  void _showStaffSelectionBottomSheet(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                    border: Border(top: BorderSide(color: isDarkMode ? Colors.white24 : Colors.white, width: 1.5)),
                  ),
                  child: Column(
                    children: [
                      Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 20),
                      Text("حدد المشرفين المشاركين", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                      const SizedBox(height: 15),
                      Expanded(
                        child: FutureBuilder<List<QuerySnapshot>>(
                          future: Future.wait([
                            FirebaseFirestore.instance.collection('users').get(),
                            FirebaseFirestore.instance.collection('supervisors').get()
                          ]),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                            
                            List<Map<String, String>> allStaff = [];
                            if (snapshot.hasData) {
                              for (var doc in snapshot.data![0].docs) {
                                allStaff.add({'id': doc.id, 'name': (doc.data() as Map)['name'] ?? 'مدير'});
                              }
                              for (var doc in snapshot.data![1].docs) {
                                allStaff.add({'id': doc.id, 'name': (doc.data() as Map)['name'] ?? 'مشرف'});
                              }
                            }

                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: allStaff.length,
                              itemBuilder: (context, index) {
                                final staff = allStaff[index];
                                final isSelected = selectedSupervisors.any((s) => s['id'] == staff['id']);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? accentGold.withOpacity(0.2) : (isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: isSelected ? accentGold : Colors.transparent),
                                  ),
                                  child: CheckboxListTile(
                                    activeColor: accentGold,
                                    title: Text(staff['name']!, style: TextStyle(fontFamily: 'Cairo', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDarkMode ? Colors.white : Colors.black87)),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          selectedSupervisors.add(staff);
                                        } else {
                                          if (selectedSupervisors.length > 1) {
                                            selectedSupervisors.removeWhere((s) => s['id'] == staff['id']);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب اختيار مشرف واحد على الأقل", style: TextStyle(fontFamily: 'Cairo'))));
                                          }
                                        }
                                      });
                                      setState(() {}); 
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _parseRangeIntoControllers(String text, TextEditingController fromCtrl, TextEditingController toCtrl) {
    if (text.isEmpty) return;
    var parts = text.split('-');
    if (parts.length == 2) {
      fromCtrl.text = parts[0].trim();
      toCtrl.text = parts[1].trim();
    } else {
      fromCtrl.text = text.trim();
    }
  }

  void _parseMultiRangeIntoControllers(String text, List<Map<String, TextEditingController>> ranges) {
    ranges.clear();
    if (text.isEmpty) {
      ranges.add({'from': TextEditingController(), 'to': TextEditingController()});
      return;
    }
    var parts = text.split('|');
    for (var part in parts) {
      var ctrlFrom = TextEditingController();
      var ctrlTo = TextEditingController();
      _parseRangeIntoControllers(part, ctrlFrom, ctrlTo);
      ranges.add({'from': ctrlFrom, 'to': ctrlTo});
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (e) {
      return DateTime(2000); 
    }
    return DateTime(2000);
  }

  Future<void> _loadPreviousSessionData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var docs = querySnapshot.docs.toList();
        
        docs.sort((a, b) {
          var dataA = a.data();
          var dataB = b.data();

          DateTime dateAObj = _parseDate(dataA['date'] ?? '');
          DateTime dateBObj = _parseDate(dataB['date'] ?? '');

          int dateComparison = dateBObj.compareTo(dateAObj);

          if (dateComparison == 0) {
            Timestamp? tA = dataA['timestamp'] as Timestamp?;
            Timestamp? tB = dataB['timestamp'] as Timestamp?;
            if (tA != null && tB != null) return tB.compareTo(tA);
            if (tA == null && tB != null) return -1;
            if (tB == null && tA != null) return 1;
          }
          return dateComparison;
        });

        final lastSession = docs.first.data();
        if (mounted) {
          setState(() {
            _parseRangeIntoControllers(lastSession['newHomework'] ?? '', newMemoFrom, newMemoTo);
            _parseRangeIntoControllers(lastSession['newReviewHomework'] ?? '', newRevFrom, newRevTo);
            _parseMultiRangeIntoControllers(lastSession['oldReviewHomework'] ?? '', oldReviewRanges);
          });
          _updateTotalPages();
        }
      }
    } catch (e) {
      print("❌ خطأ في جلب الجلسة السابقة: $e");
    }
  }

  Future<void> _checkIfStudentIsCompleted() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance.collection('students').doc(widget.studentId).get();
      if (studentDoc.exists && studentDoc.data() != null) {
        Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;
        if (data['studentType'] == 'completed') {
          setState(() => isCompletedStudent = true);
        }
      }
    } catch (e) {
      print("Error checking student type: $e");
    } finally {
      setState(() => checkingStudentType = false);
    }
  }

  void _listen(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        setState(() {
          _isListening = true;
          _activeController = controller;
          _initialText = controller.text; 
        });
        _speech.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _activeController!.text = _initialText + (val.recognizedWords.isNotEmpty ? ' ' + val.recognizedWords : '');
                _activeController!.selection = TextSelection.fromPosition(TextPosition(offset: _activeController!.text.length));
              });
            }
          },
          localeId: 'ar-SA', 
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  addSession() async {
    setState(() => loading = true);
    final date = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";

    final result = await FirebaseFirestore.instance
        .collection('sessions')
        .where('studentId', isEqualTo: widget.studentId)
        .where('date', isEqualTo: date)
        .get();

    if (result.docs.isNotEmpty) {
      if (!mounted) return;
      setState(() => loading = false);
      GlassToast.show(
        context,
        title: "تنبيه",
        message: "تم تسجيل جلسة في هذا التاريخ مسبقاً ⚠️",
        icon: Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
      );
      return;
    }

    if (isExam && !absent && examScoreController.text.trim().isEmpty) {
      setState(() => loading = false);
      GlassToast.show(
        context,
        title: "بيانات ناقصة",
        message: "يرجى إدخال علامة الاختبار أولاً ❌",
        icon: Icons.error_outline_rounded,
        color: Colors.redAccent,
      );
      return;
    }

    String finalNewMemo = (!hasNewMemorization || absent || isExam || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newMemoFrom, newMemoTo);
    String finalNearReview = (!hasReview || absent || isExam || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newRevFrom, newRevTo);
    String finalFarReview = (!hasReview || absent || isExam || didNotRecite) ? '' : _buildMultiRangeString(oldReviewRanges);
    String finalReading = (!hasReading || absent || isExam || didNotRecite) ? '' : _buildRangeString(readingFrom, readingTo);
    
    String finalMemoRating = (!hasNewMemorization || absent || isExam || isCompletedStudent || didNotRecite) ? '' : memorizationRating;
    
    String finalNewRevRating = (!hasReview || absent || isExam || isCompletedStudent || didNotRecite) ? '' : newReviewRating;
    String finalOldRevRating = (!hasReview || absent || isExam || isCompletedStudent || didNotRecite) ? '' : oldReviewRating;
    
    String finalFallbackRevRating = isCompletedStudent ? newReviewRating : (finalNewRevRating.isNotEmpty ? finalNewRevRating : finalOldRevRating);

    String finalNewHW = (absent || isExam || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newHwFrom, newHwTo);
    String finalNewRevHW = (absent || isExam || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newRevHwFrom, newRevHwTo);
    String finalOldRevHW = (absent || isExam || didNotRecite) ? '' : _buildMultiRangeString(oldRevHwRanges);
    
    String combinedHW = "";
    if (isCompletedStudent) {
      combinedHW = finalOldRevHW; 
    } else {
      if (finalNewHW.isNotEmpty) combinedHW += "حفظ: $finalNewHW";
      List<String> revParts = [];
      if (finalNewRevHW.isNotEmpty) revParts.add(finalNewRevHW);
      if (finalOldRevHW.isNotEmpty) revParts.add(finalOldRevHW);
      String combinedRev = revParts.join(" | ");

      if (combinedRev.isNotEmpty) {
        combinedHW += (combinedHW.isNotEmpty ? " \n " : "") + "مراجعة: $combinedRev";
      }
    }

    double totalPages = isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0);
    List<String> supervisorIdsList = selectedSupervisors.map((e) => e['id']!).toList();
    List<String> supervisorNamesList = selectedSupervisors.map((e) => e['name']!).toList();

    final Map<String, dynamic> sessionData = {
      'studentId': widget.studentId,
      'studentName': widget.studentName,
      'supervisorId': supervisorIdsList.isNotEmpty ? supervisorIdsList.first : '', 
      'supervisorName': supervisorNamesList.isNotEmpty ? supervisorNamesList.first : '',
      'supervisorIds': supervisorIdsList,      
      'supervisorNames': supervisorNamesList, 
      'timestamp': FieldValue.serverTimestamp(), 
      'date': date,
      'absent': absent,
      'isExam': isExam, 
      'didNotRecite': didNotRecite, 
      'examScore': isExam && !absent ? examScoreController.text.trim() : '', 
      'newMemorization': finalNewMemo,
      'nearReview': finalNearReview, 
      'farReview': finalFarReview,   
      'homework': combinedHW,
      'newHomework': finalNewHW, 
      'newReviewHomework': finalNewRevHW, 
      'oldReviewHomework': finalOldRevHW, 
      'readingBySight': finalReading,
      'memorizationRating': finalMemoRating,
      'newReviewRating': finalNewRevRating, 
      'oldReviewRating': finalOldRevRating, 
      'reviewRating': (absent || isExam || didNotRecite) ? '' : finalFallbackRevRating, 
      'rating': (absent || isExam || didNotRecite) ? '' : (isCompletedStudent ? finalFallbackRevRating : (hasNewMemorization ? finalMemoRating : finalFallbackRevRating)), 
      'studentStatus': (absent || isExam) ? '' : studentStatus, 
      'religiousActivities': (absent || isExam) ? '' : religiousActivities.text.trim(),
      'notes': notes.text.trim(),
      'absenceType': absent ? absenceType : '', 
      'absenceReason': absent ? absenceReasonController.text.trim() : '', 
      if (!absent && !isExam && !didNotRecite) 'total_memorized_pages': totalPages,
    };

    // 🚀 جدولة مهمة مزامنة فورية بالخلفية قسراً بمجرد قيام المشرف بالضغط على حفظ الجلسة
    Workmanager().registerOneOffTask(
      "sync_task_${DateTime.now().millisecondsSinceEpoch}", 
      "sync_sessions_data",
      constraints: Constraints(
        networkType: NetworkType.connected, // لا تعمل إلا عند شبك الهاتف بالإنترنت
      ),
    );

    FirebaseFirestore.instance.collection('sessions').add(sessionData).then((_) {
      sessionService.recalculateConsecutiveAbsences(widget.studentId);
    });

    if (!absent && !isExam && !didNotRecite && !isCompletedStudent && totalMemorizedPagesController.text.trim().isNotEmpty) {
      FirebaseFirestore.instance.collection('students').doc(widget.studentId).update({
        'memorizedPages': totalPages,
      });
    }

    String notifyTitle = absent ? "🚨 تنبيه غياب الطالب" : (isExam ? "📝 نتيجة اختبار جديدة" : (didNotRecite ? "ℹ️ حضور بدون تسميع" : "📢 تحديث يومي من الحلقة"));
    String notifyBody = absent ? "تم تسجيل غياب لـ ${widget.studentName} في حلقة اليوم، نوع الغياب: ($absenceType)" 
      : (isExam ? "تم توثيق نتيجة اختبار لـ ${widget.studentName} بعلامة (${examScoreController.text.trim()} من 100)" 
      : (didNotRecite ? "حضر الطالب ${widget.studentName} في حلقة اليوم ولكنه لم يسمّع أو يقرأ شيئاً ⚠️" 
      : (isCompletedStudent ? "تم تحديث سجل مراجعة الختمة الشاملة لـ ${widget.studentName} بنجاح" : "تم تسجيل يومية جديدة لـ ${widget.studentName}")));
    
    if (!absent && !isExam && !didNotRecite) {
       if (hasNewMemorization && finalMemoRating.isNotEmpty) notifyBody += "، الحفظ: ($finalMemoRating)";
       if (hasReview) {
         if (isCompletedStudent) {
           notifyBody += "، المراجعة: ($finalFallbackRevRating)";
         } else {
           if (finalNewRevRating.isNotEmpty) notifyBody += "، مراجعة الجديد: ($finalNewRevRating)";
           if (finalOldRevRating.isNotEmpty) notifyBody += "، مراجعة القديم: ($finalOldRevRating)";
         }
       }
    }
      
    String notifyType = absent ? "absent" : (isExam ? "exam" : (didNotRecite ? "info" : "regular"));

    NotificationService.sendAndSaveNotification(
      studentId: widget.studentId, title: notifyTitle, body: notifyBody, type: notifyType, context: context, 
    ).then((_) {
      print("✅ تم إرسال الإشعار فوراً (أونلاين)");
    }).catchError((error) async {
      print("⚠️ فشل الإرسال، جاري التحويل لطابور الانتظار: $error");
      await NotificationQueueManager.addToQueue(studentId: widget.studentId, title: notifyTitle, body: notifyBody, type: notifyType);
    });

    if (!mounted) return;
    setState(() => loading = false);
    
    GlassToast.show(
      context,
      title: "تم الحفظ",
      message: "تم تسجيل الجلسة للطالب بنجاح ✅",
      icon: Icons.check_circle_outline_rounded,
      color: Colors.greenAccent.shade400,
    );
    
    Navigator.pop(context);
  }

  Widget _buildMicButton(TextEditingController controller, bool isDarkMode) {
    bool isActive = _isListening && _activeController == controller;
    return IconButton(
      tooltip: "تحدث للإدخال",
      icon: Icon(
        isActive ? Icons.mic : Icons.mic_none,
        color: isActive ? Colors.redAccent : (isDarkMode ? Colors.white60 : Colors.black54),
      ),
      onPressed: () {
        HapticFeedback.lightImpact(); 
        _listen(controller);
      },
    );
  }

  Widget _buildToggleTile(String title, bool value, Color color, Function(bool) onChanged, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
      child: CheckboxListTile(
        activeColor: color,
        title: Text(title, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        value: value,
        onChanged: (v) => onChanged(v!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildMiniNumberInput(TextEditingController ctrl, bool isDarkMode) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        textAlign: TextAlign.center,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        decoration: InputDecoration(
          hintText: "---",
          hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black26),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildRangeRow(String title, IconData icon, TextEditingController fromCtrl, TextEditingController toCtrl, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text("من ص:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniNumberInput(fromCtrl, isDarkMode)),
              const SizedBox(width: 15),
              Text("إلى ص:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniNumberInput(toCtrl, isDarkMode)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiRangeRow(String title, IconData icon, List<Map<String, TextEditingController>> ranges, VoidCallback onAdd, VoidCallback onRemoveLast, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  if (ranges.length > 1)
                    InkWell(
                      onTap: onRemoveLast,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.remove, size: 18, color: Colors.white),
                      ),
                    ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.add, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          ...ranges.asMap().entries.map((entry) {
            int index = entry.key;
            var range = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  if (ranges.length > 1) Text("${index + 1}- ", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("من ص:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniNumberInput(range['from']!, isDarkMode)),
                  const SizedBox(width: 15),
                  Text("إلى ص:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniNumberInput(range['to']!, isDarkMode)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent, 
          title: Text(widget.studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: checkingStudentType 
            ? const Center(child: CircularProgressIndicator()) 
            : Stack(
                children: [
                  Container(
                    width: double.infinity, height: double.infinity,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  ),
                  AnimatedBuilder(
                    animation: _bgAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: -50 + _bgAnimation.value, right: -50 - (_bgAnimation.value / 2), 
                            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)))
                          ),
                          Positioned(
                            bottom: 100 - _bgAnimation.value, left: -80 + _bgAnimation.value, 
                            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)))
                          ),
                        ],
                      );
                    },
                  ),

                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        children: [
                          _buildGlassContainer(
                            isDarkMode: isDarkMode,
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.6), 
                                    borderRadius: BorderRadius.circular(15)
                                  ),
                                  child: ListTile(
                                    leading: Icon(Icons.calendar_month_rounded, color: accentGold),
                                    title: Text("تاريخ الجلسة", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Icon(Icons.edit_calendar_rounded, color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.7), size: 20),
                                      ],
                                    ),
                                    onTap: () => _pickDate(context, isDarkMode),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                
                                Container(
                                  decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                  child: SwitchListTile(
                                    activeColor: Colors.orange,
                                    value: absent,
                                    title: Text("تسجيل الطالب غائب؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                    secondary: Icon(absent ? Icons.person_off : Icons.person, color: isDarkMode ? Colors.white70 : primaryColor),
                                    onChanged: (v) {
                                      setState(() { 
                                        absent = v; 
                                        if (absent) { 
                                          isExam = false; 
                                          didNotRecite = false; 
                                        } 
                                      });
                                    },
                                  ),
                                ),
                                if (!absent) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                    child: SwitchListTile(
                                      activeColor: Colors.teal,
                                      value: isExam,
                                      title: Text("تسجيل كـ (جلسة اختبار) ؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                      secondary: Icon(Icons.assignment_turned_in, color: isExam ? Colors.teal : (isDarkMode ? Colors.white70 : primaryColor)),
                                      onChanged: (v) { 
                                        setState(() { 
                                          isExam = v; 
                                          if (isExam) didNotRecite = false; 
                                        }); 
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                    child: SwitchListTile(
                                      activeColor: Colors.blueGrey,
                                      value: didNotRecite,
                                      title: Text("حضر لكن لم يقرأ/يسمّع شيء?", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                      secondary: Icon(Icons.speaker_notes_off_outlined, color: didNotRecite ? Colors.blueGrey : (isDarkMode ? Colors.white70 : primaryColor)),
                                      onChanged: (v) { 
                                        setState(() { 
                                          didNotRecite = v; 
                                          if (didNotRecite) isExam = false; 
                                        }); 
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!absent && !isExam && !didNotRecite) ...[
                            _buildSectionCard(
                              title: isCompletedStudent ? "منظومة مراجعة الختمة الشاملة 👑" : "الإنجاز القرآني اليومي",
                              icon: Icons.menu_book,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  if (!isCompletedStudent) ...[
                                    Row(
                                      children: [
                                        Expanded(child: _buildToggleTile("حفظ جديد", hasNewMemorization, Colors.blueAccent, (v) => setState(() => hasNewMemorization = v), isDarkMode)),
                                        const SizedBox(width: 10),
                                        Expanded(child: _buildToggleTile("مراجعة", hasReview, Colors.green, (v) => setState(() => hasReview = v), isDarkMode)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  
                                  _buildToggleTile("قراءة نظراً من المصحف", hasReading, Colors.purpleAccent, (v) => setState(() => hasReading = v), isDarkMode),
                                  const SizedBox(height: 20),

                                  if (!isCompletedStudent && hasNewMemorization) ...[
                                    _buildRangeRow("الحفظ الجديد", Icons.star_border, newMemoFrom, newMemoTo, isDarkMode),
                                  ],

                                  if (hasReview) ...[
                                    if (!isCompletedStudent) ...[
                                      _buildRangeRow("مراجعة جديد", Icons.auto_stories_outlined, newRevFrom, newRevTo, isDarkMode),
                                    ],
                                    _buildMultiRangeRow(
                                      isCompletedStudent ? "المقدار المسموع من مراجعة الختمة الشاملة" : "مراجعة قديم", 
                                      isCompletedStudent ? Icons.verified_user_rounded : Icons.history_outlined, 
                                      oldReviewRanges, 
                                      () {
                                        setState(() {
                                          oldReviewRanges.add({'from': TextEditingController(), 'to': TextEditingController()});
                                        });
                                      },
                                      () {
                                        if (oldReviewRanges.length > 1) {
                                          setState(() {
                                            var removed = oldReviewRanges.removeLast();
                                            removed['from']?.dispose();
                                            removed['to']?.dispose();
                                          });
                                        }
                                      },
                                      isDarkMode
                                    ),
                                  ],

                                  if (hasReading) ...[
                                    _buildRangeRow("المقدار المقروء نظراً من المصحف", Icons.menu_book_outlined, readingFrom, readingTo, isDarkMode),
                                  ],
                                  
                                  if (!isCompletedStudent) ...[
                                    const SizedBox(height: 10),
                                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                                    const SizedBox(height: 10),
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), 
                                      controller: totalMemorizedPagesController, 
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                                      decoration: _glassInputDecoration("إجمالي عدد الصفحات المحفوظة حتى الآن", Icons.analytics_outlined, isDarkMode)
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildSectionCard(
                              title: "الواجب المطلوب للمرة القادمة",
                              icon: Icons.next_plan_outlined,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  if (isCompletedStudent) ...[
                                    _buildMultiRangeRow(
                                      "المقدار المطلوب للمرة القادمة", Icons.edit_note, oldRevHwRanges, 
                                      () { setState(() => oldRevHwRanges.add({'from': TextEditingController(), 'to': TextEditingController()})); },
                                      () { if (oldRevHwRanges.length > 1) setState(() { var r = oldRevHwRanges.removeLast(); r['from']?.dispose(); r['to']?.dispose(); }); },
                                      isDarkMode
                                    ),
                                  ] else ...[
                                    _buildRangeRow("واجب الحفظ الجديد القادم", Icons.edit_document, newHwFrom, newHwTo, isDarkMode),
                                    _buildRangeRow("واجب المراجعة الجديد القادم", Icons.menu_book_rounded, newRevHwFrom, newRevHwTo, isDarkMode),
                                    _buildMultiRangeRow(
                                      "واجب المراجعة القديم القادم", Icons.history_edu_rounded, oldRevHwRanges, 
                                      () { setState(() => oldRevHwRanges.add({'from': TextEditingController(), 'to': TextEditingController()})); },
                                      () { if (oldRevHwRanges.length > 1) setState(() { var r = oldRevHwRanges.removeLast(); r['from']?.dispose(); r['to']?.dispose(); }); },
                                      isDarkMode
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (!absent && !isExam) ...[
                            _buildSectionCard(
                              title: "التقييم والسلوك",
                              icon: Icons.thumbs_up_down_outlined,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  if (!didNotRecite && !isCompletedStudent && hasNewMemorization) ...[
                                    DropdownButtonFormField<String>(
                                      value: memorizationRating,
                                      dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                      decoration: _glassInputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                                      items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                      onChanged: (v) => setState(() => memorizationRating = v!),
                                    ),
                                    const SizedBox(height: 15),
                                  ],

                                  if (!didNotRecite && hasReview) ...[
                                    if (isCompletedStudent) ...[
                                      DropdownButtonFormField<String>(
                                        value: newReviewRating, 
                                        dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                        decoration: _glassInputDecoration("تقييم مراجعة الختمة", Icons.rate_review_outlined, isDarkMode),
                                        items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                        onChanged: (v) => setState(() => newReviewRating = v!),
                                      ),
                                    ] else ...[
                                      DropdownButtonFormField<String>(
                                        value: newReviewRating,
                                        dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                        decoration: _glassInputDecoration("تقييم مراجعة جديد", Icons.rate_review_outlined, isDarkMode),
                                        items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                        onChanged: (v) => setState(() => newReviewRating = v!),
                                      ),
                                      const SizedBox(height: 15),
                                      DropdownButtonFormField<String>(
                                        value: oldReviewRating,
                                        dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                        decoration: _glassInputDecoration("تقييم مراجعة قديم", Icons.history_edu, isDarkMode),
                                        items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                        onChanged: (v) => setState(() => oldReviewRating = v!),
                                      ),
                                    ],
                                    const SizedBox(height: 15),
                                  ],

                                  DropdownButtonFormField<String>(
                                    value: studentStatus,
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    decoration: _glassInputDecoration("حالة الطالب", Icons.mood, isDarkMode),
                                    items: ["مهذب", "منضبط", "مشاغب", "كثير الحركة"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                    onChanged: (v) => setState(() => studentStatus = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              title: "نشاطات إضافية",
                              icon: Icons.mosque_outlined,
                              isDarkMode: isDarkMode,
                              child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: religiousActivities, decoration: _glassInputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode, suffixIcon: _buildMicButton(religiousActivities, isDarkMode))),
                            ),
                          ],

                          const SizedBox(height: 20),
                          
                          _buildSectionCard(
                            title: "المشرفين المشاركين بالتسميع",
                            icon: Icons.groups_rounded,
                            isDarkMode: isDarkMode,
                            child: InkWell(
                              onTap: () => _showStaffSelectionBottomSheet(context, isDarkMode),
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: selectedSupervisors.map((s) => Chip(
                                          label: Text(s['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                                          backgroundColor: accentGold,
                                          elevation: 2,
                                          padding: const EdgeInsets.all(0),
                                        )).toList(),
                                      ),
                                    ),
                                    Icon(Icons.edit_rounded, color: isDarkMode ? accentGold : primaryColor),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (isExam && !absent) ...[
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              title: "نتائج اختبار الطالب",
                              icon: Icons.quiz,
                              isDarkMode: isDarkMode,
                              child: TextField(
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                controller: examScoreController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                                decoration: _glassInputDecoration("علامة الطالب من 100", Icons.percent, isDarkMode),
                              ),
                            ),
                          ],

                          if (absent) ...[
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              title: "تفاصيل الغياب",
                              icon: Icons.person_off_outlined,
                              isDarkMode: isDarkMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("نوع الغياب:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text("بدون عذر", style: TextStyle(fontFamily: 'Cairo')),
                                        selected: absenceType == "بدون عذر",
                                        selectedColor: Colors.red.shade400,
                                        backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
                                        labelStyle: TextStyle(color: absenceType == "بدون عذر" ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold),
                                        onSelected: (val) => setState(() => absenceType = "بدون عذر"),
                                      ),
                                      const SizedBox(width: 15),
                                      ChoiceChip(
                                        label: const Text("بعذر", style: TextStyle(fontFamily: 'Cairo')),
                                        selected: absenceType == "بعذر",
                                        selectedColor: Colors.green.shade400,
                                        backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
                                        labelStyle: TextStyle(color: absenceType == "بعذر" ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold),
                                        onSelected: (val) => setState(() => absenceType = "بعذر"),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  TextField(
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    controller: absenceReasonController,
                                    decoration: _glassInputDecoration("سبب الغياب (العذر بالتفصيل...)", Icons.help_outline, isDarkMode, suffixIcon: _buildMicButton(absenceReasonController, isDarkMode)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          _buildSectionCard(
                            title: "ملاحظات المشرف",
                            icon: Icons.note_alt_outlined,
                            isDarkMode: isDarkMode,
                            child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), controller: notes, maxLines: 3, decoration: _glassInputDecoration("اكتب ملاحظاتك هنا...", Icons.comment, isDarkMode, suffixIcon: _buildMicButton(notes, isDarkMode))),
                          ),
                          
                          const SizedBox(height: 35),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: loading ? null : addSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: absent ? Colors.orange.withOpacity(0.9) : (isExam ? Colors.teal.withOpacity(0.9) : (didNotRecite ? Colors.blueGrey.withOpacity(0.9) : (isDarkMode ? Colors.orange.withOpacity(0.9) : primaryColor.withOpacity(0.9)))),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Colors.black38,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("حفظ الجلسة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'Cairo')),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, required bool isDarkMode}) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
            ],
          ),
          Divider(height: 25, color: isDarkMode ? Colors.white24 : Colors.black12),
          child,
        ],
      ),
    );
  }

  InputDecoration _glassInputDecoration(String label, IconData icon, bool isDarkMode, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontFamily: 'Cairo', fontSize: 13),
      prefixIcon: Icon(icon, color: isDarkMode ? accentGold : primaryColor, size: 20),
      suffixIcon: suffixIcon, 
      filled: true,
      fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), 
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
}