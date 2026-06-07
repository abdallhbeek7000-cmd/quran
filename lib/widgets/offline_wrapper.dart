import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineWrapper extends StatelessWidget {
  final Widget child;
  const OfflineWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          child,
          Positioned(
            top: 40, right: 10,
            child: StreamBuilder<List<ConnectivityResult>>(
              stream: Connectivity().onConnectivityChanged,
              builder: (context, snapshot) {
                final isOffline = snapshot.data?.contains(ConnectivityResult.none) ?? false;
                if (!isOffline) return const SizedBox();
                
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                  child: const Text("يعمل بدون إنترنت", style: TextStyle(color: Colors.white, fontSize: 10)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}