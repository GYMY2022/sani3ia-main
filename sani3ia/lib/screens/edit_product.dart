import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/user_provider.dart';
import 'location_picker_screen.dart';
import '../models/location_model.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late Product _product;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _discountController;

  String? _selectedCategory;
  List<File> _newImages = [];
  List<String> _existingImages = [];
  List<String> _deletedImages = [];

  bool _isLoading = false;

  UserLocation? _productLocation;

  // ⭐ إضافة "عام" إلى قائمة التصنيفات
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
    _product = widget.product;
    _existingImages = List.from(_product.imageUrls);

    _titleController = TextEditingController(text: _product.title);
    _descriptionController = TextEditingController(text: _product.description);
    _priceController = TextEditingController(text: _product.price.toString());
    _originalPriceController = TextEditingController(
      text: _product.originalPrice?.toString() ?? '',
    );
    _discountController = TextEditingController(
      text: _product.discount?.toString() ?? '',
    );

    // التحقق من أن قيمة التصنيف موجودة في القائمة، وإلا نضعها على أول عنصر (مثلاً 'عام')
    if (_categories.contains(_product.category)) {
      _selectedCategory = _product.category;
    } else {
      _selectedCategory = _categories.first; // نختار أول عنصر وهو 'عام'
      print(
        '⚠️ التصنيف "${_product.category}" غير موجود، تم التعيين إلى "${_categories.first}"',
      );
    }

    if (_product.hasGeoLocation) {
      _productLocation = UserLocation(
        id: '',
        userId: _product.sellerId,
        latitude: _product.latitude!,
        longitude: _product.longitude!,
        address: _product.fullAddress ?? _product.location,
        city: '',
        country: '',
        timestamp: DateTime.now(),
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

  Future<void> _pickNewImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _newImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _deletedImages.add(_existingImages[index]);
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
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
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('الرجاء إدخال عنوان المنتج');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('الرجاء إدخال وصف المنتج');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showError('الرجاء إدخال السعر');
      return;
    }
    if (_existingImages.isEmpty && _newImages.isEmpty) {
      _showError('الرجاء إضافة صورة واحدة على الأقل');
      return;
    }
    if (_selectedCategory == null) {
      _showError('الرجاء اختيار التصنيف');
      return;
    }

    setState(() => _isLoading = true);

    try {
      double price = double.parse(_priceController.text);
      double? originalPrice;
      int? discount;
      if (_originalPriceController.text.isNotEmpty) {
        originalPrice = double.parse(_originalPriceController.text);
        if (originalPrice > price) {
          discount = ((originalPrice - price) / originalPrice * 100).round();
        }
      }

      final allImages = [..._existingImages];

      double? latitude = _productLocation?.latitude;
      double? longitude = _productLocation?.longitude;
      String? fullAddress = _productLocation?.address;

      final updatedProduct = _product.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        originalPrice: originalPrice,
        imageUrls: allImages,
        category: _selectedCategory!,
        location: fullAddress ?? _product.location,
        discount: discount,
        updatedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        fullAddress: fullAddress,
      );

      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      await productProvider.updateProductWithImages(
        product: updatedProduct,
        newImageFiles: _newImages,
        deletedImages: _deletedImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المنتج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError('فشل في تحديث المنتج: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل المنتج'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'صور المنتج *',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImages.length + _newImages.length + 1,
                      itemBuilder: (context, index) {
                        if (index ==
                            _existingImages.length + _newImages.length) {
                          return _buildAddImageButton();
                        }
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
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الموقع الجغرافي',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
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
                            _productLocation?.address ?? _product.location,
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
                        'تحديث المنتج',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
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
        onTap: _pickNewImages,
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
    bool isNewImage = index >= _existingImages.length;
    int imageIndex = isNewImage ? index - _existingImages.length : index;

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isNewImage
                ? Image.file(
                    _newImages[imageIndex],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    _existingImages[imageIndex],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => isNewImage
                  ? _removeNewImage(imageIndex)
                  : _removeExistingImage(imageIndex),
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
          if (!isNewImage)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}
