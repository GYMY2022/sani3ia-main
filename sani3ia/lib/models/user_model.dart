import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? profileImage;
  final String? profession;
  final Map<String, dynamic>? location;
  final String? birthDate;
  final String? gender;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isEmailVerified;

  // حقول للموقع الجغرافي
  final double? latitude;
  final double? longitude;
  final String? fullAddress;

  // ⭐⭐ حقل جديد للنبذة
  final String? bio;

  const UserModel({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.profileImage,
    this.profession,
    this.location,
    this.birthDate,
    this.gender,
    this.address,
    this.createdAt,
    this.updatedAt,
    this.isEmailVerified = false,
    this.latitude,
    this.longitude,
    this.fullAddress,
    this.bio, // ⭐⭐ إضافة حقل bio
  });

  // إنشاء مستخدم فارغ
  factory UserModel.empty() {
    return const UserModel(
      id: '',
      name: '',
      email: '',
      phone: '',
      profileImage: '',
      profession: '',
      location: null,
      birthDate: '',
      gender: '',
      address: '',
      isEmailVerified: false,
      latitude: null,
      longitude: null,
      fullAddress: null,
      bio: null,
    );
  }

  // تحويل من Map إلى UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // استخراج بيانات الموقع
    Map<String, dynamic>? locationData;
    if (map['location'] != null) {
      if (map['location'] is Map) {
        locationData = Map<String, dynamic>.from(map['location']);
      } else {
        locationData = {'text': map['location'].toString()};
      }
    }

    // معالجة التاريخ بشكل صحيح
    DateTime? createdAt;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(map['createdAt']);
      }
    }

    DateTime? updatedAt;
    if (map['updatedAt'] != null) {
      if (map['updatedAt'] is Timestamp) {
        updatedAt = (map['updatedAt'] as Timestamp).toDate();
      } else if (map['updatedAt'] is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(map['updatedAt']);
      }
    }

    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      profileImage: map['profileImage'],
      profession: map['profession'],
      location: locationData,
      birthDate: map['birthDate'],
      gender: map['gender'],
      address: map['address'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      isEmailVerified: map['isEmailVerified'] ?? false,
      latitude: locationData?['latitude'] ?? map['latitude'],
      longitude: locationData?['longitude'] ?? map['longitude'],
      fullAddress: locationData?['fullAddress'] ?? map['fullAddress'],
      bio: map['bio'], // ⭐⭐ إضافة bio
    );
  }

  // تحويل UserModel إلى Map
  Map<String, dynamic> toMap() {
    // دمج بيانات الموقع مع الإحداثيات
    Map<String, dynamic>? finalLocation;
    if (location != null) {
      finalLocation = Map<String, dynamic>.from(location!);
      if (latitude != null) finalLocation['latitude'] = latitude;
      if (longitude != null) finalLocation['longitude'] = longitude;
      if (fullAddress != null) finalLocation['fullAddress'] = fullAddress;
    } else if (latitude != null || longitude != null || fullAddress != null) {
      finalLocation = {};
      if (latitude != null) finalLocation['latitude'] = latitude;
      if (longitude != null) finalLocation['longitude'] = longitude;
      if (fullAddress != null) finalLocation['fullAddress'] = fullAddress;
    }

    return {
      'id': id ?? '',
      'name': name ?? '',
      'email': email ?? '',
      'phone': phone ?? '',
      'profileImage': profileImage,
      'profession': profession,
      'location': finalLocation,
      'birthDate': birthDate,
      'gender': gender,
      'address': address,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'isEmailVerified': isEmailVerified,
      'bio': bio, // ⭐⭐ إضافة bio
    };
  }

  // دالة copyWith
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? profession,
    Map<String, dynamic>? location,
    String? birthDate,
    String? gender,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEmailVerified,
    double? latitude,
    double? longitude,
    String? fullAddress,
    String? bio, // ⭐⭐ إضافة bio
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      profession: profession ?? this.profession,
      location: location ?? this.location,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      fullAddress: fullAddress ?? this.fullAddress,
      bio: bio ?? this.bio, // ⭐⭐ إضافة bio
    );
  }

  // دالة للتحقق من وجود موقع جغرافي كامل
  bool get hasGeoLocation {
    return latitude != null && longitude != null;
  }

  // دالة للحصول على عنوان الموقع كامل
  String get displayAddress {
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      return fullAddress!;
    } else if (address != null && address!.isNotEmpty) {
      return address!;
    } else if (location != null && location!.isNotEmpty) {
      final country = location!['country'] ?? '';
      final governorate = location!['governorate'] ?? '';
      final city = location!['city'] ?? '';
      final area = location!['area'] ?? '';
      return '$area, $city, $governorate, $country'
          .replaceAll(', ,', ',')
          .replaceAll(',  ', '');
    } else {
      return 'عنوان غير محدد';
    }
  }

  // دالة للتحقق من أن المستخدم فارغ
  bool get isEmpty {
    return id == null || id!.isEmpty;
  }

  // دالة للتحقق من أن المستخدم غير فارغ
  bool get isNotEmpty {
    return !isEmpty;
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, phone: $phone, profession: $profession, hasGeoLocation: $hasGeoLocation)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
