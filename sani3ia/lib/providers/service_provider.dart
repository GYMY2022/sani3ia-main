import 'package:flutter/foundation.dart';
import 'package:snae3ya/models/service_model.dart';
import 'package:snae3ya/services/api_service.dart';

class ServiceProvider with ChangeNotifier {
  List<Service> _services = [];
  bool _isLoading = false;
  String _error = '';

  List<Service> get services => _services;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> loadServices() async {
    // إذا كان بالفعل يتم التحميل، لا تفعل شيئاً
    if (_isLoading) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final newServices = await ApiService.getServices();

      // تحديث فقط إذا كانت البيانات مختلفة
      if (!listEquals(_services, newServices)) {
        _services = newServices;
        notifyListeners();
      }
    } catch (error) {
      _error = error.toString();
      if (kDebugMode) {
        print('فشل تحميل الخدمات: $error');
      }
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  Future<Service?> getServiceById(int id) async {
    try {
      return await ApiService.getServiceById(id);
    } catch (error) {
      if (kDebugMode) {
        print('فشل جلب الخدمة: $error');
      }
      return null;
    }
  }

  void clearError() {
    if (_error.isNotEmpty) {
      _error = '';
      notifyListeners();
    }
  }
}
