import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/services/post_service.dart';
import 'package:snae3ya/services/location_service.dart';
import 'dart:io';

class PostProvider with ChangeNotifier {
  final PostService _postService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();

  PostProvider() : _postService = PostService();

  List<Post> _posts = [];
  List<Post> _nearbyPosts = [];
  List<Post> _userPosts = [];
  bool _isLoading = false;
  String _error = '';

  // موقع المستخدم الحالي
  double? _userLatitude;
  double? _userLongitude;
  bool _isLocationLoading = false;

  // لتتبع الـ streams النشطة
  Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  bool _isDisposed = false;

  List<Post> get posts => _posts;
  List<Post> get nearbyPosts => _nearbyPosts;
  List<Post> get userPosts => _userPosts;
  bool get isLoading => _isLoading;
  String get error => _error;
  double? get userLatitude => _userLatitude;
  double? get userLongitude => _userLongitude;
  bool get isLocationLoading => _isLocationLoading;
  bool get hasUserLocation => _userLatitude != null && _userLongitude != null;

  // ⭐⭐ **تحديث موقع المستخدم**
  Future<void> updateUserLocation() async {
    if (_isDisposed || _isLocationLoading) return;

    _isLocationLoading = true;
    _safeNotifyListeners();

    try {
      final location = await _locationService.getCurrentLocation();
      _userLatitude = location.latitude;
      _userLongitude = location.longitude;

      print('📍 تم تحديث موقع المستخدم: $_userLatitude, $_userLongitude');

      if (_userLatitude != null && _userLongitude != null) {
        loadNearbyPosts();
      }
    } catch (e) {
      print('❌ فشل في تحديث موقع المستخدم: $e');
    } finally {
      _isLocationLoading = false;
      _safeNotifyListeners();
    }
  }

  // ⭐⭐ **تحميل المنشورات القريبة**
  void loadNearbyPosts({String? type, String? category}) {
    if (_isLoading || _isDisposed) return;
    if (!hasUserLocation) {
      print('⚠️ لا يوجد موقع للمستخدم لتحديد المنشورات القريبة');
      return;
    }

    _isLoading = true;
    _error = '';
    _safeNotifyListeners();

    try {
      final subscription = _postService
          .getNearbyPostsStream(
            userLat: _userLatitude!,
            userLon: _userLongitude!,
            type: type,
            category: category,
          )
          .listen(
            (posts) {
              if (_isDisposed) return;

              _nearbyPosts = posts;
              _isLoading = false;
              _safeNotifyListeners();
              print('✅ تم تحميل ${posts.length} منشور قريب');
            },
            onError: (error) {
              if (_isDisposed) return;

              _error = 'فشل في تحميل المنشورات القريبة: $error';
              _isLoading = false;
              _safeNotifyListeners();
              print('❌ خطأ في تحميل المنشورات القريبة: $error');
            },
          );

      addSubscription('nearby_posts', subscription);
    } catch (e) {
      if (_isDisposed) return;

      _error = 'فشل في تحميل المنشورات القريبة: $e';
      _isLoading = false;
      _safeNotifyListeners();
      if (kDebugMode) {
        print('Error loading nearby posts: $e');
      }
    }
  }

  // ⭐⭐ **الحصول على المنشورات القريبة لشاشة معينة**
  Stream<List<Post>> getNearbyPostsStream({String? type, String? category}) {
    if (!hasUserLocation) {
      print(
        '⚠️ getNearbyPostsStream: لا يوجد موقع للمستخدم، سيتم إرجاع Stream فارغ',
      );
      return Stream.value([]);
    }

    print(
      '📍 getNearbyPostsStream: userLat=$_userLatitude, userLon=$_userLongitude, type=$type, category=$category',
    );

    return _postService.getNearbyPostsStream(
      userLat: _userLatitude!,
      userLon: _userLongitude!,
      type: type,
      category: category,
    );
  }

  // ⭐⭐ **دالة جديدة: جلب أعمال الصنايعي المكتملة**
  Stream<List<Post>> getWorkerCompletedJobs(String workerId) {
    return _postService.getWorkerCompletedJobs(workerId);
  }

  // ⭐⭐ **دالة جديدة: تأكيد الاتفاق على الشغلانة**
  Future<void> agreeOnJob(
    String postId,
    String workerId,
    String workerName,
    String workerImage,
  ) async {
    if (_isDisposed) return;

    try {
      await _postService.agreeOnJob(postId, workerId, workerName, workerImage);
      _safeNotifyListeners();
    } catch (e) {
      print('❌ فشل في تأكيد الاتفاق: $e');
      rethrow;
    }
  }

