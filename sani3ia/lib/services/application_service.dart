import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/application_model.dart';

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ⭐ جديد: دالة التحقق من التقدم المسبق
  Future<bool> checkExistingApplication({
    required String postId,
    required String applicantId,
  }) async {
    try {
      final existingApplication = await _firestore
          .collection('applications')
          .where('postId', isEqualTo: postId)
          .where('applicantId', isEqualTo: applicantId)
          .limit(1)
          .get();

      return existingApplication.docs.isNotEmpty;
    } catch (e) {
      print('❌ خطأ في التحقق من التقدم المسبق: $e');
      return false;
    }
  }

  // التقدم لشغلانة
  Future<void> applyForJob({
    required String postId,
    required String postTitle,
    required String postOwnerId,
    String? message,
    double? proposedPrice,
    DateTime? proposedDate,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('يجب تسجيل الدخول أولاً');

      // ⭐ محسّن: استخدام الدالة الجديدة للتحقق من التقدم المسبق
      final existingApplication = await checkExistingApplication(
        postId: postId,
        applicantId: currentUser.uid,
      );

      if (existingApplication) {
        throw Exception('لقد تقدمت لهذه الشغلانة مسبقاً');
      }

      // جلب بيانات المتقدم
      final applicantData = await _getUserData(currentUser.uid);

      // إنشاء طلب التقدم
      final applicationRef = _firestore.collection('applications').doc();

      final application = Application(
        id: applicationRef.id,
        postId: postId,
        postTitle: postTitle,
        applicantId: currentUser.uid,
        applicantName: applicantData['name'] ?? 'مستخدم',
        applicantImage:
            applicantData['profileImage'] ??
            'assets/images/default_profile.png',
        postOwnerId: postOwnerId,
        appliedAt: DateTime.now(),
        message: message,
        proposedPrice: proposedPrice,
        proposedDate: proposedDate,
      );

      await applicationRef.set(application.toFirestore());

      print('✅ تم التقدم للشغلانة بنجاح');
    } catch (e) {
      print('❌ فشل في التقدم للشغلانة: $e');
      throw Exception('فشل في التقدم للشغلانة: $e');
    }
  }

  // جلب طلبات التقدم لشغلانة محددة
  Stream<List<Application>> getApplicationsForPost(String postId) {
    return _firestore
        .collection('applications')
        .where('postId', isEqualTo: postId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Application.fromFirestore(doc))
              .toList(),
        );
  }

  // جلب طلبات التقدم الخاصة بالمستخدم
  Stream<List<Application>> getUserApplications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('applications')
        .where('applicantId', isEqualTo: currentUser.uid)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Application.fromFirestore(doc))
              .toList(),
        );
  }

  // جلب طلبات التقدم الواردة للمستخدم (كمشرف على شغلانات)
  Stream<List<Application>> getReceivedApplications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('applications')
        .where('postOwnerId', isEqualTo: currentUser.uid)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Application.fromFirestore(doc))
              .toList(),
        );
  }

  // تحديث حالة طلب التقدم
  Future<void> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus newStatus,
  }) async {
    try {
      await _firestore.collection('applications').doc(applicationId).update({
        'status': newStatus.index,
      });

      print('✅ تم تحديث حالة الطلب بنجاح');
    } catch (e) {
      print('❌ فشل في تحديث حالة الطلب: $e');
      throw Exception('فشل في تحديث حالة الطلب: $e');
    }
  }

  // حذف طلب التقدم
  Future<void> deleteApplication(String applicationId) async {
    try {
      await _firestore.collection('applications').doc(applicationId).delete();
      print('✅ تم حذف طلب التقدم بنجاح');
    } catch (e) {
      print('❌ فشل في حذف طلب التقدم: $e');
      throw Exception('فشل في حذف طلب التقدم: $e');
    }
  }

  // دالة مساعدة لجلب بيانات المستخدم
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('❌ فشل في جلب بيانات المستخدم: $e');
      return {};
    }
  }
}
