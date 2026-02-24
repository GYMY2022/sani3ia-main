import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snae3ya/models/worker_model.dart';
import 'package:snae3ya/models/review_model.dart';
import 'package:snae3ya/models/post_model.dart';

class WorkerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⭐⭐ جلب جميع الصنايعية حسب المهنة
  Future<List<Worker>> getWorkersByProfession(String profession) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('profession', isEqualTo: profession)
          .get();

      return snapshot.docs.map((doc) {
        return Worker.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('❌ خطأ في جلب الصنايعية: $e');
      return [];
    }
  }

  // ⭐⭐ جلب جميع الصنايعية (مع فلتر المهنة)
  Stream<List<Worker>> getWorkersStream({String? profession}) {
    try {
      Query query = _firestore.collection('users');

      if (profession != null && profession.isNotEmpty) {
        query = query.where('profession', isEqualTo: profession);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return Worker.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('❌ خطأ في Stream الصنايعية: $e');
      return Stream.value([]);
    }
  }

  // ⭐⭐ جلب صنايعي واحد بواسطة userId
  Future<Worker?> getWorkerByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Worker.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب الصنايعي: $e');
      return null;
    }
  }

  // ⭐⭐ جلب صنايعي واحد بواسطة document ID
  Future<Worker?> getWorkerById(String workerId) async {
    try {
      final doc = await _firestore.collection('users').doc(workerId).get();
      if (doc.exists) {
        // ⭐⭐ التصحيح هنا: استخدام as Map<String, dynamic>
        return Worker.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب الصنايعي: $e');
      return null;
    }
  }

  // ⭐⭐ جلب تقييمات الصنايعي
  Stream<List<Review>> getWorkerReviewsStream(String workerId) {
    try {
      return _firestore
          .collection('reviews')
          .where('workerId', isEqualTo: workerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Review.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
          });
    } catch (e) {
      print('❌ خطأ في جلب التقييمات: $e');
      return Stream.value([]);
    }
  }

  // ⭐⭐ جلب أعمال الصنايعي المكتملة
  Stream<List<Post>> getWorkerCompletedJobsStream(String workerId) {
    try {
      return _firestore
          .collection('posts')
          .where('workerId', isEqualTo: workerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return Post.fromFirestore(doc);
            }).toList();
          });
    } catch (e) {
      print('❌ خطأ في جلب أعمال الصنايعي: $e');
      return Stream.value([]);
    }
  }

  // ⭐⭐ حساب عدد الصنايعي في كل مهنة
  Future<Map<String, int>> getProfessionCounts() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final Map<String, int> counts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final profession = data['profession'] as String?;
        if (profession != null && profession.isNotEmpty) {
          counts[profession] = (counts[profession] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      print('❌ خطأ في حساب أعداد المهن: $e');
      return {};
    }
  }

  // ⭐⭐ إضافة تقييم جديد
  Future<void> addReview(Review review) async {
    try {
      await _firestore.collection('reviews').add(review.toMap());

      // تحديث متوسط التقييم للصنايعي
      await _updateWorkerRating(review.workerId);

      print('✅ تم إضافة التقييم بنجاح');
    } catch (e) {
      print('❌ فشل في إضافة التقييم: $e');
      throw Exception('فشل في إضافة التقييم');
    }
  }

  // ⭐⭐ تحديث متوسط تقييم الصنايعي
  Future<void> _updateWorkerRating(String workerId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('workerId', isEqualTo: workerId)
          .get();

      if (reviewsSnapshot.docs.isEmpty) return;

      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRating += (data['rating'] as num).toDouble();
      }

      final averageRating = totalRating / reviewsSnapshot.docs.length;
      final reviewCount = reviewsSnapshot.docs.length;

      await _firestore.collection('users').doc(workerId).update({
        'rating': averageRating,
        'reviewCount': reviewCount,
      });

      print('✅ تم تحديث تقييم الصنايعي: $averageRating ($reviewCount تقييم)');
    } catch (e) {
      print('❌ فشل في تحديث التقييم: $e');
    }
  }
}
