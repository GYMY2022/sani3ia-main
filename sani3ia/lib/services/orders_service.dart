import 'package:snae3ya/models/orders_model.dart';

class OrdersService {
  // هذه الخدمة ستتعامل مع API الحقيقي في المستقبل
  // حالياً نستخدم بيانات تجريبية

  static final OrdersService _instance = OrdersService._internal();

  factory OrdersService() {
    return _instance;
  }

  OrdersService._internal();

  // محاكاة لجلب الطلبات من الخادم
  Future<List<Order>> getOrdersForUser(String userId) async {
    await Future.delayed(const Duration(seconds: 1)); // محاكاة انتظار الشبكة

    // بيانات تجريبية
    return [
      Order(
        id: '1',
        postTitle: 'تصليح حنفية المطبخ',
        craftsmanName: 'محمد أحمد',
        craftsmanImage: 'assets/images/user1.png',
        agreedPrice: 250.0,
        arrivalDate: DateTime.now().add(const Duration(days: 2)),
        status: OrderStatus.confirmed,
        location: 'القاهرة، مصر',
      ),
      Order(
        id: '2',
        postTitle: 'تركيب مكيف سبليت',
        craftsmanName: 'أحمد علي',
        craftsmanImage: 'assets/images/user2.png',
        agreedPrice: 1200.0,
        arrivalDate: DateTime.now().add(const Duration(days: 5)),
        status: OrderStatus.inProgress,
        location: 'الجيزة، مصر',
        craftsmanLocation: const LiveLocation(lat: 30.0444, lng: 31.2357),
      ),
    ];
  }

  // محاكاة لتحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    await Future.delayed(const Duration(seconds: 1)); // محاكاة انتظار الشبكة
    // في التطبيق الحقيقي، سيتم إرسال طلب إلى الخادم لتحديث الحالة
  }

  // محاكاة لتحديث الموقع الحي للصنايعي
  Future<void> updateCraftsmanLocation(
    String orderId,
    LiveLocation location,
  ) async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // محاكاة انتظار الشبكة
    // في التطبيق الحقيقي، سيتم إرسال الموقع إلى الخادم
  }

  // محاكاة لإضافة تقييم
  Future<void> addRating(String orderId, double rating) async {
    await Future.delayed(const Duration(seconds: 1)); // محاكاة انتظار الشبكة
    // في التطبيق الحقيقي، سيتم إرسال التقييم إلى الخادم
  }

  // محاكاة لإنشاء طلب جديد بعد الاتفاق
  Future<Order> createOrder({
    required String postId,
    required String postTitle,
    required String craftsmanId,
    required String craftsmanName,
    required String craftsmanImage,
    required double agreedPrice,
    required DateTime arrivalDate,
    required String location,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // محاكاة انتظار الشبكة

    return Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      postTitle: postTitle,
      craftsmanName: craftsmanName,
      craftsmanImage: craftsmanImage,
      agreedPrice: agreedPrice,
      arrivalDate: arrivalDate,
      location: location,
      status: OrderStatus.confirmed,
    );
  }
}
