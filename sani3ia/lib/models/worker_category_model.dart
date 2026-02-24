import 'package:flutter/material.dart';

class WorkerCategory {
  final String id;
  final String title;
  final String imagePath;
  final Color color;
  final int workerCount;

  WorkerCategory({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.color,
    required this.workerCount,
  });

  // دالة لإنشاء تصنيف من Map
  factory WorkerCategory.fromMap(Map<String, dynamic> map, String documentId) {
    return WorkerCategory(
      id: documentId,
      title: map['title'] ?? '',
      imagePath: map['imagePath'] ?? 'assets/images/default_job_1.png',
      color: Color(map['color'] ?? 0xFF2196F3),
      workerCount: map['workerCount'] ?? 0,
    );
  }

  // دالة لتحويل التصنيف إلى Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imagePath': imagePath,
      'color': color.value,
      'workerCount': workerCount,
    };
  }
}

// قائمة التصنيفات الأساسية (يمكن تخزينها في Firebase لاحقاً)
final List<WorkerCategory> defaultCategories = [
  WorkerCategory(
    id: 'c1',
    title: 'نجارين',
    imagePath: 'assets/images/carpenter_category.png',
    color: const Color(0xFF8D6E63),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c2',
    title: 'سباكين',
    imagePath: 'assets/images/plumber_category.png',
    color: const Color(0xFF2196F3),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c3',
    title: 'كهرباء',
    imagePath: 'assets/images/electrician_category.png',
    color: const Color(0xFFFFEB3B),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c4',
    title: 'بناء',
    imagePath: 'assets/images/builder_category.png',
    color: const Color(0xFFFF9800),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c5',
    title: 'دهانين',
    imagePath: 'assets/images/painter_category.png',
    color: const Color(0xFF9C27B0),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c6',
    title: 'تكييفات',
    imagePath: 'assets/images/ac_technician_category.png',
    color: const Color(0xFF00BCD4),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c7',
    title: 'ميكانيكا',
    imagePath: 'assets/images/mechanic_category.png',
    color: const Color(0xFF795548),
    workerCount: 0,
  ),
  WorkerCategory(
    id: 'c8',
    title: 'حدادين',
    imagePath: 'assets/images/blacksmith_category.png',
    color: const Color(0xFF607D8B),
    workerCount: 0,
  ),
];
