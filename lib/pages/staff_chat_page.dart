import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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

class StaffChatPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String peerId;
  final String peerName;
  final String peerRole;

  const StaffChatPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
    required this.peerRole,
  });

  @override
  State<StaffChatPage> createState() => _StaffChatPageState();
}

class _StaffChatPageState extends State<StaffChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // 🎨 ألوان الهوية والشعار المحددة (#425c75 & #cdb375)
  final Color primaryNavy = const Color(0xff425c75);
  final Color accentGold = const Color(0xffcdb375);

  late final rec.AudioRecorder _audioRecorder;
  bool _isUploading = false;
  String _uploadStatusText = '';

  final ImagePicker _imagePicker = ImagePicker();

  // ☁️ بيانات Cloudinary
  final String cloudName = 'dqsrrej2b'; 
  final String uploadPreset = 'rhjrrtqz'; 

  // ↩️ الرسالة المراد الرد عليها
  Map<String, dynamic>? _replyMessage;

  // 🔒 تثبيت الاتصال بالـ Firestore
  late final Stream<QuerySnapshot> _messagesStream;
  late final Stream<DocumentSnapshot> _chatSnapshotStream;

  @override
  void initState() {
    super.initState();
    _audioRecorder = rec.AudioRecorder();
    _clearUnreadBadge();

    _chatSnapshotStream = FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .snapshots();

    _messagesStream = FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearUnreadBadge() async {
    await FirebaseFirestore.instance.collection('staff_chats').doc(widget.chatId).set({
      'unread_${widget.currentUserId}': 0,
    }, SetOptions(merge: true));
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'م' : 'ص';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  String _formatRecordTimer(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ☁️ رفع الصور
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
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: pickedFile.name),
        );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        String downloadUrl = jsonMap['secure_url'];
        _sendMediaMessage(imageUrl: downloadUrl, type: 'image');
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل الرفع إلى Cloudinary');
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

  // 🎙️ رفع الصوت
  Future<void> _uploadAndSendAudio(String? path, int durationSeconds) async {
    if (path == null || path.isEmpty) {
      debugPrint("❌ مسار التسجيل فارغ");
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'جاري إرسال الصوت... 🎙️';
    });

    try {
      Uint8List? audioBytes;
      String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
        setState(() => _isUploading = false);
        return;
      }

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', audioBytes, filename: fileName),
        );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        String downloadUrl = jsonMap['secure_url'];
        _sendMediaMessage(audioUrl: downloadUrl, duration: durationSeconds > 0 ? durationSeconds : 1, type: 'audio');
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل الرفع');
      }
    } catch (e) {
      debugPrint("❌ خطأ رفع الصوت: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر إرسال التسجيل الصوتي", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyData = _replyMessage;
    setState(() => _replyMessage = null);

    _messageController.clear();
    _scrollToBottom();

    Map<String, dynamic> msgData = {
      'senderId': widget.currentUserId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    if (replyData != null) {
      msgData['replyTo'] = replyData;
    }

    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(msgData);

    _updateChatLastMessage("💬 $text");
  }

  void _sendMediaMessage({String? audioUrl, String? imageUrl, int? duration, required String type}) async {
    final replyData = _replyMessage;
    setState(() => _replyMessage = null);
    _scrollToBottom();

    Map<String, dynamic> messageData = {
      'senderId': widget.currentUserId,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };

    if (replyData != null) {
      messageData['replyTo'] = replyData;
    }

    if (type == 'audio') {
      messageData['audioUrl'] = audioUrl;
      messageData['duration'] = duration;
    } else if (type == 'image') {
      messageData['imageUrl'] = imageUrl;
    }

    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    String lastMsg = type == 'audio' 
        ? "🎙️ تسجيل صوتي (${_formatRecordTimer(duration ?? 0)})" 
        : "📷 صورة متبادلة";
        
    _updateChatLastMessage(lastMsg);
  }

  void _deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('staff_chats')
        .doc(widget.chatId)
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
  }

  void _updateChatLastMessage(String lastMessage) async {
    await FirebaseFirestore.instance.collection('staff_chats').doc(widget.chatId).set({
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': widget.currentUserId,
      'participants': [widget.currentUserId, widget.peerId],
      'unread_${widget.peerId}': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (mounted) {
      await NotificationService.sendAndSaveNotification(
        studentId: widget.peerId,
        title: "💬 رسالة من ${widget.peerRole == 'manager' ? 'المدير' : 'المشرف'}",
        body: lastMessage,
        type: "staff_chat",
        context: context,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
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
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 25, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff26384a).withOpacity(0.88) : Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    color: primaryNavy,
                    label: "المعرض",
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    color: accentGold,
                    label: "الكاميرا",
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showMessageOptionsMenu(BuildContext context, String messageId, Map<String, dynamic> msg, bool isMe, bool isDark) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1e293b) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.5),
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
                            .collection('staff_chats')
                            .doc(widget.chatId)
                            .collection('messages')
                            .doc(messageId)
                            .set({
                          'reactions': {widget.currentUserId: emoji}
                        }, SetOptions(merge: true));
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.05),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 24, thickness: 0.8),
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: primaryNavy),
                  title: const Text("رد على الرسالة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    String previewText = msg['type'] == 'image'
                        ? '📷 صورة'
                        : (msg['type'] == 'audio' ? '🎙️ تسجيل صوتي' : (msg['text'] ?? ''));
                    setState(() {
                      _replyMessage = {
                        'id': messageId,
                        'senderName': isMe ? 'أنت' : widget.peerName,
                        'text': previewText,
                      };
                    });
                  },
                ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: const Text("حذف الرسالة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(messageId);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff101722) : const Color(0xffdfe8ed),
      
      // 📌 الـ AppBar بدون أيقونات المكالمات والنقاط الثلاث
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: primaryNavy.withOpacity(0.76),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: accentGold.withOpacity(0.3),
                            child: Icon(
                              widget.peerRole == 'manager' ? Icons.groups_rounded : Icons.person_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xff22c55e),
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryNavy, width: 2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.peerName,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xff22c55e),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "متصل الآن",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: accentGold,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xff101722), Color(0xff1b2936), Color(0xff111923)]
                : const [Color(0xffeaf1f4), Color(0xfff7f4ed), Color(0xffdce8e7)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 90,
              right: -65,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGold.withOpacity(isDark ? 0.07 : 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryNavy.withOpacity(isDark ? 0.12 : 0.08),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _chatSnapshotStream,
                    builder: (context, chatSnapshot) {
                      bool isReadByPeer = false;
                      if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                        final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                        isReadByPeer = (chatData['unread_${widget.peerId}'] ?? 0) == 0;
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryNavy.withOpacity(0.08),
                                      border: Border.all(color: accentGold.withOpacity(0.4), width: 1.5),
                                    ),
                                    child: Icon(Icons.lock_outline_rounded, size: 45, color: accentGold),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "تواصل آمن ومباشر مع الطاقم 🔒",
                                    style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }

                          final messages = snapshot.data!.docs;

                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msgDoc = messages[index];
                              final msg = msgDoc.data() as Map<String, dynamic>;
                              final isMe = msg['senderId'] == widget.currentUserId;
                              final String timeString = _formatTime(msg['timestamp'] as Timestamp?);

                              final Map<String, dynamic> reactions = msg['reactions'] ?? {};
                              final List<String> displayEmojis = reactions.values.map((e) => e.toString()).toSet().toList();
                              
                              final String msgType = msg['type'] ?? 'text';
                              final Map<String, dynamic>? replyTo = msg['replyTo'];

                              return _AnimatedMessageBubble(
                                key: ValueKey(msgDoc.id),
                                index: index,
                                isMe: isMe,
                                child: Align(
                                  alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    constraints: BoxConstraints(
                                      maxWidth: screenWidth > 600 ? 420 : screenWidth * 0.78,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor: primaryNavy.withOpacity(0.12),
                                            child: Icon(Icons.person_rounded, size: 18, color: primaryNavy),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              GestureDetector(
                                                onLongPress: () => _showMessageOptionsMenu(context, msgDoc.id, msg, isMe, isDark),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(20),
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 200),
                                                      padding: msgType == 'image' && replyTo == null 
                                                          ? const EdgeInsets.all(4) 
                                                          : const EdgeInsets.fromLTRB(14, 10, 14, 8),
                                                      decoration: BoxDecoration(
                                                        // 🎨 فقاعات الرسائل متناسقة مع صورة الهوية والشعار
                                                        color: isMe
                                                            ? (isDark ? const Color(0xffcdb375).withOpacity(0.25) : const Color(0xffdcebdc).withOpacity(0.72))
                                                            : (isDark ? const Color(0xff243447).withOpacity(0.62) : Colors.white.withOpacity(0.68)),
                                                        border: Border.all(
                                                          color: Colors.white.withOpacity(isDark ? 0.16 : 0.72),
                                                          width: 1,
                                                        ),
                                                        borderRadius: BorderRadius.only(
                                                          topLeft: const Radius.circular(18),
                                                          topRight: const Radius.circular(18),
                                                          bottomLeft: Radius.circular(isMe ? 4 : 18),
                                                          bottomRight: Radius.circular(isMe ? 18 : 4),
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.04),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          )
                                                        ],
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (replyTo != null) ...[
                                                            Container(
                                                              padding: const EdgeInsets.all(6),
                                                              margin: const EdgeInsets.only(bottom: 6),
                                                              decoration: BoxDecoration(
                                                                color: isMe ? primaryNavy.withOpacity(0.08) : Colors.grey.shade100,
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border(
                                                                  right: BorderSide(color: primaryNavy, width: 3),
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    replyTo['senderName'] ?? '',
                                                                    style: TextStyle(
                                                                      fontFamily: 'Cairo',
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 10.5,
                                                                      color: primaryNavy,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 2),
                                                                  Text(
                                                                    replyTo['text'] ?? '',
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black87),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],

                                                          if (msgType == 'audio')
                                                            _AudioMessagePlayer(
                                                              audioUrl: msg['audioUrl'] ?? '',
                                                              duration: msg['duration'] ?? 0,
                                                              isMe: isMe,
                                                              isDark: isDark,
                                                              primaryNavy: primaryNavy,
                                                              accentGold: accentGold,
                                                            )
                                                          else if (msgType == 'image')
                                                            GestureDetector(
                                                              onTap: () => _showImagePreview(context, msg['imageUrl'] ?? ''),
                                                              child: ClipRRect(
                                                                borderRadius: BorderRadius.circular(14),
                                                                child: CachedNetworkImage(
                                                                  imageUrl: msg['imageUrl'] ?? '',
                                                                  width: 220,
                                                                  height: 200,
                                                                  fit: BoxFit.cover,
                                                                  placeholder: (context, url) => Container(
                                                                    width: 220,
                                                                    height: 200,
                                                                    color: Colors.black12,
                                                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                                  ),
                                                                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.redAccent),
                                                                ),
                                                              ),
                                                            )
                                                          else
                                                            Text(
                                                              msg['text'] ?? '',
                                                              style: TextStyle(
                                                                fontFamily: 'Cairo',
                                                                color: isDark ? Colors.white : const Color(0xff1f2937),
                                                                fontSize: 14,
                                                                height: 1.4,
                                                              ),
                                                            ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                timeString,
                                                                style: TextStyle(
                                                                  fontFamily: 'Cairo',
                                                                  fontSize: 9.5,
                                                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                                                ),
                                                              ),
                                                              if (isMe) ...[
                                                                const SizedBox(width: 4),
                                                                Icon(
                                                                  Icons.done_all_rounded,
                                                                  size: 14,
                                                                  color: isReadByPeer ? primaryNavy : Colors.grey,
                                                                ),
                                                              ]
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (displayEmojis.isNotEmpty)
                                                Positioned(
                                                  bottom: -8,
                                                  right: isMe ? 8 : null,
                                                  left: isMe ? null : 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                                    ),
                                                    child: Text(displayEmojis.join(' '), style: const TextStyle(fontSize: 11)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 8),
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor: accentGold.withOpacity(0.3),
                                            child: Icon(Icons.person_rounded, size: 18, color: primaryNavy),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // 📌 شريط الإدخال المحدث المقتبس من ديزاين الصورة بزر إرسال كحلي #425c75
                ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: EdgeInsets.only(bottom: isKeyboardOpen ? 6 : 14, left: 10, right: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff26384a).withOpacity(0.72) : Colors.white.withOpacity(0.62),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(color: Colors.white.withOpacity(0.72), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_replyMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.reply_rounded, size: 18, color: primaryNavy),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "الرد على: ${_replyMessage!['text']}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    onPressed: () => setState(() => _replyMessage = null),
                                  ),
                                ],
                              ),
                            ),

                          if (_isUploading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(_uploadStatusText, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          else
                            _RecordingBar(
                              audioRecorder: _audioRecorder,
                              messageController: _messageController,
                              isDark: isDark,
                              primaryNavy: primaryNavy,
                              accentGold: accentGold,
                              onSendTextMessage: _sendMessage,
                              onSendAudioMessage: _uploadAndSendAudio,
                              onOpenAttachmentMenu: () => _showAttachmentMenu(context, isDark),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 🎙️ الويجيت المستقل المعزول للتسجيل الصوتي
class _RecordingBar extends StatefulWidget {
  final rec.AudioRecorder audioRecorder;
  final TextEditingController messageController;
  final bool isDark;
  final Color primaryNavy;
  final Color accentGold;
  final VoidCallback onSendTextMessage;
  final Function(String? path, int durationSeconds) onSendAudioMessage;
  final VoidCallback onOpenAttachmentMenu;

  const _RecordingBar({
    required this.audioRecorder,
    required this.messageController,
    required this.isDark,
    required this.primaryNavy,
    required this.accentGold,
    required this.onSendTextMessage,
    required this.onSendAudioMessage,
    required this.onOpenAttachmentMenu,
  });

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  Timer? _recordingTimer;
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

        _recordDurationSeconds = 0;
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            onPressed: _cancelRecording,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.25).animate(_micPulseController),
                  child: const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRecordTimer(_recordDurationSeconds),
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  "تسجيل صوتي...",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: widget.primaryNavy, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          )
        ],
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.messageController,
      builder: (context, value, child) {
        bool hasText = value.text.trim().isNotEmpty;

        return Row(
          children: [
            // زر الإرسال المائل بالأزرق الكحلي #425c75 كما بالصورة
            GestureDetector(
              onTap: hasText ? widget.onSendTextMessage : _startRecording,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.primaryNavy, widget.primaryNavy.withOpacity(0.78)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
                  boxShadow: [
                    BoxShadow(color: widget.primaryNavy.withOpacity(0.24), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.messageController,
                style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "اكتب رسالتك...",
                  hintStyle: TextStyle(color: widget.isDark ? Colors.white54 : Colors.grey.shade400, fontFamily: 'Cairo', fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600, size: 22),
              onPressed: () => widget.onOpenAttachmentMenu(),
            ),
            Transform.rotate(
              angle: -0.6,
              child: IconButton(
                icon: Icon(Icons.attach_file_rounded, color: Colors.grey.shade600, size: 22),
                onPressed: widget.onOpenAttachmentMenu,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 🔊 المشغّل الصوتي المستقر على Android فقط بألوانك
class _AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  final bool isDark;
  final Color primaryNavy;
  final Color accentGold;

  const _AudioMessagePlayer({
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    required this.isDark,
    required this.primaryNavy,
    required this.accentGold,
  });

  @override
  State<_AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<_AudioMessagePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.duration);

    // 🛠️ تهيئة إعدادات الصوت لنظام Android فقط
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
      } else {
        if (widget.audioUrl.isNotEmpty) {
          await _audioPlayer.stop();
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
      }
    } catch (e) {
      debugPrint("❌ خطأ تشغيل الصوت: $e");
    }
  }

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: widget.primaryNavy,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(18, (index) {
                    double height = 4 + ((index * 7) % 14).toDouble();
                    double progress = _totalDuration.inSeconds > 0 ? (_position.inSeconds / _totalDuration.inSeconds) : 0.0;
                    bool isActive = (index / 18) <= progress;

                    return Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        decoration: BoxDecoration(
                          color: isActive ? widget.primaryNavy : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(_isPlaying ? _position : _totalDuration),
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 9.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final int index;

  const _AnimatedMessageBubble({
    super.key,
    required this.child,
    required this.isMe,
    required this.index,
  });

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    double startDx = widget.isMe ? 0.15 : -0.15;

    _slideAnimation = Tween<Offset>(begin: Offset(startDx, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.index == 0) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: widget.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
        child: widget.child,
      ),
    );
  }
}