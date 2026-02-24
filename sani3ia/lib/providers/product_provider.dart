import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/product_model.dart';
import 'package:snae3ya/services/product_service.dart';
import 'package:snae3ya/services/location_service.dart';

class ProductProvider with ChangeNotifier {
  final ProductService _productService = ProductService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();

  List<Product> _products = [];
  List<Product> _userProducts = [];
  List<Product> _favoriteProducts = [];

  bool _isLoading = false;
  String _error = '';

  double? _userLatitude;
  double? _userLongitude;
  bool _isLocationLoading = false;

  Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  bool _isDisposed = false;

  List<Product> get products => _products;
  List<Product> get userProducts => _userProducts;
  List<Product> get favoriteProducts => _favoriteProducts;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get hasUserLocation => _userLatitude != null && _userLongitude != null;
  bool get isLocationLoading => _isLocationLoading;

  Future<void> updateUserLocation() async {
    if (_isDisposed || _isLocationLoading) return;
    _isLocationLoading = true;
    _safeNotifyListeners();
    try {
      final location = await _locationService.getCurrentLocation();
      _userLatitude = location.latitude;
      _userLongitude = location.longitude;
      print('📍 تم تحديث موقع المستخدم: $_userLatitude, $_userLongitude');
      _calculateDistances();
      _calculateDistancesForList(_userProducts);
      _calculateDistancesForList(_favoriteProducts);
      _safeNotifyListeners();
    } catch (e) {
      print('❌ فشل في تحديث موقع المستخدم: $e');
    } finally {
      _isLocationLoading = false;
      _safeNotifyListeners();
    }
  }

  void _calculateDistances() {
    if (!hasUserLocation) {
      for (var product in _products) product.distance = null;
      return;
    }
    int countWithLocation = 0;
    for (var product in _products) {
      if (product.hasGeoLocation) {
        countWithLocation++;
        try {
          product.distance = _locationService.calculateDistance(
            lat1: _userLatitude!,
            lon1: _userLongitude!,
            lat2: product.latitude!,
            lon2: product.longitude!,
          );
        } catch (e) {
          product.distance = null;
        }
      } else {
        product.distance = null;
      }
    }
    print('📍 منتجات ذات موقع: $countWithLocation / ${_products.length}');
  }

  void _calculateDistancesForList(List<Product> list) {
    if (!hasUserLocation) {
      for (var product in list) product.distance = null;
      return;
    }
    for (var product in list) {
      if (product.hasGeoLocation) {
        try {
          product.distance = _locationService.calculateDistance(
            lat1: _userLatitude!,
            lon1: _userLongitude!,
            lat2: product.latitude!,
            lon2: product.longitude!,
          );
        } catch (e) {
          product.distance = null;
        }
      } else {
        product.distance = null;
      }
    }
  }

  Future<void> addProduct(Product product, {List<File>? imageFiles}) async {
    if (_isDisposed) return;
    _isLoading = true;
    _error = '';
    _safeNotifyListeners();
    try {
      await _productService.addProduct(product, imageFiles: imageFiles);
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في إضافة المنتج: $e';
        _safeNotifyListeners();
      }
      if (kDebugMode) print('Error adding product: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  Stream<List<Product>> getProductsStream({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? searchQuery,
  }) {
    return _productService.getProducts(
      category: category,
      minPrice: minPrice,
      maxPrice: maxPrice,
      searchQuery: searchQuery,
    );
  }

  void loadAllProducts({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? searchQuery,
  }) {
    if (_isLoading || _isDisposed) return;
    _isLoading = true;
    _error = '';
    _safeNotifyListeners();
    try {
      final subscription =
          getProductsStream(
            category: category,
            minPrice: minPrice,
            maxPrice: maxPrice,
            searchQuery: searchQuery,
          ).listen(
            (products) {
              if (_isDisposed) return;
              _products = products;
              _calculateDistances();
              _isLoading = false;
              _safeNotifyListeners();
              print('✅ تم تحميل ${products.length} منتج');
            },
            onError: (error) {
              if (_isDisposed) return;
              _error = 'فشل في تحميل المنتجات: $error';
              _isLoading = false;
              _safeNotifyListeners();
              print('❌ خطأ في تحميل المنتجات: $error');
            },
          );
      addSubscription('all_products', subscription);
    } catch (e) {
      if (_isDisposed) return;
      _error = 'فشل في تحميل المنتجات: $e';
      _isLoading = false;
      _safeNotifyListeners();
      if (kDebugMode) print('Error loading products: $e');
    }
  }

  void loadUserProducts(String userId) {
    if (_isDisposed) return;
    try {
      final subscription = _productService
          .getUserProducts(userId)
          .listen(
            (products) {
              if (_isDisposed) return;
              _userProducts = products;
              _calculateDistancesForList(_userProducts);
              _safeNotifyListeners();
              print('✅ تم تحميل ${products.length} منتج للمستخدم');
            },
            onError: (error) {
              if (_isDisposed) return;
              print('❌ خطأ في تحميل منتجات المستخدم: $error');
            },
          );
      addSubscription('user_products_$userId', subscription);
    } catch (e) {
      if (kDebugMode) print('Error loading user products: $e');
    }
  }

