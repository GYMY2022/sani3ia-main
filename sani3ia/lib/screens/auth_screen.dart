// auth_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/models/user_model.dart';
import 'dart:io';
import 'package:snae3ya/screens/forgot_password_screen.dart';
import 'package:snae3ya/screens/email_verification_screen.dart';
import 'package:snae3ya/screens/location_picker_screen.dart';
import 'package:snae3ya/models/location_model.dart';
import 'package:snae3ya/screens/complete_profile_screen.dart';
import 'package:snae3ya/services/location_service.dart';

// ✅ قائمة المهن المتاحة
final List<String> professions = [
  'نجار',
  'سباك',
  'كهربائي',
  'بناء',
  'دهان',
  'حداد',
  'بلاط',
  'جبس',
  'ميكانيكي',
  'سمكري',
  'عامل نظافة',
  'حدائق',
  'تبريد وتكييف',
  'أثاث',
  'زجاج',
  'رخام',
  'سيراميك',
  'مبلط',
  'مصمم داخلي',
  'مهندس معماري',
  'مهندس مدني',
  'مشرف بناء',
  'مقاول',
];

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  final VoidCallback? onLoginSuccess;

  const AuthScreen({super.key, this.isLogin = false, this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customProfessionController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLogin = true;
  bool _rememberMe = false;
  String? _gender;
  String? _selectedProfession;
  bool _showCustomProfession = false;
  File? _profileImage;
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  UserLocation? _userLocation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.standard(
    scopes: <String>['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString('userEmail');
    if (rememberedEmail != null && _isLogin) {
      setState(() {
        _emailController.text = rememberedEmail;
        _rememberMe = true;
      });
    }
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  bool _validatePhone(String phone) {
    return RegExp(r'^01[0-2,5]{1}[0-9]{8}$').hasMatch(phone);
  }

  double get _passwordStrength {
    final length = _passwordController.text.length;
    if (length > 8) return 1.0;
    if (length > 5) return 0.6;
    return 0.3;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  bool _checkUserVerificationSafely(User user) {
    return user.emailVerified;
  }

  void _showEmailVerificationDialog(String email, String password) {
    Future.microtask(() {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return SingleChildScrollView(
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.email, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('تأكيد البريد الإلكتروني'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تم إرسال رابط التحقق إلى بريدك الإلكتروني',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'إذا لم تستلم البريد:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '• تحقق من مجلد الرسائل غير المرغوب فيها (Spam)',
                    ),
                    const Text('• انتظر بضع دقائق'),
                    const Text('• تأكد من صحة عنوان البريد'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmailVerificationScreen(
                            email: email,
                            password: password,
                            fullName: 'مستخدم',
                            phone: _phoneController.text.trim(),
                          ),
                        ),
                      );
                    },
                    child: const Text('متابعة'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resendVerificationImmediately(email, password);
                    },
                    child: const Text('إعادة الإرسال'),
                  ),
                ],
              ),
            );
          },
        );
      }
    });
  }

  Future<void> _resendVerificationImmediately(
    String email,
    String password,
  ) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        await FirebaseAuth.instance.signOut();

        _showSnackBar('تم إعادة إرسال رابط التحقق', isError: false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: email,
              password: password,
              fullName: 'مستخدم',
              phone: _phoneController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('فشل إعادة الإرسال: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
      setState(() {
        _userLocation = selectedLocation;
        print('📍 تم تحديد الموقع: ${selectedLocation.address}');
        print(
          '📍 الإحداثيات: ${selectedLocation.latitude}, ${selectedLocation.longitude}',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد الموقع بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _getCurrentLocationAutomatically() async {
    try {
      final locationService = LocationService();
      final currentLocation = await locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _userLocation = currentLocation;
        });
        print('📍 تم تحديد الموقع تلقائياً: ${currentLocation.address}');
      }
    } catch (e) {
      print('❌ فشل في تحديد الموقع تلقائياً: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (!_isLogin) {
        try {
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);

          print('✅ تم إنشاء حساب Firebase بنجاح: ${credential.user!.uid}');

          final fullName = _fullNameController.text;
          final birthDate = _birthDateController.text;
          final gender = _gender;
          final phone = _phoneController.text.trim();
          final profession = _showCustomProfession
              ? _customProfessionController.text
              : _selectedProfession;

          await _registerUser(
            fullName: fullName,
            email: email,
            password: password,
            birthDate: birthDate,
            gender: gender,
            phone: phone,
            profession: profession,
            profileImage: _profileImage,
            firebaseUserId: credential.user!.uid,
            userLocation: _userLocation,
          );

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: email,
                password: password,
                fullName: fullName,
                birthDate: birthDate,
                gender: gender,
                phone: phone,
                profession: profession,
                profileImagePath: _profileImage?.path,
              ),
            ),
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'weak-password') {
            _showSnackBar('كلمة المرور ضعيفة جداً.', isError: true);
          } else if (e.code == 'email-already-in-use') {
            _showSnackBar(
              'هذا البريد الإلكتروني مستخدم بالفعل.',
              isError: true,
            );
          } else {
            _showSnackBar('خطأ في التسجيل: ${e.message}', isError: true);
          }
          return;
        } catch (e) {
          _showSnackBar('حدث خطأ غير متوقع: $e', isError: true);
          return;
        }
      } else {
        try {
          final credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password);

          final user = credential.user;
          if (user != null) {
            try {
              final isVerified = _checkUserVerificationSafely(user);

              print('📧 حالة البريد: $isVerified');

              if (!isVerified) {
                print('❌ تم منع تسجيل الدخول - البريد غير مؤكد: $email');

                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmailVerificationScreen(
                      email: email,
                      password: password,
                      fullName: 'مستخدم',
                      phone: '',
                    ),
                  ),
                );
                return;
              }

              print('✅ تم تسجيل الدخول بنجاح: ${user.uid}');
              print('✅ البريد الإلكتروني مفعل: $isVerified');

              // ⭐⭐ تحميل بيانات المستخدم أولاً مع الانتظار الكافي
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );

              // تأكد من تحميل البيانات بالكامل
              await userProvider.loadUserData();

              // انتظر لحظة للتأكد من اكتمال التحميل
              await Future.delayed(const Duration(milliseconds: 500));

              // تأكد أن البيانات اتحملت
              print('📋 بيانات المستخدم بعد التحميل:');
              print('   - الهاتف: ${userProvider.user.phone}');
              print('   - المهنة: ${userProvider.user.profession}');
              print('   - النوع: ${userProvider.user.gender}');

              // ⭐⭐ التحقق من اكتمال البيانات بشكل مباشر
              final bool hasPhone =
                  userProvider.user.phone != null &&
                  userProvider.user.phone!.isNotEmpty;
              final bool hasProfession =
                  userProvider.user.profession != null &&
                  userProvider.user.profession!.isNotEmpty;
              final bool hasGender =
                  userProvider.user.gender != null &&
                  userProvider.user.gender!.isNotEmpty;

              final bool isProfileComplete =
                  hasPhone && hasProfession && hasGender;
              print('📋 حالة اكتمال الملف الشخصي: $isProfileComplete');
              print(
                '   - الهاتف موجود: $hasPhone (${userProvider.user.phone})',
              );
              print(
                '   - المهنة موجودة: $hasProfession (${userProvider.user.profession})',
              );
              print(
                '   - النوع موجود: $hasGender (${userProvider.user.gender})',
              );

              if (_rememberMe) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', true);
                await prefs.setString('userEmail', email);
              } else {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('userEmail');
              }

              if (widget.onLoginSuccess != null) {
                widget.onLoginSuccess!();
              }

              if (!mounted) return;

              if (!isProfileComplete) {
                print('🔄 البيانات غير مكتملة - توجيه لإكمال الملف الشخصي...');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompleteProfileScreen(
                      user: userProvider.user,
                      isFromGoogle: false,
                    ),
                  ),
                );
              } else {
                print('✅ البيانات مكتملة - توجيه للصفحة الرئيسية...');
                Navigator.pushReplacementNamed(context, '/home');
              }
            } catch (reloadError) {
              print('❌ خطأ في reload المستخدم: $reloadError');
              if (!user.emailVerified) {
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmailVerificationScreen(
                      email: email,
                      password: password,
                      fullName: 'مستخدم',
                      phone: '',
                    ),
                  ),
                );
                return;
              } else {
                await _loginUser(
                  email: email,
                  password: password,
                  firebaseUserId: user.uid,
                );

                // ⭐⭐ تحميل بيانات المستخدم والتحقق من اكتمال الملف الشخصي
                final userProvider = Provider.of<UserProvider>(
                  context,
                  listen: false,
                );
                await userProvider.loadUserData();

                // ⭐⭐ التحقق من اكتمال البيانات بشكل مباشر
                final bool hasPhone =
                    userProvider.user.phone != null &&
                    userProvider.user.phone!.isNotEmpty;
                final bool hasProfession =
                    userProvider.user.profession != null &&
                    userProvider.user.profession!.isNotEmpty;
                final bool hasGender =
                    userProvider.user.gender != null &&
                    userProvider.user.gender!.isNotEmpty;

                final bool isProfileComplete =
                    hasPhone && hasProfession && hasGender;
                print('📋 حالة اكتمال الملف الشخصي: $isProfileComplete');

                if (_rememberMe) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', true);
                  await prefs.setString('userEmail', email);
                }

                if (widget.onLoginSuccess != null) {
                  widget.onLoginSuccess!();
                }

                if (!mounted) return;

                if (!isProfileComplete) {
                  print(
                    '🔄 الملف الشخصي غير مكتمل - توجيه لإكمال الملف الشخصي...',
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CompleteProfileScreen(
                        user: userProvider.user,
                        isFromGoogle: false,
                      ),
                    ),
                  );
                } else {
                  print('✅ الملف الشخصي مكتمل - توجيه للصفحة الرئيسية...');
                  Navigator.pushReplacementNamed(context, '/home');
                }
              }
            }
          } else {
            _showSnackBar(
              'فشل تسجيل الدخول - لم يتم العثور على مستخدم',
              isError: true,
            );
          }
        } on FirebaseAuthException catch (e) {
          String errorMessage = 'حدث خطأ غير معروف';

          if (e.code == 'user-not-found') {
            errorMessage = 'لم يتم العثور على مستخدم بهذا البريد الإلكتروني.';
          } else if (e.code == 'wrong-password') {
            errorMessage = 'كلمة المرور غير صحيحة.';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'البريد الإلكتروني غير صالح.';
          } else if (e.code == 'user-disabled') {
            errorMessage = 'هذا الحساب معطل.';
          } else if (e.code == 'too-many-requests') {
            errorMessage =
                'محاولات تسجيل دخول كثيرة جداً. الرجاء المحاولة لاحقاً.';
          } else {
            errorMessage = 'خطأ في تسجيل الدخول: ${e.message}';
          }

          _showSnackBar(errorMessage, isError: true);
          return;
        } catch (e) {
          print('❌ خطأ غير متوقع في تسجيل الدخول: $e');
          _showSnackBar('حدث خطأ غير متوقع: $e', isError: true);
          return;
        }
      }
    } catch (e) {
      _showSnackBar('حدث خطأ: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser({
    required String fullName,
    required String email,
    required String password,
    required String birthDate,
    required String? gender,
    required String phone,
    required String? profession,
    required File? profileImage,
    required String firebaseUserId,
    required UserLocation? userLocation,
  }) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    String? profileImageUrl;
    if (profileImage != null) {
      profileImageUrl = profileImage.path;
    }

    // إنشاء خريطة موقع من بيانات الموقع الجغرافي فقط
    Map<String, dynamic>? locationData;
    if (userLocation != null) {
      locationData = {
        'latitude': userLocation.latitude,
        'longitude': userLocation.longitude,
        'fullAddress': userLocation.address,
      };
    }

    final user = UserModel(
      id: firebaseUserId,
      email: email,
      name: fullName,
      phone: phone,
      profileImage: profileImageUrl,
      profession: profession,
      location: locationData,
      birthDate: birthDate,
      gender: gender,
      createdAt: DateTime.now(),
      isEmailVerified: false,
      latitude: userLocation?.latitude,
      longitude: userLocation?.longitude,
      fullAddress: userLocation?.address,
    );

    userProvider.setUser(user);

    final success = await userProvider.saveUserToFirestore(user);

    if (success) {
      print('✅ تم تسجيل المستخدم بنجاح: $fullName');
      print('🆔 Firebase UID: $firebaseUserId');
      print('📧 البريد الإلكتروني: $email');
      print('📞 رقم الهاتف: $phone');
      print('👨‍💼 المهنة: $profession');
      if (userLocation != null) {
        print(
          '📍 إحداثيات الموقع: ${userLocation.latitude}, ${userLocation.longitude}',
        );
        print('📍 العنوان الكامل: ${userLocation.address}');
      }

      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', email);
      }
    } else {
      print('❌ فشل في حفظ بيانات المستخدم في Firestore');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في حفظ بيانات المستخدم'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة loginUser المعدلة - لا تنشئ بيانات جديدة
  Future<void> _loginUser({
    required String email,
    required String password,
    required String firebaseUserId,
  }) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // تحميل بيانات المستخدم أولاً
    await userProvider.loadUserData();

    // إذا لم توجد بيانات، لا تنشئ بيانات جديدة! فقط سجل الدخول
    if (!userProvider.hasUserData) {
      print(
        '⚠️ لا توجد بيانات للمستخدم في Firestore - سيتم فتح شاشة إكمال الملف الشخصي',
      );
      // لا ننشئ بيانات هنا
    } else {
      print('✅ تم تحميل بيانات المستخدم الموجود بنجاح');
    }

    print('✅ تم تسجيل الدخول بنجاح: $email');
    print('🆔 Firebase UID: $firebaseUserId');
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      print('🔐 بدء تسجيل الدخول بجوجل...');

      await _googleSignIn.signOut();
      await Future.delayed(const Duration(milliseconds: 500));

      print('🔐 جاري فتح نافذة اختيار حساب جوجل...');

      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn()
          .catchError((e) {
            print('❌ خطأ في signIn: $e');
            return null;
          });

      if (googleUser == null) {
        print('❌ المستخدم ألغى عملية تسجيل الدخول');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ تم اختيار حساب: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔐 جاري تسجيل الدخول في Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user != null) {
        print('✅ تم تسجيل الدخول بجوجل بنجاح: ${user.uid}');
        print('📧 البريد الإلكتروني: ${user.email}');
        print('👤 الاسم: ${user.displayName}');
        print('📸 صورة الملف الشخصي: ${user.photoURL}');

        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        print('🆕 هل هو مستخدم جديد؟: $isNewUser');

        // تحديد الموقع تلقائياً لمستخدمي جوجل
        await _getCurrentLocationAutomatically();

        final userProvider = Provider.of<UserProvider>(context, listen: false);

        if (isNewUser) {
          print('🆕 مستخدم جديد - إنشاء حساب في Firestore');
          await _handleNewGoogleUser(user, googleUser);

          // بعد إنشاء الحساب الجديد، نحتاج إلى تحميل بيانات المستخدم
          await userProvider.loadUserData();

          // المستخدم جديد بالتأكيد يحتاج لإكمال الملف الشخصي
          if (mounted) {
            print('🔄 توجيه مستخدم جديد لإكمال الملف الشخصي...');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CompleteProfileScreen(
                  user: userProvider.user,
                  isFromGoogle: true,
                ),
              ),
            );
          }
        } else {
          print('👤 مستخدم موجود - تحميل البيانات من Firestore');
          await _handleExistingGoogleUser(user);

          // ⭐⭐ تحميل بيانات المستخدم بعد المعالجة مع الانتظار الكافي
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          await userProvider.loadUserData();

          // انتظر لحظة للتأكد من اكتمال التحميل
          await Future.delayed(const Duration(milliseconds: 500));

          // ⭐⭐ التحقق من اكتمال البيانات بشكل مباشر
          final bool hasPhone =
              userProvider.user.phone != null &&
              userProvider.user.phone!.isNotEmpty;
          final bool hasProfession =
              userProvider.user.profession != null &&
              userProvider.user.profession!.isNotEmpty;
          final bool hasGender =
              userProvider.user.gender != null &&
              userProvider.user.gender!.isNotEmpty;

          final bool isProfileComplete = hasPhone && hasProfession && hasGender;
          print('📋 حالة اكتمال الملف الشخصي: $isProfileComplete');
          print('   - الهاتف موجود: $hasPhone (${userProvider.user.phone})');
          print(
            '   - المهنة موجودة: $hasProfession (${userProvider.user.profession})',
          );
          print('   - النوع موجود: $hasGender (${userProvider.user.gender})');

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userEmail', user.email ?? '');
          await prefs.setString('userName', user.displayName ?? 'مستخدم جوجل');
          await prefs.setString('loginMethod', 'google');

          if (widget.onLoginSuccess != null) {
            widget.onLoginSuccess!();
          }

          if (mounted) {
            if (!isProfileComplete) {
              print('🔄 البيانات غير مكتملة - توجيه لإكمال الملف الشخصي...');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CompleteProfileScreen(
                    user: userProvider.user,
                    isFromGoogle: true,
                  ),
                ),
              );
            } else {
              print('✅ البيانات مكتملة - توجيه للصفحة الرئيسية...');
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        }
      } else {
        throw Exception('فشل في الحصول على بيانات المستخدم من جوجل');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'حدث خطأ أثناء تسجيل الدخول بجوجل';
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');

      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'هذا البريد الإلكتروني مرتبط بحساب آخر';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'بيانات الاعتماد غير صالحة';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'تسجيل الدخول بجوجل غير مفعل';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'هذا الحساب معطل';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'لم يتم العثور على حساب مرتبط بهذا البريد';
      } else {
        errorMessage = 'خطأ في تسجيل الدخول بجوجل: ${e.message}';
      }

      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول بجوجل: $e');
      _showSnackBar('فشل تسجيل الدخول بجوجل: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNewGoogleUser(
    User user,
    GoogleSignInAccount googleUser,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    String? profileImage = user.photoURL;
    if (profileImage != null && !profileImage.contains('s96-c')) {
      profileImage = profileImage.replaceAll('s96-c', 's400-c');
    }

    // إنشاء خريطة موقع من بيانات الموقع الجغرافي
    Map<String, dynamic>? locationData;
    if (_userLocation != null) {
      locationData = {
        'latitude': _userLocation!.latitude,
        'longitude': _userLocation!.longitude,
        'fullAddress': _userLocation!.address,
      };
    }

    final userModel = UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'مستخدم جوجل',
      phone: user.phoneNumber ?? '',
      profileImage: profileImage,
      isEmailVerified: user.emailVerified,
      createdAt: DateTime.now(),
      profession: null,
      gender: null,
      location: locationData,
      latitude: _userLocation?.latitude,
      longitude: _userLocation?.longitude,
      fullAddress: _userLocation?.address,
    );

    userProvider.setUser(userModel);
    final success = await userProvider.saveUserToFirestore(userModel);

    if (success) {
      print('✅ تم إنشاء حساب جديد للمستخدم من جوجل: ${userModel.name}');
      if (_userLocation != null) {
        print('📍 تم حفظ الموقع التلقائي: ${_userLocation!.address}');
      }
    } else {
      print('❌ فشل في حفظ بيانات المستخدم الجديد من جوجل');
      _showSnackBar(
        'تم التسجيل بنجاح ولكن حدث خطأ في حفظ البيانات. يرجى إكمال ملفك الشخصي لاحقاً.',
        isError: false,
      );
    }
  }

  // دالة handleExistingGoogleUser المعدلة - لا تنشئ بيانات جديدة
  Future<void> _handleExistingGoogleUser(User user) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // تحميل بيانات المستخدم أولاً
    await userProvider.loadUserData();

    // إذا لم توجد بيانات، لا تنشئ بيانات جديدة!
    if (!userProvider.hasUserData) {
      print('⚠️ مستخدم جوجل موجود ولكن لا توجد بيانات في Firestore');
      print('⚠️ لن يتم إنشاء بيانات جديدة - سيتم فتح شاشة إكمال الملف الشخصي');

      // فقط نخزن البيانات الأساسية في الذاكرة، مش في Firestore
      final tempUser = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'مستخدم جوجل',
        phone: user.phoneNumber ?? '',
        profileImage: user.photoURL,
        isEmailVerified: user.emailVerified,
        createdAt: DateTime.now(),
        profession: null,
        gender: null,
        location: null,
      );

      userProvider.setUser(tempUser);
    } else {
      print('✅ تم تحميل بيانات المستخدم الموجود بنجاح');
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _emailController.clear();
      _passwordController.clear();
      _fullNameController.clear();
      _birthDateController.clear();
      _phoneController.clear();
      _customProfessionController.clear();
      _gender = null;
      _selectedProfession = null;
      _showCustomProfession = false;
      _selectedDate = null;
      _profileImage = null;
      _userLocation = null;
    });
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      ),
      items: items.map<DropdownMenuItem<T>>((T item) {
        return DropdownMenuItem<T>(value: item, child: Text(displayText(item)));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الموقع الجغرافي',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _pickLocation,
          icon: const Icon(Icons.location_on),
          label: Text(
            _userLocation != null ? 'تم تحديد الموقع' : 'تحديد موقعي الجغرافي',
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            side: const BorderSide(color: Colors.blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        if (_userLocation != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _userLocation!.address,
                    style: const TextStyle(color: Colors.green),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'مرحباً بعودتك! يرجى تسجيل الدخول للمتابعة'
                              : 'أنشئ حسابك الجديد لتبدأ رحلتك معنا',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (!_isLogin) ...[
                          GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              backgroundColor: Colors.grey[200],
                              child: _profileImage == null
                                  ? const Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _profileImage == null
                                ? 'اضغط لإضافة صورة شخصية'
                                : 'اضغط لتغيير الصورة',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _fullNameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال الاسم الثلاثي';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'الاسم الثلاثي',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A90E2),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال البريد الإلكتروني';
                            }
                            if (!_validateEmail(value)) {
                              return 'البريد الإلكتروني غير صحيح';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: Color(0xFF4A90E2),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال رقم الهاتف';
                              }
                              if (!_validatePhone(value)) {
                                return 'رقم الهاتف غير صحيح (يجب أن يبدأ بـ 01 ويحتوي على 11 رقماً)';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف للتواصل',
                              hintText: 'مثال: 01012345678',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A90E2),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (value) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال كلمة المرور';
                            }
                            if (!_validatePassword(value)) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: Color(0xFF4A90E2),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_passwordController.text.isNotEmpty) ...[
                          LinearProgressIndicator(
                            value: _passwordStrength,
                            backgroundColor: Colors.grey[200],
                            color: _passwordStrength > 0.8
                                ? Colors.green
                                : _passwordStrength > 0.5
                                ? Colors.orange
                                : Colors.red,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _passwordStrength > 0.8
                                ? 'قوية'
                                : _passwordStrength > 0.5
                                ? 'متوسطة'
                                : 'ضعيفة',
                            style: TextStyle(
                              color: _passwordStrength > 0.8
                                  ? Colors.green
                                  : _passwordStrength > 0.5
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _birthDateController,
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال تاريخ الميلاد';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'تاريخ الميلاد',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
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
                            value: _gender,
                            validator: (value) {
                              if (value == null) {
                                return 'الرجاء اختيار النوع';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'النوع',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A90E2),
                                  width: 2,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ذكر',
                                child: Text('ذكر'),
                              ),
                              DropdownMenuItem(
                                value: 'أنثى',
                                child: Text('أنثى'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _gender = value;
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
                                items: [...professions, 'مخصص'],
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
                                    labelText: 'أدخل مهنتك',
                                    prefixIcon: const Icon(Icons.work_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
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
                          const SizedBox(height: 16),

                          _buildLocationField(),
                          const SizedBox(height: 16),
                        ],

                        if (_isLogin)
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              const Text('تذكرني'),
                              const Spacer(),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                child: const Text('نسيت كلمة المرور؟'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'أو متابعة باستخدام',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _signInWithGoogle,
                                icon: const Icon(
                                  Icons.g_mobiledata,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                label: const Text('Google'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
                            ),
                            TextButton(
                              onPressed: _toggleAuthMode,
                              child: Text(
                                _isLogin ? 'سجل الآن' : 'تسجيل الدخول',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on GoogleSignIn {
  signIn() {}
}

extension on GoogleSignInAuthentication {
  get accessToken => null;
}
