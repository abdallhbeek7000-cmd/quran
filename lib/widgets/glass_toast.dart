import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassToast {
  // 🚀 هي الدالة اللي رح نناديها من أي صفحة
  static void show(BuildContext context, {
    required String title, 
    required String message, 
    IconData? icon, 
    Color color = Colors.green, // اللون الافتراضي أخضر للنجاح
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        title: title,
        message: message,
        icon: icon ?? Icons.check_circle_outline,
        color: color,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.title, 
    required this.message, 
    required this.icon, 
    required this.color, 
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact(); // 📳 الهزة اللطيفة أول ما يطلع الإشعار
    
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
    // ينزل من فوق الشاشة مع تأثير ارتداد مطاطي (Bounce)
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, -1.0), end: const Offset(0, 0.0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );

    _controller.forward();

    // ⏱️ الإشعار بيختفي لحاله وبيرجع بيطلع لفوق بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // لمعرفة إذا التطبيق بوضع ليلي أو نهاري
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10, // ينزل تحت شريط البطارية والوقت
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1e293b).withOpacity(0.8) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: widget.color.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: widget.color.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.15), 
                        shape: BoxShape.circle
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title, 
                            style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message, 
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, fontFamily: 'Cairo')
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
    );
  }
}