import 'package:flutter/material.dart';
import 'package:snae3ya/models/orders_model.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    // تحميل الطلبات (سيتم استبدال هذا ببيانات حقيقية)
    _loadOrders();
  }

  void _loadOrders() {
    // بيانات تجريبية
    setState(() {
      _orders = [
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
        Order(
          id: '3',
          postTitle: 'دهان غرفة المعيشة',
          craftsmanName: 'محمود سعيد',
          craftsmanImage: 'assets/images/user3.png',
          agreedPrice: 1800.0,
          arrivalDate: DateTime.now().subtract(const Duration(days: 1)),
          status: OrderStatus.completed,
          location: 'الإسكندرية، مصر',
          rating: 4.5,
        ),
      ];
    });
  }

  Widget _buildOrderCard(Order order) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case OrderStatus.confirmed:
        statusColor = Colors.blue;
        statusText = 'تم التأكيد';
        break;
      case OrderStatus.inProgress:
        statusColor = Colors.orange;
        statusText = 'قيد التنفيذ';
        break;
      case OrderStatus.completed:
        statusColor = Colors.green;
        statusText = 'مكتمل';
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'ملغي';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundImage: AssetImage(order.craftsmanImage)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.postTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        order.craftsmanName,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16),
                const SizedBox(width: 4),
                Text('السعر: ${order.agreedPrice} ج.م'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text('موعد الوصول: ${_formatDate(order.arrivalDate)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text(order.location),
              ],
            ),
            if (order.status == OrderStatus.inProgress &&
                order.craftsmanLocation != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  const Text('موقع الصنايعي الحالي:'),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'خريطة بلايف لوكيشن\nلات: ${order.craftsmanLocation!.lat}\nلونج: ${order.craftsmanLocation!.lng}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // متابعة الموقع الحي
                      },
                      child: const Text('متابعة الموقع الحي'),
                    ),
                  ),
                ],
              ),
            if (order.status == OrderStatus.completed && order.rating == null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showRatingDialog(order);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'قيم الخدمة',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (order.rating != null)
              Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('تقييمك: '),
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(order.rating!.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showRatingDialog(Order order) {
    double rating = 0;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('قيم الخدمة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('كيف كانت تجربتك مع الصنايعي؟'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text('التقييم: $rating من 5'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      order.rating = rating;
                    });
                    Navigator.pop(context);
                    _showPaymentOptions(order);
                  },
                  child: const Text('تأكيد التقييم'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentOptions(Order order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('اختر طريقة الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('بطاقة ائتمان'),
                onTap: () {
                  _processPayment(order, 'credit_card');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('نقداً عند الاستلام'),
                onTap: () {
                  _processPayment(order, 'cash');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('محفظة إلكترونية'),
                onTap: () {
                  _processPayment(order, 'wallet');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _processPayment(Order order, String method) {
    // معالجة الدفع
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت عملية الدفع باستخدام $method بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي'), centerTitle: true),
      body: _orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات حالية'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                return _buildOrderCard(_orders[index]);
              },
            ),
    );
  }
}
