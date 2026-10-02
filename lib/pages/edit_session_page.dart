import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
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

  // 📖 قائمة سور القرآن الكريمة
  final List<Map<String, dynamic>> quranSurahs = const [
    {'id': 1, 'name': 'الفاتحة', 'startPage': 1, 'endPage': 1, 'verses': 7},
    {'id': 2, 'name': 'البقرة', 'startPage': 2, 'endPage': 49, 'verses': 286},
    {'id': 3, 'name': 'آل عمران', 'startPage': 50, 'endPage': 76, 'verses': 200},
    {'id': 4, 'name': 'النساء', 'startPage': 77, 'endPage': 106, 'verses': 176},
    {'id': 5, 'name': 'المائدة', 'startPage': 106, 'endPage': 127, 'verses': 120},
    {'id': 6, 'name': 'الأنعام', 'startPage': 128, 'endPage': 150, 'verses': 165},
    {'id': 7, 'name': 'الأعراف', 'startPage': 151, 'endPage': 176, 'verses': 206},
    {'id': 8, 'name': 'الأنفال', 'startPage': 177, 'endPage': 186, 'verses': 75},
    {'id': 9, 'name': 'التوبة', 'startPage': 187, 'endPage': 207, 'verses': 129},
    {'id': 10, 'name': 'يونس', 'startPage': 208, 'endPage': 221, 'verses': 109},
    {'id': 11, 'name': 'هود', 'startPage': 221, 'endPage': 235, 'verses': 123},
    {'id': 12, 'name': 'يوسف', 'startPage': 235, 'endPage': 248, 'verses': 111},
    {'id': 13, 'name': 'الرعد', 'startPage': 249, 'endPage': 255, 'verses': 43},
    {'id': 14, 'name': 'إبراهيم', 'startPage': 255, 'endPage': 261, 'verses': 52},
    {'id': 15, 'name': 'الحجر', 'startPage': 262, 'endPage': 267, 'verses': 99},
    {'id': 16, 'name': 'النحل', 'startPage': 267, 'endPage': 281, 'verses': 128},
    {'id': 17, 'name': 'الإسراء', 'startPage': 282, 'endPage': 293, 'verses': 111},
    {'id': 18, 'name': 'الكهف', 'startPage': 293, 'endPage': 304, 'verses': 110},
    {'id': 19, 'name': 'مريم', 'startPage': 305, 'endPage': 312, 'verses': 98},
    {'id': 20, 'name': 'طه', 'startPage': 312, 'endPage': 321, 'verses': 135},
    {'id': 21, 'name': 'الأنبياء', 'startPage': 322, 'endPage': 331, 'verses': 112},
    {'id': 22, 'name': 'الحج', 'startPage': 332, 'endPage': 341, 'verses': 78},
    {'id': 23, 'name': 'المؤمنون', 'startPage': 342, 'endPage': 349, 'verses': 118},
    {'id': 24, 'name': 'النور', 'startPage': 350, 'endPage': 359, 'verses': 64},
    {'id': 25, 'name': 'الفرقان', 'startPage': 359, 'endPage': 366, 'verses': 77},
    {'id': 26, 'name': 'الشعراء', 'startPage': 367, 'endPage': 376, 'verses': 227},
    {'id': 27, 'name': 'النمل', 'startPage': 377, 'endPage': 385, 'verses': 93},
    {'id': 28, 'name': 'القصص', 'startPage': 385, 'endPage': 396, 'verses': 88},
    {'id': 29, 'name': 'العنكبوت', 'startPage': 396, 'endPage': 404, 'verses': 69},
    {'id': 30, 'name': 'الروم', 'startPage': 404, 'endPage': 410, 'verses': 60},
    {'id': 31, 'name': 'لقمان', 'startPage': 411, 'endPage': 414, 'verses': 34},
    {'id': 32, 'name': 'السجدة', 'startPage': 415, 'endPage': 417, 'verses': 30},
    {'id': 33, 'name': 'الأحزاب', 'startPage': 418, 'endPage': 427, 'verses': 73},
    {'id': 34, 'name': 'سبأ', 'startPage': 428, 'endPage': 434, 'verses': 54},
    {'id': 35, 'name': 'فاطر', 'startPage': 434, 'endPage': 440, 'verses': 45},
    {'id': 36, 'name': 'يس', 'startPage': 440, 'endPage': 445, 'verses': 83},
    {'id': 37, 'name': 'الصافات', 'startPage': 445, 'endPage': 452, 'verses': 182},
    {'id': 38, 'name': 'ص', 'startPage': 453, 'endPage': 458, 'verses': 88},
    {'id': 39, 'name': 'الزمر', 'startPage': 458, 'endPage': 467, 'verses': 75},
    {'id': 40, 'name': 'غافر', 'startPage': 467, 'endPage': 476, 'verses': 85},
    {'id': 41, 'name': 'فصلت', 'startPage': 477, 'endPage': 482, 'verses': 54},
    {'id': 42, 'name': 'الشورى', 'startPage': 483, 'endPage': 489, 'verses': 53},
    {'id': 43, 'name': 'الزخرف', 'startPage': 489, 'endPage': 495, 'verses': 89},
    {'id': 44, 'name': 'الدخان', 'startPage': 496, 'endPage': 498, 'verses': 59},
    {'id': 45, 'name': 'الجاثية', 'startPage': 499, 'endPage': 502, 'verses': 37},
    {'id': 46, 'name': 'الأحقاف', 'startPage': 502, 'endPage': 506, 'verses': 35},
    {'id': 47, 'name': 'محمد', 'startPage': 507, 'endPage': 510, 'verses': 38},
    {'id': 48, 'name': 'الفتح', 'startPage': 511, 'endPage': 515, 'verses': 29},
    {'id': 49, 'name': 'الحجرات', 'startPage': 515, 'endPage': 517, 'verses': 18},
    {'id': 50, 'name': 'ق', 'startPage': 518, 'endPage': 520, 'verses': 45},
    {'id': 51, 'name': 'الذاريات', 'startPage': 520, 'endPage': 523, 'verses': 60},
    {'id': 52, 'name': 'الطور', 'startPage': 523, 'endPage': 525, 'verses': 49},
    {'id': 53, 'name': 'النجم', 'startPage': 526, 'endPage': 528, 'verses': 62},
    {'id': 54, 'name': 'القمر', 'startPage': 528, 'endPage': 531, 'verses': 55},
    {'id': 55, 'name': 'الرحمن', 'startPage': 531, 'endPage': 534, 'verses': 78},
    {'id': 56, 'name': 'الواقعة', 'startPage': 534, 'endPage': 537, 'verses': 96},
    {'id': 57, 'name': 'الحديد', 'startPage': 537, 'endPage': 541, 'verses': 29},
    {'id': 58, 'name': 'المجادلة', 'startPage': 542, 'endPage': 545, 'verses': 22},
    {'id': 59, 'name': 'الحشر', 'startPage': 545, 'endPage': 548, 'verses': 24},
    {'id': 60, 'name': 'الممتحنة', 'startPage': 549, 'endPage': 551, 'verses': 13},
    {'id': 61, 'name': 'الصف', 'startPage': 551, 'endPage': 553, 'verses': 14},
    {'id': 62, 'name': 'الجمعة', 'startPage': 553, 'endPage': 554, 'verses': 11},
    {'id': 63, 'name': 'المنافقون', 'startPage': 554, 'endPage': 555, 'verses': 11},
    {'id': 64, 'name': 'التغابن', 'startPage': 556, 'endPage': 557, 'verses': 18},
    {'id': 65, 'name': 'الطلاق', 'startPage': 558, 'endPage': 559, 'verses': 12},
    {'id': 66, 'name': 'التحريم', 'startPage': 560, 'endPage': 561, 'verses': 12},
    {'id': 67, 'name': 'الملك', 'startPage': 562, 'endPage': 564, 'verses': 30},
    {'id': 68, 'name': 'القلم', 'startPage': 564, 'endPage': 566, 'verses': 52},
    {'id': 69, 'name': 'الحاقة', 'startPage': 566, 'endPage': 568, 'verses': 52},
    {'id': 70, 'name': 'المعارج', 'startPage': 568, 'endPage': 570, 'verses': 44},
    {'id': 71, 'name': 'نوح', 'startPage': 570, 'endPage': 571, 'verses': 28},
    {'id': 72, 'name': 'الجن', 'startPage': 572, 'endPage': 573, 'verses': 28},
    {'id': 73, 'name': 'المزمل', 'startPage': 574, 'endPage': 575, 'verses': 20},
    {'id': 74, 'name': 'المدثر', 'startPage': 575, 'endPage': 577, 'verses': 56},
    {'id': 75, 'name': 'القيامة', 'startPage': 577, 'endPage': 578, 'verses': 40},
    {'id': 76, 'name': 'الإنسان', 'startPage': 578, 'endPage': 580, 'verses': 31},
    {'id': 77, 'name': 'المرسلات', 'startPage': 580, 'endPage': 581, 'verses': 50},
    {'id': 78, 'name': 'النبأ', 'startPage': 582, 'endPage': 583, 'verses': 40},
    {'id': 79, 'name': 'النازعات', 'startPage': 583, 'endPage': 584, 'verses': 46},
    {'id': 80, 'name': 'عبس', 'startPage': 585, 'endPage': 585, 'verses': 42},
    {'id': 81, 'name': 'التكوير', 'startPage': 586, 'endPage': 586, 'verses': 29},
    {'id': 82, 'name': 'الانفطار', 'startPage': 587, 'endPage': 587, 'verses': 19},
    {'id': 83, 'name': 'المطففين', 'startPage': 587, 'endPage': 589, 'verses': 36},
    {'id': 84, 'name': 'الانشقاق', 'startPage': 589, 'endPage': 590, 'verses': 25},
    {'id': 85, 'name': 'البروج', 'startPage': 590, 'endPage': 590, 'verses': 22},
    {'id': 86, 'name': 'الطارق', 'startPage': 591, 'endPage': 591, 'verses': 17},
    {'id': 87, 'name': 'الأعلى', 'startPage': 591, 'endPage': 592, 'verses': 19},
    {'id': 88, 'name': 'الغاشية', 'startPage': 592, 'endPage': 592, 'verses': 26},
    {'id': 89, 'name': 'الفجر', 'startPage': 593, 'endPage': 594, 'verses': 30},
    {'id': 90, 'name': 'البلد', 'startPage': 594, 'endPage': 594, 'verses': 20},
    {'id': 91, 'name': 'الشمس', 'startPage': 595, 'endPage': 595, 'verses': 15},
    {'id': 92, 'name': 'الليل', 'startPage': 595, 'endPage': 596, 'verses': 21},
    {'id': 93, 'name': 'الضحى', 'startPage': 596, 'endPage': 596, 'verses': 11},
    {'id': 94, 'name': 'الشرح', 'startPage': 596, 'endPage': 596, 'verses': 8},
    {'id': 95, 'name': 'التين', 'startPage': 597, 'endPage': 597, 'verses': 8},
    {'id': 96, 'name': 'العلق', 'startPage': 597, 'endPage': 597, 'verses': 19},
    {'id': 97, 'name': 'القدر', 'startPage': 598, 'endPage': 598, 'verses': 5},
    {'id': 98, 'name': 'البينة', 'startPage': 598, 'endPage': 599, 'verses': 8},
    {'id': 99, 'name': 'الزلزلة', 'startPage': 599, 'endPage': 599, 'verses': 8},
    {'id': 100, 'name': 'العاديات', 'startPage': 599, 'endPage': 600, 'verses': 11},
    {'id': 101, 'name': 'القارعة', 'startPage': 600, 'endPage': 600, 'verses': 11},
    {'id': 102, 'name': 'التكاثر', 'startPage': 600, 'endPage': 600, 'verses': 8},
    {'id': 103, 'name': 'العصر', 'startPage': 601, 'endPage': 601, 'verses': 3},
    {'id': 104, 'name': 'الهمزة', 'startPage': 601, 'endPage': 601, 'verses': 9},
    {'id': 105, 'name': 'الفيل', 'startPage': 601, 'endPage': 601, 'verses': 5},
    {'id': 106, 'name': 'قريش', 'startPage': 602, 'endPage': 602, 'verses': 4},
    {'id': 107, 'name': 'الماعون', 'startPage': 602, 'endPage': 602, 'verses': 7},
    {'id': 108, 'name': 'الكوثر', 'startPage': 602, 'endPage': 602, 'verses': 3},
    {'id': 109, 'name': 'الكافرون', 'startPage': 603, 'endPage': 603, 'verses': 6},
    {'id': 110, 'name': 'النصر', 'startPage': 603, 'endPage': 603, 'verses': 3},
    {'id': 111, 'name': 'المسد', 'startPage': 603, 'endPage': 603, 'verses': 5},
    {'id': 112, 'name': 'الإخلاص', 'startPage': 604, 'endPage': 604, 'verses': 4},
    {'id': 113, 'name': 'الفلق', 'startPage': 604, 'endPage': 604, 'verses': 5},
    {'id': 114, 'name': 'الناس', 'startPage': 604, 'endPage': 604, 'verses': 6},
  ];

  int selectedJuz = 0;

  List<Map<String, dynamic>> newMemoRanges = [];
  List<Map<String, dynamic>> newRevRanges = [];
  List<Map<String, dynamic>> oldRevRanges = [];
  List<Map<String, dynamic>> readingRanges = [];
  List<Map<String, dynamic>> newHwRanges = [];
  List<Map<String, dynamic>> newRevHwRanges = [];
  List<Map<String, dynamic>> oldRevHwRanges = [];

  late TextEditingController religiousActivities;
  late TextEditingController notes;
  late TextEditingController absenceReasonController;
  late TextEditingController examScoreController;
  late TextEditingController totalMemorizedPagesController;

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

  late DateTime _selectedDate;

  bool isCompletedStudent = false;
  bool checkingStudentType = true;

  List<Map<String, String>> selectedNewMemoSupervisors = [];
  List<Map<String, String>> selectedReviewSupervisors = [];

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
    isExam = data['isExam'] ?? false;
    didNotRecite = data['didNotRecite'] ?? false;
    selectedJuz = data['selectedJuz'] ?? (data['isJuzAmma'] == true ? 30 : 0);

    hasNewMemorization = (data['newMemorization'] ?? '').toString().trim().isNotEmpty;
    hasReview = (data['nearReview'] ?? '').toString().trim().isNotEmpty ||
        (data['farReview'] ?? '').toString().trim().isNotEmpty ||
        (data['review'] ?? '').toString().trim().isNotEmpty;
    hasReading = (data['readingBySight'] ?? '').toString().trim().isNotEmpty;

    if (!hasNewMemorization && !hasReview && !absent && !isExam && !didNotRecite) {
      hasNewMemorization = true;
      hasReview = true;
    }

    _selectedDate = _parseDate(data['date'] ?? '');

    memorizationRating = (data['memorizationRating'] ?? data['rating'] ?? "جيد").toString();
    if (memorizationRating.isEmpty) memorizationRating = "جيد";

    newReviewRating = (data['newReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "جيد").toString();
    if (newReviewRating.isEmpty) newReviewRating = "جيد";

    oldReviewRating = (data['oldReviewRating'] ?? data['reviewRating'] ?? data['rating'] ?? "جيد").toString();
    if (oldReviewRating.isEmpty) oldReviewRating = "جيد";

    studentStatus = (data['studentStatus'] == null || data['studentStatus'] == '') ? "مهذب" : data['studentStatus'];
    absenceType = (data['absenceType'] == null || data['absenceType'] == '') ? "بدون عذر" : data['absenceType'];

    religiousActivities = TextEditingController(text: data['religiousActivities'] ?? '');
    notes = TextEditingController(text: data['notes'] ?? '');
    absenceReasonController = TextEditingController(text: data['absenceReason'] ?? '');
    examScoreController = TextEditingController(text: data['examScore'] ?? '');

    var initialPages = data['total_memorized_pages']?.toString() ?? '';
    totalMemorizedPagesController = TextEditingController(text: selectedJuz > 0 ? "0" : initialPages);

    _loadSupervisorsFromData(data);
    _parseExistingData(data);
    _checkIfStudentIsCompleted();
  }

  void _loadSupervisorsFromData(Map<String, dynamic> data) {
    if (data.containsKey('newMemoSupervisorIds') && data['newMemoSupervisorIds'] is List && (data['newMemoSupervisorIds'] as List).isNotEmpty) {
      List ids = data['newMemoSupervisorIds'];
      List names = data['newMemoSupervisorNames'] ?? [];
      for (int i = 0; i < ids.length; i++) {
        selectedNewMemoSupervisors.add({'id': ids[i].toString(), 'name': i < names.length ? names[i].toString() : 'مشرف'});
      }
    } else {
      _loadFallbackSupervisors(data, selectedNewMemoSupervisors);
    }

    if (data.containsKey('reviewSupervisorIds') && data['reviewSupervisorIds'] is List && (data['reviewSupervisorIds'] as List).isNotEmpty) {
      List ids = data['reviewSupervisorIds'];
      List names = data['reviewSupervisorNames'] ?? [];
      for (int i = 0; i < ids.length; i++) {
        selectedReviewSupervisors.add({'id': ids[i].toString(), 'name': i < names.length ? names[i].toString() : 'مشرف'});
      }
    } else {
      _loadFallbackSupervisors(data, selectedReviewSupervisors);
    }
  }

  void _loadFallbackSupervisors(Map<String, dynamic> data, List<Map<String, String>> targetList) {
    if (data.containsKey('supervisorIds') && data['supervisorIds'] is List && (data['supervisorIds'] as List).isNotEmpty) {
      List ids = data['supervisorIds'];
      List names = data['supervisorNames'] ?? [];
      for (int i = 0; i < ids.length; i++) {
        targetList.add({'id': ids[i].toString(), 'name': i < names.length ? names[i].toString() : 'مشرف'});
      }
    } else {
      String sId = data['supervisorId'] ?? '';
      String sName = data['supervisorName'] ?? 'مشرف غير معروف';
      if (sId.isNotEmpty) targetList.add({'id': sId, 'name': sName});
    }
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

  void _parseExistingData(Map<String, dynamic> data) {
    newMemoRanges = _parseFormattedTextToRanges(data['newMemorization'] ?? '');

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

    newRevRanges = _parseFormattedTextToRanges(nearRev);
    oldRevRanges = _parseFormattedTextToRanges(farRev);
    readingRanges = _parseFormattedTextToRanges(data['readingBySight'] ?? '');

    String oldHw = data['homework'] ?? '';
    String nHw = data['newHomework'] ?? '';
    String nRevHw = data['newReviewHomework'] ?? '';
    String oRevHw = data['oldReviewHomework'] ?? '';

    if (nHw.isEmpty && nRevHw.isEmpty && oRevHw.isEmpty && oldHw.isNotEmpty) {
      if (oldHw.contains("حفظ:")) {
        List<String> lines = oldHw.split('\n');
        for (var line in lines) {
          if (line.contains("حفظ:")) nHw = line.replaceAll("حفظ:", "").trim();
          if (line.contains("مراجعة:")) oRevHw = line.replaceAll("مراجعة:", "").trim();
        }
      } else {
        oRevHw = oldHw;
      }
    }

    newHwRanges = _parseFormattedTextToRanges(nHw);
    newRevHwRanges = _parseFormattedTextToRanges(nRevHw);
    oldRevHwRanges = _parseFormattedTextToRanges(oRevHw);

    for (var list in [newMemoRanges, newRevRanges, oldRevRanges, readingRanges, newHwRanges, newRevHwRanges, oldRevHwRanges]) {
      if (list.isEmpty) {
        list.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()});
      }
    }
  }

  List<Map<String, dynamic>> _parseFormattedTextToRanges(String text) {
    List<Map<String, dynamic>> results = [];
    if (text.trim().isEmpty) return results;

    List<String> rawParts = text.split(RegExp(r'\||\n'));

    for (var part in rawParts) {
      String trimmedPart = part.trim();
      if (trimmedPart.isEmpty) continue;

      String surahFrom = '';
      String surahTo = '';
      String fromPage = '';
      String toPage = '';

      RegExp digitsExp = RegExp(r'\d+');
      var matches = digitsExp.allMatches(trimmedPart).map((m) => m.group(0)!).toList();

      if (matches.length >= 2) {
        fromPage = matches[0];
        toPage = matches[1];
      } else if (matches.length == 1) {
        fromPage = matches[0];
        toPage = matches[0];
      }

      for (var surah in quranSurahs) {
        String sName = surah['name'];
        if (trimmedPart.contains("من سورة $sName") || trimmedPart.contains("سورة $sName")) {
          if (surahFrom.isEmpty) {
            surahFrom = sName;
          } else {
            surahTo = sName;
          }
        } else if (trimmedPart.contains("إلى $sName") || trimmedPart.contains("إلى سورة $sName")) {
          surahTo = sName;
        }
      }

      if (surahFrom.isEmpty && fromPage.isNotEmpty) {
        surahFrom = _getStartSurahByPage(fromPage);
      }
      if (surahTo.isEmpty && toPage.isNotEmpty) {
        surahTo = _getEndSurahByPage(toPage);
      }

      var fromController = TextEditingController(text: fromPage);
      var toController = TextEditingController(text: toPage);

      results.add({
        'surah': surahFrom,
        'toSurah': surahTo.isNotEmpty ? surahTo : surahFrom,
        'isFullSurah': fromPage.isEmpty && toPage.isEmpty,
        'from': fromController,
        'to': toController,
      });
    }

    return results;
  }

  String _getStartSurahByPage(String pageStr) {
    int? page = int.tryParse(pageStr.trim());
    if (page == null || page < 1 || page > 604) return "";

    var matches = quranSurahs.where((s) => s['startPage'] == page).toList();
    if (matches.isNotEmpty) return matches.first['name'];

    for (var surah in quranSurahs) {
      if (page >= surah['startPage'] && page <= surah['endPage']) return surah['name'];
    }
    return "";
  }

  String _getEndSurahByPage(String pageStr) {
    int? page = int.tryParse(pageStr.trim());
    if (page == null || page < 1 || page > 604) return "";

    var matches = quranSurahs.where((s) => s['endPage'] == page).toList();
    if (matches.isNotEmpty) return matches.last['name'];

    for (var surah in quranSurahs) {
      if (page >= surah['startPage'] && page <= surah['endPage']) return surah['name'];
    }
    return "";
  }

  void _syncSurahFromPageController(TextEditingController ctrl, Map<String, dynamic> item, bool isFromPage) {
    if (selectedJuz > 0) return;
    String pageVal = ctrl.text.trim();
    if (pageVal.isEmpty) return;

    if (isFromPage) {
      String foundSurah = _getStartSurahByPage(pageVal);
      if (foundSurah.isNotEmpty && foundSurah != item['surah']) {
        setState(() => item['surah'] = foundSurah);
      }
    } else {
      String foundSurah = _getEndSurahByPage(pageVal);
      if (foundSurah.isNotEmpty && foundSurah != item['toSurah']) {
        setState(() => item['toSurah'] = foundSurah);
      }
    }
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
    if (isCompletedStudent || absent || isExam || didNotRecite || selectedJuz > 0) {
      if (selectedJuz > 0) totalMemorizedPagesController.text = "0";
      return;
    }
    int maxPage = 0;
    for (var item in newMemoRanges) {
      int to = int.tryParse((item['to'] as TextEditingController).text.trim()) ?? 0;
      int from = int.tryParse((item['from'] as TextEditingController).text.trim()) ?? 0;
      int m = from > to ? from : to;
      if (m > maxPage) maxPage = m;
    }
    if (maxPage > 0 && maxPage <= 604) {
      totalMemorizedPagesController.text = maxPage.toString();
    }
  }

  String _buildFormattedSectionText(List<Map<String, dynamic>> ranges) {
    List<String> parts = [];
    for (var item in ranges) {
      String surahFrom = item['surah'] ?? '';
      String surahTo = item['toSurah'] ?? surahFrom;
      bool isFull = item['isFullSurah'] ?? true;
      String from = (item['from'] as TextEditingController).text.trim();
      String to = (item['to'] as TextEditingController).text.trim();

      if (surahFrom.isEmpty && from.isEmpty && to.isEmpty) continue;

      if (selectedJuz > 0) {
        if (surahFrom.isEmpty) continue;

        if (isFull) {
          if (surahFrom == surahTo || surahTo.isEmpty) {
            parts.add("سورة $surahFrom");
          } else {
            parts.add("من سورة $surahFrom إلى سورة $surahTo");
          }
        } else {
          if (from.isNotEmpty && to.isNotEmpty) {
            parts.add(from == to ? "سورة $surahFrom (آية $from)" : "سورة $surahFrom (من آية $from إلى $to)");
          } else if (from.isNotEmpty) {
            parts.add("سورة $surahFrom (من آية $from)");
          } else {
            parts.add("سورة $surahFrom");
          }
        }
      } else {
        String startSurahName = surahFrom.isNotEmpty ? surahFrom : _getStartSurahByPage(from);
        String endSurahName = surahTo.isNotEmpty ? surahTo : _getEndSurahByPage(to);

        if (from.isNotEmpty && to.isNotEmpty) {
          if (from == to) {
            parts.add("سورة $startSurahName (ص $from)");
          } else {
            if (startSurahName == endSurahName || endSurahName.isEmpty) {
              parts.add("سورة $startSurahName (ص $from - $to)");
            } else {
              parts.add("من سورة $startSurahName إلى $endSurahName (ص $from - $to)");
            }
          }
        } else if (from.isNotEmpty) {
          parts.add("سورة $startSurahName (ص $from)");
        } else if (to.isNotEmpty) {
          parts.add("سورة $endSurahName (ص $to)");
        } else if (startSurahName.isNotEmpty) {
          parts.add("سورة $startSurahName");
        }
      }
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
            setState(() => isCompletedStudent = true);
          }
        }
      }
    } catch (e) {
      print("Error checking student type: $e");
    } finally {
      if (mounted) setState(() => checkingStudentType = false);
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _disposeRanges(newMemoRanges);
    _disposeRanges(newRevRanges);
    _disposeRanges(oldRevRanges);
    _disposeRanges(readingRanges);
    _disposeRanges(newHwRanges);
    _disposeRanges(newRevHwRanges);
    _disposeRanges(oldRevHwRanges);

    religiousActivities.dispose();
    notes.dispose();
    absenceReasonController.dispose();
    examScoreController.dispose();
    totalMemorizedPagesController.dispose();
    super.dispose();
  }

  void _disposeRanges(List<Map<String, dynamic>> list) {
    for (var item in list) {
      (item['from'] as TextEditingController?)?.dispose();
      (item['to'] as TextEditingController?)?.dispose();
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

  Widget _buildMicButton(TextEditingController controller, bool isDarkMode) {
    bool isActive = _isListening && _activeController == controller;
    return IconButton(
      key: ValueKey('mic_${controller.hashCode}'),
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

  Widget _buildMiniNumberInput(TextEditingController ctrl, bool isDarkMode, {String hint = "---", Map<String, dynamic>? itemToSync, bool isFromPage = true}) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        textAlign: TextAlign.center,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        onChanged: (val) {
          if (itemToSync != null) {
            _syncSurahFromPageController(ctrl, itemToSync, isFromPage);
          } else {
            setState(() {});
          }
          _updateTotalPages();
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black26),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildSupervisorSelectorTile({
    required String label,
    required List<Map<String, String>> selectedList,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white70),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white70 : primaryColor, fontFamily: 'Cairo')),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedList.map((s) => Chip(
                      label: Text(s['name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
                      backgroundColor: accentGold,
                      elevation: 1,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ),
                Icon(Icons.edit_rounded, color: isDarkMode ? accentGold : primaryColor, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStaffSelectionBottomSheet(BuildContext context, bool isDarkMode, List<Map<String, String>> targetList, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xff1e293b) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
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
                            final isSelected = targetList.any((s) => s['id'] == staff['id']);

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
                                      targetList.add(staff);
                                    } else {
                                      if (targetList.length > 1) {
                                        targetList.removeWhere((s) => s['id'] == staff['id']);
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
              );
            }
          ),
        );
      }
    );
  }

  void _showSurahPagesPicker(BuildContext context, Map<String, dynamic> surah, TextEditingController fromCtrl, TextEditingController toCtrl, bool isDarkMode) {
    int start = surah['startPage'];
    int end = surah['endPage'];
    List<int> pages = List.generate(end - start + 1, (i) => start + i);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white30 : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "صفحات سورة ${surah['name']} (من $start إلى $end)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor, fontSize: 16),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: pages.map((p) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                fromCtrl.text = p.toString();
                                toCtrl.text = p.toString();
                                _updateTotalPages();
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: accentGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accentGold),
                              ),
                              child: Text("ص $p", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUniversalQuranSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> ranges,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
    required bool isDarkMode,
  }) {
    List<Map<String, dynamic>> filteredSurahs;

    if (selectedJuz == 30) {
      filteredSurahs = quranSurahs.where((s) => (s['id'] as int) >= 78).toList();
    } else if (selectedJuz == 29) {
      filteredSurahs = quranSurahs.where((s) => (s['id'] as int) >= 67 && (s['id'] as int) <= 77).toList();
    } else if (selectedJuz == 28) {
      filteredSurahs = quranSurahs.where((s) => (s['id'] as int) >= 58 && (s['id'] as int) <= 66).toList();
    } else if (selectedJuz == 27) {
      filteredSurahs = quranSurahs.where((s) => (s['id'] as int) >= 51 && (s['id'] as int) <= 57).toList();
    } else if (selectedJuz == 26) {
      filteredSurahs = quranSurahs.where((s) => (s['id'] as int) >= 46 && (s['id'] as int) <= 50).toList();
    } else {
      filteredSurahs = quranSurahs;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
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
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.remove, size: 16, color: Colors.white),
                      ),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),

          ...ranges.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;

            TextEditingController fromCtrl = item['from'];
            TextEditingController toCtrl = item['to'];

            if (selectedJuz == 0) {
              if (fromCtrl.text.isNotEmpty) {
                String autoSurah = _getStartSurahByPage(fromCtrl.text);
                if (autoSurah.isNotEmpty) item['surah'] = autoSurah;
              }
              if (toCtrl.text.isNotEmpty) {
                String autoToSurah = _getEndSurahByPage(toCtrl.text);
                if (autoToSurah.isNotEmpty) item['toSurah'] = autoToSurah;
              }
            }

            String currentSurah = item['surah'] ?? '';
            String currentToSurah = item['toSurah'] ?? '';
            bool isFullSurah = item['isFullSurah'] ?? true;

            var selectedSurahData = quranSurahs.firstWhere((s) => s['name'] == currentSurah, orElse: () => {'name': '', 'startPage': 1, 'endPage': 1});

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ranges.length > 1)
                    Text("المقطع ${index + 1}:", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Cairo')),

                  if (selectedJuz > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("النطاق:", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(isFullSurah ? "السورة كاملة 📜" : "آيات محددة 🔢", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: accentGold, fontWeight: FontWeight.bold)),
                            Switch(
                              value: isFullSurah,
                              activeColor: accentGold,
                              onChanged: (val) {
                                setState(() {
                                  item['isFullSurah'] = val;
                                  if (val) {
                                    fromCtrl.clear();
                                    toCtrl.clear();
                                  }
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: filteredSurahs.any((s) => s['name'] == currentSurah) ? currentSurah : '',
                            dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: isFullSurah ? "من سورة" : "السورة",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              filled: true,
                              fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.7),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            items: [
                              const DropdownMenuItem(value: '', child: Text("-- غير محدد --", style: TextStyle(color: Colors.grey))),
                              ...filteredSurahs.map((s) => DropdownMenuItem(
                                value: s['name'].toString(),
                                child: Text(s['name'].toString()),
                              )),
                            ],
                            onChanged: (v) {
                              setState(() {
                                item['surah'] = v ?? '';
                                if (isFullSurah && (item['toSurah'] == null || item['toSurah'].toString().isEmpty)) {
                                  item['toSurah'] = v ?? '';
                                }
                              });
                            },
                          ),
                        ),
                        if (isFullSurah) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: filteredSurahs.any((s) => s['name'] == currentToSurah) ? currentToSurah : '',
                              dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: "إلى سورة",
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                filled: true,
                                fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.7),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              items: [
                                const DropdownMenuItem(value: '', child: Text("-- غير محدد --", style: TextStyle(color: Colors.grey))),
                                ...filteredSurahs.map((s) => DropdownMenuItem(
                                  value: s['name'].toString(),
                                  child: Text(s['name'].toString()),
                                )),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  item['toSurah'] = v ?? '';
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (!isFullSurah) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text("من آية:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildMiniNumberInput(item['from'], isDarkMode, hint: "بداية")),
                          const SizedBox(width: 10),
                          Text("إلى آية:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildMiniNumberInput(item['to'], isDarkMode, hint: "نهاية")),
                        ],
                      ),
                    ],
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: filteredSurahs.any((s) => s['name'] == currentSurah) ? currentSurah : '',
                      dropdownColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "اختر السورة (تتغير تلقائياً حسب الصفحات)",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text("-- غير محدد --", style: TextStyle(color: Colors.grey))),
                        ...filteredSurahs.map((s) => DropdownMenuItem(
                          value: s['name'].toString(),
                          child: Text("${s['id']}- سورة ${s['name']}"),
                        )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          item['surah'] = v ?? '';
                          if (v != null && v.isNotEmpty) {
                            var sData = quranSurahs.firstWhere((element) => element['name'] == v);
                            (item['from'] as TextEditingController).text = sData['startPage'].toString();
                            (item['to'] as TextEditingController).text = sData['endPage'].toString();
                            _updateTotalPages();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text("من ص:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildMiniNumberInput(item['from'], isDarkMode, hint: "صفحة", itemToSync: item, isFromPage: true)),
                        const SizedBox(width: 10),
                        Text("إلى ص:", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Expanded(child: _buildMiniNumberInput(item['to'], isDarkMode, hint: "صفحة", itemToSync: item, isFromPage: false)),
                      ],
                    ),

                    if (selectedSurahData['name'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          onPressed: () => _showSurahPagesPicker(context, selectedSurahData, item['from'], item['to'], isDarkMode),
                          icon: const Icon(Icons.menu_book_rounded, size: 14, color: Colors.orangeAccent),
                          label: Text("عرض صفحات سورة ${selectedSurahData['name']}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJuzChip(int juzNum, String title, bool isDarkMode) {
    bool isSelected = selectedJuz == juzNum;
    return ChoiceChip(
      label: Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : (isDarkMode ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: accentGold,
      backgroundColor: isDarkMode ? Colors.black26 : Colors.white54,
      elevation: isSelected ? 2 : 0,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            selectedJuz = juzNum;
            for (var list in [newMemoRanges, newRevRanges, oldRevRanges, readingRanges, newHwRanges, newRevHwRanges, oldRevHwRanges]) {
              for (var item in list) {
                item['surah'] = '';
                item['toSurah'] = '';
                item['isFullSurah'] = true;
                (item['from'] as TextEditingController).clear();
                (item['to'] as TextEditingController).clear();
              }
            }
            if (selectedJuz > 0) {
              totalMemorizedPagesController.text = "0";
            }
          });
        }
      },
    );
  }

  save() async {
    if (loading) return;

    if (isExam && !absent && examScoreController.text.trim().isEmpty) {
      GlassToast.show(
        context,
        title: "بيانات ناقصة",
        message: "يرجى إدخال علامة الاختبار أولاً ❌",
        icon: Icons.error_outline_rounded,
        color: Colors.redAccent,
      );
      return;
    }

    setState(() => loading = true);

    double totalPages = (selectedJuz > 0) ? 0.0 : (isCompletedStudent ? 604.0 : (double.tryParse(totalMemorizedPagesController.text.trim()) ?? 0.0));
    String studentId = widget.data['studentId'] ?? '';

    final String monthStr = _selectedDate.month.toString().padLeft(2, '0');
    final String dayStr = _selectedDate.day.toString().padLeft(2, '0');
    final String date = "${_selectedDate.year}-$monthStr-$dayStr";

    DateTime realNow = DateTime.now();
    String actualEditedTimeFormatted = DateFormat('yyyy-MM-dd hh:mm a').format(realNow);

    String finalNewMemo = (!hasNewMemorization || absent || isExam || isCompletedStudent || didNotRecite) ? '' : _buildFormattedSectionText(newMemoRanges);
    String finalNearReview = (!hasReview || absent || isExam || isCompletedStudent || didNotRecite) ? '' : _buildFormattedSectionText(newRevRanges);
    String finalFarReview = (!hasReview || absent || isExam || didNotRecite) ? '' : _buildFormattedSectionText(oldRevRanges);
    String finalReading = (!hasReading || absent || isExam || didNotRecite) ? '' : _buildFormattedSectionText(readingRanges);

    String finalMemoRating = (!hasNewMemorization || absent || isExam || isCompletedStudent || didNotRecite) ? '' : memorizationRating;
    String finalNewRevRating = (!hasReview || absent || isExam || isCompletedStudent || didNotRecite) ? '' : newReviewRating;
    String finalOldRevRating = (!hasReview || absent || isExam || didNotRecite) ? '' : oldReviewRating;
    String finalFallbackRevRating = isCompletedStudent ? newReviewRating : (finalNewRevRating.isNotEmpty ? finalNewRevRating : finalOldRevRating);

    String finalNewHW = (isCompletedStudent) ? '' : _buildFormattedSectionText(newHwRanges);
    String finalNewRevHW = (isCompletedStudent) ? '' : _buildFormattedSectionText(newRevHwRanges);
    String finalOldRevHW = _buildFormattedSectionText(oldRevHwRanges);

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

    List<String> newMemoSupIds = selectedNewMemoSupervisors.map((e) => e['id']!).toList();
    List<String> newMemoSupNames = selectedNewMemoSupervisors.map((e) => e['name']!).toList();

    List<String> reviewSupIds = selectedReviewSupervisors.map((e) => e['id']!).toList();
    List<String> reviewSupNames = selectedReviewSupervisors.map((e) => e['name']!).toList();

    final Map<String, dynamic> updateData = {
      'studentId': studentId,
      'studentName': widget.data['studentName'] ?? '',
      'date': date,
      'actualEditedAt': actualEditedTimeFormatted,
      'lastUpdatedTimestamp': FieldValue.serverTimestamp(),
      'absent': absent,
      'isExam': isExam,
      'didNotRecite': didNotRecite,
      'isJuzAmma': selectedJuz == 30,
      'selectedJuz': selectedJuz,
      'examScore': isExam && !absent ? examScoreController.text.trim() : '',
      'supervisorId': newMemoSupIds.isNotEmpty ? newMemoSupIds.first : widget.data['supervisorId'],
      'supervisorName': newMemoSupNames.isNotEmpty ? newMemoSupNames.first : widget.data['supervisorName'],
      'newMemoSupervisorIds': newMemoSupIds,
      'newMemoSupervisorNames': newMemoSupNames,
      'reviewSupervisorIds': reviewSupIds,
      'reviewSupervisorNames': reviewSupNames,
      'newMemorization': finalNewMemo,
      'review': (absent || isExam || didNotRecite || !hasReview) ? '' : (isCompletedStudent ? finalFarReview : "$finalNearReview | $finalFarReview"),
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

    try {
      await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).set(updateData, SetOptions(merge: true));
      sessionService.recalculateConsecutiveAbsences(studentId);

      if (!absent && !isExam && !didNotRecite && studentId.isNotEmpty && !isCompletedStudent) {
        FirebaseFirestore.instance.collection('students').doc(studentId).update({
          'memorizedPages': totalPages,
        }).catchError((e) => print("خطأ في تحديث الطالب: $e"));
      }

      if (studentId.isNotEmpty) {
        String notifyTitle = "✏️ تعديل في بيانات الحلقة";
        String notifyBody = absent
            ? "تم تعديل الجلسة وتسجيل غياب الطالب اليوم ($absenceType)."
            : (isExam ? "تم تعديل الجلسة وتحديث درجة الاختبار (${examScoreController.text.trim()} من 100)" : "تم تعديل وتحديث بيانات يومية الطالب بنجاح.");
        String notifyType = absent ? "absent" : (isExam ? "exam" : "regular");

        NotificationService.sendAndSaveNotification(
          studentId: studentId,
          title: notifyTitle,
          body: notifyBody,
          type: notifyType,
          context: context,
        ).catchError((error) async {
          await NotificationQueueManager.addToQueue(
            studentId: studentId,
            title: notifyTitle,
            body: notifyBody,
            type: notifyType,
          );
        });
      }

      if (!mounted) return;

      GlassToast.show(
        context,
        title: "تم التحديث",
        message: "تم تحديث بيانات الجلسة بنجاح 🔄",
        icon: Icons.edit_note_rounded,
        color: Colors.lightBlueAccent,
      );

      Navigator.pop(context);
    } catch (e) {
      print("خطأ في تحديث الجلسة: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final String studentName = widget.data['studentName'] ?? 'الطالب';

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(studentName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
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
                                        Text("${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
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
                                  child: CheckboxListTile(
                                    activeColor: Colors.orange,
                                    value: absent,
                                    title: Text("تسجيل الطالب غائب؟", style: TextStyle(color: isDarkMode ? Colors.white : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                    secondary: Icon(absent ? Icons.person_off : Icons.person, color: isDarkMode ? Colors.white70 : primaryColor),
                                    onChanged: (v) {
                                      setState(() {
                                        absent = v ?? false;
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.black26 : Colors.white30,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: selectedJuz > 0 ? accentGold : Colors.transparent, width: 1.2),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.style_rounded, size: 16, color: accentGold),
                                              const SizedBox(width: 6),
                                              Text(
                                                "حدد نظام التسميع:",
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: isDarkMode ? Colors.white70 : primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            child: Row(
                                              children: [
                                                _buildJuzChip(0, "العادي (صفحات)", isDarkMode),
                                                const SizedBox(width: 6),
                                                _buildJuzChip(30, "جزء عمَّ 👶", isDarkMode),
                                                const SizedBox(width: 6),
                                                _buildJuzChip(29, "جزء تبارك", isDarkMode),
                                                const SizedBox(width: 6),
                                                _buildJuzChip(28, "قد سمع", isDarkMode),
                                                const SizedBox(width: 6),
                                                _buildJuzChip(27, "الذاريات", isDarkMode),
                                                const SizedBox(width: 6),
                                                _buildJuzChip(26, "الأحقاف", isDarkMode),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

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
                                    _buildUniversalQuranSection(
                                      title: "الحفظ الجديد",
                                      icon: Icons.star_border,
                                      ranges: newMemoRanges,
                                      onAdd: () => setState(() => newMemoRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                      onRemove: () { if (newMemoRanges.length > 1) setState(() { var r = newMemoRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                      isDarkMode: isDarkMode,
                                    ),
                                  ],

                                  if (hasReview) ...[
                                    if (!isCompletedStudent) ...[
                                      _buildUniversalQuranSection(
                                        title: "مراجعة جديد",
                                        icon: Icons.auto_stories_outlined,
                                        ranges: newRevRanges,
                                        onAdd: () => setState(() => newRevRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                        onRemove: () { if (newRevRanges.length > 1) setState(() { var r = newRevRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                        isDarkMode: isDarkMode,
                                      ),
                                    ],
                                    _buildUniversalQuranSection(
                                      title: isCompletedStudent ? "المقدار المسموع من مراجعة الختمة الشاملة" : "مراجعة قديم",
                                      icon: isCompletedStudent ? Icons.verified_user_rounded : Icons.history_outlined,
                                      ranges: oldRevRanges,
                                      onAdd: () => setState(() => oldRevRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                      onRemove: () { if (oldRevRanges.length > 1) setState(() { var r = oldRevRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                      isDarkMode: isDarkMode,
                                    ),
                                  ],

                                  if (hasReading) ...[
                                    _buildUniversalQuranSection(
                                      title: "المقدار المقروء نظراً من المصحف",
                                      icon: Icons.menu_book_outlined,
                                      ranges: readingRanges,
                                      onAdd: () => setState(() => readingRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                      onRemove: () { if (readingRanges.length > 1) setState(() { var r = readingRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                      isDarkMode: isDarkMode,
                                    ),
                                  ],

                                  if (!isCompletedStudent && selectedJuz == 0) ...[
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
                          ],

                          _buildSectionCard(
                            title: "الواجب المطلوب للمرة القادمة",
                            icon: Icons.next_plan_outlined,
                            isDarkMode: isDarkMode,
                            child: Column(
                              children: [
                                if (isCompletedStudent) ...[
                                  _buildUniversalQuranSection(
                                    title: "المقدار المطلوب للمرة القادمة",
                                    icon: Icons.edit_note,
                                    ranges: oldRevHwRanges,
                                    onAdd: () => setState(() => oldRevHwRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                    onRemove: () { if (oldRevHwRanges.length > 1) setState(() { var r = oldRevHwRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                    isDarkMode: isDarkMode,
                                  ),
                                ] else ...[
                                  _buildUniversalQuranSection(
                                    title: "واجب الحفظ الجديد القادم",
                                    icon: Icons.edit_document,
                                    ranges: newHwRanges,
                                    onAdd: () => setState(() => newHwRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                    onRemove: () { if (newHwRanges.length > 1) setState(() { var r = newHwRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                    isDarkMode: isDarkMode,
                                  ),
                                  _buildUniversalQuranSection(
                                    title: "واجب المراجعة الجديد القادم",
                                    icon: Icons.menu_book_rounded,
                                    ranges: newRevHwRanges,
                                    onAdd: () => setState(() => newRevHwRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                    onRemove: () { if (newRevHwRanges.length > 1) setState(() { var r = newRevHwRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                    isDarkMode: isDarkMode,
                                  ),
                                  _buildUniversalQuranSection(
                                    title: "واجب المراجعة القديم القادم",
                                    icon: Icons.history_edu_rounded,
                                    ranges: oldRevHwRanges,
                                    onAdd: () => setState(() => oldRevHwRanges.add({'surah': '', 'toSurah': '', 'isFullSurah': true, 'from': TextEditingController(), 'to': TextEditingController()})),
                                    onRemove: () { if (oldRevHwRanges.length > 1) setState(() { var r = oldRevHwRanges.removeLast(); (r['from'] as TextEditingController?)?.dispose(); (r['to'] as TextEditingController?)?.dispose(); }); },
                                    isDarkMode: isDarkMode,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

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
                            child: Column(
                              children: [
                                if (hasNewMemorization)
                                  _buildSupervisorSelectorTile(
                                    label: "مشرف الحفظ الجديد:",
                                    selectedList: selectedNewMemoSupervisors,
                                    onTap: () => _showStaffSelectionBottomSheet(context, isDarkMode, selectedNewMemoSupervisors, "حدد مشرفي الحفظ الجديد"),
                                    isDarkMode: isDarkMode,
                                  ),
                                if (hasReview)
                                  _buildSupervisorSelectorTile(
                                    label: "مشرف المراجعة:",
                                    selectedList: selectedReviewSupervisors,
                                    onTap: () => _showStaffSelectionBottomSheet(context, isDarkMode, selectedReviewSupervisors, "حدد مشرفي المراجعة"),
                                    isDarkMode: isDarkMode,
                                  ),
                              ],
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
                              onPressed: loading ? null : save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: absent ? Colors.orange.withOpacity(0.9) : (isExam ? Colors.teal.withOpacity(0.9) : (didNotRecite ? Colors.blueGrey.withOpacity(0.9) : (isDarkMode ? Colors.orange.withOpacity(0.9) : primaryColor.withOpacity(0.9)))),
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: Colors.black38,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("حفظ التعديلات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'Cairo')),
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