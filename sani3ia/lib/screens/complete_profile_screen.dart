import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/models/user_model.dart';
import 'package:snae3ya/data/data.dart';

class CompleteProfileScreen extends StatefulWidget {
  final UserModel user;
  final bool isFromGoogle;

  const CompleteProfileScreen({
    super.key,
    required this.user,
    this.isFromGoogle = false,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customProfessionController =
      TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _bioController =
      TextEditingController(); // ⭐⭐ إضافة حقل النبذة

  File? _profileImage;
  bool _isLoading = false;
  String? _selectedGender;
  String? _selectedProfession;
  bool _showCustomProfession = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    print('🚀 بدء شاشة إكمال الملف الشخصي للمستخدم: ${widget.user.name}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfProfileAlreadyComplete();
    });

    _initializeUserData();
  }

  void _checkIfProfileAlreadyComplete() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (userProvider.isProfileComplete) {
        print('⚠️ الملف الشخصي مكتمل بالفعل، توجيه للصفحة الرئيسية...');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الملف الشخصي مكتمل بالفعل'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      }
    });
  }

  void _initializeUserData() {
    print('🔍 تهيئة بيانات المستخدم...');

    _phoneController.text = widget.user.phone ?? '';
    _birthDateController.text = widget.user.birthDate ?? '';
    _selectedGender = widget.user.gender;
    _bioController.text =
        widget.user.bio ?? ''; // ⭐⭐ تحميل النبذة إذا كانت موجودة

    if (widget.user.hasGeoLocation) {
      print('📍 المستخدم لديه موقع جغرافي: ${widget.user.fullAddress}');
    }

    final userProfession = widget.user.profession;
    print('🔍 مهنة المستخدم الحالية: $userProfession');

    if (userProfession != null && userProfession.isNotEmpty) {
      if (AppData.professions.contains(userProfession)) {
        _selectedProfession = userProfession;
        print('✅ المهنة موجودة في القائمة: $userProfession');
      } else {
        _selectedProfession = 'مخصص';
        _showCustomProfession = true;
        _customProfessionController.text = userProfession;
        print('🔧 تحويل المهنة إلى "مخصص": $userProfession');
      }
    } else {
      _selectedProfession = null;
      print('📭 لا توجد مهنة محددة، القيمة: null');
    }

    if (widget.user.birthDate != null && widget.user.birthDate!.isNotEmpty) {
      try {
        final parts = widget.user.birthDate!.split('/');
        if (parts.length == 3) {
          _selectedDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        print('❌ خطأ في تحليل تاريخ الميلاد: $e');
      }
    }

    print('🎯 تهيئة البيانات المكتملة:');
    print('   - المهنة: $_selectedProfession');
    print('   - النوع: $_selectedGender');
    print('   - الهاتف: ${_phoneController.text}');
    print('   - النبذة: ${_bioController.text}');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (userProvider.isProfileComplete) {
        print('⚠️ الملف الشخصي مكتمل بالفعل، توجيه للصفحة الرئيسية...');
        _showSuccessAndRedirect();
        return;
      }

      final profession = _showCustomProfession
          ? _customProfessionController.text
          : _selectedProfession;

      final Map<String, dynamic>? existingLocation = widget.user.location;

      final updates = <String, dynamic>{
        'phone': _phoneController.text.trim(),
        'profession': profession,
        'birthDate': _birthDateController.text.trim(),
        'gender': _selectedGender,
        'bio': _bioController.text.trim(), // ⭐⭐ إضافة النبذة
        'updatedAt': DateTime.now(),
      };

      if (existingLocation != null) {
        updates['location'] = existingLocation;
      }

      if (_profileImage != null) {
        updates['profileImage'] = _profileImage!.path;
      }

      final success = await userProvider.updateUserInFirestore(updates);

      if (success) {
        _showSuccessAndRedirect();
      } else {
        _showError('فشل في حفظ البيانات. يرجى المحاولة مرة أخرى.');
      }
    } catch (e) {
      print('❌ خطأ في إكمال الملف الشخصي: $e');
      _showError('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessAndRedirect() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إكمال الملف الشخصي بنجاح!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildProfessionDropdown() {
    final professionItems = [...AppData.professions, 'مخصص'];

    final bool isValidValue =
        _selectedProfession == null ||
        professionItems.contains(_selectedProfession);

    if (!isValidValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedProfession = null;
          });
        }
      });
    }

    return DropdownButtonFormField<String>(
      value: isValidValue ? _selectedProfession : null,
      validator: (value) {
        if (value == null) {
          return 'الرجاء اختيار المهنة';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'المهنة *',
        prefixIcon: const Icon(Icons.work_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      ),
      items: professionItems.map<DropdownMenuItem<String>>((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedProfession = value;
          _showCustomProfession = value == 'مخصص';
          if (!_showCustomProfession) {
            _customProfessionController.clear();
          }
        });
      },
    );
  }

  Widget _buildGenderDropdown() {
    const genderItems = ['ذكر', 'أنثى'];

    final bool isValidValue =
        _selectedGender == null || genderItems.contains(_selectedGender);

    if (!isValidValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedGender = null;
          });
        }
      });
    }

    return DropdownButtonFormField<String>(
      value: isValidValue ? _selectedGender : null,
      validator: (value) {
        if (value == null) {
          return 'الرجاء اختيار النوع';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'النوع *',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      ),
      items: genderItems.map<DropdownMenuItem<String>>((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال الملف الشخصي'),
        backgroundColor: const Color(0xFF4A90E2),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً بك ${widget.user.name ?? "مستخدم"}! 👋',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isFromGoogle
                                ? 'تم التسجيل بنجاح باستخدام جوجل'
                                : 'مرحباً بك في تطبيق صنايعية',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'برجاء إكمال بياناتك الشخصية للحصول على أفضل تجربة',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '⚠️ يجب إكمال جميع الحقول الإلزامية (*) للمتابعة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          if (widget.user.hasGeoLocation) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'الموقع الجغرافي',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.user.displayAddress,
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _getProfileImage(),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'البيانات الأساسية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف *',
                        hintText: 'مثال: 01012345678',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A90E2),
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال رقم الهاتف';
                        }
                        if (!RegExp(
                          r'^01[0-2,5]{1}[0-9]{8}$',
                        ).hasMatch(value)) {
                          return 'رقم الهاتف غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildGenderDropdown(),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'تاريخ الميلاد',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A90E2),
                            width: 2,
                          ),
                        ),
                      ),
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'البيانات المهنية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfessionDropdown(),
                        if (_showCustomProfession) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customProfessionController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال المهنة';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'أدخل مهنتك *',
                              prefixIcon: const Icon(Icons.work_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A90E2),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ⭐⭐ حقل النبذة الجديد
                    const Text(
                      'نبذة عني',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'نبذة عني (اختياري)',
                        hintText: 'اكتب نبذة مختصرة عن خبراتك ومهاراتك...',
                        prefixIcon: const Icon(Icons.info_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4A90E2),
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _completeProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: const Color(0xFF4A90E2),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'إكمال الملف الشخصي',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  ImageProvider _getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }
    if (widget.user.profileImage != null &&
        widget.user.profileImage!.isNotEmpty) {
      if (widget.user.profileImage!.startsWith('http')) {
        return NetworkImage(widget.user.profileImage!);
      } else {
        return FileImage(File(widget.user.profileImage!));
      }
    }
    return const AssetImage('assets/images/user_profile.png');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _customProfessionController.dispose();
    _birthDateController.dispose();
    _bioController.dispose(); // ⭐⭐ إضافة dispose
    super.dispose();
  }
}
