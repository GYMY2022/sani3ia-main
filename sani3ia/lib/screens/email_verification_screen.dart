// email_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/models/user_model.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String fullName;
  final String? birthDate;
  final String? gender;
  final String? address;
  final String? profession;
  final Map<String, String?>? location;
  final String? profileImagePath;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    this.birthDate,
    this.gender,
    this.address,
    this.profession,
    this.location,
    this.profileImagePath,
    required String phone,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 60;
  bool _canResend = false;
  Timer? _cooldownTimer;
  Timer? _autoCheckTimer;
  int _autoCheckCount = 0;
  final int _maxAutoChecks = 60;
  bool _initialEmailSent = false;

  @override
  void initState() {
    super.initState();
    print('🚀 بدء شاشة تأكيد البريد للمستخدم: ${widget.email}');
    _startResendCooldown();
    _startAutoCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // إرسال البريد الإلكتروني بعد ما الـ widget يكون جاهز
    if (!_initialEmailSent) {
      _initialEmailSent = true;
      _sendVerificationEmail();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoCheckTimer?.cancel();
    print('🛑 إيقاف شاشة تأكيد البريد');
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      print('👤 محاولة إرسال بريد تحقق للمستخدم: ${user?.uid}');
      print('📧 البريد: ${user?.email}');

      if (user != null && !user.emailVerified) {
        await user
            .sendEmailVerification()
            .then((_) {
              print('✅ تم إرسال رابط التحقق إلى ${user.email}');
              print('🕒 وقت الإرسال: ${DateTime.now()}');

              print('🔍 معلومات التفعيل:');
              print('   - UID: ${user.uid}');
              print('   - Email: ${user.email}');
              print('   - Verified: ${user.emailVerified}');

              // استخدام WidgetsBinding لإظهار SnackBar بعد بناء الـ widget
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم إرسال رابط التحقق إلى بريدك الإلكتروني',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            })
            .catchError((error) {
              print('❌ خطأ في إرسال البريد: $error');
              _showErrorSnackBar('خطأ في إرسال رابط التحقق: $error');
            });
      } else if (user == null) {
        print('❌ لا يوجد مستخدم مسجل لإرسال البريد');
        _showErrorSnackBar('خطأ: لا يوجد مستخدم مسجل');
      } else {
        print('✅ البريد مؤكد بالفعل');
      }
    } catch (e) {
      print('❌ خطأ في إرسال رابط التحقق: $e');
      _showErrorSnackBar('خطأ في إرسال رابط التحقق: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _showSuccessSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    });
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  void _startAutoCheck() {
    // فحص تلقائي كل 5 ثوانٍ
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _autoCheckCount++;
      print('🔄 الفحص التلقائي #$_autoCheckCount');

      if (_autoCheckCount >= _maxAutoChecks) {
        timer.cancel();
        print('⏰ انتهت مدة الفحص التلقائي');
        _showErrorSnackBar(
          'انتهت مدة الانتظار، الرجاء إعادة إرسال رابط التحقق',
        );
        return;
      }
      _checkEmailVerification();
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      print('🔄 بدء الفحص التلقائي للبريد...');
      final user = _auth.currentUser;
      if (user != null) {
        print('👤 المستخدم موجود: ${user.uid}');
        print('📧 حالة البريد قبل التحديث: ${user.emailVerified}');

        await user.reload();
        final updatedUser = _auth.currentUser;

        if (updatedUser != null) {
          print('📧 حالة البريد بعد التحديث: ${updatedUser.emailVerified}');

          if (updatedUser.emailVerified) {
            print('✅ تم التحقق من البريد الإلكتروني!');
            _autoCheckTimer?.cancel();
            await _completeRegistration();
          } else {
            print('❌ البريد لم يتم التحقق بعد');
          }
        }
      } else {
        print('❌ لا يوجد مستخدم مسجل');
      }
    } catch (e) {
      print('❌ خطأ في الفحص التلقائي: $e');
    }
  }

  Future<void> _verifyManually() async {
    print('🔄 بدء التحقق اليدوي...');
    setState(() => _isLoading = true);

    try {
      await _checkEmailVerification();

      // إذا لم يتم التحقق بعد
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        print('❌ التحقق اليدوي: البريد لم يتم التحقق بعد');
        _showErrorSnackBar(
          'لم يتم التحقق من البريد الإلكتروني بعد، الرجاء الضغط على رابط التحقق في بريدك',
        );
      }
    } catch (e) {
      print('❌ خطأ في التحقق اليدوي: $e');
      _showErrorSnackBar('خطأ في التحقق: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('🔄 انتهى التحقق اليدوي');
      }
    }
  }

  Future<void> _completeRegistration() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = _auth.currentUser;

      if (user != null) {
        // حفظ بيانات المستخدم في Provider
        userProvider.setUser(
          UserModel(
            id: user.uid,
            email: widget.email,
            name: widget.fullName,
            phone: '01000000000',
            profileImage: widget.profileImagePath,
            profession: widget.profession,
            location: widget.location,
            birthDate: widget.birthDate,
            gender: widget.gender,
            address: widget.address,
          ),
        );

        print('✅ تم تسجيل المستخدم بنجاح: ${widget.fullName}');
        print('🆔 Firebase UID: ${user.uid}');
        print('📧 البريد الإلكتروني: ${widget.email}');
        print('✅ البريد الإلكتروني مفعل: ${user.emailVerified}');

        // حفظ حالة تسجيل الدخول
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', widget.email);

        // إظهار رسالة نجاح
        _showSuccessSnackBar('تم التحقق من البريد الإلكتروني بنجاح!');

        // الانتقال إلى الصفحة الرئيسية بعد تأخير بسيط
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('❌ خطأ في إكمال التسجيل: $e');
      _showErrorSnackBar('خطأ في إكمال التسجيل: ${e.toString()}');
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend) return;

    setState(() => _isResending = true);

    try {
      await _sendVerificationEmail();
      _startResendCooldown();

      // إعادة تشغيل الفحص التلقائي
      _autoCheckCount = 0;
      _autoCheckTimer?.cancel();
      _startAutoCheck();

      _showSuccessSnackBar('تم إعادة إرسال رابط التحقق');
    } catch (e) {
      _showErrorSnackBar('خطأ في إعادة الإرسال: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _navigateToLogin() {
    _autoCheckTimer?.cancel();
    Navigator.pushReplacementNamed(context, '/login');
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // أيقونة التحقق
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.mark_email_read,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // العنوان
                      const Text(
                        'تأكيد البريد الإلكتروني',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // الرسالة التوضيحية
                      Text(
                        'تم إرسال رابط التحقق إلى',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),

                      // البريد الإلكتروني
                      Text(
                        widget.email,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // التعليمات
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'الرجاء فتح بريدك الإلكتروني والضغط على رابط التحقق. سيتم التحقق تلقائياً عند نجاح العملية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // مؤشر التحميل للفحص التلقائي
                      if (_autoCheckCount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.autorenew,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'جاري الفحص التلقائي... (${_autoCheckCount ~/ 12}/5)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // زر التحقق اليدوي
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
                          onPressed: _isLoading ? null : _verifyManually,
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
                                  'تحقق من حالة البريد',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // زر إعادة الإرسال
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            side: const BorderSide(color: Color(0xFF4A90E2)),
                          ),
                          onPressed: _canResend && !_isResending
                              ? _resendVerificationEmail
                              : null,
                          child: _isResending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF4A90E2),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _canResend
                                      ? 'إعادة إرسال الرابط'
                                      : 'إعادة إرسال ($_resendCooldown)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF4A90E2),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // زر العودة لتسجيل الدخول
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton(
                          onPressed: _navigateToLogin,
                          child: const Text(
                            'العودة لتسجيل الدخول',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // معلومات إضافية
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'معلومات مهمة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• تأكد من فحص مجلد الرسائل غير المرغوب فيها (Spam)\n• قد يستغرق وصول الرسالة بضع دقائق\n• سيتم التحقق تلقائياً عند الضغط على رابط التحقق\n• يمكنك إعادة إرسال الرابط بعد 60 ثانية إذا لم تستلمه',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
