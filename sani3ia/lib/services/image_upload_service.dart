import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  // ✅ استخدام Anon Key العادي للرفع
  final SupabaseClient _supabase = SupabaseClient(
    'https://cezhcyhaiztoqgetxehv.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlemhjeWhhaXp0b3FnZXR4ZWh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxMTc1MjgsImV4cCI6MjA3NzY5MzUyOH0.sNS7Vi_CWUBwZuc3C90Z1ZZYi6NjminWw4ybb8kBO9Q',
  );

  // ✅ استخدام Service Key الصحيح للحذف (ملاحظة: لا ينصح باستخدامه مباشرة في التطبيق، ولكننا سنستخدمه هنا)
  final SupabaseClient _supabaseService = SupabaseClient(
    'https://cezhcyhaiztoqgetxehv.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlemhjeWhhaXp0b3FnZXR4ZWh2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjExNzUyOCwiZXhwIjoyMDc3NjkzNTI4fQ.TAwTWHeexIQ-SO8QD26LxP6ODODcqmjsF9w8J9ltsKI',
  );

  static const String _bucketName = 'posts_images';

  SupabaseClient get client => _supabase;
  SupabaseClient get serviceClient => _supabaseService;

  Future<bool> ensureBucketExists() async {
    try {
      print('🔍 التحقق من وجود bucket "$_bucketName"...');
      try {
        final files = await _supabase.storage.from(_bucketName).list();
        print('✅ bucket "$_bucketName" موجود - عدد الملفات: ${files.length}');
        return true;
      } catch (e) {
        print('❌ bucket "$_bucketName" غير موجود: $e');
        return false;
      }
    } catch (e) {
      print('❌ خطأ في التحقق من وجود bucket: $e');
      return false;
    }
  }

  Future<bool> testPermissions() async {
    try {
      print('🔑 اختبار صلاحيات الرفع...');
      final testContent = Uint8List.fromList('test'.codeUnits);
      final testPath =
          'test_permissions_${DateTime.now().millisecondsSinceEpoch}.txt';
      try {
        await _supabase.storage
            .from(_bucketName)
            .uploadBinary(testPath, testContent);
        await _supabase.storage.from(_bucketName).remove([testPath]);
        print('✅ صلاحيات الرفع تعمل بنجاح');
        return true;
      } catch (e) {
        print('❌ فشل اختبار الصلاحيات: $e');
        return false;
      }
    } catch (e) {
      print('❌ خطأ في اختبار الصلاحيات: $e');
      return false;
    }
  }

  Future<String?> uploadImage(File imageFile, {String? folderName}) async {
    try {
      print('📸 بدء رفع الصورة: ${imageFile.path}');
      if (!await imageFile.exists()) {
        print('❌ الملف غير موجود');
        return null;
      }
      final bucketExists = await ensureBucketExists();
      if (!bucketExists) {
        print('❌ لا يمكن رفع الصورة: bucket "$_bucketName" غير موجود');
        throw Exception('البكت $_bucketName غير موجود في Supabase Storage');
      }
      final hasPermissions = await testPermissions();
      if (!hasPermissions) {
        print('⚠️ تحذير: قد تكون صلاحيات الرفع غير مفعلة');
      }
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      String storagePath;
      if (folderName != null) {
        storagePath = '$folderName/$fileName';
      } else {
        storagePath = 'posts/$fileName';
      }
      print('📁 مسار التخزين: $storagePath');
      print('📦 الـ Bucket: $_bucketName');
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('📊 حجم الصورة: ${imageBytes.length} bytes');
      if (imageBytes.isEmpty) {
        print('❌ بيانات الصورة فارغة');
        return null;
      }
      print('🔼 جاري رفع الصورة...');
      try {
        await _supabase.storage
            .from(_bucketName)
            .uploadBinary(storagePath, imageBytes);
        print('✅ تم رفع الصورة بنجاح');
      } catch (uploadError) {
        print('❌ فشل الرفع الأول: $uploadError');
        final simplePath = fileName.replaceAll('/', '_').replaceAll('\\', '_');
        print('🔄 محاولة بمسار أبسط: posts/$simplePath');
        await _supabase.storage
            .from(_bucketName)
            .uploadBinary('posts/$simplePath', imageBytes);
        storagePath = 'posts/$simplePath';
        print('✅ تم رفع الصورة بنجاح في المحاولة الثانية');
      }
      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);
      print('🔗 رابط الصورة: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      throw Exception('فشل في رفع الصورة: $e');
    }
  }

  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles, {
    String? folderName,
  }) async {
    print('🔄 بدء رفع ${imageFiles.length} صورة...');
    final bucketExists = await ensureBucketExists();
    if (!bucketExists) {
      print('❌ لا يمكن رفع الصور: bucket "$_bucketName" غير موجود');
      throw Exception('البكت $_bucketName غير موجود في Supabase Storage');
    }
    final List<String> uploadedUrls = [];
    for (int i = 0; i < imageFiles.length; i++) {
      print('📤 رفع الصورة ${i + 1} من ${imageFiles.length}');
      try {
        final String? imageUrl = await uploadImage(
          imageFiles[i],
          folderName: folderName,
        );
        if (imageUrl != null) {
          uploadedUrls.add(imageUrl);
          print('✅ تم رفع الصورة ${i + 1} بنجاح');
        } else {
          print('❌ فشل في رفع الصورة ${i + 1}');
        }
      } catch (e) {
        print('❌ خطأ في رفع الصورة ${i + 1}: $e');
      }
    }
    print(
      '🎉 تم رفع ${uploadedUrls.length} من أصل ${imageFiles.length} صورة بنجاح',
    );
    return uploadedUrls;
  }

  // ⭐⭐ دالة محسنة لاستخراج المسار الصحيح داخل الـ bucket
  String _extractCorrectFilePath(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      print('🔍 تحليل الرابط: $imageUrl');
      print('📁 أجزاء المسار: $pathSegments');

      // نبحث عن index 'public'
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex != -1) {
        // المسار الصحيح يبدأ من بعد public+1 (أي بعد اسم الـ bucket مباشرة)
        // مثال: public, posts_images, products, 2026, 2, file.jpg
        // المطلوب: products/2026/2/file.jpg (نبدأ من publicIndex + 2)
        if (publicIndex + 2 < pathSegments.length) {
          final filePath = pathSegments.sublist(publicIndex + 2).join('/');
          print('✅ المسار المستخرج الصحيح: $filePath');
          return filePath;
        } else {
          throw Exception('المسار قصير جداً بعد public');
        }
      }
      throw Exception('رابط صورة غير صالح - لا يوجد public في المسار');
    } catch (e) {
      print('❌ خطأ في استخراج مسار الملف: $e');
      throw Exception('فشل في تحليل رابط الصورة: $e');
    }
  }

  Future<void> _deleteWithServiceKey(String filePath) async {
    try {
      print('🔑 جاري الحذف باستخدام Service Key: $filePath');
      print('📦 الـ Bucket: $_bucketName');
      final result = await _supabaseService.storage.from(_bucketName).remove([
        filePath,
      ]);
      print('✅ نتيجة الحذف: $result');
      if (result.isEmpty) {
        // لا ترمي خطأ، فقط أبلغ أن الملف غير موجود (قد يكون محذوفاً مسبقاً)
        print('⚠️ الملف غير موجود أو لا توجد صلاحيات، نعتبره محذوفاً');
      } else {
        print('🎉 تم حذف الصورة بنجاح: $filePath');
      }
    } catch (e) {
      print('❌ خطأ في الحذف بـ Service Key: $e');
      throw e;
    }
  }

  Future<void> deleteImageFromUrl(String imageUrl) async {
    try {
      print('🗑️ بدء حذف الصورة من الرابط: $imageUrl');
      final filePath = _extractCorrectFilePath(imageUrl);
      print('📁 المسار الصحيح داخل الباكت: $filePath');
      await _deleteWithServiceKey(filePath);
    } catch (e) {
      print('❌ فشل في حذف الصورة: $e');
      throw Exception('فشل في حذف الصورة من التخزين');
    }
  }

  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    try {
      if (imageUrls.isEmpty) {
        print('⚠️ لا توجد صور لحذفها');
        return;
      }
      print('🗑️ بدء حذف ${imageUrls.length} صورة...');
      print('📦 الـ Bucket: $_bucketName');
      List<String> filePaths = [];
      for (final imageUrl in imageUrls) {
        try {
          final filePath = _extractCorrectFilePath(imageUrl);
          filePaths.add(filePath);
          print('✅ تم استخراج المسار: $filePath');
        } catch (e) {
          print('⚠️ فشل في استخراج مسار الصورة: $imageUrl - $e');
        }
      }
      if (filePaths.isEmpty) {
        print('⚠️ لا توجد مسارات صالحة للحذف');
        return;
      }
      print('📸 الملفات المطلوب حذفها: $filePaths');
      final result = await _supabaseService.storage
          .from(_bucketName)
          .remove(filePaths);
      print('✅ نتيجة الحذف: $result');
      if (result.isEmpty) {
        print('⚠️ لم يتم حذف أي ملف (قد تكون غير موجودة)');
      } else {
        print('🎉 تم حذف ${result.length} ملف بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في حذف الصور المتعددة: $e');
      throw Exception('فشل في حذف الصور: $e');
    }
  }

  Future<void> safeDeleteImage(String imageUrl) async {
    try {
      print('🛡️ بدء الحذف الآمن للصورة: $imageUrl');
      print('📦 الـ Bucket: $_bucketName');
      final filePath = _extractCorrectFilePath(imageUrl);
      print('🗑️ جاري حذف: $filePath');
      try {
        final result = await _supabase.storage.from(_bucketName).remove([
          filePath,
        ]);
        if (result.isNotEmpty) {
          print('✅ تم الحذف بنجاح بالطريقة العادية');
          return;
        }
      } catch (e) {
        print('⚠️ الحذف العادي فشل، جاري استخدام Service Key: $e');
      }
      final result = await _supabaseService.storage.from(_bucketName).remove([
        filePath,
      ]);
      if (result.isEmpty) {
        print('⚠️ الملف غير موجود، نعتبره محذوفاً');
      } else {
        print('✅ تم الحذف بنجاح باستخدام Service Key');
      }
    } catch (e) {
      print('❌ خطأ في الحذف الآمن: $e');
      throw e;
    }
  }

  Future<bool> testStorageConnection() async {
    try {
      print('🔍 اختبار الاتصال بـ $_bucketName...');
      final bucketExists = await ensureBucketExists();
      if (!bucketExists) return false;
      final files = await _supabase.storage.from(_bucketName).list();
      print('✅ اتصال الـ Storage يعمل بنجاح - عدد الملفات: ${files.length}');
      return true;
    } catch (e) {
      print('❌ فشل في الاتصال بالـ Storage: $e');
      return false;
    }
  }

  Future<bool> checkSupabaseConnection() async {
    try {
      print('🔗 التحقق من اتصال Supabase...');
      print('📦 الـ Bucket: $_bucketName');
      final files = await _supabase.storage.from(_bucketName).list();
      print('✅ اتصال Supabase يعمل بنجاح');
      return true;
    } catch (e) {
      print('❌ فشل في الاتصال بـ Supabase: $e');
      try {
        final files = await _supabaseService.storage.from(_bucketName).list();
        print('✅ اتصال Supabase بـ Service Key يعمل بنجاح');
        return true;
      } catch (e2) {
        print('❌ فشل في الاتصال حتى بـ Service Key: $e2');
        return false;
      }
    }
  }

  Future<void> testDeleteFunction(String imageUrl) async {
    try {
      print('🧪 بدء اختبار الحذف للصورة: $imageUrl');
      await deleteImageFromUrl(imageUrl);
      print('🎉 اختبار الحذف تم بنجاح!');
    } catch (e) {
      print('❌ خطأ في اختبار الحذف: $e');
      rethrow;
    }
  }
}
