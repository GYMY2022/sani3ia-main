import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://cezhcyhaiztoqgetxehv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNlemhjeWhhaXp0b3FnZXR4ZWh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxMTc1MjgsImV4cCI6MjA3NzY5MzUyOH0.sNS7Vi_CWUBwZuc3C90Z1ZZYi6NjminWw4ybb8kBO9Q';

  final SupabaseClient _client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  SupabaseClient get client => _client;

  Future<void> initialize() async {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      print('✅ Supabase initialized successfully!');
      print('🔗 URL: $supabaseUrl');
    } catch (e) {
      print('❌ Failed to initialize Supabase: $e');
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await _client.from('posts').select('id').limit(1);
      print('✅ Supabase connection test successful');
      return true;
    } catch (e) {
      print('❌ Supabase connection test failed: $e');
      return false;
    }
  }

  // ✅ دالة جديدة لحذف الصور من Supabase Storage
  Future<void> deleteImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      print('⚠️ لا توجد صور لحذفها من Supabase.');
      return;
    }

    try {
      print('🗑️ جاري حذف الصور من Supabase Storage...');
      final response = await _client.storage
          .from('posts_images')
          .remove(imagePaths);

      if (response.isNotEmpty) {
        print('✅ تم حذف الصور بنجاح: ${response.length} ملف.');
      } else {
        print('✅ تم حذف الصور بنجاح (استجابة فارغة).');
      }
    } catch (e) {
      print('❌ حدث خطأ أثناء حذف الصور من Supabase: $e');
    }
  }
}
