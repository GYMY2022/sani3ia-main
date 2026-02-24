import 'dart:async';
import 'package:flutter/material.dart';
import 'package:snae3ya/models/worker_model.dart';
import 'package:snae3ya/models/review_model.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/services/worker_service.dart';
import 'package:snae3ya/services/location_service.dart';

class WorkerProvider with ChangeNotifier {
  final WorkerService _workerService = WorkerService();
  final LocationService _locationService = LocationService();

  List<Worker> _workers = [];
  List<Worker> _nearbyWorkers = [];
  List<Review> _currentWorkerReviews = [];
  List<Post> _currentWorkerCompletedJobs = [];
  Worker? _selectedWorker;
  bool _isLoading = false;
  String _error = '';

  // موقع المستخدم الحالي
  double? _userLatitude;
  double? _userLongitude;
  bool _isLocationLoading = false;

  // لتتبع الـ streams النشطة
  Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  bool _isDisposed = false;

  List<Worker> get workers => _workers;
  List<Worker> get nearbyWorkers => _nearbyWorkers;
  List<Review> get currentWorkerReviews => _currentWorkerReviews;
  List<Post> get currentWorkerCompletedJobs => _currentWorkerCompletedJobs;
  Worker? get selectedWorker => _selectedWorker;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isLocationLoading => _isLocationLoading;
  bool get hasUserLocation => _userLatitude != null && _userLongitude != null;

  // ⭐⭐ تحديث موقع المستخدم
  Future<void> updateUserLocation() async {
    if (_isDisposed || _isLocationLoading) return;

    _isLocationLoading = true;
    notifyListeners();

    try {
      final location = await _locationService.getCurrentLocation();
      _userLatitude = location.latitude;
      _userLongitude = location.longitude;
      print('📍 تم تحديث موقع المستخدم: $_userLatitude, $_userLongitude');
    } catch (e) {
      print('❌ فشل في تحديث موقع المستخدم: $e');
    } finally {
      _isLocationLoading = false;
      notifyListeners();
    }
  }

  // ⭐⭐ حساب المسافة بين المستخدم والصنايعي
  double _calculateDistance(Worker worker) {
    if (!hasUserLocation ||
        worker.latitude == null ||
        worker.longitude == null) {
      return 999999.0;
    }

    return _locationService.calculateDistance(
      lat1: _userLatitude!,
      lon1: _userLongitude!,
      lat2: worker.latitude!,
      lon2: worker.longitude!,
    );
  }

  // ⭐⭐ جلب الصنايعية حسب المهنة مع ترتيب حسب المسافة
  Future<List<Worker>> getWorkersByProfession({
    required String profession,
    bool sortByDistance = true,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final workers = await _workerService.getWorkersByProfession(profession);

      // حساب المسافة لكل صنايعي
      for (var worker in workers) {
        // المسافة هتتحسب عند العرض
      }

      if (sortByDistance && hasUserLocation) {
        workers.sort((a, b) {
          final distA = _calculateDistance(a);
          final distB = _calculateDistance(b);
          return distA.compareTo(distB);
        });
      }

      _workers = workers;
      return workers;
    } catch (e) {
      _error = e.toString();
      print('❌ خطأ في جلب الصنايعية: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ⭐⭐ Stream للصنايعية حسب المهنة
  Stream<List<Worker>> getWorkersStream({String? profession}) {
    return _workerService.getWorkersStream(profession: profession).map((
      workers,
    ) {
      if (hasUserLocation) {
        for (var worker in workers) {
          // هنا ممكن نحسب المسافة لو عايز نعرضها
        }
      }
      return workers;
    });
  }

  // ⭐⭐ تحميل صنايعي بواسطة ID
  Future<void> loadWorkerById(String workerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedWorker = await _workerService.getWorkerById(workerId);
      if (_selectedWorker != null) {
        // تحميل التقييمات والأعمال
        _loadWorkerReviews(_selectedWorker!.id);
        _loadWorkerCompletedJobs(_selectedWorker!.id);
      }
    } catch (e) {
      _error = e.toString();
      print('❌ خطأ في جلب الصنايعي: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ⭐⭐ تحميل تقييمات الصنايعي
  void _loadWorkerReviews(String workerId) {
    try {
      final subscription = _workerService
          .getWorkerReviewsStream(workerId)
          .listen((reviews) {
            _currentWorkerReviews = reviews;
            notifyListeners();
          });

      _activeSubscriptions['reviews_$workerId'] = subscription;
    } catch (e) {
      print('❌ خطأ في تحميل التقييمات: $e');
    }
  }

  // ⭐⭐ تحميل أعمال الصنايعي المكتملة
  void _loadWorkerCompletedJobs(String workerId) {
    try {
      final subscription = _workerService
          .getWorkerCompletedJobsStream(workerId)
          .listen((jobs) {
            _currentWorkerCompletedJobs = jobs;
            notifyListeners();
          });

      _activeSubscriptions['jobs_$workerId'] = subscription;
    } catch (e) {
      print('❌ خطأ في تحميل الأعمال: $e');
    }
  }

  // ⭐⭐ إضافة تقييم
  Future<void> addReview(Review review) async {
    try {
      await _workerService.addReview(review);
      print('✅ تم إضافة التقييم بنجاح');
    } catch (e) {
      print('❌ فشل في إضافة التقييم: $e');
      rethrow;
    }
  }

  // ⭐⭐ حساب عدد الصنايعي في كل مهنة
  Future<Map<String, int>> getProfessionCounts() async {
    return await _workerService.getProfessionCounts();
  }

  // ⭐⭐ إيقاف جميع الـ listeners
  void stopAllListeners() {
    if (_isDisposed) return;

    for (var subscription in _activeSubscriptions.values) {
      try {
        subscription.cancel();
      } catch (e) {
        print('⚠️ خطأ في إلغاء الاشتراك: $e');
      }
    }
    _activeSubscriptions.clear();
  }

  void addSubscription(String key, StreamSubscription<dynamic> subscription) {
    if (_isDisposed) {
      subscription.cancel();
      return;
    }
    _activeSubscriptions[key] = subscription;
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopAllListeners();
    super.dispose();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void reset() {
    _workers = [];
    _nearbyWorkers = [];
    _currentWorkerReviews = [];
    _currentWorkerCompletedJobs = [];
    _selectedWorker = null;
    _error = '';
    notifyListeners();
  }
}
