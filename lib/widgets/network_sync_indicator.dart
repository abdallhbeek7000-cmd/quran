import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkSyncIndicator extends StatelessWidget {
  final bool isDarkMode;
  
  const NetworkSyncIndicator({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        bool isOffline = false;
        
        // فحص حالة الاتصال (تدعم النسخ الحديثة والقديمة من المكتبة)
        if (snapshot.hasData) {
          var data = snapshot.data;
          if (data is List<ConnectivityResult>) {
            isOffline = data.contains(ConnectivityResult.none);
          } else {
            isOffline = data == ConnectivityResult.none;
          }
        }

        // حركة انتقال ناعمة بين الحالتين
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: isOffline
              ? _buildBadge(Icons.cloud_off_rounded, "حفظ محلي", Colors.grey.shade500, isDarkMode, key: const ValueKey(1))
              : _buildBadge(Icons.cloud_sync_rounded, "متصل", Colors.greenAccent.shade400, isDarkMode, key: const ValueKey(2)),
        );
      },
    );
  }

  // 🧊 تصميم الشارة الزجاجية الأنيقة
  Widget _buildBadge(IconData icon, String text, Color color, bool isDark, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}