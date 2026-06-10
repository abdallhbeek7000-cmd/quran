import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'supervisor_chat_page.dart'; 
import 'staff_chat_page.dart'; 
import '../widgets/offline_wrapper.dart'; // 🚀 استيراد غلاف الأوفلاين

class SupervisorInboxPage extends StatefulWidget {
  final String supervisorId;

  const SupervisorInboxPage({super.key, required this.supervisorId});

  @override
  State<SupervisorInboxPage> createState() => _SupervisorInboxPageState();
}

class _SupervisorInboxPageState extends State<SupervisorInboxPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);
  
  // 🚀 كاش (ذاكرة مؤقتة) لحفظ أسماء الموظفين
  final Map<String, Map<String, dynamic>> _peerCache = {};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  }

  // 🎯 دالة لتوليد ID فريد وموحد لغرفة الدردشة بين أي موظفين
  String _generateStaffChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); 
    return "staff_${ids[0]}_${ids[1]}";
  }

  // 🎯 دالة ذكية وسريعة لجلب معلومات الطرف الآخر
  Future<Map<String, dynamic>> _getPeerDataCached(String peerId) async {
    if (_peerCache.containsKey(peerId)) return _peerCache[peerId]!;
    try {
      var supDoc = await FirebaseFirestore.instance.collection('supervisors').doc(peerId).get();
      if (supDoc.exists) {
        _peerCache[peerId] = {'name': supDoc['name'], 'role': 'supervisor', 'imageUrl': supDoc['imageUrl']};
        return _peerCache[peerId]!;
      }
      var manDoc = await FirebaseFirestore.instance.collection('users').doc(peerId).get();
      if (manDoc.exists) {
        _peerCache[peerId] = {'name': manDoc['name'], 'role': 'manager', 'imageUrl': manDoc['imageUrl']};
        return _peerCache[peerId]!;
      }
    } catch (e) {
      print(e);
    }
    return {'name': 'غير معروف', 'role': '', 'imageUrl': null};
  }

  // 🗑️ دالة حذف المحادثة من قاعدة البيانات
  Future<void> _deleteChat(String docId, bool isStaff) async {
    try {
      String collectionName = isStaff ? 'staff_chats' : 'chats';
      await FirebaseFirestore.instance.collection(collectionName).doc(docId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green, 
            content: Text("تم حذف المحادثة بنجاح 🗑️", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))
          ),
        );
      }
    } catch (e) {
      print("خطأ في حذف المحادثة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text("فشل الحذف، تأكد من الاتصال بالإنترنت", style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  // ⚠️ نافذة تأكيد الحذف
  void _showDeleteConfirmDialog(String docId, bool isStaff, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text("حذف المحادثة", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("هل أنت متأكد أنك تريد إزالة هذه المحادثة من صندوق الوارد الخاص بك؟", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(docId, isStaff);
            },
            child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🎯 القائمة السفلية لبدء محادثة جديدة
  void _showNewChatBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75, 
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                  border: Border(top: BorderSide(color: isDark ? Colors.white24 : Colors.white, width: 1.5)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 10),
                    
                    TabBar(
                      indicatorColor: goldColor,
                      labelColor: goldColor,
                      unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                      labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: "الطلاب (الأهالي)"),
                        Tab(text: "طاقم العمل"),
                      ],
                    ),
                    
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildStudentsTab(isDark), 
                          _buildStaffTab(isDark),    
                        ],
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

  Widget _buildStudentsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').where('supervisorId', isEqualTo: widget.supervisorId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: goldColor));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("لا يوجد طلاب مسجلين باسمك حالياً", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)));

        final students = snapshot.data!.docs;
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final studentDoc = students[index];
            final studentData = studentDoc.data() as Map<String, dynamic>;
            final studentName = studentData['name'] ?? 'غير معروف';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? Colors.white12 : Colors.black12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: goldColor.withOpacity(0.2), child: Icon(Icons.person, color: goldColor)),
                title: Text(studentName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text("ولي الأمر", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                trailing: Icon(Icons.chat_bubble_outline, color: goldColor),
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorChatPage(chatId: '${studentDoc.id}_${widget.supervisorId}', studentId: studentDoc.id, studentName: studentName, supervisorId: widget.supervisorId)));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStaffTab(bool isDark) {
    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([FirebaseFirestore.instance.collection('users').get(), FirebaseFirestore.instance.collection('supervisors').get()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData) return const Center(child: Text("خطأ في جلب البيانات"));

        List<Map<String, dynamic>> allStaff = [];
        for (var doc in snapshot.data![0].docs) { 
          if (doc.id != widget.supervisorId) { var data = doc.data() as Map<String, dynamic>; data['id'] = doc.id; data['staffRole'] = 'manager'; allStaff.add(data); }
        }
        for (var doc in snapshot.data![1].docs) { 
          if (doc.id != widget.supervisorId) { var data = doc.data() as Map<String, dynamic>; data['id'] = doc.id; data['staffRole'] = 'supervisor'; allStaff.add(data); }
        }

        if (allStaff.isEmpty) return Center(child: Text("لا يوجد أعضاء آخرين في الطاقم.", style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white54 : Colors.black54)));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          itemCount: allStaff.length,
          itemBuilder: (context, index) {
            final staff = allStaff[index];
            final String staffId = staff['id'];
            final String staffName = staff['name'] ?? 'عضو إدارة';
            final String staffRole = staff['staffRole'];
            final String? imageUrl = staff['imageUrl'];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(15), border: Border.all(color: staffRole == 'manager' ? goldColor.withOpacity(0.5) : (isDark ? Colors.white12 : Colors.white), width: 1.5)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: staffRole == 'manager' ? goldColor.withOpacity(0.2) : primaryColor.withOpacity(0.1), backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null, child: (imageUrl == null || imageUrl.isEmpty) ? Icon(staffRole == 'manager' ? Icons.admin_panel_settings : Icons.support_agent, color: staffRole == 'manager' ? goldColor : primaryColor) : null),
                title: Text(staffName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Cairo')),
                subtitle: Text(staffRole == 'manager' ? 'مدير المعهد' : 'زميل إشراف', style: TextStyle(fontSize: 12, color: staffRole == 'manager' ? goldColor : (isDark ? Colors.white54 : Colors.black54), fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                trailing: Icon(Icons.chat_rounded, color: primaryColor),
                onTap: () {
                  String chatRoomId = _generateStaffChatId(widget.supervisorId, staffId);
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StaffChatPage(chatId: chatRoomId, currentUserId: widget.supervisorId, peerId: staffId, peerName: staffName, peerRole: staffRole)));
                },
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

    return OfflineWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
          title: Text("صندوق الوارد", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        ),
        
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showNewChatBottomSheet(context, isDark),
          backgroundColor: goldColor,
          elevation: 5,
          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
          label: const Text("مراسلة", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),

        body: Stack(
          children: [
            Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
            Positioned(top: -50, left: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12)))),

            SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').where('supervisorId', isEqualTo: widget.supervisorId).snapshots(),
                builder: (context, parentSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('staff_chats').where('participants', arrayContains: widget.supervisorId).snapshots(),
                    builder: (context, staffSnap) {
                      if (parentSnap.connectionState == ConnectionState.waiting && staffSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<Map<String, dynamic>> allChats = [];

                      if (parentSnap.hasData) {
                        for (var doc in parentSnap.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          if (data.containsKey('studentId') && data['studentId'].toString().isNotEmpty) {
                            data['docId'] = doc.id;
                            data['isStaff'] = false;
                            data['sortTime'] = data['lastMessageTime'] ?? Timestamp.now();
                            allChats.add(data);
                          }
                        }
                      }

                      if (staffSnap.hasData) {
                        for (var doc in staffSnap.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          data['docId'] = doc.id;
                          data['isStaff'] = true;
                          data['sortTime'] = data['lastMessageTime'] ?? Timestamp.now();
                          allChats.add(data);
                        }
                      }

                      allChats.sort((a, b) => (b['sortTime'] as Timestamp).compareTo(a['sortTime'] as Timestamp));

                      if (allChats.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mark_chat_read_rounded, size: 80, color: isDark ? Colors.white24 : primaryColor.withOpacity(0.3)),
                              const SizedBox(height: 15),
                              Text("صندوق الوارد فارغ", style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : primaryColor, fontFamily: 'Cairo')),
                              const SizedBox(height: 5),
                              Text("اضغط على مراسلة للبدء بالتواصل", style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45, fontFamily: 'Cairo')),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 80), 
                        itemCount: allChats.length,
                        itemBuilder: (context, index) {
                          final chatData = allChats[index];
                          final bool isStaff = chatData['isStaff'];
                          final String docId = chatData['docId'];
                          final lastMessage = chatData['lastMessage'] ?? '';
                          final lastTime = (chatData['sortTime'] as Timestamp).toDate();

                          if (!isStaff) {
                            final studentName = chatData['studentName'] ?? 'طالب غير معروف';
                            final unreadCount = chatData['unreadBySupervisor'] ?? 0;
                            
                            return _buildChatTile(
                              context: context, isDark: isDark, isStaff: false,
                              title: "ولي أمر الطالب: $studentName",
                              subtitle: lastMessage,
                              time: lastTime,
                              unreadCount: unreadCount,
                              icon: Icons.person_rounded, iconColor: primaryColor,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorChatPage(chatId: docId, studentId: chatData['studentId'], studentName: studentName, supervisorId: widget.supervisorId))),
                              onLongPress: () => _showDeleteConfirmDialog(docId, false, isDark), // 🚀 تفعيل الحذف بالضغط المطول
                            );
                          } 
                          else {
                            final unreadCount = chatData['unread_${widget.supervisorId}'] ?? 0;
                            List parts = chatData['participants'] ?? [];
                            String peerId = parts.firstWhere((id) => id != widget.supervisorId, orElse: () => '');

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getPeerDataCached(peerId),
                              builder: (context, peerSnap) {
                                String peerName = peerSnap.data?['name'] ?? '...';
                                String peerRole = peerSnap.data?['role'] ?? '';
                                bool isManager = peerRole == 'manager';

                                return _buildChatTile(
                                  context: context, isDark: isDark, isStaff: true,
                                  title: peerName,
                                  subtitle: lastMessage,
                                  time: lastTime,
                                  unreadCount: unreadCount,
                                  icon: isManager ? Icons.admin_panel_settings : Icons.support_agent, 
                                  iconColor: isManager ? goldColor : primaryColor,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffChatPage(chatId: docId, currentUserId: widget.supervisorId, peerId: peerId, peerName: peerName, peerRole: peerRole))),
                                  onLongPress: () => _showDeleteConfirmDialog(docId, true, isDark), // 🚀 تفعيل الحذف بالضغط المطول
                                );
                              },
                            );
                          }
                        },
                      );
                    }
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required BuildContext context, required bool isDark, required bool isStaff,
    required String title, required String subtitle, required DateTime time, required int unreadCount,
    required IconData icon, required Color iconColor, required VoidCallback onTap, required VoidCallback onLongPress
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress, // 🚀 استدعاء عملية الحذف
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isStaff ? goldColor.withOpacity(0.3) : (isDark ? Colors.white12 : Colors.white), width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: isDark ? const Color(0xff1e293b) : iconColor.withOpacity(0.1),
                    child: Icon(icon, color: isDark ? goldColor : iconColor),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isStaff) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: goldColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text("طاقم", style: TextStyle(fontSize: 9, color: goldColor, fontWeight: FontWeight.bold))),
                            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(timeago.format(time, locale: 'ar'), style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey, fontFamily: 'Cairo')),
                      const SizedBox(height: 8),
                      if (unreadCount > 0)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)), child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}