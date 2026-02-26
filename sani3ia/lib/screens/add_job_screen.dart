import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/services/location_service.dart';
import 'package:snae3ya/services/image_upload_service.dart';
import 'package:snae3ya/services/notification_helper.dart'; // ⭐ إضافة

class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isLocationLoading = false;
  String _userAddress = '';
  Map<String, dynamic>? _userGeoLocation;

  // متغيرات لتحسين تجربة رفع الصور
  bool _isUploadingImages = false;
  String _uploadProgress = '';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserLocation();
    });
  }

  Future<void> _loadUserLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (userProvider.hasUserData && userProvider.user.hasGeoLocation) {
        setState(() {
          _userAddress = userProvider.user.displayAddress;
          _userGeoLocation = {
            'latitude': userProvider.user.latitude,
            'longitude': userProvider.user.longitude,
            'fullAddress': userProvider.user.fullAddress,
          };
        });
        print('📍 تم تحميل موقع المستخدم من UserProvider: $_userAddress');
      } else {
        final locationService = LocationService();
        final location = await locationService.getCurrentLocation();

        setState(() {
          _userAddress = location.address;
          _userGeoLocation = {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'fullAddress': location.address,
          };
        });
        print('📍 تم تحميل موقع المستخدم من LocationService: $_userAddress');
      }
    } catch (e) {
      print('❌ فشل في تحميل موقع المستخدم: $e');
      setState(() {
        _userAddress = 'تعذر تحديد الموقع';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديد موقعك. يرجى التحقق من صلاحيات الموقع.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _refreshLocation() async {
    await _loadUserLocation();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSubmitting || _isUploadingImages) return;

    final pickedImage = await _picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        _selectedImages.add(File(pickedImage.path));
      });
    }
  }

  void _removeImage(int index) {
    if (_isSubmitting || _isUploadingImages) return;

    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    if (_isSubmitting || _isUploadingImages) return;

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

  // دالة لاختبار الاتصال بـ Supabase قبل رفع الصور
  Future<bool> _testSupabaseConnection() async {
    try {
      final imageUploadService = ImageUploadService();
      return await imageUploadService.testStorageConnection();
    } catch (e) {
      print('❌ فشل اختبار الاتصال بـ Supabase: $e');
      return false;
    }
  }

  // دالة محسنة لرفع الصور مع مؤشر تقدم
  Future<List<String>> _uploadImagesWithProgress() async {
    if (_selectedImages.isEmpty) {
      return [];
    }

    setState(() {
      _isUploadingImages = true;
      _uploadProgress = 'جاري رفع الصور...';
    });

    try {
      final imageUploadService = ImageUploadService();
      final List<String> uploadedUrls = [];

      for (int i = 0; i < _selectedImages.length; i++) {
        setState(() {
          _uploadProgress =
              'جاري رفع الصورة ${i + 1} من ${_selectedImages.length}';
        });

        final imageFile = _selectedImages[i];

        // التحقق من حجم الصورة
        final fileSize = await imageFile.length();
        if (fileSize > 10 * 1024 * 1024) {
          // 10 MB
          throw Exception('حجم الصورة كبير جداً (أقصى حد 10 ميجابايت)');
        }

        final imageUrl = await imageUploadService.uploadImage(
          imageFile,
          folderName: 'posts/${DateTime.now().year}/${DateTime.now().month}',
        );

        if (imageUrl != null && imageUrl.isNotEmpty) {
          uploadedUrls.add(imageUrl);
          print('✅ تم رفع الصورة ${i + 1}: $imageUrl');
        } else {
          throw Exception('فشل في رفع الصورة ${i + 1}');
        }
      }

      return uploadedUrls;
    } catch (e) {
      print('❌ خطأ في رفع الصور: $e');
      rethrow;
    } finally {
      setState(() {
        _isUploadingImages = false;
        _uploadProgress = '';
      });
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userGeoLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم تحديد موقعك بعد. يرجى الانتظار أو تحديث الموقع.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      // ⭐⭐ التحقق من وجود bucket 'posts' أولاً
      final imageUploadService = ImageUploadService();
      final bucketExists = await imageUploadService.ensureBucketExists();

      if (!bucketExists && _selectedImages.isNotEmpty) {
        // إظهار رسالة خطأ للمستخدم
        final shouldContinue = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('خطأ في التخزين'),
            content: const Text(
              'لم يتم العثور على bucket "posts" في Supabase Storage.\n\n'
              'يرجى إنشاؤه يدوياً من خلال:\n'
              '1. الذهاب إلى Supabase Dashboard\n'
              '2. Storage > Create bucket\n'
              '3. الاسم: posts\n'
              '4. تفعيل Public bucket\n\n'
              'هل تريد المتابعة بدون صور؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('متابعة بدون صور'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // اختبار الاتصال بـ Supabase قبل البدء
      List<String> imageUrls = [];

      if (_selectedImages.isNotEmpty && bucketExists) {
        final canConnect = await _testSupabaseConnection();

        if (!canConnect) {
          // إظهار خيار للمستخدم
          final shouldContinue = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('مشكلة في الاتصال'),
              content: const Text(
                'لا يمكن الاتصال بخادم الصور حالياً. هل تريد المتابعة بدون صور؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('متابعة بدون صور'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            setState(() => _isSubmitting = false);
            return;
          }
        } else {
          // رفع الصور
          try {
            imageUrls = await _uploadImagesWithProgress();
            print('✅ تم رفع ${imageUrls.length} صورة بنجاح');
          } catch (e) {
            // إذا فشل رفع الصور، نسأل المستخدم إذا كان يريد المتابعة بدون صور
            final shouldContinue = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('فشل في رفع الصور'),
                content: Text('حدث خطأ: $e\n\nهل تريد المتابعة بدون صور؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('متابعة بدون صور'),
                  ),
                ],
              ),
            );

            if (shouldContinue != true) {
              setState(() => _isSubmitting = false);
              return;
            }
          }
        }
      }

      // استخدام الصور الافتراضية فقط إذا لم يتم رفع أي صور
      if (imageUrls.isEmpty) {
        imageUrls = [
          'assets/images/default_job_1.png',
          'assets/images/default_job_2.png',
        ];
        print('🖼️ استخدام الصور الافتراضية');
      }

      // إنشاء كائن البوست
      final newPost = Post(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: imageUrls,
        type: 'customer',
        category: _selectedCategory!,
        date: DateTime.now(),
        authorId: user.uid,
        authorName: user.displayName ?? 'مستخدم',
        authorImage: user.photoURL ?? 'assets/images/default_profile.png',
        location: _userAddress,
        budget: double.parse(_priceController.text),
        status: 'open',
        createdAt: DateTime.now(),
        geoLocation: _userGeoLocation,
      );

      // إضافة البوست
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      await postProvider.addPost(newPost);

      // ⭐ إرسال إشعار للصنايعية في نفس التخصص
      NotificationHelper.sendNewJobPostedNotification(post: newPost);

      // إظهار رسالة النجاح
      if (imageUrls.isNotEmpty && !imageUrls[0].startsWith('assets/')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نشر الشغلانة بنجاح مع ${imageUrls.length} صورة'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر الشغلانة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // العودة للشاشة السابقة
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في نشر الشغلانة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة شغلانة جديدة'),
        backgroundColor: const Color(0xFF00A8E8),
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
                        // عرض الموقع التلقائي
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isLocationLoading
                                ? Colors.grey[100]
                                : (_userGeoLocation != null
                                      ? Colors.green[50]
                                      : Colors.orange[50]),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isLocationLoading
                                  ? Colors.grey
                                  : (_userGeoLocation != null
                                        ? Colors.green
                                        : Colors.orange),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_isLocationLoading)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  _userGeoLocation != null
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  color: _userGeoLocation != null
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isLocationLoading
                                          ? 'جاري تحديد موقعك...'
                                          : (_userGeoLocation != null
                                                ? 'موقعك الحالي'
                                                : 'لم يتم تحديد الموقع'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isLocationLoading
                                            ? Colors.grey
                                            : (_userGeoLocation != null
                                                  ? Colors.green
                                                  : Colors.orange),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isLocationLoading
                                          ? 'يرجى الانتظار'
                                          : (_userAddress.isNotEmpty
                                                ? _userAddress
                                                : 'اضغط على زر التحديث لتحديد موقعك'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed:
                                    (_isLocationLoading ||
                                        _isSubmitting ||
                                        _isUploadingImages)
                                    ? null
                                    : _refreshLocation,
                                color: Colors.blue,
                                tooltip: 'تحديث الموقع',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // معرض الصور
                        if (_selectedImages.isNotEmpty)
                          Column(
                            children: [
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
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      width: 150,
                                                      height: 150,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        size: 50,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: GestureDetector(
                                              onTap:
                                                  (_isSubmitting ||
                                                      _isUploadingImages)
                                                  ? null
                                                  : () => _removeImage(index),
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

                        // عرض مؤشر تقدم رفع الصور
                        if (_isUploadingImages)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _uploadProgress,
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // زر إضافة الصور
                        GestureDetector(
                          onTap: (_isSubmitting || _isUploadingImages)
                              ? null
                              : _showImageSourceDialog,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (_isSubmitting || _isUploadingImages)
                                    ? Colors.grey
                                    : const Color(0xFF00A8E8),
                                width: 2,
                              ),
                            ),
                            child: Opacity(
                              opacity: (_isSubmitting || _isUploadingImages)
                                  ? 0.5
                                  : 1.0,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 40,
                                    color: (_isSubmitting || _isUploadingImages)
                                        ? Colors.grey
                                        : const Color(0xFF00A8E8),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedImages.isEmpty
                                        ? 'إضافة صور للشغلانة (اختياري)'
                                        : 'إضافة المزيد من الصور',
                                    style: TextStyle(
                                      color:
                                          (_isSubmitting || _isUploadingImages)
                                          ? Colors.grey
                                          : const Color(0xFF00A8E8),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
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
                          enabled: !_isSubmitting && !_isUploadingImages,
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
                          onChanged: (_isSubmitting || _isUploadingImages)
                              ? null
                              : (value) {
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
                          enabled: !_isSubmitting && !_isUploadingImages,
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
                          enabled: !_isSubmitting && !_isUploadingImages,
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
                  onPressed:
                      (_isSubmitting ||
                          _isLocationLoading ||
                          _isUploadingImages)
                      ? null
                      : _submitJob,
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
                      : Text(
                          _isLocationLoading
                              ? 'جاري تحديد الموقع...'
                              : (_isUploadingImages
                                    ? _isUploadingImages
                                          ? 'جاري رفع الصور...'
                                          : 'نشر الشغلانة'
                                    : 'نشر الشغلانة'),
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
