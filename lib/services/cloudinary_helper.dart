import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CloudinaryHelper {
  // الحساب الخاص بك الجاهز والمجرب
  static final cloudinary = CloudinaryPublic('dqsrrej2b', 'rhjrrtqz', cache: false);

  // دالة لفتح الاستوديو، اختيار صورة، ورفعها فوراً
  static Future<String?> pickAndUploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    
    // فتح معرض الصور واختيار صورة مع ضغطها قليلاً للحفاظ على المساحة
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return null; // إذا أغلق المستخدم الاستوديو ولم يختار شيء

    try {
      // رفع الصورة إلى مجلد مخصص للملفات الشخصية داخل الـ Cloudinary
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, folder: 'profile_pictures'),
      );
      return response.secureUrl; // إرجاع رابط الصورة المرفوعة بنجاح
    } catch (e) {
      print("خطأ أثناء رفع الصورة الشخصية: $e");
      return null;
    }
  }
}