  // ⭐⭐ **دالة جديدة: إكمال الشغلانة**
  Future<void> completeJob(
    String postId,
    List<File> completionImageFiles,
  ) async {
    if (_isDisposed) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      await _postService.completeJob(postId, completionImageFiles);
    } catch (e) {
      print('❌ فشل في إكمال الشغلانة: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ⭐⭐ **دالة جديدة: تقييم الشغلانة**
  Future<void> rateJob(
    String postId,
    double rating,
    String? review, {
    required String clientName,
    required String? clientImage,
  }) async {
    if (_isDisposed) return;

    try {
      await _postService.rateJob(
        postId,
        rating,
        review,
        clientName: clientName,
        clientImage: clientImage,
      );
      _safeNotifyListeners();
    } catch (e) {
      print('❌ فشل في تقييم الشغلانة: $e');
      rethrow;
    }
  }

  // ⭐⭐ **دالة جديدة: تعيين حالة التوفر**
  Future<void> setPostAvailability(String postId, bool isAvailable) async {
    if (_isDisposed) return;

    try {
      await _postService.setPostAvailability(postId, isAvailable);
      _safeNotifyListeners();
    } catch (e) {
      print('❌ فشل في تغيير حالة المنشور: $e');
      rethrow;
    }
  }

  // إيقاف جميع الـ listeners
  void stopAllListeners() {
    if (_isDisposed) return;

    print('🛑 PostProvider: إيقاف جميع الـ listeners...');
    for (var subscription in _activeSubscriptions.values) {
      try {
        subscription.cancel();
      } catch (e) {
        print('⚠️ خطأ في إلغاء الاشتراك: $e');
      }
    }
    _activeSubscriptions.clear();
    _posts = [];
    _nearbyPosts = [];
    _userPosts = [];
    _error = '';

    print('✅ PostProvider: تم إيقاف جميع الـ listeners بنجاح');
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

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }

  // إضافة بوست جديد مع رفع الصور
  Future<void> addPost(Post post, {List<File>? imageFiles}) async {
    if (_isDisposed) return;

    _isLoading = true;
    _error = '';
    _safeNotifyListeners();

    try {
      await _postService.addPost(post, imageFiles: imageFiles);
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في إضافة المنشور: $e';
        _safeNotifyListeners();
      }
      if (kDebugMode) {
        print('Error adding post: $e');
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  // جلب جميع البوستات مع إمكانية التصفية
  Stream<List<Post>> getPostsStream({
    String? type,
    String? category,
    double? minBudget,
    double? maxBudget,
    String? searchQuery,
  }) {
    return _postService.getPosts(
      type: type,
      category: category,
      minBudget: minBudget,
      maxBudget: maxBudget,
      searchQuery: searchQuery,
    );
  }

  // جلب بوستات المستخدم الحالي
  Stream<List<Post>> getUserPostsStream(String userId) {
    return _postService.getUserPosts(userId);
  }

  // تحميل جميع المنشورات إلى الحالة المحلية
  void loadAllPosts({
    String? type,
    String? category,
    double? minBudget,
    double? maxBudget,
    String? searchQuery,
  }) {
    if (_isLoading || _isDisposed) return;

    _isLoading = true;
    _error = '';
    _safeNotifyListeners();

    try {
      final subscription =
          getPostsStream(
            type: type,
            category: category,
            minBudget: minBudget,
            maxBudget: maxBudget,
            searchQuery: searchQuery,
          ).listen(
            (posts) {
              if (_isDisposed) return;

              _posts = posts;
              _isLoading = false;
              _safeNotifyListeners();
              print('✅ تم تحميل ${posts.length} منشور');
            },
            onError: (error) {
              if (_isDisposed) return;

              _error = 'فشل في تحميل المنشورات: $error';
              _isLoading = false;
              _safeNotifyListeners();
              print('❌ خطأ في تحميل المنشورات: $error');
            },
          );

      addSubscription('all_posts', subscription);
    } catch (e) {
      if (_isDisposed) return;

      _error = 'فشل في تحميل المنشورات: $e';
      _isLoading = false;
      _safeNotifyListeners();
      if (kDebugMode) {
        print('Error loading posts: $e');
      }
    }
  }

  // تحميل منشورات المستخدم إلى الحالة المحلية
  void loadUserPosts(String userId) {
    try {
      final subscription = getUserPostsStream(userId).listen(
        (posts) {
          if (_isDisposed) return;

          _userPosts = posts;
          _safeNotifyListeners();
          print('✅ تم تحميل ${posts.length} منشور للمستخدم');
        },
        onError: (error) {
          if (_isDisposed) return;

          print('❌ خطأ في تحميل منشورات المستخدم: $error');
        },
      );

      addSubscription('user_posts_$userId', subscription);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user posts: $e');
      }
    }
  }

  // تحديث البوست الأساسي
  Future<void> updatePost(Post post) async {
    if (_isDisposed) return;

    try {
      await _postService.updatePost(post.id, post.toFirestore());
      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في تحديث المنشور: $e';
        _safeNotifyListeners();
      }
      rethrow;
    }
  }

  // تحديث البوست مع الصور
  Future<void> updatePostWithImages({
    required Post post,
    required List<File> newImageFiles,
    required List<String> deletedImages,
  }) async {
    if (_isDisposed) return;

    _isLoading = true;
    _error = '';
    _safeNotifyListeners();

    try {
      List<String> imageUrls = List.from(post.images);

      for (String imageUrl in deletedImages) {
        if (imageUrl.contains('supabase.co')) {
          await _postService.deleteImageFromUrl(imageUrl);
        }
      }

      if (newImageFiles.isNotEmpty) {
        print('📸 جاري رفع ${newImageFiles.length} صورة جديدة إلى Supabase...');

        final uploadedUrls = await _postService.uploadMultipleImagesToSupabase(
          newImageFiles,
        );
        imageUrls.addAll(uploadedUrls);

        print('✅ تم رفع ${uploadedUrls.length} صورة جديدة بنجاح إلى Supabase');
      }

      final updatedPost = post.copyWith(images: imageUrls);
      await _postService.updatePost(updatedPost.id, updatedPost.toFirestore());

      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في تحديث المنشور مع الصور: $e';
        _safeNotifyListeners();
      }
      rethrow;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  // حذف البوست
  Future<void> deletePost(String postId) async {
    if (_isDisposed) return;

    try {
      await _postService.deletePost(postId);
      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في حذف المنشور: $e';
        _safeNotifyListeners();
      }
      rethrow;
    }
  }

  // زيادة عدد المشاهدات
  Future<void> incrementViews(String postId) async {
    if (_isDisposed) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _postService.incrementViews(postId);

      print('✅ تم زيادة مشاهدات البوست: $postId');
    } catch (e) {
      print('⚠️ فشل في زيادة المشاهدات: $e');
    }
  }

  // زيادة عدد المتقدمين
  Future<void> incrementApplications(String postId) async {
    if (_isDisposed) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _postService.incrementApplications(postId);

      print('✅ تم زيادة عدد المتقدمين للبوست: $postId');
    } catch (e) {
      print('⚠️ فشل في زيادة المتقدمين: $e');
    }
  }

