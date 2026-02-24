import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/providers/user_provider.dart';
import 'package:snae3ya/models/user_model.dart';
import 'package:snae3ya/screens/edit_profile_details.dart';
import 'package:snae3ya/screens/app_settings.dart';
import 'package:snae3ya/screens/auth_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && !userProvider.hasUserData) {
      await userProvider.loadUserData();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.user;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            stretch: true,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                return FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[700]!,
                          Colors.blue[500]!,
                          Colors.cyan[400]!,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 38,
                                backgroundImage: _getProfileImage(currentUser),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              userProvider.displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userProvider.displayEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            if (currentUser.profession != null &&
                                currentUser.profession!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  userProvider.displayProfession,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (currentUser.phone != null &&
                                currentUser.phone!.isNotEmpty)
                              Text(
                                currentUser.phone!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildUserInfoCard(userProvider),
                  const SizedBox(height: 16),
                  _buildMenuSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getProfileImage(UserModel user) {
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      if (user.profileImage!.startsWith('http')) {
        return NetworkImage(user.profileImage!);
      } else {
        return FileImage(File(user.profileImage!));
      }
    }
    return const AssetImage('assets/images/user_profile.png');
  }

  Widget _buildUserInfoCard(UserProvider userProvider) {
    final user = userProvider.user;
    final completionPercentage = userProvider.profileCompletionPercentage;
    final isProfileComplete = userProvider.isProfileComplete;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isProfileComplete) ...[
              _buildProfileCompletionIndicator(
                userProvider,
                completionPercentage,
              ),
              const SizedBox(height: 12),
            ],

            const Text(
              'معلومات الحساب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('الاسم الكامل', userProvider.displayName),
            _buildInfoRow('البريد الإلكتروني', userProvider.displayEmail),
            _buildInfoRow('رقم الهاتف', userProvider.displayPhone),
            if (user.profession != null && user.profession!.isNotEmpty)
              _buildInfoRow('المهنة', userProvider.displayProfession),

            // ✅ عرض الموقع الجغرافي إذا كان موجوداً
            if (user.hasGeoLocation) _buildLocationInfoRow(user),

            if (user.birthDate != null && user.birthDate!.isNotEmpty)
              _buildInfoRow('تاريخ الميلاد', user.birthDate!),
            if (user.gender != null && user.gender!.isNotEmpty)
              _buildInfoRow('النوع', user.gender!),
          ],
        ),
      ),
    );
  }

  // ✅ دالة جديدة لعرض الموقع الجغرافي بشكل مميز
  Widget _buildLocationInfoRow(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الموقع الجغرافي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.displayAddress,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.hasGeoLocation) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الإحداثيات: ${user.latitude?.toStringAsFixed(6)}, ${user.longitude?.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletionIndicator(
    UserProvider userProvider,
    double percentage,
  ) {
    final missingFields = userProvider.missingProfileFields;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'اكتمال الملف الشخصي',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[300],
            color: percentage > 0.7 ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 6),
          Text(
            '${(percentage * 100).toStringAsFixed(0)}% مكتمل',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (missingFields.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'الحقول الناقصة: ${missingFields.join('، ')}',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'إكمال الملف الشخصي',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Column(
      children: [
        _buildMenuCard(
          'تعديل الحساب',
          'قم بتحديث معلوماتك الشخصية',
          Icons.edit_outlined,
          Colors.blue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            ).then((_) {
              _loadUserData();
            });
          },
        ),
        const SizedBox(height: 8),
        _buildMenuCard(
          'الإعدادات',
          'تخصيص التطبيق حسب احتياجاتك',
          Icons.settings_outlined,
          Colors.orange,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AppSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildMenuCard(
          'تسجيل الخروج',
          'الخروج من التطبيق',
          Icons.logout,
          Colors.red,
          () {
            _showLogoutDialog(context, userProvider);
          },
        ),
      ],
    );
  }

  // ✅ الحل النهائي لمشكلة تسجيل الخروج
  Future<void> _logout(BuildContext context, UserProvider userProvider) async {
    try {
      print('🚪 بدء عملية تسجيل الخروج...');

      // 1. إظهار مؤشر تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );

      // 2. تنفيذ تسجيل الخروج
      await userProvider.logout();

      print('✅ تم تسجيل الخروج بنجاح');

      // 3. إغلاق مؤشر التحميل
      if (context.mounted) {
        Navigator.of(context).pop(); // إغلاق dialog
      }

      // ⭐⭐ 4. الحل النهائي: استخدام pushAndRemoveUntil مع MaterialPageRoute
      if (!context.mounted) return;

      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isLogin: true),
        ),
        (Route<dynamic> route) => false,
      );

      print('🎉 تم التوجيه بنجاح لشاشة Auth');
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');

      // إغلاق مؤشر التحميل في حالة الخطأ
      if (context.mounted) {
        Navigator.of(context).pop();

        // عرض رسالة الخطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // إغلاق الـ dialog أولاً
                  _logout(context, userProvider); // ثم تنفيذ الخروج
                },
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
