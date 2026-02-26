import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/application_model.dart';
import 'package:snae3ya/services/application_service.dart';
import 'package:snae3ya/services/chat_service.dart';
import 'package:snae3ya/services/notification_helper.dart'; // ⭐ إضافة

class ApplicationProvider with ChangeNotifier {
  final ApplicationService _applicationService;
  final ChatService _chatService;
  final FirebaseAuth _auth;

  List<Application> _userApplications = [];
  List<Application> _receivedApplications = [];
  bool _isLoading = false;
  String _error = '';

  // ⭐ جديد: لتتبع الـ listeners النشطة
  List<StreamSubscription<dynamic>> _activeSubscriptions = [];
  bool _isDisposed = false;

  ApplicationProvider()
    : _applicationService = ApplicationService(),
      _chatService = ChatService(),
      _auth = FirebaseAuth.instance;

  List<Application> get userApplications => _userApplications;
  List<Application> get receivedApplications => _receivedApplications;
  bool get isLoading => _isLoading;
  String get error => _error;

  // ⭐ جديد: دالة لإيقاف جميع الـ listeners
  void stopAllListeners() {
    if (_isDisposed) return;

    print('🛑 ApplicationProvider: إيقاف جميع الـ listeners...');
    for (var subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _userApplications = [];
    _receivedApplications = [];
    _error = '';
  }

  void addSubscription(StreamSubscription<dynamic> subscription) {
    if (_isDisposed) {
      subscription.cancel();
      return;
    }
    _activeSubscriptions.add(subscription);
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopAllListeners();
    super.dispose();
  }

  // ⭐ محسّن: دالة آمنة لـ notifyListeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ⭐ جديد: دالة للتحقق إذا كان متقدم قبل كده
  Future<bool> checkIfAppliedBefore(String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      return await _applicationService.checkExistingApplication(
        postId: postId,
        applicantId: currentUser.uid,
      );
    } catch (e) {
      print('❌ خطأ في التحقق من التقدم المسبق: $e');
      return false;
    }
  }

