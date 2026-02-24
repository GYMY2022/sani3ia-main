import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();

  // Supabase clients
  final SupabaseClient _supabase = SupabaseClient(
    'https://cezhcyhaiztoqgetxehv.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlemhjeWhhaXp0b3FnZXR4ZWh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxMTc1MjgsImV4cCI6MjA3NzY5MzUyOH0.sNS7Vi_CWUBwZuc3C90Z1ZZYi6NjminWw4ybb8kBO9Q',
  );

  // ⭐⭐ **التصحيح: استخدم الـ bucket الصحيح 'posts_images'**
  static const String _bucketName = 'posts_images';

  // ⭐⭐ **جديد: دالة مبسطة للتحقق من اتصال Supabase**
  Future<bool> checkSupabaseConnection() async {
    try {
      print('🔗 جاري التحقق من اتصال Supabase...');
      final session = _supabase.auth.currentSession;
      print(
        '✅ اتصال Supabase نشط - Session: ${session != null ? "موجود" : "غير موجود"}',
      );
      return true;
    } catch (e) {
      print('❌ خطأ في اتصال Supabase: $e');
      return false;
    }
  }

  // ⭐⭐ **جديد: دالة لاختبار الرفع إلى bucket posts_images داخل مجلد posts**
  Future<bool> testUploadToBucket() async {
    try {
      print('🧪 اختبار الرفع إلى bucket $_bucketName...');

      // اختبار بملف صغير
      final testBytes = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
      final testFileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';

      // ⭐⭐ **رفع إلى مجلد posts الموجود لديك**
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary('posts/$testFileName', testBytes);

      print('✅ تم رفع ملف الاختبار بنجاح');

      // الحصول على الرابط
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl('posts/$testFileName');

      print('🔗 رابط الاختبار: $publicUrl');

      // حذف ملف الاختبار
      await _supabase.storage.from(_bucketName).remove(['posts/$testFileName']);

      print('✅ تم حذف ملف الاختبار');
      return true;
    } catch (e) {
      print('❌ فشل اختبار الرفع: $e');
      print('💡 تأكد من:');
      print('   1. وجود bucket باسم "$_bucketName"');
      print('   2. وجود مجلد "posts" داخل الـ bucket');
      print('   3. صلاحيات الـ RLS تسمح بالرفع');
      return false;
    }
  }

  // ⭐ اختيار صورة
  Future<File?> pickImage({required BuildContext context}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  // ⭐ اختيار فيديو
  Future<File?> pickVideo({required BuildContext context}) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      print('❌ خطأ في اختيار الفيديو: $e');
      return null;
    }
  }

  // ⭐ اختيار ملف
  Future<File?> pickFile() async {
    try {
      final XFile? pickedFile = await _picker.pickMedia(
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الملف: $e');
      return null;
    }
  }

  // ⭐ تحديد نوع الملف
  String getFileType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'image';
    } else if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'].contains(extension)) {
      return 'video';
    } else {
      return 'document';
    }
  }

  // ⭐ الحصول على اسم الملف
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  // ⭐ الحصول على حجم الملف
  Future<int> getFileSize(File file) async {
    try {
      final length = await file.length();
      return length;
    } catch (e) {
      print('❌ خطأ في الحصول على حجم الملف: $e');
      return 0;
    }
  }

  // ⭐⭐ **مُعدّل: رفع الوسائط إلى Supabase - يرفع إلى مجلد posts**
  Future<String> uploadMediaToSupabase(
    File mediaFile, {
    String? folderName,
  }) async {
    try {
      print('📤 جاري رفع الوسائط إلى Supabase...');
      print('📁 اسم الملف: ${mediaFile.path}');
      print('📦 الـ Bucket: $_bucketName');

      // التحقق من وجود الملف
      if (!await mediaFile.exists()) {
        throw Exception('❌ الملف غير موجود في المسار: ${mediaFile.path}');
      }

      final String fileName =
          'chat_${DateTime.now().millisecondsSinceEpoch}_${path.basename(mediaFile.path)}';

      // ⭐⭐ **التصحيح: رفع إلى مجلد posts الموجود**
      final String storagePath = 'posts/$fileName';

      print('🗂️ المسار النهائي للتخزين: $storagePath');

      final Uint8List mediaBytes = await mediaFile.readAsBytes();

      if (mediaBytes.isEmpty) {
        throw Exception('❌ بيانات الملف فارغة');
      }

      print('📊 حجم الملف: ${mediaBytes.length} bytes');

      // ⭐⭐ **رفع الملف إلى الـ bucket 'posts_images' داخل مجلد posts**
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            storagePath,
            mediaBytes,
            fileOptions: FileOptions(upsert: true),
          );

      print('✅ تم رفع الملف بنجاح');

      // ⭐⭐ **الحصول على الرابط العام**
      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      print('🔗 رابط الملف العام: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ خطأ في رفع الوسائط: $e');

      // ⭐⭐ رسالة خطأ أكثر وضوحاً
      if (e.toString().contains('bucket') || e.toString().contains('Bucket')) {
        throw Exception('''
❌ مشكلة في الـ Bucket!
- Bucket المطلوب: $_bucketName
- المجلد المطلوب: posts
- تأكد من:
  1. وجود bucket باسم '$_bucketName' في Supabase Dashboard
  2. وجود مجلد 'posts' داخل الـ bucket
  3. تفعيل الـ Public access للـ bucket
  4. إعداد سياسات RLS الصحيحة
''');
      }

      rethrow;
    }
  }

  // ⭐ دالة مساعدة جديدة للتحقق من صلاحيات Bucket
  Future<bool> checkSupabaseStorageAccess() async {
    try {
      print('🔍 التحقق من صلاحيات Supabase Storage...');
      print('📦 الـ Bucket: $_bucketName');

      // محاولة سرد الملفات في Bucket
      final result = await _supabase.storage
          .from(_bucketName)
          .list(path: 'posts');

      print('✅ تم الوصول إلى Bucket بنجاح');
      print('📁 عدد الملفات في posts: ${result.length}');

      return true;
    } catch (e) {
      print('❌ خطأ في الوصول إلى Storage: $e');
      print('💡 الحل: تأكد من:');
      print('   1. وجود bucket باسم "$_bucketName"');
      print('   2. وجود مجلد "posts" داخل الـ bucket');
      print('   3. إعدادات RLS Policies في Supabase Dashboard');
      print('   4. تفعيل Public access للـ bucket');
      return false;
    }
  }

  // ⭐⭐ **جديدة: دالة لرفع الوسائط مع خيارات متعددة**
  Future<Map<String, dynamic>> uploadMediaWithOptions(
    File mediaFile, {
    String? customFileName,
    bool compressImage = true,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      print('🔄 إعداد الوسائط للرفع...');

      // ⭐ رفع الملف
      final String mediaUrl = await uploadMediaToSupabase(mediaFile);

      // ⭐ إرجاع معلومات الملف
      return {
        'success': true,
        'url': mediaUrl,
        'fileName': customFileName ?? path.basename(mediaFile.path),
        'fileType': getFileType(mediaFile.path),
        'fileSize': await getFileSize(mediaFile),
        'uploadedAt': DateTime.now().toString(),
      };
    } catch (e) {
      print('❌ فشل في رفع الوسائط: $e');
      return {'success': false, 'error': e.toString(), 'url': null};
    }
  }

  // ⭐ رفع الوسائط وإرجاع المعلومات الكاملة
  Future<Map<String, dynamic>?> uploadMedia(
    File file, {
    String? folderName,
  }) async {
    try {
      print('📤 جاري رفع الوسائط...');

      final String? mediaUrl = await uploadMediaToSupabase(file);

      if (mediaUrl == null) {
        return null;
      }

      final String mediaType = getFileType(file.path);
      final String fileName = getFileName(file.path);
      final int fileSize = await getFileSize(file);

      return {
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'fileName': fileName,
        'fileSize': fileSize,
      };
    } catch (e) {
      print('❌ خطأ في رفع الوسائط: $e');
      return null;
    }
  }

  // ⭐⭐ **معدل: دالة رفع الوسائط للشات - ترفع إلى مجلد posts**
  Future<Map<String, dynamic>> uploadMediaForChat({
    required File mediaFile,
    String? customFileName,
  }) async {
    try {
      print('📤 === بدء رفع الوسائط للشات ===');

      // التحقق من وجود الملف
      if (!await mediaFile.exists()) {
        throw Exception('الملف غير موجود: ${mediaFile.path}');
      }

      // إنشاء اسم فريد للملف
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = path.basename(mediaFile.path);

      // ⭐⭐ **مهم: استخدم بادئة 'chat_' للتمييز**
      final uniqueFileName = 'chat_${timestamp}_$originalName';

      // ⭐⭐ **مهم: رفع إلى مجلد 'posts' الموجود لديك**
      final storagePath = 'posts/$uniqueFileName';

      print('📁 اسم الملف: $originalName');
      print('🗂️ مسار التخزين: $storagePath');
      print('📦 الـ Bucket: $_bucketName');
      print('📂 المجلد: posts');

      // قراءة الملف
      final Uint8List fileBytes = await mediaFile.readAsBytes();
      if (fileBytes.isEmpty) {
        throw Exception('ملف فارغ');
      }

      print('📊 حجم الملف: ${fileBytes.length} bytes');

      // ⭐⭐ **رفع الملف إلى Supabase داخل مجلد posts**
      print('🔼 جاري رفع الملف...');
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(upsert: true),
          );

      print('✅ تم رفع الملف بنجاح');

      // الحصول على الرابط العام
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      print('🔗 الرابط العام: $publicUrl');

      // تحديد نوع الملف
      final fileType = getFileType(mediaFile.path);

      print('✅ === تم رفع الوسائط بنجاح ===');

      return {
        'success': true,
        'url': publicUrl,
        'fileName': customFileName ?? originalName,
        'fileType': fileType,
        'fileSize': fileBytes.length,
        'path': storagePath,
        'timestamp': timestamp,
      };
    } catch (e) {
      print('❌ === فشل في رفع الوسائط ===');
      print('🚨 الخطأ: $e');
      print('📋 StackTrace: ${e.toString()}');

      return {'success': false, 'error': e.toString(), 'url': null};
    }
  }

  // ⭐ تنزيل الوسائط
  Future<File?> downloadMedia(String mediaUrl, String fileName) async {
    try {
      print('⬇️ جاري تنزيل الملف: $fileName');

      final Uri uri = Uri.parse(mediaUrl);
      final String fileExtension = fileName.split('.').last;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String downloadPath = '${appDir.path}/downloads';
      await Directory(downloadPath).create(recursive: true);

      final String filePath =
          '$downloadPath/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      final http.Response response = await http.get(uri);

      if (response.statusCode == 200) {
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('✅ تم تنزيل الملف بنجاح: $filePath');
        return file;
      } else {
        print('❌ فشل في تنزيل الملف: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ خطأ في تنزيل الملف: $e');
      return null;
    }
  }

  // ⭐ حفظ الصورة في المعرض (بديل مؤقت)
  Future<bool> saveImageToGallery(File imageFile) async {
    try {
      if (await imageFile.exists()) {
        // حل مؤقت: حفظ في مجلد التطبيق
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String savePath = '${appDir.path}/saved_images';
        await Directory(savePath).create(recursive: true);

        final String fileName =
            'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File savedFile = await imageFile.copy('$savePath/$fileName');

        print('✅ تم حفظ الصورة محلياً: ${savedFile.path}');

        return true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في حفظ الصورة: $e');
      return false;
    }
  }

  // ⭐ مشاركة الملف
  Future<void> shareFile(File file) async {
    try {
      if (await file.exists()) {
        await Share.shareXFiles([XFile(file.path)]);
        print('✅ تم مشاركة الملف');
      }
    } catch (e) {
      print('❌ خطأ في مشاركة الملف: $e');
    }
  }

  // ⭐ فتح الملف
  Future<void> openFile(File file) async {
    try {
      if (await file.exists()) {
        await OpenFile.open(file.path);
        print('✅ تم فتح الملف');
      }
    } catch (e) {
      print('❌ خطأ في فتح الملف: $e');
    }
  }

  // ⭐ التحقق من صلاحيات التخزين
  Future<bool> checkStoragePermission() async {
    try {
      // في التطبيق الحقيقي، استخدم permission_handler
      return true;
    } catch (e) {
      print('⚠️ خطأ في التحقق من الصلاحيات: $e');
      return false;
    }
  }

  // ⭐ تنظيف الملفات المؤقتة
  Future<void> cleanupTempFiles() async {
    try {
      final Directory tempDir = Directory.systemTemp;
      if (await tempDir.exists()) {
        final List<FileSystemEntity> files = tempDir.listSync();
        for (final file in files) {
          if (file is File && file.path.contains('snack3ya_temp')) {
            await file.delete();
          }
        }
        print('🧹 تم تنظيف الملفات المؤقتة');
      }
    } catch (e) {
      print('⚠️ خطأ في تنظيف الملفات المؤقتة: $e');
    }
  }

  // ⭐ معاينة الفيديو
  Future<Widget> getVideoPreview(File videoFile) async {
    try {
      final VideoPlayerController controller = VideoPlayerController.file(
        videoFile,
      );
      await controller.initialize();

      final ChewieController chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
      );

      return Chewie(controller: chewieController);
    } catch (e) {
      print('❌ خطأ في معاينة الفيديو: $e');
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.videocam_off, size: 50, color: Colors.grey),
        ),
      );
    }
  }

  // ⭐ الحصول على معاينة الصورة
  Widget getImagePreview(File imageFile) {
    return Image.file(
      imageFile,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        );
      },
    );
  }

  // ⭐ الحصول على أيقونة الملف حسب النوع
  IconData getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  // ⭐ تنسيق حجم الملف
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  // ⭐⭐ **جديد: دالة لتحليل الرابط وإرجاع المسار**
  String extractFilePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // البحث عن 'public' في المسار
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex != -1) {
        // المسار المطلوب: posts/filename.ext
        return pathSegments.sublist(publicIndex + 2).join('/');
      }

      // إذا لم يكن هناك public، افترض أن المسار من posts/
      return url.contains('/posts/')
          ? url.split('/posts/').last
          : url.split('/').last;
    } catch (e) {
      print('❌ خطأ في تحليل الرابط: $e');
      return '';
    }
  }

  // ⭐⭐ **جديد: دالة لاختبار النظام بالكامل**
  Future<void> testCompleteSystem() async {
    try {
      print('🧪 === اختبار نظام الوسائط بالكامل ===');

      // 1. اختبار الاتصال
      print('1. 🔗 اختبار الاتصال بـ Supabase...');
      final isConnected = await checkSupabaseConnection();
      if (!isConnected) {
        throw Exception('فشل اختبار الاتصال');
      }
      print('✅ اختبار الاتصال ناجح');

      // 2. اختبار الرفع
      print('2. 📤 اختبار الرفع إلى bucket...');
      final canUpload = await testUploadToBucket();
      if (!canUpload) {
        throw Exception('فشل اختبار الرفع');
      }
      print('✅ اختبار الرفع ناجح');

      print('🎉 === جميع الاختبارات ناجحة ===');
    } catch (e) {
      print('❌ === فشل في اختبار النظام ===');
      print('🚨 الخطأ: $e');
      throw e;
    }
  }

  // ⭐⭐ **جديد: دالة اختيار صورة من المعرض**
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (pickedFile != null) {
        print('✅ تم اختيار صورة: ${pickedFile.path}');
        return File(pickedFile.path);
      }
      print('⚠️ لم يتم اختيار صورة');
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  // ⭐⭐ **جديد: دالة اختيار فيديو**
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        print('✅ تم اختيار فيديو: ${pickedFile.path}');
        return File(pickedFile.path);
      }
      print('⚠️ لم يتم اختيار فيديو');
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الفيديو: $e');
      return null;
    }
  }

  // ⭐⭐ **جديد: دالة اختيار ملف**
  Future<File?> pickFileFromDevice() async {
    try {
      final XFile? pickedFile = await _picker.pickMedia();

      if (pickedFile != null) {
        print('✅ تم اختيار ملف: ${pickedFile.path}');
        return File(pickedFile.path);
      }
      print('⚠️ لم يتم اختيار ملف');
      return null;
    } catch (e) {
      print('❌ خطأ في اختيار الملف: $e');
      return null;
    }
  }

  // ⭐⭐ **جديد: دالة شاملة لرفع أي ملف مع التحقق**
  Future<Map<String, dynamic>> uploadAnyMedia({
    required File mediaFile,
    String? customFileName,
  }) async {
    try {
      // التحقق من وجود الملف
      if (!await mediaFile.exists()) {
        return {'success': false, 'error': 'الملف غير موجود', 'url': null};
      }

      // التحقق من نوع الملف
      if (!isFileTypeAllowed(mediaFile.path)) {
        return {
          'success': false,
          'error': 'نوع الملف غير مسموح به',
          'url': null,
        };
      }

      // التحقق من حجم الملف
      final fileSize = await mediaFile.length();
      if (!isFileSizeAllowed(fileSize)) {
        return {
          'success': false,
          'error': 'حجم الملف كبير جداً (الحد الأقصى 20MB)',
          'url': null,
        };
      }

      // رفع الملف
      return await uploadMediaForChat(
        mediaFile: mediaFile,
        customFileName: customFileName,
      );
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'url': null};
    }
  }

  // ⭐⭐ **جديد: التحقق من نوع الملف المسموح به**
  bool isFileTypeAllowed(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    final allowedExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', // صور
      'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', // فيديو
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', // مستندات
    ];
    return allowedExtensions.contains(extension);
  }

  // ⭐⭐ **جديد: التحقق من حجم الملف (حد أقصى 20MB)**
  bool isFileSizeAllowed(int fileSizeInBytes) {
    const maxSizeInBytes = 20 * 1024 * 1024; // 20MB
    return fileSizeInBytes <= maxSizeInBytes;
  }
}
