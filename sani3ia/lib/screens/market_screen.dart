import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import 'product_details.dart';
import 'add_product_to_market.dart';
import 'market_profile_details.dart';
import 'single_chat_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  late TabController _tabController;

  // إعدادات الفلترة الجديدة
  double _minPrice = 0;
  double _maxPrice = 50000;
  String _sortBy = 'الأحدث';
  bool _sortByDistance = true; // مفعل دائماً

  // متغيرات للتحكم في عرض الفلتر
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  final List<Category> _categories = [
    Category('الكل', Icons.all_inclusive),
    Category('أجهزة إلكترونية', Icons.electrical_services),
    Category('أثاث منزل', Icons.chair),
    Category('ملابس', Icons.checkroom),
    Category('سيارات', Icons.directions_car),
    Category('عقارات', Icons.home),
    Category('أدوات', Icons.build),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // تهيئة controllers بالقيم الافتراضية
    _minPriceController.text = _minPrice.toInt().toString();
    _maxPriceController.text = _maxPrice.toInt().toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      productProvider.loadAllProducts();
      productProvider.loadFavoriteProducts();
      productProvider.updateUserLocation(); // لتحديث موقع المستخدم
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts(List<Product> products) {
    List<Product> filtered = products.where((product) {
      final matchesCategory =
          _selectedCategoryIndex == 0 ||
          product.category == _categories[_selectedCategoryIndex].name;
      final matchesSearch =
          _searchQuery.isEmpty ||
          product.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      final matchesPrice =
          product.price >= _minPrice && product.price <= _maxPrice;
      final matchesAvailability = product.isAvailable;

      return matchesCategory &&
          matchesSearch &&
          matchesPrice &&
          matchesAvailability;
    }).toList();

    // الترتيب حسب المسافة (الأقرب أولاً) - مفعل دائماً
    if (_sortByDistance) {
      filtered.sort((a, b) {
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });
    } else {
      // في حالة عدم توفر الموقع، نستخدم الترتيب الافتراضي (الأحدث)
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'السوق',
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt),
                SizedBox(width: screenSize.width * 0.01),
                Text('فلتر', style: TextStyle(fontSize: isTablet ? 18 : 14)),
              ],
            ),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.person, size: isTablet ? 28 : 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MarketProfileDetails(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontSize: isTablet ? 16 : 14),
          tabs: [
            Tab(
              icon: Icon(Icons.shopping_bag, size: isTablet ? 28 : 24),
              text: 'المنتجات',
            ),
            Tab(
              icon: Icon(Icons.favorite, size: isTablet ? 28 : 24),
              text: 'المفضلة',
            ),
          ],
        ),
      ),
      floatingActionButton: currentUser != null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductToMarket(),
                  ),
                );
              },
              child: Icon(Icons.add, size: isTablet ? 32 : 28),
            )
          : null,
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: EdgeInsets.all(screenSize.width * 0.03),
            child: SearchBar(
              controller: _searchController,
              hintText: 'ابحث عن منتجات...',
              textStyle: WidgetStateProperty.all(
                TextStyle(fontSize: isTablet ? 18 : 16),
              ),
              hintStyle: WidgetStateProperty.all(
                TextStyle(fontSize: isTablet ? 18 : 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
              trailing: [
                IconButton(
                  icon: Icon(Icons.search, size: isTablet ? 28 : 24),
                  onPressed: () => FocusScope.of(context).unfocus(),
                ),
              ],
            ),
          ),

          // قائمة الفئات
          Container(
            height: isTablet ? 80 : 60,
            margin: EdgeInsets.symmetric(vertical: screenSize.height * 0.01),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.02,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(
                    right: index == 0 ? 0 : screenSize.width * 0.02,
                    left: index == _categories.length - 1
                        ? 0
                        : screenSize.width * 0.015,
                  ),
                  child: FilterChip(
                    label: Text(
                      _categories[index].name,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedCategoryIndex == index
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    selected: _selectedCategoryIndex == index,
                    onSelected: (selected) => setState(() {
                      _selectedCategoryIndex = selected ? index : 0;
                    }),
                    selectedColor: Theme.of(context).primaryColor,
                    backgroundColor: Colors.grey[100],
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: _selectedCategoryIndex == index
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                    avatar: Icon(
                      _categories[index].icon,
                      size: isTablet ? 22 : 18,
                      color: _selectedCategoryIndex == index
                          ? Colors.white70
                          : Colors.black54,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: isTablet ? 12 : 8,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),

          // قائمة المنتجات
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading &&
                    productProvider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductsGrid(
                      _filteredProducts(productProvider.products),
                      productProvider,
                    ),
                    productProvider.favoriteProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: isTablet ? 80 : 60,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: screenSize.height * 0.02),
                                Text(
                                  'لا توجد منتجات في المفضلة بعد',
                                  style: TextStyle(
                                    fontSize: isTablet ? 20 : 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'اضغط على ♡ لإضافة منتج للمفضلة',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildProductsGrid(
                            _filteredProducts(productProvider.favoriteProducts),
                            productProvider,
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<Product> products, ProductProvider provider) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final crossAxisCount = isTablet ? 3 : 2;

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: isTablet ? 80 : 60,
              color: Colors.grey,
            ),
            SizedBox(height: screenSize.height * 0.02),
            Text(
              _searchQuery.isEmpty && _selectedCategoryIndex == 0
                  ? 'لا توجد منتجات حالياً'
                  : 'لا توجد منتجات متطابقة مع بحثك',
              style: TextStyle(
                fontSize: isTablet ? 20 : 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(screenSize.width * 0.02),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: screenSize.width * 0.02,
        mainAxisSpacing: screenSize.width * 0.02,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          _buildProductCard(products[index], provider),
    );
  }

  Widget _buildProductCard(Product product, ProductProvider provider) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyProduct =
        currentUser != null && product.sellerId == currentUser.uid;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxWidth * (isTablet ? 1.3 : 1.5);

        return GestureDetector(
          onTap: () async {
            if (currentUser != null) {
              await provider.incrementViewsIfNotViewed(
                product.id,
                currentUser.uid,
              );
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(product: product),
              ),
            );
          },
          child: Card(
            key: ValueKey('${product.id}_${product.isFavorite}'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: isTablet ? 6 : 4,
            child: SizedBox(
              height: cardHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 55,
                    child: Stack(
                      children: [
                        _buildProductImage(
                          product.imageUrls.isNotEmpty
                              ? product.imageUrls.first
                              : 'assets/images/default_product.png',
                        ),
                        if (product.distance != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                product.distance! < 1
                                    ? '${(product.distance! * 1000).toStringAsFixed(0)} متر'
                                    : '${product.distance!.toStringAsFixed(1)} كم',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (!product.isAvailable)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: product.isSoldOut
                                    ? Colors.red
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                product.isSoldOut ? 'مباع' : 'محجوز',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (product.discount != null && product.isAvailable)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${product.discount}% خصم',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (isMyProduct)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'منشورك',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (currentUser != null && !isMyProduct)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: 20,
                                icon: Icon(
                                  product.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: product.isFavorite
                                      ? Colors.red
                                      : Colors.white,
                                ),
                                onPressed: () =>
                                    provider.toggleFavorite(product),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 45,
                    child: Padding(
                      padding: EdgeInsets.all(screenSize.width * 0.02),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            product.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 16 : 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${product.price} ج.م',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: isTablet ? 18 : 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (product.originalPrice != null)
                                Text(
                                  '${product.originalPrice} ج.م',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: isTablet ? 14 : 11,
                                  ),
                                  maxLines: 1,
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: isTablet ? 18 : 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                product.rating.toStringAsFixed(1),
                                style: TextStyle(fontSize: isTablet ? 14 : 11),
                                maxLines: 1,
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.remove_red_eye,
                                size: isTablet ? 16 : 12,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 2),
                              Text(
                                '${product.views}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isTablet ? 14 : 11,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: isTablet ? 12 : 10,
                                backgroundImage: _getImageProvider(
                                  product.sellerImage,
                                ),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  product.sellerName,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: isTablet ? 14 : 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ فشل تحميل الصورة: $imageUrl, خطأ: $error');
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ فشل تحميل الصورة asset: $imageUrl');
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            ),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image, color: Colors.grey, size: 40),
        ),
      );
    }
  }

  void _openChatWithSeller(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SingleChatScreen(
          userName: product.sellerName,
          userImage: product.sellerImage,
          receiverId: product.sellerId,
          isOnline: true,
          postId: product.id,
          chatType: 'product',
          isFromProductQuery: true,
          initialMessage: 'هل هذا المنتج "${product.title}" متوفر؟',
        ),
      ),
    ).then((_) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      productProvider.loadAllProducts();
    });
  }

  // ⭐ دالة الفلتر الجديدة
  void _showFilterDialog(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    // نسخ القيم الحالية إلى الـ controllers
    _minPriceController.text = _minPrice.toInt().toString();
    _maxPriceController.text = _maxPrice.toInt().toString();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'تصفية المنتجات',
                style: TextStyle(fontSize: isTablet ? 24 : 20),
              ),
              content: SizedBox(
                width: isTablet
                    ? screenSize.width * 0.6
                    : screenSize.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نطاق السعر
                      const Text(
                        'نطاق السعر:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الحد الأدنى',
                                border: OutlineInputBorder(),
                                prefixText: 'ج.م ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الحد الأقصى',
                                border: OutlineInputBorder(),
                                prefixText: 'ج.م ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ملاحظة: تم إزالة خانة الموقع والتقييم
                      const Text(
                        'سيتم عرض المنتجات مرتبة حسب الأقرب إلى موقعك.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // إعادة تعيين الفلتر إلى القيم الافتراضية
                    setState(() {
                      _minPriceController.text = '0';
                      _maxPriceController.text = '50000';
                    });
                  },
                  child: Text(
                    'إعادة تعيين',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // تطبيق الفلتر
                    final newMin =
                        double.tryParse(_minPriceController.text) ?? 0;
                    final newMax =
                        double.tryParse(_maxPriceController.text) ?? 50000;

                    // التأكد من أن الحد الأدنى <= الحد الأقصى
                    final min = newMin <= newMax ? newMin : newMax;
                    final max = newMin <= newMax ? newMax : newMin;

                    this.setState(() {
                      _minPrice = min;
                      _maxPrice = max;
                    });

                    Navigator.pop(context);
                  },
                  child: Text(
                    'تطبيق',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    if (imagePath.startsWith('assets/')) return AssetImage(imagePath);
    return const AssetImage('assets/images/default_profile.png');
  }
}

class Category {
  final String name;
  final IconData icon;
  Category(this.name, this.icon);
}
