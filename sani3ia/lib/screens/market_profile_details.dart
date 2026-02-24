import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/user_provider.dart';
import 'edit_product.dart';
import 'product_details.dart';

class MarketProfileDetails extends StatefulWidget {
  const MarketProfileDetails({super.key});

  @override
  State<MarketProfileDetails> createState() => _MarketProfileDetailsState();
}

class _MarketProfileDetailsState extends State<MarketProfileDetails>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProducts();
    });
  }

  void _loadUserProducts() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      productProvider.loadUserProducts(currentUser.uid);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final currentUser = FirebaseAuth.instance.currentUser;
    final userProvider = Provider.of<UserProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ملفي الشخصي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: [
                  Tab(icon: const Icon(Icons.person_outline), text: 'معلوماتي'),
                  Tab(
                    icon: const Icon(Icons.shopping_bag_outlined),
                    text: 'منتجاتي',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(context, userProvider),
            _buildMyProductsTab(currentUser),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, UserProvider userProvider) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: isTablet ? 80 : 60,
                backgroundImage: _getProfileImage(
                  userProvider.user.profileImage,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userProvider.user.name ?? 'مستخدم',
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userProvider.user.profession ?? 'لا توجد مهنة',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'مستخدم منذ ${_formatDate(userProvider.user.createdAt)}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.phone,
                    userProvider.user.phone ?? 'غير محدد',
                  ),
                  const Divider(),
                  _buildInfoRow(
                    Icons.email,
                    userProvider.user.email ?? 'غير محدد',
                  ),
                  const Divider(),
                  _buildInfoRow(
                    Icons.location_on,
                    userProvider.user.displayAddress,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'إحصائياتي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              final myProducts = productProvider.userProducts;
              final availableCount = myProducts
                  .where((p) => p.isAvailable)
                  .length;
              final soldCount = myProducts.where((p) => p.isSoldOut).length;
              final totalViews = myProducts.fold(0, (sum, p) => sum + p.views);
              final avgRating = myProducts.isEmpty
                  ? 0.0
                  : myProducts.fold(0.0, (sum, p) => sum + p.rating) /
                        myProducts.length;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    Icons.shopping_bag,
                    'منتجات',
                    '${myProducts.length}',
                  ),
                  _buildStatItem(
                    context,
                    Icons.visibility,
                    'مشاهدات',
                    '$totalViews',
                  ),
                  _buildStatItem(
                    context,
                    Icons.star,
                    'تقييم',
                    avgRating.toStringAsFixed(1),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              final myProducts = productProvider.userProducts;
              final availableCount = myProducts
                  .where((p) => p.isAvailable)
                  .length;
              final soldCount = myProducts.where((p) => p.isSoldOut).length;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    Icons.check_circle,
                    'متوفر',
                    '$availableCount',
                    color: Colors.green,
                  ),
                  _buildStatItem(
                    context,
                    Icons.sell,
                    'مباع',
                    '$soldCount',
                    color: Colors.red,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyProductsTab(User? currentUser) {
    if (currentUser == null) {
      return const Center(child: Text('الرجاء تسجيل الدخول لعرض منتجاتك'));
    }

    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading && productProvider.userProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final myProducts = productProvider.userProducts;

        if (myProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد منتجات',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'انقر على زر + لإضافة منتج جديد',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/add_product');
                  },
                  child: const Text('إضافة منتج'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            productProvider.loadUserProducts(currentUser.uid);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: myProducts.length,
            itemBuilder: (context, index) {
              final product = myProducts[index];
              return _buildProductCard(product, productProvider);
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, ProductProvider provider) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildProductImage(
                      product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : 'assets/images/default_product.png',
                    ),
                  ),
                  if (product.isSoldOut)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: Text(
                          'مباع',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!product.isAvailable && !product.isSoldOut)
                    Container(
                      color: Colors.orange.withOpacity(0.7),
                      child: const Center(
                        child: Text(
                          'محجوز',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price} ج.م',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${product.views}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProductScreen(product: product),
                            ),
                          ).then((_) {
                            provider.loadUserProducts(product.sellerId);
                          });
                        },
                      ),
                      // ⭐⭐ زر تبديل الحالة (متوفر/مباع) - معدل
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        onPressed: () =>
                            _showToggleStatusDialog(context, product, provider),
                        child: Text(
                          product.isAvailable ? 'تمييز كمباع' : 'تمييز كمتوفر',
                          style: TextStyle(
                            color: product.isAvailable
                                ? Colors.green
                                : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐⭐ دالة عرض حوار تبديل الحالة
  void _showToggleStatusDialog(
    BuildContext context,
    Product product,
    ProductProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            product.isAvailable ? 'تمييز المنتج كمباع' : 'إعادة المنتج كمتوفر',
          ),
          content: Text(
            product.isAvailable
                ? 'هل أنت متأكد من تمييز هذا المنتج كمباع؟'
                : 'هل أنت متأكد من إعادة هذا المنتج كمتوفر؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: product.isAvailable
                    ? Colors.red
                    : Colors.green,
              ),
              onPressed: () async {
                Navigator.pop(context);
                if (product.isAvailable) {
                  await provider.markAsSold(product.id);
                } else {
                  await provider.markAsAvailable(product.id);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        product.isAvailable
                            ? 'تم تمييز المنتج كمباع'
                            : 'تم إعادة المنتج كمتوفر',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(product.isAvailable ? 'تمييز كمباع' : 'تمييز كمتوفر'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            ),
          );
        },
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1) ?? Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.blue),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(title, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  ImageProvider _getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const AssetImage('assets/images/user_profile.png');
    }
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return FileImage(File(imagePath));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير معروف';
    return '${date.year}/${date.month}/${date.day}';
  }
}
