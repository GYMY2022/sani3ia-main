import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import 'single_chat_screen.dart';
import 'edit_product.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  late Product _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final productProvider = Provider.of<ProductProvider>(
          context,
          listen: false,
        );
        productProvider.incrementViewsIfNotViewed(_product.id, currentUser.uid);
      }
    });
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SingleChatScreen(
          userName: _product.sellerName,
          userImage: _product.sellerImage,
          receiverId: _product.sellerId,
          isOnline: true,
          postId: _product.id,
          chatType: 'product',
          isFromProductQuery: true,
          initialMessage: 'هل هذا المنتج "${_product.title}" متوفر؟',
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

  void _toggleFavorite() {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    productProvider.toggleFavorite(_product);
    setState(() => _product.isFavorite = !_product.isFavorite);
  }

  void _editProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: _product),
      ),
    ).then((_) {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      productProvider.loadAllProducts();
    });
  }

  void _deleteProduct() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المنتج'),
          content: const Text('هل أنت متأكد أنك تريد حذف هذا المنتج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final productProvider = Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري حذف المنتج...')),
                  );
                  await productProvider.deleteProduct(_product.id);
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف المنتج بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل في الحذف: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleProductStatus() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            _product.isAvailable ? 'تمييز المنتج كمباع' : 'تمييز المنتج كمتوفر',
          ),
          content: Text(
            _product.isAvailable
                ? 'هل أنت متأكد من تمييز هذا المنتج كمباع؟'
                : 'هل أنت متأكد من إعادة هذا المنتج كمتوفر؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final productProvider = Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  );
                  if (_product.isAvailable)
                    await productProvider.markAsSold(_product.id);
                  else
                    await productProvider.markAsAvailable(_product.id);
                  setState(() {
                    _product = _product.copyWith(
                      status: _product.isAvailable ? 'sold' : 'available',
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _product.isAvailable
                            ? 'تم تمييز المنتج كمباع'
                            : 'تم إعادة المنتج كمتوفر',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _product.isAvailable
                    ? Colors.red
                    : Colors.green,
              ),
              child: Text(
                _product.isAvailable ? 'تمييز كمباع' : 'تمييز كمتوفر',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap() async {
    if (_product.hasGeoLocation) {
      final url =
          'https://www.google.com/maps/search/?api=1&query=${_product.latitude},${_product.longitude}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح الخريطة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المنتج لا يحتوي على موقع محدد'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyProduct =
        currentUser != null && _product.sellerId == currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        actions: [
          if (isMyProduct) ...[
            IconButton(icon: const Icon(Icons.edit), onPressed: _editProduct),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteProduct,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _product.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _product.isFavorite ? Colors.red : null,
              ),
              onPressed: _toggleFavorite,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: _product.imageUrls.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemBuilder: (context, i) =>
                        _buildProductImage(_product.imageUrls[i]),
                  ),
                  if (!_product.isAvailable)
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _product.isSoldOut
                              ? Colors.red
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _product.isSoldOut ? 'مباع' : 'محجوز',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _product.imageUrls.length,
                        (i) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == i
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _product.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.remove_red_eye,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text('${_product.views}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_product.price} ج.م',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      if (_product.originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${_product.originalPrice} ج.م',
                          style: const TextStyle(
                            fontSize: 18,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      if (_product.discount != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_product.discount}% خصم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'الوصف',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _product.description,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'معلومات البائع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: _getImageProvider(_product.sellerImage),
                    ),
                    title: Text(_product.sellerName),
                    subtitle: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[400], size: 16),
                        const SizedBox(width: 4),
                        Text(_product.rating.toStringAsFixed(1)),
                        const SizedBox(width: 8),
                        Text(
                          '(${_product.reviewCount} تقييم)',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: !isMyProduct && currentUser != null
                        ? IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green),
                            onPressed: _navigateToChat,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'الموقع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(_product.fullAddress ?? _product.location),
                    subtitle: _product.hasGeoLocation
                        ? Text(
                            '${_product.latitude?.toStringAsFixed(6)}, ${_product.longitude?.toStringAsFixed(6)}',
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: _openMap,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'التصنيف',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_product.category),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isMyProduct && currentUser != null
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _navigateToChat,
                child: const Text(
                  'تواصل مع البائع',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          : isMyProduct
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: _product.isAvailable
                      ? Colors.green
                      : Colors.red,
                ),
                onPressed: _toggleProductStatus,
                child: Text(
                  _product.isAvailable ? 'تمييز كمباع' : 'تمييز كمتوفر',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.error, size: 50, color: Colors.grey),
        ),
      );
    } else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
    } else {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    if (imagePath.startsWith('assets/')) return AssetImage(imagePath);
    return const AssetImage('assets/images/default_profile.png');
  }
}