  // ⭐ محسّن: التقدم لشغلانة مع فتح الدردشة مباشرة
  Future<bool> applyForJob({
    required String postId,
    required String postTitle,
    required String postOwnerId,
    required String postOwnerName,
    required String postOwnerImage,
    String? message,
    double? proposedPrice,
    DateTime? proposedDate,
  }) async {
    if (_isDisposed) return false;

    _isLoading = true;
    _error = '';
    _safeNotifyListeners();

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('يجب تسجيل الدخول أولاً');

      // ⭐ محسّن: التحقق من التقدم المسبق
      final existingApplication = await _applicationService
          .checkExistingApplication(
            postId: postId,
            applicantId: currentUser.uid,
          );

      if (existingApplication) {
        // ⭐ جديد: إذا متقدم قبل كده، نرجع true علشان نفتح الشات مباشرة
        print('✅ المستخدم متقدم مسبقاً، فتح الشات مباشرة');
        _isLoading = false;
        _safeNotifyListeners();
        return true; // نرجع true علشان نفتح الشات مباشرة
      }

      // ⭐ 1. إنشاء طلب التقدم (فقط إذا مقدمش قبل كده)
      await _applicationService.applyForJob(
        postId: postId,
        postTitle: postTitle,
        postOwnerId: postOwnerId,
        message: message,
        proposedPrice: proposedPrice,
        proposedDate: proposedDate,
      );

      // ⭐ 2. إرسال رسالة تلقائية في الدردشة
      await _chatService.sendMessage(
        receiverId: postOwnerId,
        message: message ?? 'هل الشغلانة "$postTitle" متوفرة؟',
        postId: postId,
        isAvailabilityQuestion: true,
      );

      // ⭐ 3. إعادة تحميل الطلبات
      loadUserApplications();

      print('✅ تم التقدم للشغلانة وفتح المحادثة بنجاح');
      return false; // نرجع false علشان ده أول تقديم
    } catch (e) {
      _error = 'فشل في التقدم للشغلانة: $e';
      if (kDebugMode) {
        print('Error applying for job: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ⭐ جديد: دالة لفتح الشات مباشرة بدون تقديم
  Future<void> openChatDirectly({
    required String postId,
    required String postTitle,
    required String postOwnerId,
    required String postOwnerName,
    required String postOwnerImage,
  }) async {
    // هذه الدالة بتكون للاستخدام من الـ UI علشان يفتح الشات مباشرة
    print('🚀 فتح الشات مباشرة للشغلانة: $postTitle');
  }

  // ⭐ جديد: دالة للرد على استفسار التوفر
  Future<void> respondToAvailability({
    required String applicationId,
    required String receiverId,
    required String postTitle,
    required bool isAvailable,
    String? customMessage,
  }) async {
    if (_isDisposed) return;

    try {
      final responseMessage =
          customMessage ??
          (isAvailable
              ? "نعم، الشغلانة '$postTitle' متوفرة"
              : "للأسف، الشغلانة '$postTitle' غير متوفرة حالياً");

      // ⭐ إرسال الرد في الدردشة
      await _chatService.sendMessage(
        receiverId: receiverId,
        message: responseMessage,
        isAvailabilityResponse: true,
        availabilityStatus: isAvailable,
      );

      // ⭐ تحديث حالة الطلب
      final newStatus = isAvailable
          ? ApplicationStatus.accepted
          : ApplicationStatus.rejected;

      await updateApplicationStatus(
        applicationId: applicationId,
        newStatus: newStatus,
      );

      print('✅ تم إرسال الرد على استفسار التوفر: $responseMessage');
    } catch (e) {
      _error = 'فشل في إرسال الرد: $e';
      _safeNotifyListeners();
      rethrow;
    }
  }

  // جلب طلبات التقدم الخاصة بالمستخدم
  void loadUserApplications() {
    if (_isDisposed) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final subscription = _applicationService.getUserApplications().listen((
        applications,
      ) {
        if (_isDisposed) return;
        _userApplications = applications;
        _safeNotifyListeners();
      });

      addSubscription(subscription);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user applications: $e');
      }
    }
  }

  // جلب طلبات التقدم الواردة
  void loadReceivedApplications() {
    if (_isDisposed) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final subscription = _applicationService.getReceivedApplications().listen(
        (applications) {
          if (_isDisposed) return;
          _receivedApplications = applications;
          _safeNotifyListeners();
        },
      );

      addSubscription(subscription);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading received applications: $e');
      }
    }
  }

  // تحديث حالة طلب التقدم (مع إشعار قبول/رفض)
  Future<void> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus newStatus,
  }) async {
    if (_isDisposed) return;

    try {
      await _applicationService.updateApplicationStatus(
        applicationId: applicationId,
        newStatus: newStatus,
      );

      // ⭐ إرسال إشعار للمتقدم بقبول/رفض الطلب
      final application = getApplicationById(applicationId);
      if (application != null) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          if (newStatus == ApplicationStatus.accepted) {
            NotificationHelper.sendJobApplicationAcceptedNotification(
              applicantId: application.applicantId,
              postOwnerName: currentUser.displayName ?? 'صاحب الشغلانة',
              postTitle: application.postTitle,
              postId: application.postId,
            );
          } else if (newStatus == ApplicationStatus.rejected) {
            NotificationHelper.sendJobApplicationRejectedNotification(
              applicantId: application.applicantId,
              postOwnerName: currentUser.displayName ?? 'صاحب الشغلانة',
              postTitle: application.postTitle,
              postId: application.postId,
            );
          }
        }
      }

      // تحديث البيانات المحلية
      _updateLocalApplicationStatus(applicationId, newStatus);

      _safeNotifyListeners();
    } catch (e) {
      _error = 'فشل في تحديث حالة الطلب: $e';
      _safeNotifyListeners();
      rethrow;
    }
  }

  // تحديث الحالة المحلية للطلب
  void _updateLocalApplicationStatus(
    String applicationId,
    ApplicationStatus newStatus,
  ) {
    // تحديث في طلبات المستخدم
    final userAppIndex = _userApplications.indexWhere(
      (app) => app.id == applicationId,
    );
    if (userAppIndex != -1) {
      _userApplications[userAppIndex] = _userApplications[userAppIndex]
          .copyWith(status: newStatus);
    }

    // تحديث في الطلبات الواردة
    final receivedAppIndex = _receivedApplications.indexWhere(
      (app) => app.id == applicationId,
    );
    if (receivedAppIndex != -1) {
      _receivedApplications[receivedAppIndex] =
          _receivedApplications[receivedAppIndex].copyWith(status: newStatus);
    }
  }

  // حذف طلب التقدم
  Future<void> deleteApplication(String applicationId) async {
    if (_isDisposed) return;

    try {
      await _applicationService.deleteApplication(applicationId);

      // تحديث البيانات المحلية
      _userApplications.removeWhere((app) => app.id == applicationId);
      _receivedApplications.removeWhere((app) => app.id == applicationId);

      _safeNotifyListeners();
    } catch (e) {
      _error = 'فشل في حذف طلب التقدم: $e';
      _safeNotifyListeners();
      rethrow;
    }
  }

  // الحصول على طلب تقدم محدد
  Application? getApplicationById(String applicationId) {
    final userApp = _userApplications.firstWhere(
      (app) => app.id == applicationId,
      orElse: () => Application(
        id: '',
        postId: '',
        postTitle: '',
        applicantId: '',
        applicantName: '',
        applicantImage: '',
        postOwnerId: '',
        appliedAt: DateTime.now(),
      ),
    );
    if (userApp.id.isNotEmpty) return userApp;

    final receivedApp = _receivedApplications.firstWhere(
      (app) => app.id == applicationId,
      orElse: () => Application(
        id: '',
        postId: '',
        postTitle: '',
        applicantId: '',
        applicantName: '',
        applicantImage: '',
        postOwnerId: '',
        appliedAt: DateTime.now(),
      ),
    );
    return receivedApp.id.isNotEmpty ? receivedApp : null;
  }

  // التحقق من التقدم لشغلانة محددة
  bool hasAppliedForPost(String postId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    return _userApplications.any(
      (app) => app.postId == postId && app.applicantId == currentUser.uid,
    );
  }

  // الحصول على عدد الطلبات الواردة الجديدة
  int getNewApplicationsCount() {
    return _receivedApplications
        .where((app) => app.status == ApplicationStatus.pending)
        .length;
  }

  // ⭐ جديد: الحصول على طلبات التقدم لشغلانة محددة
  Stream<List<Application>> getApplicationsForPost(String postId) {
    return _applicationService.getApplicationsForPost(postId);
  }

  // مسح الأخطاء
  void clearError() {
    if (_error.isNotEmpty && !_isDisposed) {
      _error = '';
      _safeNotifyListeners();
    }
  }

  // إعادة تعيين البيانات
  void reset() {
    if (_isDisposed) return;

    _userApplications = [];
    _receivedApplications = [];
    _error = '';
    _safeNotifyListeners();
  }
}
