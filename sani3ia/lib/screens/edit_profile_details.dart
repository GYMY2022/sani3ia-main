import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/models/user_model.dart';
import 'package:snae3ya/data/data.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _customProfessionController;
  late TextEditingController _birthDateController;
  late TextEditingController _passwordController;
  late TextEditingController _bioController; // ⭐⭐ إضافة حقل النبذة

  File? _profileImage;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _selectedGender;
  String? _selectedProfession;
  bool _showCustomProfession = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _customProfessionController = TextEditingController();
    _birthDateController = TextEditingController();
    _passwordController = TextEditingController();
    _bioController = TextEditingController(); // ⭐⭐ تهيئة حقل النبذة

    _nameController.text = user.name ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
    _birthDateController.text = user.birthDate ?? '';
    _bioController.text = user.bio ?? ''; // ⭐⭐ تحميل النبذة

    _selectedGender = user.gender;
    _selectedProfession = user.profession;

    if (_selectedProfession != null) {
      if (!AppData.professions.contains(_selectedProfession) &&
          _selectedProfession != 'مخصص') {
        _showCustomProfession = true;
        _customProfessionController.text = _selectedProfession!;
        _selectedProfession = 'مخصص';
      } else if (_selectedProfession == 'مخصص') {
        _showCustomProfession = true;
      }
    }
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
      initialDate: _selectedDate ?? DateTime.now(),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final profession =
          _showCustomProfession && _customProfessionController.text.isNotEmpty
          ? _customProfessionController.text
          : (_showCustomProfession ? '' : _selectedProfession);

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profession': profession,
        'birthDate': _birthDateController.text.trim(),
        'gender': _selectedGender,
        'bio': _bioController.text.trim(), // ⭐⭐ إضافة النبذة
      };

      if (userProvider.user.location != null) {
        updates['location'] = userProvider.user.location;
      }

      if (_profileImage != null) {
        updates['profileImage'] = _profileImage!.path;
      }

      if (_passwordController.text.isNotEmpty) {
        print('كلمة المرور الجديدة: ${_passwordController.text}');
      }

      final success = await userProvider.updateUserInFirestore(updates);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في حفظ التغييرات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ خطأ في حفظ التغييرات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProfileCompletionHeader(UserProvider userProvider) {
    final completionPercentage = userProvider.profileCompletionPercentage;
    final missingFields = userProvider.missingProfileFields;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أكمل ملفك الشخصي',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completionPercentage,
            backgroundColor: Colors.grey[300],
            color: completionPercentage > 0.7 ? Colors.green : Colors.blue,
          ),
          const SizedBox(height: 8),
          Text(
            '${(completionPercentage * 100).toStringAsFixed(0)}% مكتمل',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (missingFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ركز على إكمال: ${missingFields.join('، ')}',
              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownFormField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) displayText,
    String? Function(T?)? validator,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      validator:
          validator ??
          (value) {
            if (isRequired && value == null) {
              return 'الرجاء اختيار $label';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.list),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      ),
      items: items.map<DropdownMenuItem<T>>((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayText(item), style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!userProvider.isProfileComplete)
                      _buildProfileCompletionHeader(userProvider),

                    if (!userProvider.isProfileComplete)
                      const SizedBox(height: 16),

                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _getProfileImage(user),
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
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        prefixIcon: const Icon(Icons.person_outline),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال الاسم الثلاثي';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: const Icon(Icons.email),
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
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true,
                      style: TextStyle(color: Colors.grey[600]),
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
                          return 'رقم الهاتف غير صحيح (يجب أن يبدأ بـ 01 ويحتوي على 11 رقماً)';
                        }
                        return null;
                      },
                    ),
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
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'النوع',
                        prefixIcon: const Icon(Icons.person_outline),
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
                      items: const [
                        DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                        DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDropdownFormField<String>(
                          label: 'المهنة',
                          value: _selectedProfession,
                          items: [...AppData.professions, 'مخصص'],
                          displayText: (item) => item,
                          onChanged: (value) {
                            setState(() {
                              _selectedProfession = value;
                              _showCustomProfession = value == 'مخصص';
                              if (!_showCustomProfession) {
                                _customProfessionController.clear();
                              }
                            });
                          },
                        ),
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
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة (اختياري)',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
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
                      obscureText: !_isPasswordVisible,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
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
                                'حفظ التغييرات',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  ImageProvider _getProfileImage(UserModel user) {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      if (user.profileImage!.startsWith('http')) {
        return NetworkImage(user.profileImage!);
      } else {
        return FileImage(File(user.profileImage!));
      }
    }
    return const AssetImage('assets/images/user_profile.png');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _customProfessionController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _bioController.dispose(); // ⭐⭐ إضافة dispose
    super.dispose();
  }
}
