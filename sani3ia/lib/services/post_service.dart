import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/services/image_upload_service.dart';
import 'package:snae3ya/services/location_service.dart';
import 'dart:io';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();
  final LocationService _locationService = LocationService();

  // ✅ دالة التحقق من الاتصال
  Future<bool> checkSupabaseConnection() async {
    try {
      print('🔗 التحقق من اتصال Supabase...');

      final response = await _imageUploadService.client.storage
          .from('posts_images')
          .list();
      print('✅ اتصال Supabase يعمل بنجاح');
      return true;
    } catch (e) {
      print('❌ فشل في الاتصال بـ Supabase: $e');

      try {
        final response = await _imageUploadService.serviceClient.storage
            .from('posts_images')
            .list();
        print('✅ اتصال Supabase بـ Service Key يعمل بنجاح');
        return true;
      } catch (e2) {
        print('❌ فشل في الاتصال حتى بـ Service Key: $e2');
        return false;
      }
    }
  }

  // إضافة بوست جديد مع رفع الصور
  Future<String> addPost(Post post, {List<File>? imageFiles}) async {
    try {
      List<String> imageUrls = [];

      // رفع الصور إذا وجدت
      if (imageFiles != null && imageFiles.isNotEmpty) {
        print('📸 جاري رفع ${imageFiles.length} صورة...');

        final canConnect = await _imageUploadService.testStorageConnection();
        if (!canConnect) {
          print(
            '⚠️ لا يمكن الاتصال بـ Supabase Storage، سيتم المتابعة بدون صور',
          );
        } else {
          imageUrls = await _imageUploadService.uploadMultipleImages(
            imageFiles,
            folderName: 'posts/${DateTime.now().year}/${DateTime.now().month}',
          );

          if (imageUrls.isEmpty) {
            print('⚠️ فشل في رفع الصور، سيتم المتابعة بدون صور');
          } else {
            print('✅ تم رفع الصور بنجاح: ${imageUrls.length} صورة');
          }
        }
      } else {
        print('ℹ️ لا توجد صور لرفعها');
      }

      // ⭐⭐ مهم: إذا كان هناك صور مرفوعة مسبقاً (من add_job_screen)، استخدمها
      // وإذا كانت الصور فارغة، استخدم الصور الافتراضية
      if (imageUrls.isEmpty &&
          post.images.isNotEmpty &&
          !post.images[0].startsWith('assets/')) {
        // إذا كان البوست يحتوي على صور وليست افتراضية، استخدمها
        imageUrls = post.images;
        print('🖼️ استخدام الصور المرفوعة مسبقاً: ${imageUrls.length}');
      } else if (imageUrls.isEmpty) {
        // إذا لم ترفع الصور، استخدم الصور الافتراضية
        imageUrls = [
          'assets/images/default_job_1.png',
          'assets/images/default_job_2.png',
        ];
        print('🖼️ استخدام الصور الافتراضية');
      }

      // جلب موقع المستخدم الحالي إذا لم يكن موجوداً
      Map<String, dynamic>? finalGeoLocation = post.geoLocation;
      if (finalGeoLocation == null) {
        try {
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            final userLocation = await _locationService.getUserLocation(
              currentUser.uid,
            );
            if (userLocation != null) {
              finalGeoLocation = {
                'latitude': userLocation.latitude,
                'longitude': userLocation.longitude,
                'address': userLocation.address,
                'city': userLocation.city,
                'country': userLocation.country,
              };
              print('📍 تم إضافة موقع الناشر تلقائياً');
            }
          }
        } catch (e) {
          print('⚠️ فشل في جلب موقع الناشر: $e');
        }
      }

      // إنشاء البوست مع روابط الصور والموقع
      final postWithImages = post.copyWith(
        images: imageUrls,
        geoLocation: finalGeoLocation,
      );

      final docRef = await _firestore
          .collection('posts')
          .add(postWithImages.toFirestore());

      // تحديث الـ ID للمستند
      await _firestore.collection('posts').doc(docRef.id).update({
        'id': docRef.id,
      });

      print('✅ تم إضافة البوست بنجاح: ${docRef.id}');
      print('🖼️ الصور المرفوعة: $imageUrls');
      if (finalGeoLocation != null) {
        print(
          '📍 موقع الناشر: ${finalGeoLocation['latitude']}, ${finalGeoLocation['longitude']}',
        );
      }

      return docRef.id;
    } catch (e) {
      print('❌ فشل في إضافة المنشور: $e');
      throw Exception('فشل في إضافة المنشور: $e');
    }
  }

  // ✅ دالة الحذف الرئيسية المحسنة
  Future<void> deletePost(String postId) async {
    try {
      print('🗑️ بدء عملية حذف البوست: $postId');

      final postDoc = await _firestore.collection('posts').doc(postId).get();

      if (!postDoc.exists) {
        print('⚠️ البوست غير موجود: $postId');
        throw Exception('البوست غير موجود');
      }

      final post = Post.fromFirestore(postDoc);
      print('📸 الصور المرتبطة بالبوست: ${post.images}');

      await _deletePostImages(post.images);

      await _firestore.collection('posts').doc(postId).delete();

      print('✅ تم حذف البوست والصور بنجاح');
    } catch (e) {
      print('❌ فشل في حذف المنشور: $e');
      throw Exception('فشل في حذف المنشور: $e');
    }
  }

  // ✅ دالة حذف الصور المحسنة
  Future<void> _deletePostImages(List<String> imageUrls) async {
    try {
      if (imageUrls.isEmpty) {
        print('⚠️ لا توجد صور لحذفها من الـ Storage');
        return;
      }

      print('🗑️ بدء حذف ${imageUrls.length} صورة من الـ Storage...');

      final supabaseImages = imageUrls
          .where(
            (url) =>
                url.contains('supabase.co') && !url.contains('assets/images/'),
          )
          .toList();

      if (supabaseImages.isEmpty) {
        print('⚠️ لا توجد صور من Supabase لحذفها');
        return;
      }

      print('📸 الصور التي سيتم حذفها من Supabase:');
      for (final image in supabaseImages) {
        print('   - $image');
      }

      await _imageUploadService.deleteMultipleImages(supabaseImages);
    } catch (e) {
      print('❌ خطأ في حذف الصور من الـ Storage: $e');
      throw Exception('فشل في حذف الصور: $e');
    }
  }

  // جلب جميع البوستات مع إمكانية التصفية (للصنايعية)
  Stream<List<Post>> getPosts({
    String? type,
    String? category,
    double? minBudget,
    double? maxBudget,
    String? searchQuery,
  }) {
    try {
      Query query = _firestore.collection('posts');

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      query = query.orderBy('date', descending: true).limit(50);

      return query.snapshots().map((snapshot) {
        print('📊 getPosts - عدد المنشورات: ${snapshot.docs.length}');

        final posts = snapshot.docs.map((doc) {
          try {
            return Post.fromFirestore(doc);
          } catch (e) {
            print('Error parsing post ${doc.id}: $e');
            return Post(
              id: doc.id,
              title: 'عنوان افتراضي',
              description: 'وصف افتراضي',
              images: ['assets/images/default_job_1.png'],
              type: 'customer',
              category: 'عام',
              date: DateTime.now(),
              authorId: 'unknown',
              authorName: 'مستخدم',
              authorImage: 'assets/images/default_profile.png',
              location: 'موقع غير محدد',
              budget: 0.0,
              createdAt: DateTime.now(),
            );
          }
        }).toList();

        return posts.where((post) {
          // ⭐⭐ عرض المنشورات المتوفرة فقط
          if (!post.isAvailable) {
            return false;
          }

          final categoryMatch = category == null || post.category == category;
          final minBudgetMatch = minBudget == null || post.budget >= minBudget;
          final maxBudgetMatch = maxBudget == null || post.budget <= maxBudget;

          return categoryMatch && minBudgetMatch && maxBudgetMatch;
        }).toList();
      });
    } catch (e) {
      print('Error getting posts: $e');
      return Stream.value([]);
    }
  }

  // ⭐⭐ **معدل: جلب المنشورات القريبة (مع تصفية المتوفرة فقط)**
  Stream<List<Post>> getNearbyPostsStream({
    required double userLat,
    required double userLon,
    String? type,
    String? category,
  }) {
    try {
      // بناء الاستعلام الأساسي
      Query query = _firestore.collection('posts');

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      return query.snapshots().map((snapshot) {
        print(
          '📊 عدد المنشورات المستلمة من Firestore: ${snapshot.docs.length}',
        );

        final posts = <Post>[];

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromFirestore(doc);

            // ⭐⭐ تخطي المنشورات غير المتوفرة
            if (!post.isAvailable) {
              continue;
            }

            // حساب المسافة للمنشورات التي لها موقع
            if (post.hasGeoLocation) {
              final postLat = post.geoLocation!['latitude'] as double;
              final postLon = post.geoLocation!['longitude'] as double;

              post.distance = _locationService.calculateDistance(
                lat1: userLat,
                lon1: userLon,
                lat2: postLat,
                lon2: postLon,
              );
            } else {
              // المنشورات بدون موقع نضيفها مع مسافة كبيرة
              post.distance = 999999.0;
            }

            posts.add(post);
          } catch (e) {
            print('Error parsing post ${doc.id}: $e');
          }
        }

        // تصفية حسب التصنيف إذا كان موجوداً
        var filteredPosts = posts.where((post) {
          if (category != null && post.category != category) {
            return false;
          }
          return true;
        }).toList();

        // ترتيب المنشورات حسب المسافة (الأقرب أولاً)
        filteredPosts.sort((a, b) {
          if (a.distance == null && b.distance == null) return 0;
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        });

        print('✅ عدد المنشورات بعد التصفية: ${filteredPosts.length}');
        return filteredPosts;
      });
    } catch (e) {
      print('Error getting nearby posts: $e');
      return Stream.value([]);
    }
  }

  // ⭐⭐ **جلب بوستات مستخدم معين (مع orderBy الصحيح)**
  Stream<List<Post>> getUserPosts(String userId) {
    try {
      return _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .orderBy('__name__', descending: true)
          .snapshots()
          .map((snapshot) {
            print(
              '📊 getUserPosts - عدد المنشورات: ${snapshot.docs.length} للمستخدم: $userId',
            );

            return snapshot.docs.map((doc) {
              try {
                return Post.fromFirestore(doc);
              } catch (e) {
                print('Error parsing user post ${doc.id}: $e');
                return Post(
                  id: doc.id,
                  title: 'عنوان افتراضي',
                  description: 'وصف افتراضي',
                  images: ['assets/images/default_job_1.png'],
                  type: 'customer',
                  category: 'عام',
                  date: DateTime.now(),
                  authorId: userId,
                  authorName: 'مستخدم',
                  authorImage: 'assets/images/default_profile.png',
                  location: 'موقع غير محدد',
                  budget: 0.0,
                  createdAt: DateTime.now(),
                );
              }
            }).toList();
          });
    } catch (e) {
      print('Error getting user posts: $e');
      return Stream.value([]);
    }
  }

  // جلب بوست بواسطة ID
  Future<Post?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return Post.fromFirestore(doc);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting post by ID: $e');
      return null;
    }
  }

  // تحديث البوست
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('posts').doc(postId).update(updates);
    } catch (e) {
      throw Exception('فشل في تحديث المنشور: $e');
    }
  }

  // زيادة عدد المشاهدات
  Future<void> incrementViews(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('فشل في زيادة المشاهدات: $e');
    }
  }

  // زيادة عدد المتقدمين
  Future<void> incrementApplications(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'applications': FieldValue.increment(1),
      });
    } catch (e) {
      print('فشل في زيادة عدد المتقدمين: $e');
    }
  }

  // البحث في البوستات
  Stream<List<Post>> searchPosts(String query) {
    try {
      return _firestore.collection('posts').orderBy('title').snapshots().map((
        snapshot,
      ) {
        final allPosts = snapshot.docs.map((doc) {
          try {
            return Post.fromFirestore(doc);
          } catch (e) {
            print('Error parsing post in search: $e');
            return Post(
              id: doc.id,
              title: 'عنوان افتراضي',
              description: 'وصف افتراضي',
              images: ['assets/images/default_job_1.png'],
              type: 'customer',
              category: 'عام',
              date: DateTime.now(),
              authorId: 'unknown',
              authorName: 'مستخدم',
              authorImage: 'assets/images/default_profile.png',
              location: 'موقع غير محدد',
              budget: 0.0,
              createdAt: DateTime.now(),
            );
          }
        }).toList();

        if (query.isEmpty) {
          return allPosts;
        }

        return allPosts.where((post) {
          return post.title.toLowerCase().contains(query.toLowerCase()) ||
              post.description.toLowerCase().contains(query.toLowerCase()) ||
              post.category.toLowerCase().contains(query.toLowerCase());
        }).toList();
      });
    } catch (e) {
      print('Error searching posts: $e');
      return Stream.value([]);
    }
  }

  // ✅ دالة لرفع صورة واحدة إلى Supabase
  Future<String> _uploadImageToSupabase(File imageFile) async {
    try {
      final randomSuffix =
          DateTime.now().millisecondsSinceEpoch + imageFile.hashCode;
      final fileName =
          'posts/${DateTime.now().millisecondsSinceEpoch}_$randomSuffix.jpg';

      print('📤 جاري رفع: $fileName');

      final imageUrl = await _imageUploadService.uploadImage(
        imageFile,
        folderName: 'posts/${DateTime.now().year}/${DateTime.now().month}',
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('فشل في رفع الصورة');
      }

      print('✅ تم الرفع بنجاح: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ فشل في رفع الصورة إلى Supabase: $e');
      throw Exception('فشل في رفع الصورة: $e');
    }
  }

  // ✅ دالة لرفع عدة صور إلى Supabase
  Future<List<String>> uploadMultipleImagesToSupabase(
    List<File> imageFiles,
  ) async {
    try {
      print('🚀 بدء رفع ${imageFiles.length} صورة إلى Supabase Storage...');

      final List<String> imageUrls = [];

      for (final imageFile in imageFiles) {
        try {
          final imageUrl = await _uploadImageToSupabase(imageFile);
          imageUrls.add(imageUrl);
          print('✅ تم رفع صورة: $imageUrl');
        } catch (e) {
          print('❌ فشل في رفع صورة: $e');
        }
      }

      print(
        '🎉 انتهى رفع الصور - النجاح: ${imageUrls.length} من ${imageFiles.length}',
      );
      return imageUrls;
    } catch (e) {
      print('❌ فشل في رفع الصور إلى Supabase: $e');
      throw Exception('فشل في رفع الصور: $e');
    }
  }

  // ✅ دالة لحذف صورة من Supabase
  Future<void> deleteImageFromUrl(String imageUrl) async {
    try {
      if (imageUrl.contains('supabase.co')) {
        print('🗑️ جاري حذف الصورة من Supabase: $imageUrl');
        await _imageUploadService.deleteImageFromUrl(imageUrl);
        print('✅ تم حذف الصورة بنجاح');
      } else {
        print('⚠️ الصورة ليست من Supabase، تخطي الحذف: $imageUrl');
      }
    } catch (e) {
      print('❌ فشل في حذف الصورة من Supabase: $e');
    }
  }

  // ✅ دالة لاختبار الحذف
  Future<void> testPostDeletion(String postId) async {
    try {
      print('🧪 بدء اختبار حذف البوست: $postId');

      final postDoc = await _firestore.collection('posts').doc(postId).get();

      if (!postDoc.exists) {
        print('❌ البوست غير موجود');
        return;
      }

      final post = Post.fromFirestore(postDoc);
      print('📸 الصور المرتبطة: ${post.images}');

      await _deletePostImages(post.images);

      print('🎉 اختبار الحذف اكتمل بنجاح!');
    } catch (e) {
      print('❌ خطأ في اختبار الحذف: $e');
    }
  }

  // ✅ دالة اختبار للحذف
  Future<void> testImageDeletion(String imageUrl) async {
    try {
      print('🧪 بدء اختبار الحذف للصورة: $imageUrl');

      await _imageUploadService.testDeleteFunction(imageUrl);

      print('🎉 اختبار الحذف تم بنجاح!');
    } catch (e) {
      print('❌ خطأ في اختبار الحذف: $e');
      rethrow;
    }
  }

  // ⭐⭐ دالة جديدة: تأكيد الاتفاق على الشغلانة
  Future<void> agreeOnJob(
    String postId,
    String workerId,
    String workerName,
    String workerImage,
  ) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'status': 'agreed',
        'workerId': workerId,
        'workerName': workerName,
        'workerImage': workerImage,
        'agreedAt': FieldValue.serverTimestamp(),
      });
      print('✅ تم تأكيد الاتفاق على الشغلانة: $postId');
    } catch (e) {
      print('❌ فشل في تأكيد الاتفاق: $e');
      throw Exception('فشل في تأكيد الاتفاق على الشغلانة');
    }
  }

  // ⭐⭐ دالة جديدة: إكمال الشغلانة مع رفع صور
  Future<void> completeJob(
    String postId,
    List<File> completionImageFiles,
  ) async {
    try {
      List<String> imageUrls = [];

      if (completionImageFiles.isNotEmpty) {
        imageUrls = await _imageUploadService.uploadMultipleImages(
          completionImageFiles,
          folderName:
              'completed_jobs/${DateTime.now().year}/${DateTime.now().month}',
        );
      }

      await _firestore.collection('posts').doc(postId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completionImages': imageUrls,
      });

      print('✅ تم إكمال الشغلانة: $postId مع ${imageUrls.length} صورة');
    } catch (e) {
      print('❌ فشل في إكمال الشغلانة: $e');
      throw Exception('فشل في إكمال الشغلانة');
    }
  }

  // ⭐⭐ دالة جديدة: تقييم الشغلانة
  Future<void> rateJob(
    String postId,
    double rating,
    String? review, {
    required String clientName,
    required String? clientImage,
  }) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'clientRating': rating,
        'clientReview': review,
        'clientName': clientName,
        'clientImage': clientImage,
      });
      print('✅ تم تقييم الشغلانة: $postId بتقييم $rating');

      // ⭐⭐ إضافة التقييم في collection منفصلة
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postData = postDoc.data();

      await _firestore.collection('reviews').add({
        'workerId': postData?['workerId'],
        'clientId': postData?['authorId'],
        'clientName': clientName,
        'clientImage': clientImage,
        'rating': rating,
        'comment': review,
        'createdAt': FieldValue.serverTimestamp(),
        'postId': postId,
      });
    } catch (e) {
      print('❌ فشل في تقييم الشغلانة: $e');
      throw Exception('فشل في تقييم الشغلانة');
    }
  }

  // ⭐⭐ دالة جديدة: تعيين حالة التوفر
  Future<void> setPostAvailability(String postId, bool isAvailable) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isAvailable': isAvailable,
      });
      print('✅ تم ${isAvailable ? 'تفعيل' : 'تعطيل'} المنشور: $postId');
    } catch (e) {
      print('❌ فشل في تغيير حالة المنشور: $e');
      throw Exception('فشل في تغيير حالة المنشور');
    }
  }

  // ⭐⭐ دالة جديدة: جلب أعمال الصنايعي المكتملة
  Stream<List<Post>> getWorkerCompletedJobs(String workerId) {
    try {
      return _firestore
          .collection('posts')
          .where('workerId', isEqualTo: workerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) {
                  try {
                    return Post.fromFirestore(doc);
                  } catch (e) {
                    print('Error parsing completed job: $e');
                    return null;
                  }
                })
                .where((post) => post != null)
                .cast<Post>()
                .toList();
          });
    } catch (e) {
      print('Error getting worker completed jobs: $e');
      return Stream.value([]);
    }
  }
}
