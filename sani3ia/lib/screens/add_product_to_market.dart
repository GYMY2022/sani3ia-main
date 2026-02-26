import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/user_provider.dart';
import 'location_picker_screen.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../services/notification_helper.dart'; // ⭐ إضافة

class AddProductToMarket extends StatefulWidget {
  const AddProductToMarket({super.key});

  @override
  State<AddProductToMarket> createState() => _AddProductToMarketState();
}

class _AddProductToMarketState extends State<AddProductToMarket> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  String? _selectedCategory;
  List<File> _selectedImages = [];
  bool _isLoading = false;

  UserLocation? _productLocation;
  bool _isLocationLoading = false;

  final List<String> _categories = [
    'عام',
    'أجهزة إلكترونية',
    'أثاث منزل',
    'ملابس',
    'سيارات',
    'عقارات',
    'أدوات',
    'كتب',
    'ألعاب',
    'رياضة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.user.hasGeoLocation) {
        setState(() {
          _productLocation = UserLocation(
            id: '',
            userId: userProvider.user.id ?? '',
            latitude: userProvider.user.latitude!,
            longitude: userProvider.user.longitude!,
            address: userProvider.user.displayAddress,
            city: '',
            country: '',
            timestamp: DateTime.now(),
          );
        });
        print('📍 تم تحميل موقع المستخدم تلقائياً');
      } else {
        final locationService = LocationService();
        final location = await locationService.getCurrentLocation();
        setState(() {
          _productLocation = location;
        });
        print('📍 تم الحصول على موقع المستخدم الحالي');
      }
    } catch (e) {
      print('⚠️ لا يمكن الحصول على موقع المستخدم: $e');
    } finally {
      setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _pickLocation() async {
    final UserLocation? selectedLocation = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(isRegistration: true),
      ),
    );
    if (selectedLocation != null && mounted) {
      setState(() => _productLocation = selectedLocation);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث موقع المنتج'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // دالة مساعدة لجلب المستخدمين المهتمين بهذا التصنيف (يمكن تطويرها لاحقاً)
  Future<List<String>> _getInterestedUsers(String category) async {
    // مثال بسيط: نرجع قائمة فارغة حالياً
    // يمكنك لاحقاً إضافة منطق حقيقي (مثلاً جلب المستخدمين الذين تابعوا هذا التصنيف)
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إضافة صورة واحدة على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('يجب تسجيل الدخول أولاً');

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userName = userProvider.user.name ?? 'مستخدم';
      final userImage =
          userProvider.user.profileImage ?? 'assets/images/default_profile.png';

      double? latitude;
      double? longitude;
      String? fullAddress;

      if (_productLocation != null) {
        latitude = _productLocation!.latitude;
        longitude = _productLocation!.longitude;
        fullAddress = _productLocation!.address;
      }

      double price = double.parse(_priceController.text);
      double? originalPrice;
      int? discount;
      if (_originalPriceController.text.isNotEmpty) {
        originalPrice = double.parse(_originalPriceController.text);
        if (originalPrice > price) {
          discount = ((originalPrice - price) / originalPrice * 100).round();
        }
      }

      final product = Product(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        originalPrice: originalPrice,
        imageUrls: [],
        category: _selectedCategory!,
        location: fullAddress ?? 'موقع غير محدد',
        sellerId: currentUser.uid,
        sellerName: userName,
        sellerImage: userImage,
        rating: 0,
        createdAt: DateTime.now(),
        discount: discount,
        latitude: latitude,
        longitude: longitude,
        fullAddress: fullAddress,
      );

      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      await productProvider.addProduct(product, imageFiles: _selectedImages);

      // ⭐ إرسال إشعار للمستخدمين المهتمين بهذا التصنيف
      final interestedUsers = await _getInterestedUsers(product.category);
      if (interestedUsers.isNotEmpty) {
        NotificationHelper.sendNewProductAddedNotification(
          product: product,
          interestedUserIds: interestedUsers,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المنتج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة المنتج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة منتج جديد'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'صور المنتج *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _selectedImages.length)
                            return _buildAddImageButton();
                          return _buildImageTile(index);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان المنتج *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'الرجاء إدخال عنوان المنتج'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'وصف المنتج *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) => value == null || value.isEmpty
                          ? 'الرجاء إدخال وصف المنتج'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'السعر *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'الرجاء إدخال السعر';
                              if (double.tryParse(value) == null)
                                return 'الرجاء إدخال رقم صحيح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _originalPriceController,
                            decoration: const InputDecoration(
                              labelText: 'السعر قبل الخصم',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                      validator: (value) =>
                          value == null ? 'الرجاء اختيار التصنيف' : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'الموقع الجغرافي',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLocationLoading)
                      const LinearProgressIndicator()
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _productLocation?.address ??
                                    'لم يتم تحديد موقع بعد',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: _pickLocation,
                              tooltip: 'تغيير الموقع',
                            ),
                          ],
                        ),
                      ),
                      if (_productLocation == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: _pickLocation,
                            icon: const Icon(Icons.add_location),
                            label: const Text('إضافة موقع'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text(
                          'إضافة المنتج',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAddImageButton() {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('اختيار من المعرض'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('التقاط صورة'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
            SizedBox(height: 4),
            Text('إضافة صور', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(int index) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImages[index],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