  // البحث في البوستات مع التحميل للحالة المحلية
  void searchPosts(String query) {
    if (_isDisposed) return;

    try {
      final subscription = _postService
          .searchPosts(query)
          .listen(
            (posts) {
              if (_isDisposed) return;

              _posts = posts;
              _safeNotifyListeners();
              print('✅ تم البحث في المنشورات، النتائج: ${posts.length}');
            },
            onError: (error) {
              if (_isDisposed) return;

              print('❌ خطأ في البحث: $error');
            },
          );

      addSubscription('search_$query', subscription);
    } catch (e) {
      if (kDebugMode) {
        print('Error searching posts: $e');
      }
    }
  }

  // جلب بوست بواسطة ID
  Future<Post?> getPostById(String postId) async {
    if (_isDisposed) return null;

    return await _postService.getPostById(postId);
  }

  // التحقق من ملكية البوست
  bool isMyPost(String authorId) {
    final currentUser = _auth.currentUser;
    return currentUser != null && authorId == currentUser.uid;
  }

  // تحميل منشورات حسب التصنيف
  void loadPostsByCategory(String category) {
    if (_isDisposed) return;

    try {
      final subscription = _postService
          .getPosts(category: category)
          .listen(
            (posts) {
              if (_isDisposed) return;

              _posts = posts;
              _safeNotifyListeners();
              print('✅ تم تحميل ${posts.length} منشور في تصنيف: $category');
            },
            onError: (error) {
              if (_isDisposed) return;

              print('❌ خطأ في تحميل المنشورات حسب التصنيف: $error');
            },
          );

      addSubscription('category_$category', subscription);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading posts by category: $e');
      }
    }
  }

  // إعادة تحميل البيانات
  void reloadData() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _isDisposed) return;

    stopAllListeners();
    loadAllPosts();
    loadUserPosts(currentUser.uid);
    if (hasUserLocation) {
      loadNearbyPosts();
    }
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

    _posts = [];
    _nearbyPosts = [];
    _userPosts = [];
    _error = '';
    _safeNotifyListeners();
  }
}
