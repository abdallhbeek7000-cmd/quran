import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

class ZegoService {
  static void initCall({required String userId, required String userName}) {
    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: 1826232795, // 🚀 تم وضع الـ AppID الخاص بك بنجاح
      appSign: "f6dd7712be01b6d417570701eeb163284839ec783c4f70118c2589b7df9170b6", // 🚀 تم وضع الـ AppSign الخاص بك بنجاح
      userID: userId,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()], // تفعيل نظام الرنين في الخلفية
    );
  }

  static void deinitCall() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
  }
}