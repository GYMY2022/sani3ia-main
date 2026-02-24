import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/product_model.dart';
import 'package:snae3ya/services/image_upload_service.dart';
import 'package:snae3ya/services/location_service.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();
  final LocationService _locationService = LocationService();

  // ✅ التحقق من اتصال Supabase
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
      return false;
    }
  }

  // ✅ إضافة منتج جديد مع رفع الصور
  Future<String> addProduct(Product product, {List<File>? imageFiles}) async {
    try {
      List<String> imageUrls = [];

      if (imageFiles != null && imageFiles.isNotEmpty) {
        print('📸 جاري رفع ${imageFiles.length} صورة للمنتج...');

        final canConnect = await _imageUploadService.testStorageConnection();
        if (!canConnect) {
          print(
            '⚠️ لا يمكن الاتصال بـ Supabase Storage، سيتم المتابعة بدون صور',
          );
        } else {
          imageUrls = await _imageUploadService.uploadMultipleImages(
            imageFiles,
            folderName:
                'products/${DateTime.now().year}/${DateTime.now().month}',
          );

          if (imageUrls.isEmpty) {
            print('⚠️ فشل في رفع الصور، سيتم المتابعة بدون صور');
          } else {
            print('✅ تم رفع الصور بنجاح: ${imageUrls.length} صورة');
          }
        }
      }

      if (imageUrls.isEmpty) {
        imageUrls = ['assets/images/default_product.png'];
      }

      final productWithImages = product.copyWith(
        imageUrls: imageUrls,
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('products')
          .add(productWithImages.toFirestore());

      await _firestore.collection('products').doc(docRef.id).update({
        'id': docRef.id,
      });

      print('✅ تم إضافة المنتج بنجاح: ${docRef.id}');
      print('🖼️ الصور المرفوعة: $imageUrls');

      return docRef.id;
    } catch (e) {
      print('❌ فشل في إضافة المنتج: $e');
      throw Exception('فشل في إضافة المنتج: $e');
    }
  }

  // ✅ جلب جميع المنتجات
  Stream<List<Product>> getProducts({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? searchQuery,
    String? sellerId,
  }) {
    try {
      Query query = _firestore.collection('products');

      if (category != null && category != 'الكل') {
        query = query.where('category', isEqualTo: category);
      }

      if (sellerId != null) {
        query = query.where('sellerId', isEqualTo: sellerId);
      }

      query = query.orderBy('createdAt', descending: true).limit(50);

      return query.snapshots().map((snapshot) {
        print('📊 getProducts - عدد المنتجات: ${snapshot.docs.length}');

        final products = snapshot.docs.map((doc) {
          try {
            return Product.fromFirestore(doc);
          } catch (e) {
            print('Error parsing product ${doc.id}: $e');
            return Product(
              id: doc.id,
              title: 'عنوان افتراضي',
              description: 'وصف افتراضي',
              price: 0,
              imageUrls: ['assets/images/default_product.png'],
              category: 'عام',
              location: 'موقع غير محدد',
              sellerId: '',
              sellerName: 'بائع',
              sellerImage: 'assets/images/default_profile.png',
              rating: 0,
              createdAt: DateTime.now(),
            );
          }
        }).toList();

        return products.where((product) {
          final priceMatch =
              (minPrice == null || product.price >= minPrice) &&
              (maxPrice == null || product.price <= maxPrice);

          final searchMatch =
              searchQuery == null ||
              product.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              product.description.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );

          return priceMatch && searchMatch;
        }).toList();
      });
    } catch (e) {
      print('Error getting products: $e');
      return Stream.value([]);
    }
  }

  // ✅ جلب منتجات مستخدم معين
  Stream<List<Product>> getUserProducts(String userId) {
    return getProducts(sellerId: userId);
  }

  // ✅ جلب منتج بواسطة ID
  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting product by ID: $e');
      return null;
    }
  }

  // ✅ تحديث المنتج
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('products').doc(productId).update(updates);
      print('✅ تم تحديث المنتج: $productId');
    } catch (e) {
      throw Exception('فشل في تحديث المنتج: $e');
    }
  }

  // ✅ تحديث المنتج مع الصور
  Future<void> updateProductWithImages({
    required Product product,
    required List<File> newImageFiles,
    required List<String> deletedImages,
  }) async {
    try {
      List<String> imageUrls = List.from(product.imageUrls);

      // حذف الصور المحذوفة من Supabase
      for (String imageUrl in deletedImages) {
        if (imageUrl.contains('supabase.co')) {
          await _deleteImageFromUrl(imageUrl);
        }
      }

      // رفع الصور الجديدة
      if (newImageFiles.isNotEmpty) {
        print('📸 جاري رفع ${newImageFiles.length} صورة جديدة...');

        final uploadedUrls = await _imageUploadService.uploadMultipleImages(
          newImageFiles,
          folderName: 'products/${DateTime.now().year}/${DateTime.now().month}',
        );

        imageUrls.removeWhere((url) => deletedImages.contains(url));
        imageUrls.addAll(uploadedUrls);
      }

      final updatedProduct = product.copyWith(
        imageUrls: imageUrls,
        updatedAt: DateTime.now(),
      );

      await updateProduct(product.id, updatedProduct.toFirestore());

      print('✅ تم تحديث المنتج مع الصور بنجاح');
    } catch (e) {
      print('❌ فشل في تحديث المنتج مع الصور: $e');
      throw Exception('فشل في تحديث المنتج مع الصور: $e');
    }
  }

  // ✅ دالة مساعدة لاستخراج المسار الصحيح (محسنة)
  String _extractCorrectPath(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;

      // الرابط: storage/v1/object/public/posts_images/products/2026/2/file.jpg
      final bucketIndex = segments.indexOf('posts_images');

      if (bucketIndex == -1) return '';

      // نأخذ ما بعد اسم الباكت فقط
      final pathSegments = segments.sublist(bucketIndex + 1);
      return pathSegments.join('/');
    } catch (e) {
      print('❌ خطأ في استخراج المسار: $e');
      return '';
    }
  }

  // ✅ حذف المنتج مع الصور من Supabase
  Future<void> deleteProduct(String productId) async {
    print('🚀 بدء deleteProduct للمنتج: $productId');
    try {
      print('🗑️ جلب بيانات المنتج من Firestore...');
      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        print('⚠️ المنتج غير موجود: $productId');
        throw Exception('المنتج غير موجود');
      }

      print('📄 تم جلب المستند بنجاح، جاري تحويله إلى Product...');
      final product = Product.fromFirestore(productDoc);
      print('📸 الصور المرتبطة بالمنتج: ${product.imageUrls}');

      // حذف الصور من Supabase
      if (product.imageUrls.isNotEmpty) {
        print(
          '📸 استدعاء _deleteProductImages مع ${product.imageUrls.length} صورة',
        );
        await _deleteProductImages(product.imageUrls);
      } else {
        print('⚠️ لا توجد صور لحذفها');
      }

      // حذف المنتج من Firestore
      print('🗑️ حذف المنتج من Firestore...');
      await _firestore.collection('products').doc(productId).delete();
      print('✅ تم حذف المنتج من Firestore');

      // حذف المفضلة المرتبطة
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('productId', isEqualTo: productId)
          .get();

      if (favoritesSnapshot.docs.isNotEmpty) {
        print(
          '🗑️ حذف ${favoritesSnapshot.docs.length} إشارة مرجعية من المفضلة...',
        );
        final batch = _firestore.batch();
        for (var doc in favoritesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print('✅ تم حذف إشارات المفضلة');
      }

      print('✅ تم حذف المنتج والصور بنجاح');
    } catch (e) {
      print('❌ فشل في حذف المنتج: $e');
      throw Exception('فشل في حذف المنتج: $e');
    }
  }

  // ✅ حذف صور المنتج من Supabase
  Future<void> _deleteProductImages(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;

    final supabase = _imageUploadService.client; // أو serviceClient

    final supabaseImages = imageUrls
        .where((url) => url.contains('supabase.co') && !url.contains('assets/'))
        .toList();

    if (supabaseImages.isEmpty) {
      print('⚠️ لا توجد صور من Supabase لحذفها');
      return;
    }

    for (final imageUrl in supabaseImages) {
      try {
        final path = _extractCorrectPath(imageUrl);

        if (path.isEmpty) {
          print('⚠️ لم يتم استخراج مسار صحيح للصورة');
          continue;
        }

        print('🗑️ حذف الصورة من bucket posts_images');
        print('📁 المسار: $path');

        final response = await supabase.storage.from('posts_images').remove([
          path,
        ]);

        print('✅ نتيجة الحذف: $response');
      } catch (e) {
        print('❌ فشل حذف الصورة: $e');
      }
    }
  }

  // ✅ حذف صورة من الرابط (احتياطي)
  Future<void> _deleteImageFromUrl(String imageUrl) async {
    try {
      if (imageUrl.contains('supabase.co')) {
        await _imageUploadService.deleteImageFromUrl(imageUrl);
        print('✅ تم حذف الصورة: $imageUrl');
      }
    } catch (e) {
      print('❌ فشل في حذف الصورة: $imageUrl - $e');
    }
  }

  // ✅ زيادة عدد المشاهدات (الطريقة القديمة)
  Future<void> incrementViews(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('⚠️ فشل في زيادة المشاهدات: $e');
    }
  }

  // ⭐⭐ زيادة المشاهدات مرة واحدة لكل مستخدم
  Future<void> incrementViewsIfNotViewed(
    String productId,
    String userId,
  ) async {
    try {
      final productRef = _firestore.collection('products').doc(productId);

      await _firestore.runTransaction((transaction) async {
        final productDoc = await transaction.get(productRef);
        if (!productDoc.exists) return;

        List<dynamic> viewedBy = productDoc.data()?['viewedBy'] ?? [];
        if (!viewedBy.contains(userId)) {
          viewedBy.add(userId);
          transaction.update(productRef, {
            'viewedBy': viewedBy,
            'views': FieldValue.increment(1),
          });
          print(
            '✅ تم تسجيل مشاهدة جديدة للمنتج $productId من المستخدم $userId',
          );
        } else {
          print('ℹ️ المستخدم $userId شاهد المنتج مسبقاً، لن تزداد المشاهدات');
        }
      });
    } catch (e) {
      print('❌ فشل في زيادة المشاهدات: $e');
    }
  }

  // ✅ تبديل حالة المفضلة
  Future<void> toggleFavorite({
    required String userId,
    required String productId,
    required bool isFavorite,
  }) async {
    try {
      final favoriteRef = _firestore
          .collection('favorites')
          .doc('${userId}_$productId');

      if (isFavorite) {
        await favoriteRef.set({
          'userId': userId,
          'productId': productId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('products').doc(productId).update({
          'favoriteCount': FieldValue.increment(1),
        });
      } else {
        await favoriteRef.delete();

        await _firestore.collection('products').doc(productId).update({
          'favoriteCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      print('❌ فشل في تبديل المفضلة: $e');
      throw Exception('فشل في تحديث المفضلة');
    }
  }

  // ✅ التحقق إذا كان المنتج في مفضلة المستخدم
  Future<bool> isFavorite(String userId, String productId) async {
    try {
      final doc = await _firestore
          .collection('favorites')
          .doc('${userId}_$productId')
          .get();
      return doc.exists;
    } catch (e) {
      print('❌ فشل في التحقق من المفضلة: $e');
      return false;
    }
  }

  // ✅ جلب منتجات المفضلة للمستخدم
  Stream<List<Product>> getFavoriteProducts(String userId) {
    try {
      return _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<Product> products = [];
            for (var doc in snapshot.docs) {
              final productId = doc.data()['productId'] as String;
              final product = await getProductById(productId);
              if (product != null) {
                products.add(product.copyWith(isFavorite: true));
              }
            }
            return products;
          });
    } catch (e) {
      print('❌ خطأ في جلب المنتجات المفضلة: $e');
      return Stream.value([]);
    }
  }

  // ✅ البحث في المنتجات
  Stream<List<Product>> searchProducts(String query) {
    if (query.isEmpty) return getProducts();

    return getProducts(searchQuery: query);
  }

  // ✅ تغيير حالة المنتج (available/sold/reserved)
  Future<void> updateProductStatus(String productId, String status) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ تم تحديث حالة المنتج إلى: $status');
    } catch (e) {
      print('❌ فشل في تحديث حالة المنتج: $e');
      throw Exception('فشل في تحديث حالة المنتج');
    }
  }

  // ✅ تمييز المنتج كمباع
  Future<void> markAsSold(String productId) async {
    await updateProductStatus(productId, 'sold');
  }

  // ✅ تمييز المنتج كمتوفر
  Future<void> markAsAvailable(String productId) async {
    await updateProductStatus(productId, 'available');
  }

  // ✅ دالة مساعدة لرفع صورة واحدة
  Future<String> _uploadImageToSupabase(File imageFile) async {
    try {
      final imageUrl = await _imageUploadService.uploadImage(
        imageFile,
        folderName: 'products/${DateTime.now().year}/${DateTime.now().month}',
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('فشل في رفع الصورة');
      }

      return imageUrl;
    } catch (e) {
      print('❌ فشل في رفع الصورة إلى Supabase: $e');
      throw Exception('فشل في رفع الصورة: $e');
    }
  }

  // ✅ جلب صورة المنتج
  Future<String?> getProductImage(String productId) async {
    try {
      if (productId.isEmpty) return null;

      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();
      if (productDoc.exists) {
        final productData = productDoc.data();
        final images = productData?['imageUrls'] ?? [];
        if (images is List && images.isNotEmpty) {
          final firstImage = images[0];
          if (firstImage is String && firstImage.isNotEmpty) {
            return firstImage;
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب صورة المنتج: $e');
      return null;
    }
  }

  // ✅ جلب عنوان المنتج
  Future<String?> getProductTitle(String productId) async {
    try {
      if (productId.isEmpty) return null;

      final productDoc = await _firestore
          .collection('products')
          .doc(productId)
          .get();
      if (productDoc.exists) {
        final productData = productDoc.data();
        return productData?['title'] ?? 'منتج';
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب عنوان المنتج: $e');
      return null;
    }
  }
}
