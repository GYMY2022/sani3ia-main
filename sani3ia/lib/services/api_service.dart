import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:snae3ya/models/service_model.dart';

class ApiService {
  // لو بتشغل على Android Emulator استخدم 10.0.2.2 بدل localhost
  static const String baseUrl = 'http://10.0.2.2:3000';

  // ============================
  // تسجيل الدخول
  // ============================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('فشل تسجيل الدخول');
    }
  }

  // ============================
  // جلب جميع الخدمات
  // ============================
  static Future<List<Service>> getServices() async {
    try {
      // مثال: لو عندك API حقيقي، هتبقى حاجة زي:
      // final response = await http.get(Uri.parse('$baseUrl/api/services'));
      // final data = jsonDecode(response.body);
      // return data.map<Service>((item) => Service.fromJson(item)).toList();

      // محاكاة لجلب البيانات (للاختبار دلوقتي)
      await Future.delayed(const Duration(seconds: 2));

      return [
        Service(
          id: 1,
          name: 'سباكة',
          description: 'خدمات سباكة متكاملة',
          price: 150.0,
          imageUrl: 'assets/images/plumber_category.png',
        ),
        Service(
          id: 2,
          name: 'كهرباء',
          description: 'خدمات كهرباء متكاملة',
          price: 200.0,
          imageUrl: 'assets/images/electrician_category.png',
        ),
        Service(
          id: 3,
          name: 'نقاشة',
          description: 'خدمات نقاشة متكاملة',
          price: 250.0,
          imageUrl: 'assets/images/painter_category.png',
        ),
      ];
    } catch (e) {
      throw Exception('فشل في جلب الخدمات: $e');
    }
  }

  // ============================
  // جلب خدمة بالـ ID
  // ============================
  static Future<Service> getServiceById(int id) async {
    try {
      // محاكاة لجلب البيانات
      await Future.delayed(const Duration(seconds: 1));

      return Service(
        id: id,
        name: 'خدمة تجريبية',
        description: 'هذه خدمة تجريبية',
        price: 100.0,
        imageUrl: 'assets/images/default_service.png',
      );
    } catch (e) {
      throw Exception('فشل في جلب الخدمة: $e');
    }
  }
}
