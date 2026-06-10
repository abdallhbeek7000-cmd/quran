import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; 
import '../models/session_model.dart';
import '../services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; 
import '../services/theme_provider.dart'; 
import '../services/notification_service.dart'; 
import '../services/notification_queue_manager.dart'; // 🚀 استيراد مدير طابور الإشعارات
import '../widgets/offline_wrapper.dart'; 

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

  final newMemorization = TextEditingController();
  final newReview = TextEditingController(); 
  final oldReview = TextEditingController(); 
  
  final newHomeworkController = TextEditingController();
  final newReviewHomeworkController = TextEditingController(); 
  final oldReviewHomeworkController = TextEditingController(); 

  final readingBySight = TextEditingController(); 
  final religiousActivities = TextEditingController();
  final notes = TextEditingController();
  final absenceReasonController = TextEditingController(); 
  final examScoreController = TextEditingController(); 
  
  final totalMemorizedPagesController = TextEditingController();

  bool loading = false;
  bool absent = false;
  bool isExam = false; 
  
  bool hasNewMemorization = true;
  bool hasReview = true;
  bool hasReading = true; 

  String absenceType = "بدون عذر"; 
  
  String memorizationRating = "جيد"; 
  String reviewRating = "جيد";       
  
  String studentStatus = "مهذب";

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
    
    newMemorization.addListener(_extractHighestPageNumber);

    _checkIfStudentIsCompleted();
    _loadPreviousSessionData(); 
  }

  @override
  void dispose() {
    _bgController.dispose(); 
    newMemorization.removeListener(_extractHighestPageNumber);
    newMemorization.dispose();
    newReview.dispose();
    oldReview.dispose();
    newHomeworkController.dispose();
    newReviewHomeworkController.dispose();
    oldReviewHomeworkController.dispose();
    readingBySight.dispose();
    religiousActivities.dispose();
    notes.dispose();
    absenceReasonController.dispose();
    examScoreController.dispose();
    totalMemorizedPagesController.dispose();
    super.dispose();
  }

  void _listen(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (val) => print('onError: $val'),
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

  void _extractHighestPageNumber() {
    if (isCompletedStudent || absent || isExam) return;
    
    String text = newMemorization.text;
    RegExp regExp = RegExp(r'\d+');
    Iterable<Match> matches = regExp.allMatches(text);
    
    if (matches.isNotEmpty) {
      List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();
      int maxNumber = numbers.reduce((a, b) => a > b ? a : b);
      
      if (maxNumber > 0 && maxNumber <= 604) {
        if (totalMemorizedPagesController.text != maxNumber.toString()) {
          totalMemorizedPagesController.text = maxNumber.toString();
        }
      }
    }
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

          Timestamp? tA = dataA['timestamp'] as Timestamp?;
          Timestamp? tB = dataB['timestamp'] as Timestamp?;
          
          if (tA != null && tB != null) return tB.compareTo(tA);
          
          String dateA = dataA['date'] ?? '';
          String dateB = dataB['date'] ?? '';
          return dateB.compareTo(dateA); 
        });

        final lastSession = docs.first.data();
        
        if (mounted) {
          setState(() {
            newMemorization.text = lastSession['newHomework'] ?? '';
            newReview.text = lastSession['newReviewHomework'] ?? '';
            oldReview.text = lastSession['oldReviewHomework'] ?? '';
          });
          _extractHighestPageNumber();
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
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب اختيار مشرف واحد على الأقل")));
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

  addSession() async {
    final hasToday = await sessionService.hasSessionToday(widget.studentId);
    if (hasToday) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("تم تسجيل جلسة اليوم مسبقًا")));
      return;
    }

    if (isExam && !absent && examScoreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("يرجى إدخال علامة الاختبار أولاً")));
      return;
    }

    setState(() => loading = true);
    final now = DateTime.now();
    final date = "${now.year}-${now.month}-${now.day}";

    String finalNewMemo = (!hasNewMemorization || absent || isExam || isCompletedStudent) ? '' : newMemorization.text.trim();
    String finalNearReview = (!hasReview || absent || isExam || isCompletedStudent) ? '' : newReview.text.trim();
    String finalFarReview = (!hasReview || absent || isExam) ? '' : oldReview.text.trim();
    
    String finalReading = (!hasReading || absent || isExam) ? '' : readingBySight.text.trim();
    
    String finalMemoRating = (!hasNewMemorization || absent || isExam || isCompletedStudent) ? '' : memorizationRating;
    String finalRevRating = (!hasReview || absent || isExam) ? '' : reviewRating;

    String finalNewHW = (absent || isExam || isCompletedStudent) ? '' : newHomeworkController.text.trim();
    String finalNewRevHW = (absent || isExam || isCompletedStudent) ? '' : newReviewHomeworkController.text.trim();
    String finalOldRevHW = (absent || isExam) ? '' : oldReviewHomeworkController.text.trim();
    
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

    final session = SessionModel(
      id: '',
      studentId: widget.studentId,
      studentName: widget.studentName,
      supervisorId: selectedSupervisors.first['id']!, 
      supervisorName: selectedSupervisors.first['name']!, 
      date: date,
      absent: absent,
      newMemorization: finalNewMemo,
      review: (absent || isExam || !hasReview) ? '' : (isCompletedStudent ? finalFarReview : "$finalNearReview | $finalFarReview"),
      homework: combinedHW,
      rating: (absent || isExam) ? '' : (isCompletedStudent ? finalRevRating : (hasNewMemorization ? finalMemoRating : finalRevRating)),
      studentStatus: (absent || isExam) ? '' : studentStatus,
      religiousActivities: (absent || isExam) ? '' : religiousActivities.text.trim(),
      notes: notes.text.trim(),
    );

    double totalPages = isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0);

    List<String> supervisorIdsList = selectedSupervisors.map((e) => e['id']!).toList();
    List<String> supervisorNamesList = selectedSupervisors.map((e) => e['name']!).toList();

    final Map<String, dynamic> sessionData = {
      'studentId': session.studentId,
      'studentName': session.studentName,
      'supervisorId': session.supervisorId, 
      'supervisorName': session.supervisorName,
      'supervisorIds': supervisorIdsList,      
      'supervisorNames': supervisorNamesList, 
      'timestamp': FieldValue.serverTimestamp(), 
      'date': session.date,
      'absent': session.absent,
      'isExam': isExam, 
      'examScore': isExam && !absent ? examScoreController.text.trim() : '', 
      'newMemorization': session.newMemorization,
      'nearReview': finalNearReview, 
      'farReview': finalFarReview,   
      'homework': session.homework,
      'newHomework': finalNewHW, 
      'newReviewHomework': finalNewRevHW, 
      'oldReviewHomework': finalOldRevHW, 
      'readingBySight': finalReading,
      'memorizationRating': finalMemoRating,
      'reviewRating': finalRevRating,
      'rating': session.rating, 
      'studentStatus': session.studentStatus,
      'religiousActivities': session.religiousActivities,
      'notes': session.notes,
      'absenceType': absent ? absenceType : '', 
      'absenceReason': absent ? absenceReasonController.text.trim() : '', 
      if (!absent && !isExam) 'total_memorized_pages': totalPages,
    };

    FirebaseFirestore.instance.collection('sessions').add(sessionData);

    final studentRef = FirebaseFirestore.instance.collection('students').doc(widget.studentId);
    
    if (absent) {
      studentRef.update({'consecutiveAbsences': FieldValue.increment(1)});
    } else {
      final Map<String, dynamic> updateData = {'consecutiveAbsences': 0};
      if (!isExam && !isCompletedStudent && totalMemorizedPagesController.text.trim().isNotEmpty) {
        updateData['memorizedPages'] = totalPages;
      }
      studentRef.update(updateData);
    }

    String notifyTitle = "";
    String notifyBody = "";
    String notifyType = "regular";

    if (absent) {
      notifyTitle = "🚨 تنبيه غياب الطالب";
      notifyBody = "تم تسجيل غياب لـ ${widget.studentName} في حلقة اليوم، نوع الغياب: ($absenceType)";
      notifyType = "absent";
    } else if (isExam) {
      notifyTitle = "📝 نتيجة اختبار جديدة";
      notifyBody = "تم توثيق نتيجة اختبار لـ ${widget.studentName} بعلامة (${examScoreController.text.trim()} من 100)";
      notifyType = "exam";
    } else {
      notifyTitle = "📢 تحديث يومي من الحلقة";
      String bodyText = isCompletedStudent ? "تم تحديث سجل مراجعة الختمة الشاملة لـ ${widget.studentName} بنجاح" : "تم تسجيل يومية جديدة لـ ${widget.studentName}";
      if (hasNewMemorization && finalMemoRating.isNotEmpty) bodyText += "، الحفظ: ($finalMemoRating)";
      if (hasReview && finalRevRating.isNotEmpty) bodyText += "، المراجعة: ($finalRevRating)";
      notifyBody = bodyText;
      notifyType = "regular";
    }

    // 🚀 التعديل الأهم: إرسال الإشعار وتخزينه في الطابور إذا فشل
    NotificationService.sendAndSaveNotification(
      studentId: widget.studentId, title: notifyTitle, body: notifyBody, type: notifyType, context: context, 
    ).then((_) {
      print("✅ تم إرسال الإشعار فوراً (أونلاين)");
    }).catchError((error) async {
      print("⚠️ فشل الإرسال أو انقطع الاتصال، جاري تحويل الإشعار لطابور الانتظار: $error");
      
      // حفظ الإشعار أوفلاين ليتم إرساله لاحقاً
      await NotificationQueueManager.addToQueue(
        studentId: widget.studentId,
        title: notifyTitle,
        body: notifyBody,
        type: notifyType,
      );
    });

    if (!mounted) return;
    setState(() => loading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      backgroundColor: Colors.blueGrey, 
      content: Text("تم حفظ الجلسة (ستتم المزامنة عند توفر الإنترنت)")
    ));
    
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
        title: Text(title, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
        value: value,
        onChanged: (v) => onChanged(v!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
          title: Text(widget.studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
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
                                  decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                  child: SwitchListTile(
                                    activeColor: Colors.orange,
                                    value: absent,
                                    title: Text("تسجيل الطالب غائب؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                    secondary: Icon(absent ? Icons.person_off : Icons.person, color: isDarkMode ? Colors.white70 : primaryColor),
                                    onChanged: (v) {
                                      setState(() { absent = v; if (absent) isExam = false; });
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
                                      title: Text("تسجيل كـ (جلسة اختبار) ؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                      secondary: Icon(Icons.assignment_turned_in, color: isExam ? Colors.teal : (isDarkMode ? Colors.white70 : primaryColor)),
                                      onChanged: (v) { setState(() { isExam = v; }); },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!absent && !isExam) ...[
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
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: newMemorization, 
                                      decoration: _glassInputDecoration("الحفظ الجديد", Icons.star_border, isDarkMode, suffixIcon: _buildMicButton(newMemorization, isDarkMode))
                                    ),
                                    const SizedBox(height: 15),
                                  ],

                                  if (hasReview) ...[
                                    if (!isCompletedStudent) ...[
                                      TextField(
                                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                        controller: newReview, 
                                        decoration: _glassInputDecoration("مراجعة جديد", Icons.auto_stories_outlined, isDarkMode, suffixIcon: _buildMicButton(newReview, isDarkMode))
                                      ),
                                      const SizedBox(height: 15),
                                    ],
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: oldReview, 
                                      decoration: _glassInputDecoration(
                                        isCompletedStudent ? "المقدار المسموع من مراجعة الختمة الشاملة" : "مراجعة قديم", 
                                        isCompletedStudent ? Icons.verified_user_rounded : Icons.history_outlined, 
                                        isDarkMode,
                                        suffixIcon: _buildMicButton(oldReview, isDarkMode)
                                      )
                                    ),
                                    const SizedBox(height: 15),
                                  ],

                                  if (hasReading) ...[
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: readingBySight, 
                                      decoration: _glassInputDecoration("المقدار المقروء نظراً من المصحف", Icons.menu_book_outlined, isDarkMode, suffixIcon: _buildMicButton(readingBySight, isDarkMode))
                                    ),
                                    const SizedBox(height: 15),
                                  ],
                                  
                                  if (isCompletedStudent) ...[
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: oldReviewHomeworkController, 
                                      decoration: _glassInputDecoration("المقدار المطلوب للمرة القادمة", Icons.edit_note, isDarkMode, suffixIcon: _buildMicButton(oldReviewHomeworkController, isDarkMode))
                                    ),
                                  ] else ...[
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: newHomeworkController, 
                                      decoration: _glassInputDecoration("واجب الحفظ الجديد القادم", Icons.edit_document, isDarkMode, suffixIcon: _buildMicButton(newHomeworkController, isDarkMode))
                                    ),
                                    const SizedBox(height: 15),
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: newReviewHomeworkController, 
                                      decoration: _glassInputDecoration("واجب المراجعة الجديد القادم", Icons.menu_book_rounded, isDarkMode, suffixIcon: _buildMicButton(newReviewHomeworkController, isDarkMode))
                                    ),
                                    const SizedBox(height: 15),
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
                                      controller: oldReviewHomeworkController, 
                                      decoration: _glassInputDecoration("واجب المراجعة القديم القادم", Icons.history_edu_rounded, isDarkMode, suffixIcon: _buildMicButton(oldReviewHomeworkController, isDarkMode))
                                    ),
                                  ],
                                  
                                  if (!isCompletedStudent) ...[
                                    const SizedBox(height: 20),
                                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                                    const SizedBox(height: 10),
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold), 
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
                              title: "التقييم والسلوك",
                              icon: Icons.thumbs_up_down_outlined,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  if (!isCompletedStudent && hasNewMemorization) ...[
                                    DropdownButtonFormField<String>(
                                      value: memorizationRating,
                                      dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                      decoration: _glassInputDecoration("تقييم الحفظ الجديد", Icons.stars, isDarkMode),
                                      items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                      onChanged: (v) => setState(() => memorizationRating = v!),
                                    ),
                                    const SizedBox(height: 15),
                                  ],

                                  if (hasReview) ...[
                                    DropdownButtonFormField<String>(
                                      value: reviewRating,
                                      dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                      decoration: _glassInputDecoration(isCompletedStudent ? "تقييم مراجعة الختمة" : "تقييم المراجعة", Icons.rate_review_outlined, isDarkMode),
                                      items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                      onChanged: (v) => setState(() => reviewRating = v!),
                                    ),
                                    const SizedBox(height: 15),
                                  ],

                                  DropdownButtonFormField<String>(
                                    value: studentStatus,
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
                              child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: religiousActivities, decoration: _glassInputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode, suffixIcon: _buildMicButton(religiousActivities, isDarkMode))),
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
                                          label: Text(s['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
                                  Text("نوع الغياب:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : primaryColor)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text("بدون عذر"),
                                        selected: absenceType == "بدون عذر",
                                        selectedColor: Colors.red.shade400,
                                        backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
                                        labelStyle: TextStyle(color: absenceType == "بدون عذر" ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87)),
                                        onSelected: (val) => setState(() => absenceType = "بدون عذر"),
                                      ),
                                      const SizedBox(width: 15),
                                      ChoiceChip(
                                        label: const Text("بعذر"),
                                        selected: absenceType == "بعذر",
                                        selectedColor: Colors.green.shade400,
                                        backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
                                        labelStyle: TextStyle(color: absenceType == "بعذر" ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87)),
                                        onSelected: (val) => setState(() => absenceType = "بعذر"),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  TextField(
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                                    controller: absenceReasonController,
                                    decoration: _glassInputDecoration("سبب الغياب (اختياري مثل: مرض، سفر...)", Icons.help_outline, isDarkMode, suffixIcon: _buildMicButton(absenceReasonController, isDarkMode)),
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
                            child: TextField(style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), controller: notes, maxLines: 3, decoration: _glassInputDecoration("اكتب ملاحظاتك هنا...", Icons.comment, isDarkMode, suffixIcon: _buildMicButton(notes, isDarkMode))),
                          ),
                          
                          const SizedBox(height: 35),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: loading ? null : addSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: absent ? Colors.orange.withOpacity(0.9) : (isExam ? Colors.teal.withOpacity(0.9) : (isDarkMode ? Colors.orange.withOpacity(0.9) : primaryColor.withOpacity(0.9))),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Colors.black38,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("حفظ الجلسة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600),
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