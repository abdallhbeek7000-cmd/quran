import 'dart:async' as async;
import 'dart:core';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart' as rec;
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class SupervisorChatPage extends StatefulWidget {
  final String chatId;
  final String studentId;
  final String studentName;
  final String supervisorId;

  const SupervisorChatPage({
    super.key,
    required this.chatId,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
  });

  @override
  State<SupervisorChatPage> createState() => _SupervisorChatPageState();
}

class _SupervisorChatPageState extends State<SupervisorChatPage> {
  _SupervisorChatPageState();

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // 🎨 ألوان الهوية المعتمدة
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffcdb375);

  // ☁️ بيانات Cloudinary
  final String cloudName = 'dqsrrej2b';
  final String uploadPreset = 'rhjrrtqz';

  late final rec.AudioRecorder _audioRecorder;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  String _uploadStatusText = '';

  late final async.Stream<List<dynamic>> _messagesStream;
  late final async.Stream<DocumentSnapshot> _chatDocStream;
  List<String> _allChatDocIds = [];

  // 🖼️ بيانات وصورة الطالب
  String? _studentImageUrl;
  Map<String, dynamic> _studentProfile = {};

  String? _floatingDateLabel;
  bool _showFloatingDate = false;
  bool _showScrollToBottomBtn = false;

  // 🔍 البحث والفلترة داخل المحادثة
  bool _isSearching = false;
  String _searchQuery = '';
  String _activeFilter = 'all'; // all | image | audio | starred

  // 📌 الرسالة المثبتة
  Map<String, dynamic>? _pinnedMessage;

  // ↩️ الرد على رسالة
  Map<String, dynamic>? _replyingTo;

  // ⚡ ردود سريعة للمشرف
  bool _showQuickReplies = false;
  final List<String> _quickRepliesList = const [
    "وعليكم السلام ورحمة الله 🌹",
    "حياكم الله، تم الاطلاع",
    "بانتظاركم في موعد التسميع إن شاء الله",
    "تم تسجيل الملاحظة، جزاكم الله خيراً",
    "مبارك تفوق الطالب، بارك الله فيكم 🌟",
  ];

  @override
  void initState() {
    super.initState();
    _audioRecorder = rec.AudioRecorder();

    final initialIds = <String>{widget.chatId};
    if (widget.studentId.isNotEmpty) {
      initialIds.add(widget.studentId);
      if (widget.supervisorId.isNotEmpty) {
        initialIds.add('${widget.studentId}_${widget.supervisorId}');
      }
    }
    _allChatDocIds = initialIds.toList();

    _chatDocStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots();

    _messagesStream = _createMergedStudentMessagesStream(initialIds.toList());
    _scrollController.addListener(_onScroll);
    _loadStudentProfileAndImage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _audioRecorder.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentProfileAndImage() async {
    try {
      Map<String, dynamic>? data;
      if (widget.studentId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('students')
            .doc(widget.studentId)
            .get();
        if (doc.exists && doc.data() != null) {
          data = doc.data()!;
        }
      }

      if (data == null && widget.studentName.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('students')
            .where('name', isEqualTo: widget.studentName)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          data = snap.docs.first.data();
        }
      }

      if (data != null && mounted) {
        final rawImg = data['imageUrl']?.toString().trim() ?? '';
        setState(() {
          _studentProfile = data!;
          _studentImageUrl = rawImg.isNotEmpty ? rawImg : null;
        });
      }
    } catch (e) {
      debugPrint("خطأ جلب بيانات وصورة الطالب: $e");
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    final isScrolling = pixels > 40;
    final showDownBtn = pixels > 260;

    if ((isScrolling != _showFloatingDate || showDownBtn != _showScrollToBottomBtn) && mounted) {
      setState(() {
        _showFloatingDate = isScrolling;
        _showScrollToBottomBtn = showDownBtn;
      });
    }
  }

  void _clearUnreadBadges(Iterable<String> ids) {
    for (final id in ids) {
      if (id.isEmpty) continue;
      FirebaseFirestore.instance.collection('chats').doc(id).set({
        'unreadBySupervisor': 0,
      }, SetOptions(merge: true)).catchError((_) {});
    }
  }

  DateTime? _extractDateTime(Map<String, dynamic> msg) {
    final raw = msg['timestamp'] ?? msg['createdAt'] ?? msg['sentAt'] ?? msg['date'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  String _extractMessageText(Map<String, dynamic> msg) {
    final val = msg['text'] ?? msg['message'] ?? msg['body'] ?? msg['content'];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString();
    }
    final reactions = msg['reactions'];
    if (reactions is Map && reactions['text'] != null) {
      return reactions['text'].toString();
    }
    return '';
  }

  String _detectMessageType(Map<String, dynamic> msg) {
    final explicitType = msg['type']?.toString().toLowerCase() ?? '';
    if (explicitType == 'image' || explicitType == 'audio') return explicitType;
    if ((msg['imageUrl']?.toString() ?? '').isNotEmpty) return 'image';
    if ((msg['audioUrl']?.toString() ?? '').isNotEmpty) return 'audio';
    return 'text';
  }

  bool _isSentByMe(Map<String, dynamic> msg) {
    if (msg['senderId'] == widget.supervisorId) return true;
    final senderType = msg['senderType']?.toString().toLowerCase() ?? '';
    return senderType == 'supervisor' || senderType == 'admin' || senderType == 'manager';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDayHeader(DateTime? dt) {
    if (dt == null) return 'غير محدد';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return 'اليوم';
    if (target == yesterday) return 'أمس';

    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '${dt.month}';
    if (dt.year == now.year) {
      return '${dt.day} $monthName';
    }
    return '${dt.day} $monthName ${dt.year}';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'م' : 'ص';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  String _formatRecordTimer(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  async.Stream<List<dynamic>> _createMergedStudentMessagesStream(List<String> seedIds) {
    late async.StreamController<List<dynamic>> controller;
    final Map<String, async.StreamSubscription<QuerySnapshot>> subSubs = {};
    final Map<String, List<dynamic>> latestMsgsByDoc = {};
    async.StreamSubscription<QuerySnapshot>? chatsQuerySub;

    void emitSorted() {
      if (controller.isClosed) return;
      final Map<String, Map<String, dynamic>> unique = {};

      for (final entry in latestMsgsByDoc.entries) {
        for (final msg in entry.value) {
          final dt = _extractDateTime(msg);
          final txt = _extractMessageText(msg);
          final media = msg['imageUrl']?.toString() ?? msg['audioUrl']?.toString() ?? '';
          final sender = msg['senderId']?.toString() ?? msg['senderType']?.toString() ?? '';
          final key = '${sender}_${txt}_${media}_${dt?.millisecondsSinceEpoch ?? msg['_docId']}';
          unique[key] = msg;
        }
      }

      final sorted = unique.values.toList()
        ..sort((a, b) {
          final dtA = _extractDateTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = _extractDateTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });

      controller.add(sorted);
    }

    void attachDocListener(String docId) {
      if (docId.isEmpty || subSubs.containsKey(docId)) return;
      latestMsgsByDoc[docId] = [];
      subSubs[docId] = FirebaseFirestore.instance
          .collection('chats')
          .doc(docId)
          .collection('messages')
          .snapshots()
          .listen(
        (snap) {
          latestMsgsByDoc[docId] = snap.docs.map((d) {
            final map = Map<String, dynamic>.from(d.data());
            map['_docId'] = d.id;
            map['_chatDocId'] = docId;
            return map;
          }).toList();
          emitSorted();
        },
        onError: (_) => emitSorted(),
      );
    }

    controller = async.StreamController<List<dynamic>>(
      onListen: () {
        final discoveredIds = <String>{...seedIds};
        for (final id in discoveredIds) {
          attachDocListener(id);
        }
        _clearUnreadBadges(discoveredIds);

        if (widget.studentId.isNotEmpty) {
          chatsQuerySub = FirebaseFirestore.instance
              .collection('chats')
              .where('studentId', isEqualTo: widget.studentId)
              .snapshots()
              .listen(
            (snap) {
              for (final doc in snap.docs) {
                if (!discoveredIds.contains(doc.id)) {
                  discoveredIds.add(doc.id);
                  _allChatDocIds = discoveredIds.toList();
                  attachDocListener(doc.id);
                  _clearUnreadBadges([doc.id]);
                }
              }
            },
            onError: (_) {},
          );
        }
      },
      onCancel: () async {
        await chatsQuerySub?.cancel();
        for (final s in subSubs.values) {
          await s.cancel();
        }
        await controller.close();
      },
    );

    return controller.stream;
  }

  // ☁️ رفع وإرسال الصور عبر Cloudinary
  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatusText = 'جاري رفع الصورة... 🖼️';
      });

      final bytes = await pickedFile.readAsBytes();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: pickedFile.name),
        );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        final String downloadUrl = jsonMap['secure_url'];
        await _sendMediaMessage(imageUrl: downloadUrl, type: 'image');
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل رفع الصورة');
      }
    } catch (e) {
      debugPrint("❌ خطأ رفع الصورة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تعذر رفع الصورة: ${e.toString()}", style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 🎙️ رفع وإرسال التسجيل الصوتي عبر Cloudinary
  Future<void> _uploadAndSendAudio(String? path, int durationSeconds) async {
    if (path == null || path.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'جاري إرسال التسجيل الصوتي... 🎙️';
    });

    try {
      Uint8List? audioBytes;
      final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (kIsWeb) {
        final res = await http.get(Uri.parse(path));
        audioBytes = res.bodyBytes;
      } else {
        final file = File(path);
        if (await file.exists()) {
          audioBytes = await file.readAsBytes();
        }
      }

      if (audioBytes == null || audioBytes.isEmpty) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', audioBytes, filename: fileName),
        );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        final String downloadUrl = jsonMap['secure_url'];
        await _sendMediaMessage(
          audioUrl: downloadUrl,
          duration: durationSeconds > 0 ? durationSeconds : 1,
          type: 'audio',
        );
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل رفع الصوت');
      }
    } catch (e) {
      debugPrint("❌ خطأ رفع الصوت: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تعذر إرسال التسجيل الصوتي", style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _setReplyTarget({
    required String messageId,
    required String previewText,
    required bool isMe,
  }) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyingTo = {
        'id': messageId,
        'senderName': isMe ? 'أنت' : 'ولي أمر الطالب',
        'text': previewText,
      };
    });
    _inputFocusNode.requestFocus();
  }

  Future<void> _toggleStarMessage(String parentChatDocId, String messageId, bool currentStarred) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(parentChatDocId)
          .collection('messages')
          .doc(messageId)
          .set({'isStarred': !currentStarred}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _pinMessageToChat({
    required String messageId,
    required String previewText,
    required bool isMe,
  }) async {
    final pinData = {
      'id': messageId,
      'senderName': isMe ? 'المشرف' : 'ولي الأمر',
      'text': previewText,
    };
    setState(() => _pinnedMessage = pinData);

    final targets = _allChatDocIds.isNotEmpty ? _allChatDocIds : [widget.chatId];
    for (final id in targets) {
      FirebaseFirestore.instance.collection('chats').doc(id).set({
        'pinnedMessage': pinData,
      }, SetOptions(merge: true)).catchError((_) {});
    }
  }

  Future<void> _unpinMessage() async {
    setState(() => _pinnedMessage = null);
    final targets = _allChatDocIds.isNotEmpty ? _allChatDocIds : [widget.chatId];
    for (final id in targets) {
      FirebaseFirestore.instance.collection('chats').doc(id).set({
        'pinnedMessage': FieldValue.delete(),
      }, SetOptions(merge: true)).catchError((_) {});
    }
  }

  void _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final replyPayload = _replyingTo;
    setState(() {
      _replyingTo = null;
      _showQuickReplies = false;
    });

    if (overrideText == null) {
      _messageController.clear();
    }
    _scrollToBottom();

    final Map<String, dynamic> newMsgData = {
      'senderId': widget.supervisorId,
      'senderType': 'supervisor',
      'type': 'text',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    if (replyPayload != null) {
      newMsgData['replyTo'] = replyPayload;
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(newMsgData);

    await _syncChatLastMessageAndNotify(lastMessagePreview: text);
  }

  Future<void> _sendMediaMessage({
    String? audioUrl,
    String? imageUrl,
    int? duration,
    required String type,
  }) async {
    final replyPayload = _replyingTo;
    setState(() {
      _replyingTo = null;
      _showQuickReplies = false;
    });
    _scrollToBottom();

    final Map<String, dynamic> messageData = {
      'senderId': widget.supervisorId,
      'senderType': 'supervisor',
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    if (replyPayload != null) {
      messageData['replyTo'] = replyPayload;
    }

    if (type == 'audio') {
      messageData['audioUrl'] = audioUrl;
      messageData['duration'] = duration ?? 1;
      messageData['text'] = '';
    } else if (type == 'image') {
      messageData['imageUrl'] = imageUrl;
      messageData['text'] = '';
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    final String lastMsg = type == 'audio'
        ? "🎙️ تسجيل صوتي (${_formatRecordTimer(duration ?? 0)})"
        : "📷 صورة";

    await _syncChatLastMessageAndNotify(lastMessagePreview: lastMsg);
  }

  Future<void> _syncChatLastMessageAndNotify({required String lastMessagePreview}) async {
    final targets = _allChatDocIds.isNotEmpty ? _allChatDocIds : [widget.chatId];
    for (final id in targets) {
      FirebaseFirestore.instance.collection('chats').doc(id).set({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderType': 'supervisor',
        'lastSenderId': widget.supervisorId,
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'supervisorId': widget.supervisorId,
        'unreadByParent': FieldValue.increment(1),
      }, SetOptions(merge: true)).catchError((_) {});
    }

    if (mounted) {
      NotificationService.sendAndSaveNotification(
        studentId: widget.studentId,
        title: "💬 رسالة جديدة من مشرف الدورة",
        body: lastMessagePreview,
        type: "chat",
        chatStudentId: widget.studentId,
        context: context,
      );
    }
  }

  Future<void> _deleteMessage(String parentChatDocId, String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(parentChatDocId)
          .collection('messages')
          .doc(messageId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حذف الرسالة", style: TextStyle(fontFamily: 'Cairo')),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showStudentProfileSheet(bool isDark) {
    final fatherName = _studentProfile['fatherName']?.toString() ?? '';
    final points = _studentProfile['points']?.toString() ?? '0';
    final memorizedPages = _studentProfile['memorizedPages']?.toString() ?? '0';
    final phone = _studentProfile['phone']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff131c2e).withOpacity(0.95) : Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: accentGold.withOpacity(0.5), width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_studentImageUrl != null && _studentImageUrl!.isNotEmpty) {
                          Navigator.pop(sheetCtx);
                          _showImagePreview(context, _studentImageUrl!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentGold, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: primaryColor.withOpacity(0.15),
                          backgroundImage: (_studentImageUrl != null && _studentImageUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(_studentImageUrl!)
                              : null,
                          child: (_studentImageUrl == null || _studentImageUrl!.isEmpty)
                              ? Text(
                                  widget.studentName.isNotEmpty ? widget.studentName.characters.first : 'ط',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                    color: isDark ? accentGold : primaryColor,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.studentName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                    ),
                    if (fatherName.isNotEmpty)
                      Text(
                        "ولي الأمر: $fatherName",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatMiniBox(
                            icon: Icons.menu_book_rounded,
                            label: "الصفحات المحفوظة",
                            value: memorizedPages,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatMiniBox(
                            icon: Icons.stars_rounded,
                            label: "النقاط",
                            value: points,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(isDark ? 0.25 : 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_rounded, size: 16, color: accentGold),
                            const SizedBox(width: 8),
                            Text(
                              phone,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: accentGold,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: accentGold.withOpacity(0.5)),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _sendMessage(
                            "السلام عليكم، نبارك لكم مستوى الطالب ${widget.studentName} المتميز (الحفظ: $memorizedPages صفحة | النقاط: $points نقطة) 🌟",
                          );
                        },
                        icon: const Icon(Icons.celebration_rounded, size: 19),
                        label: const Text(
                          "إرسال بطاقة تهنئة بإنجاز الطالب",
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatMiniBox({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentGold.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accentGold, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : primaryColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.88),
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => CircularProgressIndicator(color: accentGold),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.94) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accentGold.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "إرسال مرفق لولي الأمر",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAttachmentOption(
                          icon: Icons.photo_library_rounded,
                          color: primaryColor,
                          label: "معرض الصور",
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _pickAndSendImage(ImageSource.gallery);
                          },
                        ),
                        _buildAttachmentOption(
                          icon: Icons.camera_alt_rounded,
                          color: accentGold,
                          label: "التقاط صورة",
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _pickAndSendImage(ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.14),
              border: Border.all(color: color.withOpacity(0.45), width: 1.5),
            ),
            child: Icon(icon, color: isDark && color == primaryColor ? accentGold : color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: isDark ? Colors.white : const Color(0xff0f172a),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActionsSheet({
    required BuildContext context,
    required String parentChatDocId,
    required String messageId,
    required String msgType,
    required String messageText,
    required bool isStarred,
    required bool isMe,
    required bool isDark,
  }) {
    HapticFeedback.mediumImpact();
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    final String replyPreview = msgType == 'image'
        ? '📷 صورة'
        : (msgType == 'audio' ? '🎙️ تسجيل صوتي' : messageText);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.94) : Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? Colors.white24 : primaryColor.withOpacity(0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: emojis.map((emoji) {
                        return GestureDetector(
                          onTap: () {
                            FirebaseFirestore.instance
                                .collection('chats')
                                .doc(parentChatDocId)
                                .collection('messages')
                                .doc(messageId)
                                .set({
                              'reactions': {
                                widget.supervisorId: emoji,
                              }
                            }, SetOptions(merge: true));
                            Navigator.pop(sheetContext);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withOpacity(0.07),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 25)),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 22, thickness: 0.8),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.reply_rounded, color: isDark ? accentGold : primaryColor),
                      title: Text(
                        "رد على الرسالة",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xff0f172a),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _setReplyTarget(
                          messageId: messageId,
                          previewText: replyPreview,
                          isMe: isMe,
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.push_pin_rounded, color: accentGold),
                      title: Text(
                        "تثبيت أعلى المحادثة",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xff0f172a),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pinMessageToChat(
                          messageId: messageId,
                          previewText: replyPreview,
                          isMe: isMe,
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: accentGold,
                      ),
                      title: Text(
                        isStarred ? "إزالة النجمة" : "تمييز بنجمة ⭐",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xff0f172a),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _toggleStarMessage(parentChatDocId, messageId, isStarred);
                      },
                    ),
                    if (msgType == 'text' && messageText.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.copy_rounded, color: isDark ? Colors.white70 : primaryColor),
                        title: Text(
                          "نسخ النص",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xff0f172a),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Clipboard.setData(ClipboardData(text: messageText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("تم نسخ الرسالة", style: TextStyle(fontFamily: 'Cairo')),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    if (isMe)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        title: const Text(
                          "حذف الرسالة",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.redAccent,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _deleteMessage(parentChatDocId, messageId);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateDivider(String label, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff1e293b).withOpacity(0.92) : Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentGold.withOpacity(isDark ? 0.35 : 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? accentGold : primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuotedBubble(Map<String, dynamic> replyTo, bool isMe, bool isDark) {
    final senderName = replyTo['senderName']?.toString() ?? 'رسالة';
    final quotedText = replyTo['text']?.toString() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withOpacity(0.2)
            : (isDark ? Colors.white.withOpacity(0.06) : primaryColor.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(
            color: isMe ? accentGold : primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isMe ? accentGold : (isDark ? accentGold : primaryColor),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            quotedText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: isMe
                  ? Colors.white.withOpacity(0.88)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, bool isDark) {
    final bool selected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor
              : (isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.9)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accentGold : accentGold.withOpacity(0.3),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: selected ? accentGold : (isDark ? Colors.white70 : primaryColor)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : (isDark ? Colors.white70 : primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff0b1120) : const Color(0xffeaf0f5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? [const Color(0xff182636).withOpacity(0.94), const Color(0xff0f172a).withOpacity(0.94)]
                  : [primaryColor.withOpacity(0.95), const Color(0xff32485d).withOpacity(0.95)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
            border: Border(
              bottom: BorderSide(color: accentGold.withOpacity(0.48), width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.24),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _isSearching
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: "ابحث في رسائل المحادثة...",
                                  hintStyle: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.backspace_outlined, color: accentGold, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                          ],
                        )
                      : Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            GestureDetector(
                              onTap: () => _showStudentProfileSheet(isDark),
                              child: Stack(
                                alignment: Alignment.bottomLeft,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accentGold, width: 1.6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentGold.withOpacity(0.28),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white.withOpacity(0.14),
                                      backgroundImage: (_studentImageUrl != null && _studentImageUrl!.isNotEmpty)
                                          ? CachedNetworkImageProvider(_studentImageUrl!)
                                          : null,
                                      child: (_studentImageUrl == null || _studentImageUrl!.isEmpty)
                                          ? Text(
                                              widget.studentName.isNotEmpty
                                                  ? widget.studentName.characters.first
                                                  : 'ط',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: accentGold,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Container(
                                    width: 10.5,
                                    height: 10.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff22c55e),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: primaryColor, width: 1.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showStudentProfileSheet(isDark),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.studentName,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.verified_user_rounded, size: 12, color: accentGold),
                                        const SizedBox(width: 4),
                                        Text(
                                          "ولي أمر الطالب • اضغط للتفاصيل",
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: accentGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "بطاقة الطالب",
                              icon: Icon(Icons.badge_outlined, color: accentGold, size: 21),
                              onPressed: () => _showStudentProfileSheet(isDark),
                            ),
                            IconButton(
                              tooltip: "بحث في المحادثة",
                              icon: Icon(Icons.search_rounded, color: accentGold, size: 22),
                              onPressed: () => setState(() => _isSearching = true),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🌌 خلفية متدرجة ناعمة مع لمسات زخرفية
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? const [Color(0xff0b1120), Color(0xff131f33), Color(0xff0b1120)]
                    : const [Color(0xfff1f5f9), Color(0xfff7f4ed), Color(0xffe4ecf2)],
              ),
            ),
          ),
          Positioned(
            top: 95,
            right: -60,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGold.withOpacity(isDark ? 0.06 : 0.13),
              ),
            ),
          ),
          Positioned(
            bottom: 110,
            left: -75,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(isDark ? 0.12 : 0.08),
              ),
            ),
          ),

          Column(
            children: [
              SizedBox(height: topPadding + 74 + 10),

              // 🗂️ شريط فلترة سريع للوسائط والرسائل المميزة
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _buildFilterChip('all', 'الكل', Icons.forum_rounded, isDark),
                    const SizedBox(width: 7),
                    _buildFilterChip('image', 'الصور', Icons.image_rounded, isDark),
                    const SizedBox(width: 7),
                    _buildFilterChip('audio', 'الصوتيات', Icons.graphic_eq_rounded, isDark),
                    const SizedBox(width: 7),
                    _buildFilterChip('starred', 'المميزة ⭐', Icons.star_rounded, isDark),
                  ],
                ),
              ),

              Expanded(
                child: Stack(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: _chatDocStream,
                      builder: (context, chatSnapshot) {
                        bool isReadByParent = false;
                        Map<String, dynamic>? activePinned = _pinnedMessage;
                        if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                          final chatData = chatSnapshot.data!.data()! as Map<String, dynamic>;
                          isReadByParent = (chatData['unreadByParent'] ?? 0) == 0;
                          if (chatData['pinnedMessage'] is Map) {
                            activePinned = Map<String, dynamic>.from(chatData['pinnedMessage']);
                          }
                        }

                        return Column(
                          children: [
                            // 📌 شريط الرسالة المثبتة
                            if (activePinned != null)
                              Container(
                                margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xff1e293b).withOpacity(0.95)
                                      : Colors.white.withOpacity(0.96),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: accentGold.withOpacity(0.55), width: 1.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.push_pin_rounded, size: 17, color: accentGold),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "رسالة مثبتة • ${activePinned['senderName'] ?? ''}",
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? accentGold : primaryColor,
                                            ),
                                          ),
                                          Text(
                                            activePinned['text']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11.5,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _unpinMessage,
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            Expanded(
                              child: StreamBuilder<List<dynamic>>(
                                stream: _messagesStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                    return Center(
                                      child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
                                    );
                                  }

                                  final rawMessages = snapshot.data ?? [];
                                  final messages = rawMessages.where((m) {
                                    final map = m as Map<String, dynamic>;
                                    final mType = _detectMessageType(map);
                                    if (_activeFilter == 'image' && mType != 'image') return false;
                                    if (_activeFilter == 'audio' && mType != 'audio') return false;
                                    if (_activeFilter == 'starred' && map['isStarred'] != true) return false;
                                    if (_searchQuery.isNotEmpty) {
                                      final txt = _extractMessageText(map).toLowerCase();
                                      if (!txt.contains(_searchQuery.toLowerCase())) return false;
                                    }
                                    return true;
                                  }).toList();

                                  if (messages.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(22),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primaryColor.withOpacity(0.08),
                                              border: Border.all(color: accentGold.withOpacity(0.45), width: 1.5),
                                            ),
                                            child: Icon(
                                              _searchQuery.isNotEmpty || _activeFilter != 'all'
                                                  ? Icons.filter_list_off_rounded
                                                  : Icons.forum_outlined,
                                              size: 44,
                                              color: isDark ? accentGold : primaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            _searchQuery.isNotEmpty || _activeFilter != 'all'
                                                ? "لا توجد رسائل ضمن هذا الفلتر"
                                                : "لا توجد رسائل بعد",
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : primaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _searchQuery.isNotEmpty || _activeFilter != 'all'
                                                ? "اختر (الكل) لعرض جميع الرسائل"
                                                : "أرسل رسالة نصية أو صورة أو تسجيلاً صوتياً لولي الأمر",
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              color: isDark ? Colors.white38 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final topDt = _extractDateTime(messages.first as Map<String, dynamic>);
                                  _floatingDateLabel = _formatDayHeader(topDt);

                                  return ListView.builder(
                                    controller: _scrollController,
                                    reverse: true,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = messages[index] as Map<String, dynamic>;
                                      final String msgDocId = msg['_docId']?.toString() ?? '$index';
                                      final String parentChatDocId = msg['_chatDocId']?.toString() ?? widget.chatId;
                                      final isMe = _isSentByMe(msg);
                                      final bool isStarred = msg['isStarred'] == true;
                                      final dt = _extractDateTime(msg);
                                      final timeString = _formatTime(dt);
                                      final msgType = _detectMessageType(msg);
                                      final messageText = _extractMessageText(msg);
                                      final Map<String, dynamic>? replyTo =
                                          msg['replyTo'] is Map ? Map<String, dynamic>.from(msg['replyTo']) : null;

                                      final olderMsg = (index + 1 < messages.length)
                                          ? messages[index + 1] as Map<String, dynamic>
                                          : null;
                                      final olderDt = olderMsg != null ? _extractDateTime(olderMsg) : null;
                                      final olderIsMe = olderMsg != null ? _isSentByMe(olderMsg) : null;

                                      final bool showDateSeparator = dt != null &&
                                          (olderDt == null || !_isSameDay(dt, olderDt));

                                      final bool isGroupedWithOlder = olderIsMe == isMe &&
                                          dt != null &&
                                          olderDt != null &&
                                          _isSameDay(dt, olderDt);

                                      final Map<String, dynamic> reactions =
                                          msg['reactions'] is Map ? Map<String, dynamic>.from(msg['reactions']) : {};
                                      final List<String> displayEmojis = reactions.entries
                                          .where((e) =>
                                              e.key != 'text' &&
                                              e.key != 'senderId' &&
                                              e.key != 'senderType' &&
                                              e.key != 'timestamp')
                                          .map((e) => e.value.toString())
                                          .toSet()
                                          .toList();

                                      final String replyPreview = msgType == 'image'
                                          ? '📷 صورة'
                                          : (msgType == 'audio' ? '🎙️ تسجيل صوتي' : messageText);

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (showDateSeparator) _buildDateDivider(_formatDayHeader(dt), isDark),

                                          _SwipeToReplyWrapper(
                                            isMe: isMe,
                                            accentColor: accentGold,
                                            onReply: () => _setReplyTarget(
                                              messageId: msgDocId,
                                              previewText: replyPreview,
                                              isMe: isMe,
                                            ),
                                            child: Align(
                                              alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                                              child: Container(
                                                margin: EdgeInsets.only(
                                                  bottom: displayEmojis.isNotEmpty
                                                      ? 18
                                                      : (isGroupedWithOlder ? 4 : 10),
                                                ),
                                                constraints: BoxConstraints(
                                                  maxWidth: screenWidth > 600 ? 440 : screenWidth * 0.78,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    if (!isMe && !isGroupedWithOlder) ...[
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundColor: primaryColor.withOpacity(0.15),
                                                        backgroundImage: (_studentImageUrl != null &&
                                                                _studentImageUrl!.isNotEmpty)
                                                            ? CachedNetworkImageProvider(_studentImageUrl!)
                                                            : null,
                                                        child: (_studentImageUrl == null ||
                                                                _studentImageUrl!.isEmpty)
                                                            ? Text(
                                                                widget.studentName.isNotEmpty
                                                                    ? widget.studentName.characters.first
                                                                    : 'ط',
                                                                style: TextStyle(
                                                                  fontFamily: 'Cairo',
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: isDark ? accentGold : primaryColor,
                                                                ),
                                                              )
                                                            : null,
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ] else if (!isMe && isGroupedWithOlder) ...[
                                                      const SizedBox(width: 34),
                                                    ],

                                                    Flexible(
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          GestureDetector(
                                                            onLongPress: () => _showMessageActionsSheet(
                                                              context: context,
                                                              parentChatDocId: parentChatDocId,
                                                              messageId: msgDocId,
                                                              msgType: msgType,
                                                              messageText: messageText,
                                                              isStarred: isStarred,
                                                              isMe: isMe,
                                                              isDark: isDark,
                                                            ),
                                                            child: Container(
                                                              padding: msgType == 'image' && replyTo == null
                                                                  ? const EdgeInsets.fromLTRB(6, 6, 6, 8)
                                                                  : const EdgeInsets.fromLTRB(14, 10, 14, 8),
                                                              decoration: BoxDecoration(
                                                                gradient: isMe
                                                                    ? LinearGradient(
                                                                        begin: Alignment.topRight,
                                                                        end: Alignment.bottomLeft,
                                                                        colors: [primaryColor, const Color(0xff33495e)],
                                                                      )
                                                                    : null,
                                                                color: isMe
                                                                    ? null
                                                                    : (isDark
                                                                        ? const Color(0xff1e293b)
                                                                        : Colors.white),
                                                                borderRadius: BorderRadius.only(
                                                                  topLeft: const Radius.circular(20),
                                                                  topRight: const Radius.circular(20),
                                                                  bottomLeft: Radius.circular(isMe ? 4 : 20),
                                                                  bottomRight: Radius.circular(isMe ? 20 : 4),
                                                                ),
                                                                border: Border.all(
                                                                  color: isStarred
                                                                      ? accentGold
                                                                      : (isMe
                                                                          ? accentGold.withOpacity(0.35)
                                                                          : (isDark
                                                                              ? Colors.white.withOpacity(0.1)
                                                                              : primaryColor.withOpacity(0.12))),
                                                                  width: isStarred ? 1.4 : 1,
                                                                ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: isMe
                                                                        ? primaryColor.withOpacity(0.22)
                                                                        : Colors.black
                                                                            .withOpacity(isDark ? 0.25 : 0.05),
                                                                    blurRadius: 10,
                                                                    offset: const Offset(0, 3),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: isMe
                                                                    ? CrossAxisAlignment.start
                                                                    : CrossAxisAlignment.end,
                                                                children: [
                                                                  if (replyTo != null)
                                                                    _buildQuotedBubble(replyTo, isMe, isDark),

                                                                  if (msgType == 'audio')
                                                                    _SupervisorAudioPlayer(
                                                                      audioUrl: msg['audioUrl']?.toString() ?? '',
                                                                      duration: (msg['duration'] is num)
                                                                          ? (msg['duration'] as num).toInt()
                                                                          : 0,
                                                                      isMe: isMe,
                                                                      isDark: isDark,
                                                                      primaryColor: primaryColor,
                                                                      accentGold: accentGold,
                                                                    )
                                                                  else if (msgType == 'image')
                                                                    GestureDetector(
                                                                      onTap: () => _showImagePreview(
                                                                        context,
                                                                        msg['imageUrl']?.toString() ?? '',
                                                                      ),
                                                                      child: ClipRRect(
                                                                        borderRadius: BorderRadius.circular(14),
                                                                        child: CachedNetworkImage(
                                                                          imageUrl:
                                                                              msg['imageUrl']?.toString() ?? '',
                                                                          width: 225,
                                                                          height: 205,
                                                                          fit: BoxFit.cover,
                                                                          placeholder: (_, __) => Container(
                                                                            width: 225,
                                                                            height: 205,
                                                                            color: Colors.black12,
                                                                            child: Center(
                                                                              child: CircularProgressIndicator(
                                                                                strokeWidth: 2,
                                                                                color: isMe
                                                                                    ? accentGold
                                                                                    : primaryColor,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          errorWidget: (_, __, ___) => Container(
                                                                            width: 225,
                                                                            height: 120,
                                                                            color: Colors.black12,
                                                                            child: const Icon(
                                                                              Icons.broken_image_rounded,
                                                                              color: Colors.redAccent,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    )
                                                                  else
                                                                    Text(
                                                                      messageText,
                                                                      style: TextStyle(
                                                                        fontFamily: 'Cairo',
                                                                        fontSize: 14.5,
                                                                        height: 1.45,
                                                                        color: isMe
                                                                            ? Colors.white
                                                                            : (isDark
                                                                                ? Colors.white
                                                                                : const Color(0xff0f172a)),
                                                                      ),
                                                                    ),

                                                                  const SizedBox(height: 5),
                                                                  Padding(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal: msgType == 'image' ? 6 : 0,
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        if (isStarred) ...[
                                                                          Icon(Icons.star_rounded,
                                                                              size: 12.5, color: accentGold),
                                                                          const SizedBox(width: 4),
                                                                        ],
                                                                        if (dt != null) ...[
                                                                          Text(
                                                                            _formatDayHeader(dt),
                                                                            style: TextStyle(
                                                                              fontFamily: 'Cairo',
                                                                              fontSize: 9.5,
                                                                              fontWeight: FontWeight.w600,
                                                                              color: isMe
                                                                                  ? accentGold
                                                                                  : (isDark
                                                                                      ? accentGold.withOpacity(0.85)
                                                                                      : primaryColor.withOpacity(0.75)),
                                                                            ),
                                                                          ),
                                                                          if (timeString.isNotEmpty)
                                                                            Text(
                                                                              ' • ',
                                                                              style: TextStyle(
                                                                                fontSize: 9.5,
                                                                                color: isMe
                                                                                    ? Colors.white60
                                                                                    : Colors.grey,
                                                                              ),
                                                                            ),
                                                                        ],
                                                                        Text(
                                                                          timeString,
                                                                          style: TextStyle(
                                                                            fontFamily: 'Cairo',
                                                                            fontSize: 10,
                                                                            fontWeight: FontWeight.w600,
                                                                            color: isMe
                                                                                ? Colors.white.withOpacity(0.8)
                                                                                : (isDark
                                                                                    ? Colors.white54
                                                                                    : Colors.grey.shade600),
                                                                          ),
                                                                        ),
                                                                        if (isMe) ...[
                                                                          const SizedBox(width: 4),
                                                                          Icon(
                                                                            Icons.done_all_rounded,
                                                                            size: 15,
                                                                            color: isReadByParent
                                                                                ? accentGold
                                                                                : Colors.white54,
                                                                          ),
                                                                        ],
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),

                                                          if (displayEmojis.isNotEmpty)
                                                            Positioned(
                                                              bottom: -12,
                                                              left: isMe ? 12 : null,
                                                              right: isMe ? null : 12,
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(
                                                                    horizontal: 7, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: isDark
                                                                      ? const Color(0xff1e293b)
                                                                      : Colors.white,
                                                                  borderRadius: BorderRadius.circular(14),
                                                                  border: Border.all(
                                                                    color: accentGold.withOpacity(0.55),
                                                                    width: 1,
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors.black.withOpacity(0.14),
                                                                      blurRadius: 5,
                                                                      offset: const Offset(0, 2),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Text(
                                                                  displayEmojis.join(' '),
                                                                  style: const TextStyle(fontSize: 13),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    if (_showFloatingDate && _floatingDateLabel != null)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: _buildDateDivider(_floatingDateLabel!, isDark),
                        ),
                      ),

                    if (_showScrollToBottomBtn)
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: accentGold, width: 1.3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: accentGold,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ⚡ شريط الردود السريعة للمشرف
              if (_showQuickReplies)
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _quickRepliesList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final quickText = _quickRepliesList[idx];
                      return GestureDetector(
                        onTap: () => _sendMessage(quickText),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xff1e293b) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accentGold.withOpacity(0.55), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            quickText,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ✍️ شريط الإدخال المتكامل (نصوص + صور + تسجيل صوتي + رد + ردود سريعة)
              Container(
                margin: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 4,
                  bottom: isKeyboardOpen ? 10 : 18,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff131c2e).withOpacity(0.95) : Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accentGold.withOpacity(isDark ? 0.35 : 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.32 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4, top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            right: BorderSide(color: accentGold, width: 3.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply_rounded, size: 18, color: isDark ? accentGold : primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "الرد على ${_replyingTo!['senderName']}",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? accentGold : primaryColor,
                                    ),
                                  ),
                                  Text(
                                    _replyingTo!['text'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyingTo = null),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isUploading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: accentGold),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _uploadStatusText,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : primaryColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _SupervisorRecordingBar(
                        audioRecorder: _audioRecorder,
                        messageController: _messageController,
                        inputFocusNode: _inputFocusNode,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        accentGold: accentGold,
                        showQuickReplies: _showQuickReplies,
                        onToggleQuickReplies: () => setState(() => _showQuickReplies = !_showQuickReplies),
                        onSendTextMessage: () => _sendMessage(),
                        onSendAudioMessage: _uploadAndSendAudio,
                        onOpenAttachmentMenu: () => _showAttachmentMenu(context, isDark),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🎙️ شريط الإدخال والتسجيل الصوتي المستقل
class _SupervisorRecordingBar extends StatefulWidget {
  final rec.AudioRecorder audioRecorder;
  final TextEditingController messageController;
  final FocusNode inputFocusNode;
  final bool isDark;
  final Color primaryColor;
  final Color accentGold;
  final bool showQuickReplies;
  final VoidCallback onToggleQuickReplies;
  final VoidCallback onSendTextMessage;
  final Function(String? path, int durationSeconds) onSendAudioMessage;
  final VoidCallback onOpenAttachmentMenu;

  const _SupervisorRecordingBar({
    required this.audioRecorder,
    required this.messageController,
    required this.inputFocusNode,
    required this.isDark,
    required this.primaryColor,
    required this.accentGold,
    required this.showQuickReplies,
    required this.onToggleQuickReplies,
    required this.onSendTextMessage,
    required this.onSendAudioMessage,
    required this.onOpenAttachmentMenu,
  });

  @override
  State<_SupervisorRecordingBar> createState() => _SupervisorRecordingBarState();
}

class _SupervisorRecordingBarState extends State<_SupervisorRecordingBar>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  async.Timer? _recordingTimer;
  int _recordDurationSeconds = 0;
  late AnimationController _micPulseController;

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _micPulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await widget.audioRecorder.hasPermission()) {
        rec.RecordConfig config;
        String savePath = '';

        if (kIsWeb) {
          config = const rec.RecordConfig(encoder: rec.AudioEncoder.opus);
          savePath = '';
        } else {
          config = const rec.RecordConfig(encoder: rec.AudioEncoder.aacLc, bitRate: 128000);
          final dir = await getTemporaryDirectory();
          savePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await widget.audioRecorder.start(config, path: savePath);
        HapticFeedback.mediumImpact();

        _recordDurationSeconds = 0;
        _recordingTimer?.cancel();
        _recordingTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDurationSeconds++;
            });
          }
        });

        _micPulseController.repeat(reverse: true);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("❌ خطأ عند بدء التسجيل: $e");
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    _micPulseController.stop();
    final int finalDuration = _recordDurationSeconds;

    try {
      final String? path = await widget.audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordDurationSeconds = 0;
      });
      widget.onSendAudioMessage(path, finalDuration);
    } catch (e) {
      debugPrint("❌ خطأ عند إيقاف التسجيل: $e");
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _micPulseController.stop();
    await widget.audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordDurationSeconds = 0;
    });
  }

  String _formatRecordTimer(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Row(
        children: [
          IconButton(
            tooltip: "إلغاء التسجيل",
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            onPressed: _cancelRecording,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.25).animate(_micPulseController),
                  child: const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRecordTimer(_recordDurationSeconds),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "جاري التسجيل الصوتي...",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: widget.isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: widget.accentGold, width: 1.2),
              ),
              child: Icon(Icons.send_rounded, color: widget.accentGold, size: 20),
            ),
          ),
        ],
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.messageController,
      builder: (context, value, child) {
        final bool hasText = value.text.trim().isNotEmpty;

        return Row(
          children: [
            IconButton(
              tooltip: "ردود سريعة",
              onPressed: widget.onToggleQuickReplies,
              icon: Icon(
                widget.showQuickReplies ? Icons.bolt_rounded : Icons.bolt_outlined,
                color: widget.showQuickReplies
                    ? widget.accentGold
                    : (widget.isDark ? Colors.white60 : widget.primaryColor.withOpacity(0.8)),
                size: 22,
              ),
            ),
            Expanded(
              child: TextField(
                controller: widget.messageController,
                focusNode: widget.inputFocusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSendTextMessage(),
                style: TextStyle(
                  color: widget.isDark ? Colors.white : const Color(0xff0f172a),
                  fontFamily: 'Cairo',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: "اكتب رسالتك...",
                  hintStyle: TextStyle(
                    color: widget.isDark ? Colors.white38 : Colors.grey.shade500,
                    fontFamily: 'Cairo',
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                ),
              ),
            ),
            if (!hasText) ...[
              IconButton(
                tooltip: "إرسال صورة",
                icon: Icon(
                  Icons.camera_alt_outlined,
                  color: widget.isDark ? Colors.white60 : widget.primaryColor.withOpacity(0.8),
                  size: 22,
                ),
                onPressed: widget.onOpenAttachmentMenu,
              ),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              onTap: hasText ? widget.onSendTextMessage : _startRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.primaryColor, const Color(0xff32485d)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.accentGold.withOpacity(0.65), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: widget.accentGold,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 🔊 مشغل الصوت داخل الفقاعات
class _SupervisorAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  final bool isDark;
  final Color primaryColor;
  final Color accentGold;

  const _SupervisorAudioPlayer({
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    required this.isDark,
    required this.primaryColor,
    required this.accentGold,
  });

  @override
  State<_SupervisorAudioPlayer> createState() => _SupervisorAudioPlayerState();
}

class _SupervisorAudioPlayerState extends State<_SupervisorAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.duration);

    if (!kIsWeb) {
      _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
    }

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else if (widget.audioUrl.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      debugPrint("❌ خطأ تشغيل الصوت: $e");
    }
  }

  String _formatDuration(Duration d) {
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final Color activeBarColor = widget.isMe ? widget.accentGold : widget.primaryColor;
    final Color inactiveBarColor = widget.isMe
        ? Colors.white.withOpacity(0.32)
        : (widget.isDark ? Colors.white24 : Colors.grey.shade400);

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: widget.isMe ? widget.accentGold : widget.primaryColor,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 21,
                color: widget.isMe ? widget.primaryColor : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(20, (index) {
                    final double height = 5 + ((index * 7) % 14).toDouble();
                    final double progress = _totalDuration.inSeconds > 0
                        ? (_position.inSeconds / _totalDuration.inSeconds)
                        : 0.0;
                    final bool isActive = (index / 20) <= progress;

                    return Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        decoration: BoxDecoration(
                          color: isActive ? activeBarColor : inactiveBarColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(_isPlaying ? _position : _totalDuration),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.85)
                        : (widget.isDark ? Colors.white60 : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ↔️ السحب للرد على الرسالة
class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final Color accentColor;
  final VoidCallback onReply;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.isMe,
    required this.accentColor,
    required this.onReply,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> {
  double _dragOffset = 0.0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(-64.0, 64.0);
        });
        if (!_triggered && _dragOffset.abs() >= 48.0) {
          _triggered = true;
          widget.onReply();
        }
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _dragOffset = 0.0;
          _triggered = false;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_dragOffset.abs() > 8)
            Positioned(
              left: _dragOffset > 0 ? 12 : null,
              right: _dragOffset < 0 ? 12 : null,
              child: Opacity(
                opacity: (_dragOffset.abs() / 48.0).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    color: widget.accentColor,
                    size: 18,
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}