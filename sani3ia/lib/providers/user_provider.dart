import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snae3ya/models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String _error = '';
  bool _isInitialized = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel get user => _user ?? UserModel.empty();
  bool get hasUserData => _user != null && _user!.isNotEmpty;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isInitialized => _isInitialized;

  // الحقول المعروضة بشكل آمن
  String get displayName => _user?.name ?? 'مستخدم';
  String get displayEmail => _user?.email ?? 'البريد الإلكتروني';
  String get displayPhone => _user?.phone ?? 'رقم الهاتف';
  String get displayProfession => _user?.profession ?? 'المهنة';

  // دوال التحقق من اكتمال الملف الشخصي
  List<String> get missingProfileFields {
    final missing = <String>[];

    if (_user == null) return missing;

    if (_user!.phone == null || _user!.phone!.isEmpty) {
      missing.add('رقم الهاتف');
    }
    if (_user!.profession == null || _user!.profession!.isEmpty) {
      missing.add('المهنة');
    }
    if (_user!.gender == null || _user!.gender!.isEmpty) {
      missing.add('النوع');
    }

    return missing;
  }

  bool get isProfileComplete {
    if (_user == null) return false;

    // التحقق من الحقول الأساسية المطلوبة
    final hasPhone = _user!.phone != null && _user!.phone!.isNotEmpty;
    final hasProfession =
        _user!.profession != null && _user!.profession!.isNotEmpty;
    final hasGender = _user!.gender != null && _user!.gender!.isNotEmpty;

    print('🔍 التحقق من اكتمال الملف الشخصي:');
    print('   - الهاتف: $hasPhone (${_user!.phone})');
    print('   - المهنة: $hasProfession (${_user!.profession})');
    print('   - النوع: $hasGender (${_user!.gender})');

    return hasPhone && hasProfession && hasGender;
  }

  double get profileCompletionPercentage {
    if (_user == null) return 0.0;

    int totalFields = 3; // phone, profession, gender
    int completedFields = 0;

    if (_user!.phone != null && _user!.phone!.isNotEmpty) completedFields++;
    if (_user!.profession != null && _user!.profession!.isNotEmpty)
      completedFields++;
    if (_user!.gender != null && _user!.gender!.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }

  // دالة initialize
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ UserProvider already initialized');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await loadUserData();
      } else {
        print('ℹ️ No user logged in during initialization');
      }
      _isInitialized = true;
    } catch (e) {
      _error = 'Initialization error: $e';
      print('❌ Error initializing UserProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تعيين المستخدم
  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  // ⭐⭐ تحميل بيانات المستخدم من Firestore - محسنة
  Future<void> loadUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('⚠️ لا يوجد مستخدم مسجل دخول');
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('📥 جاري تحميل بيانات المستخدم: ${currentUser.uid}');
      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _user = UserModel.fromMap(data);
        print('✅ تم تحميل بيانات المستخدم: ${_user?.name}');
        print('📋 تفاصيل البيانات المحملة:');
        print('   - الهاتف: ${_user?.phone}');
        print('   - المهنة: ${_user?.profession}');
        print('   - النوع: ${_user?.gender}');
        print('   - تاريخ الميلاد: ${_user?.birthDate}');
      } else {
        print('⚠️ لا توجد بيانات للمستخدم في Firestore');
        _user = UserModel(
          id: currentUser.uid,
          email: currentUser.email,
          name: currentUser.displayName ?? 'مستخدم',
          phone: '',
          profession: '',
          gender: '',
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      _error = 'فشل في تحميل بيانات المستخدم: $e';
      print('❌ خطأ في loadUserData: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // حفظ المستخدم في Firestore مع دمج البيانات
  Future<bool> saveUserToFirestore(UserModel user) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .set(user.toMap(), SetOptions(merge: true));

      _user = user;
      print('✅ تم حفظ المستخدم في Firestore');
      return true;
    } catch (e) {
      _error = 'فشل في حفظ المستخدم: $e';
      print('❌ خطأ في saveUserToFirestore: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تحديث بيانات المستخدم
  Future<bool> updateUserInFirestore(Map<String, dynamic> updates) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _error = 'لا يوجد مستخدم مسجل دخول';
      return false;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _firestore.collection('users').doc(currentUser.uid).update(updates);

      // تحديث البيانات المحلية
      if (_user != null) {
        _user = _user!.copyWith(
          name: updates['name'] ?? _user!.name,
          phone: updates['phone'] ?? _user!.phone,
          profession: updates['profession'] ?? _user!.profession,
          birthDate: updates['birthDate'] ?? _user!.birthDate,
          gender: updates['gender'] ?? _user!.gender,
          location: updates['location'] ?? _user!.location,
          profileImage: updates['profileImage'] ?? _user!.profileImage,
          updatedAt: DateTime.now(),
        );
      }

      print('✅ تم تحديث بيانات المستخدم');
      return true;
    } catch (e) {
      _error = 'فشل في تحديث المستخدم: $e';
      print('❌ خطأ في updateUserInFirestore: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signOut();
      _user = null;
      _isInitialized = false;
      print('✅ تم تسجيل الخروج بنجاح');
    } catch (e) {
      _error = 'فشل في تسجيل الخروج: $e';
      print('❌ خطأ في logout: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // مسح الأخطاء
  void clearError() {
    _error = '';
    notifyListeners();
  }
}