  void loadFavoriteProducts() {
    if (_isDisposed) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      final subscription = _productService
          .getFavoriteProducts(currentUser.uid)
          .listen(
            (products) {
              if (_isDisposed) return;
              _favoriteProducts = products;
              _calculateDistancesForList(_favoriteProducts);
              _safeNotifyListeners();
              print('✅ تم تحميل ${products.length} منتج مفضل');
            },
            onError: (error) {
              if (_isDisposed) return;
              print('❌ خطأ في تحميل المنتجات المفضلة: $error');
            },
          );
      addSubscription('favorite_products', subscription);
    } catch (e) {
      print('Error loading favorite products: $e');
    }
  }

  Future<Product?> getProductById(String productId) async {
    return await _productService.getProductById(productId);
  }

  Future<void> updateProduct(Product product) async {
    if (_isDisposed) return;
    try {
      await _productService.updateProduct(product.id, product.toFirestore());
      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في تحديث المنتج: $e';
        _safeNotifyListeners();
      }
      rethrow;
    }
  }

  Future<void> updateProductWithImages({
    required Product product,
    required List<File> newImageFiles,
    required List<String> deletedImages,
  }) async {
    if (_isDisposed) return;
    _isLoading = true;
    _error = '';
    _safeNotifyListeners();
    try {
      await _productService.updateProductWithImages(
        product: product,
        newImageFiles: newImageFiles,
        deletedImages: deletedImages,
      );
      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في تحديث المنتج مع الصور: $e';
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

  Future<void> deleteProduct(String productId) async {
    if (_isDisposed) return;
    try {
      await _productService.deleteProduct(productId);
      _safeNotifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        _error = 'فشل في حذف المنتج: $e';
        _safeNotifyListeners();
      }
      rethrow;
    }
  }

  Future<void> incrementViewsIfNotViewed(
    String productId,
    String userId,
  ) async {
    if (_isDisposed) return;
    try {
      await _productService.incrementViewsIfNotViewed(productId, userId);
    } catch (e) {
      print('⚠️ فشل في زيادة المشاهدات: $e');
    }
  }

  Future<void> toggleFavorite(Product product) async {
    if (_isDisposed) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final newFavoriteState = !product.isFavorite;
    try {
      product.isFavorite = newFavoriteState;
      _updateProductInLists(product);
      _safeNotifyListeners();
      await _productService.toggleFavorite(
        userId: currentUser.uid,
        productId: product.id,
        isFavorite: newFavoriteState,
      );
      print(
        '✅ ${newFavoriteState ? 'أضيف' : 'أزيل'} من المفضلة: ${product.title}',
      );
    } catch (e) {
      product.isFavorite = !newFavoriteState;
      _updateProductInLists(product);
      _safeNotifyListeners();
      _error = 'فشل في تحديث المفضلة: $e';
      _safeNotifyListeners();
      print('❌ فشل في تبديل المفضلة: $e');
    }
  }

  void _updateProductInLists(Product updatedProduct) {
    final productIndex = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (productIndex != -1) _products[productIndex] = updatedProduct;
    final userIndex = _userProducts.indexWhere(
      (p) => p.id == updatedProduct.id,
    );
    if (userIndex != -1) _userProducts[userIndex] = updatedProduct;
    final favIndex = _favoriteProducts.indexWhere(
      (p) => p.id == updatedProduct.id,
    );
    if (favIndex != -1) {
      if (updatedProduct.isFavorite) {
        _favoriteProducts[favIndex] = updatedProduct;
      } else {
        _favoriteProducts.removeAt(favIndex);
      }
    } else if (updatedProduct.isFavorite) {
      _favoriteProducts.add(updatedProduct);
    }
    _favoriteProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<bool> isFavorite(String productId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    return await _productService.isFavorite(currentUser.uid, productId);
  }

  Future<void> updateProductStatus(String productId, String status) async {
    if (_isDisposed) return;
    try {
      await _productService.updateProductStatus(productId, status);
      final product = _products.firstWhere((p) => p.id == productId);
      final updatedProduct = product.copyWith(status: status);
      _updateProductInLists(updatedProduct);
      _safeNotifyListeners();
    } catch (e) {
      _error = 'فشل في تحديث حالة المنتج: $e';
      _safeNotifyListeners();
      rethrow;
    }
  }

  Future<void> markAsSold(String productId) async =>
      updateProductStatus(productId, 'sold');
  Future<void> markAsAvailable(String productId) async =>
      updateProductStatus(productId, 'available');

  void searchProducts(String query) {
    if (_isDisposed) return;
    try {
      final subscription = _productService
          .searchProducts(query)
          .listen(
            (products) {
              if (_isDisposed) return;
              _products = products;
              _calculateDistances();
              _safeNotifyListeners();
              print('✅ تم البحث في المنتجات، النتائج: ${products.length}');
            },
            onError: (error) {
              if (_isDisposed) return;
              print('❌ خطأ في البحث: $error');
            },
          );
      addSubscription('search_$query', subscription);
    } catch (e) {
      if (kDebugMode) print('Error searching products: $e');
    }
  }

  void reloadData() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _isDisposed) return;
    stopAllListeners();
    loadAllProducts();
    loadUserProducts(currentUser.uid);
    loadFavoriteProducts();
  }

  void addSubscription(String key, StreamSubscription<dynamic> subscription) {
    if (_isDisposed) {
      subscription.cancel();
      return;
    }
    _activeSubscriptions[key] = subscription;
  }

  void stopAllListeners() {
    if (_isDisposed) return;
    print('🛑 ProductProvider: إيقاف جميع الـ listeners...');
    for (var subscription in _activeSubscriptions.values) {
      try {
        subscription.cancel();
      } catch (e) {
        print('⚠️ خطأ في إلغاء الاشتراك: $e');
      }
    }
    _activeSubscriptions.clear();
    print('✅ ProductProvider: تم إيقاف جميع الـ listeners');
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopAllListeners();
    super.dispose();
  }

  void clearError() {
    if (_error.isNotEmpty && !_isDisposed) {
      _error = '';
      _safeNotifyListeners();
    }
  }

  void reset() {
    if (_isDisposed) return;
    _products = [];
    _userProducts = [];
    _favoriteProducts = [];
    _error = '';
    _safeNotifyListeners();
  }
}
