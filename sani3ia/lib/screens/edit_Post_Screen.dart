import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/providers/post_provider.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  String? _selectedCategory;
  final List<File> _selectedImages = [];
  final List<String> _existingImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'سباكة', 'icon': Icons.plumbing},
    {'name': 'كهرباء', 'icon': Icons.electrical_services},
    {'name': 'نجارة', 'icon': Icons.carpenter},
    {'name': 'دهان', 'icon': Icons.format_paint},
    {'name': 'بناء', 'icon': Icons.construction},
    {'name': 'تكييفات', 'icon': Icons.ac_unit},
  ];

  @override
  void initState() {
    super.initState();
    // تهيئة البيانات الحالية للبوست
    _titleController = TextEditingController(text: widget.post.title);
    _descriptionController = TextEditingController(
      text: widget.post.description,
    );
    _priceController = TextEditingController(
      text: widget.post.budget.toInt().toString(),
    );
    _locationController = TextEditingController(text: widget.post.location);
    _selectedCategory = widget.post.category;
    _existingImages.addAll(widget.post.images);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedImage = await _picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        _selectedImages.add(File(pickedImage.path));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر مصدر الصورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('الكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      // طباعة معلومات التصحيح
      print('🔄 بدء تحديث البوست...');
      print('📸 الصور الحالية: ${_existingImages.length}');
      print('📸 الصور الجديدة: ${_selectedImages.length}');
      print('🗑️ الصور المحذوفة: ${_getDeletedImages().length}');

      // إنشاء كائن البوست المحدث
      final updatedPost = Post(
        id: widget.post.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: _existingImages, // الصور الحالية المتبقية
        type: widget.post.type,
        category: _selectedCategory!,
        date: DateTime.now(), // تحديث التاريخ
        authorId: user.uid,
        authorName: user.displayName ?? 'مستخدم',
        authorImage: user.photoURL ?? 'assets/images/default_profile.png',
        location: _locationController.text.trim(),
        budget: double.parse(_priceController.text),
        status: widget.post.status,
        createdAt: widget.post.createdAt,
        views: widget.post.views,
        applications: widget.post.applications,
      );

      // تحديث البوست
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      // ✅ التصحيح: استخدام updatePostWithImages مباشرة
      await postProvider.updatePostWithImages(
        post: updatedPost,
        newImageFiles: _selectedImages, // الصور الجديدة
        deletedImages: _getDeletedImages(), // الصور المحذوفة
      );

      // إظهار رسالة النجاح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الشغلانة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // العودة للشاشة السابقة
      Navigator.pop(context);
    } catch (e) {
      print('❌ خطأ في تحديث البوست: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديث الشغلانة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  List<String> _getDeletedImages() {
    final originalImages = widget.post.images;
    final deletedImages = <String>[];

    for (final originalImage in originalImages) {
      if (!_existingImages.contains(originalImage)) {
        deletedImages.add(originalImage);
        print('🗑️ سيتم حذف الصورة: $originalImage');
      }
    }

    print('📊 إحصائيات الحذف: ${deletedImages.length} صورة');
    return deletedImages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الشغلانة'),
        backgroundColor: const Color(0xFF00A8E8),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _updatePost,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // معرض الصور الحالية
                        if (_existingImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الصور الحالية:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 150,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _existingImages.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image(
                                              image: _getImageProvider(
                                                _existingImages[index],
                                              ),
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      width: 150,
                                                      height: 150,
                                                      color: Colors.grey[200],
                                                      child: const Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons.error,
                                                            color: Colors.grey,
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'خطأ في الصورة',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _removeExistingImage(index),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // معرض الصور الجديدة
                        if (_selectedImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الصور الجديدة:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 150,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.file(
                                              _selectedImages[index],
                                              width: 150,
                                              height: 150,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _removeNewImage(index),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // زر إضافة الصور
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF00A8E8),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Color(0xFF00A8E8),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'إضافة صور جديدة (اختياري)',
                                  style: TextStyle(
                                    color: Color(0xFF00A8E8),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // باقي الحقول
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'عنوان الشغلانة',
                            prefixIcon: Icon(
                              Icons.title,
                              color: const Color(0xFF00A8E8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF00A8E8),
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'من فضلك أدخل العنوان';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'التخصص',
                            prefixIcon: Icon(
                              Icons.category,
                              color: const Color(0xFF00A8E8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF00A8E8),
                              ),
                            ),
                          ),
                          items: _categories.map<DropdownMenuItem<String>>((
                            category,
                          ) {
                            return DropdownMenuItem<String>(
                              value: category['name'],
                              child: Row(
                                children: [
                                  Icon(
                                    category['icon'],
                                    color: const Color(0xFF00A8E8),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(category['name']),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'من فضلك اختر التخصص';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: 'الموقع',
                            prefixIcon: Icon(
                              Icons.location_on,
                              color: const Color(0xFF00A8E8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF00A8E8),
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'من فضلك أدخل الموقع';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'وصف المشكلة',
                            prefixIcon: Icon(
                              Icons.description,
                              color: const Color(0xFF00A8E8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF00A8E8),
                              ),
                            ),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'من فضلك أدخل الوصف';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: 'السعر المتوقع (جنيه)',
                            prefixIcon: Icon(
                              Icons.attach_money,
                              color: const Color(0xFF00A8E8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF00A8E8),
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'من فضلك أدخل السعر';
                            }
                            if (double.tryParse(value) == null) {
                              return 'من فضلك أدخل سعراً صحيحاً';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _updatePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A8E8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'حفظ التعديلات',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return const AssetImage('assets/images/default_job_1.png');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
