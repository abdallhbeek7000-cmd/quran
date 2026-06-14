import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:speech_to_text/speech_to_text.dart' as stt; 
import '../services/session_service.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/notification_queue_manager.dart'; 
import '../widgets/offline_wrapper.dart'; 
import '../widgets/glass_toast.dart'; 

class EditSessionPage extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> data;

  const EditSessionPage({
    super.key,
    required this.sessionId,
    required this.data,
  });

  @override
  State<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends State<EditSessionPage> with SingleTickerProviderStateMixin {
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

  List<Map<String, TextEditingController>> oldReviewRanges = [];

  final readingFrom = TextEditingController();
  final readingTo = TextEditingController();

  final newHwFrom = TextEditingController();
  final newHwTo = TextEditingController();

  final newRevHwFrom = TextEditingController();
  final newRevHwTo = TextEditingController();

  List<Map<String, TextEditingController>> oldRevHwRanges = [];

  late TextEditingController religiousActivities;
  late TextEditingController notes;
  late TextEditingController totalMemorizedPagesController;

  bool absent = false;
  bool didNotRecite = false; // 🚀 المتغير الجديد
  
  bool hasNewMemorization = true;
  bool hasReview = true;
  bool hasReading = false; 

  String memorizationRating = "جيد";
  String newReviewRating = "جيد"; 
  String oldReviewRating = "جيد"; 
  
  String studentStatus = "مهذب";
  bool loading = false;

  late DateTime _selectedDate;

  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  List<Map<String, String>> selectedSupervisors = [];

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37); 

  @override
  void initState() {
    super.initState();
    final data = widget.data;

    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));

    _speech = stt.SpeechToText(); 

    absent = data['absent'] ?? false;
    didNotRecite = data['didNotRecite'] ?? false; // 🚀 استرجاع الحالة إذا كانت محفوظة مسبقاً
    
    hasNewMemorization = (data['newMemorization'] ?? '').toString().trim().isNotEmpty;
    hasReview = (data['nearReview'] ?? '').toString().trim().isNotEmpty || 
                (data['farReview'] ?? '').toString().trim().isNotEmpty || 
                (data['review'] ?? '').toString().trim().isNotEmpty;

    hasReading = (data['readingBySight'] ?? '').toString().trim().isNotEmpty;

    if (!hasNewMemorization && !hasReview && !absent && !didNotRecite) {
      hasNewMemorization = true;
      hasReview = true;
    }

    _selectedDate = _parseDate(data['date'] ?? '');

    memorizationRating = data['memorizationRating'] ?? data['rating'] ?? "جيد";
    if (memorizationRating.isEmpty) memorizationRating = "جيد";
    
    newReviewRating = data['newReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "جيد";
    if (newReviewRating.isEmpty) newReviewRating = "جيد";

    oldReviewRating = data['oldReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "جيد";
    if (oldReviewRating.isEmpty) oldReviewRating = "جيد";

    studentStatus = (data['studentStatus'] == null || data['studentStatus'] == '') ? "مهذب" : data['studentStatus'];

    religiousActivities = TextEditingController(text: data['religiousActivities']);
    notes = TextEditingController(text: data['notes']);
    
    var initialPages = data['total_memorized_pages']?.toString() ?? '';
    totalMemorizedPagesController = TextEditingController(text: initialPages);

    if (data.containsKey('supervisorIds') && data['supervisorIds'] is List && (data['supervisorIds'] as List).isNotEmpty) {
      List ids = data['supervisorIds'];
      List names = data['supervisorNames'] ?? [];
      for (int i = 0; i < ids.length; i++) {
        selectedSupervisors.add({
          'id': ids[i].toString(),
          'name': i < names.length ? names[i].toString() : 'مشرف',
        });
      }
    } else {
      String sId = data['supervisorId'] ?? '';
      String sName = data['supervisorName'] ?? 'مشرف غير معروف';
      if (sId.isNotEmpty) {
        selectedSupervisors.add({'id': sId, 'name': sName});
      }
    }

    newMemoTo.addListener(_updateTotalPages);
    newMemoFrom.addListener(_updateTotalPages);

    _parseExistingData(data);
    _checkIfStudentIsCompleted();
  }

  DateTime _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (e) {
      return DateTime.now(); 
    }
    return DateTime.now();
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

  void _parseExistingData(Map<String, dynamic> data) {
    _parseRangeIntoControllers(data['newMemorization'] ?? '', newMemoFrom, newMemoTo);

    String fullReview = data['review'] ?? '';
    String nearRev = data['nearReview'] ?? '';
    String farRev = data['farReview'] ?? '';

    if (fullReview.contains('|') && nearRev.isEmpty && farRev.isEmpty) {
      var parts = fullReview.split('|');
      nearRev = parts[0].trim();
      farRev = parts.length > 1 ? parts.sublist(1).join('|').trim() : '';
    } else if (nearRev.isEmpty && farRev.isEmpty) {
      nearRev = fullReview;
    }

    _parseRangeIntoControllers(nearRev, newRevFrom, newRevTo);
    _parseMultiRangeIntoControllers(farRev, oldReviewRanges);

    _parseRangeIntoControllers(data['readingBySight'] ?? '', readingFrom, readingTo);

    String oldHw = data['homework'] ?? '';
    String nHw = data['newHomework'] ?? '';
    String nRevHw = data['newReviewHomework'] ?? '';
    String oRevHw = data['oldReviewHomework'] ?? '';

    if (nHw.isEmpty && nRevHw.isEmpty && oRevHw.isEmpty && oldHw.isNotEmpty) {
      String rHwLegacy = data['reviewHomework'] ?? ''; 
      if (rHwLegacy.isNotEmpty) {
        oRevHw = rHwLegacy; 
      } else {
        if (oldHw.contains('جديد:') || oldHw.contains('مراجعة:')) {
          var parts = oldHw.split(RegExp(r'\n|\|'));
          for (var p in parts) {
            if (p.contains('حفظ:') || p.contains('جديد:')) nHw = p.replaceAll(RegExp(r'حفظ:|جديد:'), '').trim();
            if (p.contains('مراجعة:')) oRevHw = p.replaceAll('مراجعة:', '').trim();
          }
        } else {
          oRevHw = oldHw; 
        }
      }
    }

    _parseRangeIntoControllers(nHw, newHwFrom, newHwTo);
    _parseRangeIntoControllers(nRevHw, newRevHwFrom, newRevHwTo);
    _parseMultiRangeIntoControllers(oRevHw, oldRevHwRanges);
  }

  void _parseRangeIntoControllers(String text, TextEditingController fromCtrl, TextEditingController toCtrl) {
    if (text.isEmpty) return;
    RegExp exp = RegExp(r'\d+');
    Iterable<Match> matches = exp.allMatches(text);
    List<String> numbers = matches.map((m) => m.group(0)!).toList();

    if (numbers.isNotEmpty) {
      fromCtrl.text = numbers[0];
      if (numbers.length > 1) {
        toCtrl.text = numbers[1];
      }
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
    if (ranges.isEmpty) {
      ranges.add({'from': TextEditingController(), 'to': TextEditingController()});
    }
  }

  void _updateTotalPages() {
    if (isCompletedStudent || absent || didNotRecite) return;
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

  Future<void> _checkIfStudentIsCompleted() async {
    try {
      String studentId = widget.data['studentId'] ?? '';
      if (studentId.isNotEmpty) {
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();
            
        if (studentDoc.exists && studentDoc.data() != null) {
          Map<String, dynamic> sData = studentDoc.data() as Map<String, dynamic>;
          if (sData['studentType'] == 'completed') {
            setState(() {
              isCompletedStudent = true;
            });
          }
        }
      }
    } catch (e) {
      print("Error checking student type in edit page: $e");
    } finally {
      setState(() {
        checkingStudentType = false;
      });
    }
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
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.remove, size: 18, color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.add, size: 18, color: Colors.green),
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
          }).toList(),
        ],
      ),
    );
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
                      Text("تعديل المشرفين المشاركين", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
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
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يجب إبقاء مشرف واحد على الأقل", style: TextStyle(fontFamily: 'Cairo'))));
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

  save() async {
    setState(() => loading = true);

    double totalPages = isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0);
    String studentId = widget.data['studentId'] ?? '';

    final date = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";

    // 🚀 تطبيق استثناء (حضر ولم يقرأ)
    String finalNewMemo = (!hasNewMemorization || absent || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newMemoFrom, newMemoTo);
    String finalNearReview = (!hasReview || absent || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newRevFrom, newRevTo);
    String finalFarReview = (!hasReview || absent || didNotRecite) ? '' : _buildMultiRangeString(oldReviewRanges);
    
    String finalReading = (!hasReading || absent || didNotRecite) ? '' : _buildRangeString(readingFrom, readingTo);

    String finalMemoRating = (!hasNewMemorization || absent || isCompletedStudent || didNotRecite) ? '' : memorizationRating;
    
    String finalNewRevRating = (!hasReview || absent || isCompletedStudent || didNotRecite) ? '' : newReviewRating;
    String finalOldRevRating = (!hasReview || absent || isCompletedStudent || didNotRecite) ? '' : oldReviewRating;
    String finalFallbackRevRating = isCompletedStudent ? newReviewRating : (finalNewRevRating.isNotEmpty ? finalNewRevRating : finalOldRevRating);

    String finalNewHW = (absent || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newHwFrom, newHwTo);
    String finalNewRevHW = (absent || isCompletedStudent || didNotRecite) ? '' : _buildRangeString(newRevHwFrom, newRevHwTo);
    String finalOldRevHW = (absent || didNotRecite) ? '' : _buildMultiRangeString(oldRevHwRanges);
    
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

    List<String> supervisorIdsList = selectedSupervisors.map((e) => e['id']!).toList();
    List<String> supervisorNamesList = selectedSupervisors.map((e) => e['name']!).toList();

    final Map<String, dynamic> updateData = {
      'date': date, 
      'absent': absent,
      'didNotRecite': didNotRecite, // 🚀 تحديث الحالة في قاعدة البيانات
      'supervisorId': supervisorIdsList.isNotEmpty ? supervisorIdsList.first : '', 
      'supervisorName': supervisorNamesList.isNotEmpty ? supervisorNamesList.first : '', 
      'supervisorIds': supervisorIdsList, 
      'supervisorNames': supervisorNamesList, 
      'newMemorization': finalNewMemo,
      'review': (absent || didNotRecite || !hasReview) ? '' : (isCompletedStudent ? finalFarReview : "$finalNearReview | $finalFarReview"),
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
      'reviewRating': (absent || didNotRecite) ? '' : finalFallbackRevRating, 
      'rating': (absent || didNotRecite) ? '' : (isCompletedStudent ? finalFallbackRevRating : (hasNewMemorization ? finalMemoRating : finalFallbackRevRating)), 
      'studentStatus': absent ? '' : studentStatus, // يحافظ على السلوك إذا حضر ولم يقرأ
      'religiousActivities': absent ? '' : religiousActivities.text.trim(), // يحافظ على النشاطات
      'notes': notes.text.trim(),
      if (!absent && !didNotRecite) 'total_memorized_pages': totalPages,
    };

    FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update(updateData).then((_) {
      sessionService.recalculateConsecutiveAbsences(studentId);
    }).catchError((e) {
      print("خطأ في تحديث الجلسة: $e");
    });

    if (!absent && !didNotRecite && studentId.isNotEmpty && !isCompletedStudent && totalMemorizedPagesController.text.trim().isNotEmpty) {
      FirebaseFirestore.instance.collection('students').doc(studentId).update({
        'memorizedPages': totalPages,
      }).catchError((e) {
        print("خطأ في تحديث الطالب: $e");
      });
    }

    if (studentId.isNotEmpty) {
      String notifyTitle = "✏️ تعديل في بيانات الحلقة";
      String notifyBody = "";
      String notifyType = "regular";

      if (absent) {
        notifyTitle = "🚨 تعديل: تسجيل غياب طالب";
        notifyBody = "تم تعديل الجلسة وتوثيق غياب الطالب اليوم بـ السجل الإداري.";
        notifyType = "absent";
      } else if (didNotRecite) {
        notifyTitle = "ℹ️ تعديل: حضور بدون تسميع";
        notifyBody = "تم تعديل الجلسة وتوثيق أن الطالب حضر ولكنه لم يسمّع أو يقرأ شيئاً.";
        notifyType = "info";
      } else {
        String bodyText = isCompletedStudent
            ? "تم تحديث وتعديل سجل مراجعة الختمة الشاملة بنجاح"
            : "تم تعديل بيانات الإنجاز اليومي بنجاح";
            
        if (hasNewMemorization && finalMemoRating.isNotEmpty) {
          bodyText += "، الحفظ: ($finalMemoRating)";
        }
        if (hasReview) {
          if (isCompletedStudent) {
            bodyText += "، المراجعة: ($finalFallbackRevRating)";
          } else {
            if (finalNewRevRating.isNotEmpty) bodyText += "، مراجعة الجديد: ($finalNewRevRating)";
            if (finalOldRevRating.isNotEmpty) bodyText += "، مراجعة القديم: ($finalOldRevRating)";
          }
        }
        
        notifyBody = bodyText;
        notifyType = "regular";
      }

      NotificationService.sendAndSaveNotification(
        studentId: studentId,
        title: notifyTitle,
        body: notifyBody,
        type: notifyType,
        context: context, 
      ).then((_) {
        print("✅ تم إرسال إشعار التعديل فوراً (أونلاين)");
      }).catchError((error) async {
        print("⚠️ فشل الإرسال أوفلاين، جاري تحويل إشعار التعديل لطابور الانتظار: $error");
        await NotificationQueueManager.addToQueue(
          studentId: studentId,
          title: notifyTitle,
          body: notifyBody,
          type: notifyType,
        );
      });
    }

    if (!mounted) return;
    setState(() => loading = false);

    GlassToast.show(
      context,
      title: "تم التحديث",
      message: "تم تحديث بيانات الجلسة بنجاح 🔄",
      icon: Icons.edit_note_rounded,
      color: Colors.lightBlueAccent,
    );

    Navigator.pop(context);
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
          title: Text("تعديل بيانات الجلسة", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18)),
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
          centerTitle: true,
        ),
        body: checkingStudentType
            ? const Center(child: CircularProgressIndicator()) 
            : Stack(
                children: [
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
                  
                  AnimatedBuilder(
                    animation: _bgAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: -20 + _bgAnimation.value,
                            left: -50 - (_bgAnimation.value / 2),
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
                            ),
                          ),
                          Positioned(
                            bottom: 100 - _bgAnimation.value,
                            right: -60 + _bgAnimation.value,
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
                            ),
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
                                    activeColor: Colors.orangeAccent,
                                    value: absent,
                                    title: Text("تسجيل غياب في هذا اليوم", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
                                    secondary: Icon(absent ? Icons.person_off : Icons.person, color: isDarkMode ? Colors.white70 : primaryColor),
                                    onChanged: (v) => setState(() {
                                      absent = v;
                                      if (absent) didNotRecite = false; 
                                    }),
                                  ),
                                ),
                                if (!absent) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                                    child: SwitchListTile(
                                      activeColor: Colors.blueGrey,
                                      value: didNotRecite,
                                      title: Text("حضر لكن لم يقرأ/يسمّع شيء؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
                                      secondary: Icon(Icons.speaker_notes_off_outlined, color: didNotRecite ? Colors.blueGrey : (isDarkMode ? Colors.white70 : primaryColor)),
                                      onChanged: (v) => setState(() {
                                        didNotRecite = v;
                                        if (didNotRecite) absent = false;
                                      }),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!absent && !didNotRecite) ...[
                            _buildSectionCard(
                              title: isCompletedStudent ? "تعديل مراجعة الختمة الشاملة 👑" : "تعديل الإنجاز القرآني",
                              icon: Icons.edit_calendar,
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
                                      () { setState(() => oldReviewRanges.add({'from': TextEditingController(), 'to': TextEditingController()})); },
                                      () { if (oldReviewRanges.length > 1) setState(() { var r = oldReviewRanges.removeLast(); r['from']?.dispose(); r['to']?.dispose(); }); },
                                      isDarkMode
                                    ),
                                  ],

                                  if (hasReading) ...[
                                    _buildRangeRow("قراءة نظراً من المصحف (اختياري)", Icons.menu_book_outlined, readingFrom, readingTo, isDarkMode),
                                  ],
                                  
                                  if (!isCompletedStudent) ...[
                                    const SizedBox(height: 20), 
                                    Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
                                    const SizedBox(height: 10),
                                    TextField(
                                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), 
                                      controller: totalMemorizedPagesController, 
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"^\d+\.?\d*"))],
                                      decoration: _glassInputDecoration("إجمالي عدد الصفحات المحفوظة حتى الآن", Icons.analytics_outlined, isDarkMode)
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),

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
                            const SizedBox(height: 15),
                          ],

                          if (!absent) ...[
                            _buildSectionCard(
                              title: "تعديل السلوك والتقييم",
                              icon: Icons.thumbs_up_down_outlined,
                              isDarkMode: isDarkMode,
                              child: Column(
                                children: [
                                  if (!didNotRecite && !isCompletedStudent && hasNewMemorization) ...[
                                    DropdownButtonFormField<String>(
                                      value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(memorizationRating) ? memorizationRating : "جيد",
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
                                        value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(newReviewRating) ? newReviewRating : "جيد",
                                        dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                        decoration: _glassInputDecoration("تقييم مراجعة الختمة", Icons.rate_review_outlined, isDarkMode),
                                        items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                        onChanged: (v) => setState(() => newReviewRating = v!),
                                      ),
                                    ] else ...[
                                      DropdownButtonFormField<String>(
                                        value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(newReviewRating) ? newReviewRating : "جيد",
                                        dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                        decoration: _glassInputDecoration("تقييم مراجعة جديد", Icons.rate_review_outlined, isDarkMode),
                                        items: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                        onChanged: (v) => setState(() => newReviewRating = v!),
                                      ),
                                      const SizedBox(height: 15),
                                      DropdownButtonFormField<String>(
                                        value: ["ممتاز", "جيد جداً", "جيد", "مقبول", "ضعيف"].contains(oldReviewRating) ? oldReviewRating : "جيد",
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
                                    value: ["مهذب", "منضبط", "مشاغب", "كثير الحركة"].contains(studentStatus) ? studentStatus : "مهذب",
                                    dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                    decoration: _glassInputDecoration("حالة الطالب", Icons.mood, isDarkMode),
                                    items: ["مهذب", "منضبط", "مشاغب", "كثير الحركة"].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                                    onChanged: (v) => setState(() => studentStatus = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),

                            _buildSectionCard(
                              title: "نشاطات إضافية",
                              icon: Icons.mosque_outlined,
                              isDarkMode: isDarkMode,
                              child: TextField(
                                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), 
                                controller: religiousActivities, 
                                decoration: _glassInputDecoration("نشاطات دينية", Icons.volunteer_activism, isDarkMode, suffixIcon: _buildMicButton(religiousActivities, isDarkMode))
                              ),
                            ),
                          ],

                          const SizedBox(height: 15),

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

                          const SizedBox(height: 15),
                          _buildSectionCard(
                            title: "ملاحظات إضافية",
                            icon: Icons.comment_bank_outlined,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (absent) const SizedBox(height: 5),
                                TextField(
                                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold), 
                                  controller: notes, 
                                  maxLines: 3, 
                                  decoration: _glassInputDecoration("الملاحظات العامة", Icons.comment, isDarkMode, suffixIcon: _buildMicButton(notes, isDarkMode))
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 35),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: loading ? null : save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: absent ? Colors.orange.withOpacity(0.9) : (didNotRecite ? Colors.blueGrey.withOpacity(0.9) : (isDarkMode ? accentGold.withOpacity(0.9) : primaryColor.withOpacity(0.9))),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Colors.black38,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("تحديث البيانات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', letterSpacing: 0.5)),
                            ),
                          ),
                          const SizedBox(height: 30),
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