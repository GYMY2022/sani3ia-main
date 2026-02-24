import 'package:flutter/material.dart';
import 'package:snae3ya/models/worker_category_model.dart';

final List<WorkerCategory> dummyWorkerCategories = [
  WorkerCategory(
    id: 'c1',
    title: 'نجارين',
    imagePath: 'assets/images/carpenter_category.png',
    color: Color(0xFF8D6E63), // بني خشبي
    workerCount: 24,
  ),
  WorkerCategory(
    id: 'c2',
    title: 'سباكين',
    imagePath: 'assets/images/plumber_category.png',
    color: Color(0xFF2196F3), // أزرق
    workerCount: 18,
  ),
  WorkerCategory(
    id: 'c3',
    title: 'كهرباء',
    imagePath: 'assets/images/electrician_category.png',
    color: Color(0xFFFFEB3B), // أصفر
    workerCount: 15,
  ),
  WorkerCategory(
    id: 'c4',
    title: 'بناء',
    imagePath: 'assets/images/builder_category.png',
    color: Color(0xFFFF9800), // برتقالي
    workerCount: 32,
  ),
  WorkerCategory(
    id: 'c5',
    title: 'دهانين',
    imagePath: 'assets/images/painter_category.png',
    color: Color(0xFF9C27B0), // بنفسجي
    workerCount: 12,
  ),
  WorkerCategory(
    id: 'c6',
    title: 'تكييفات',
    imagePath: 'assets/images/ac_technician_category.png',
    color: Color(0xFF00BCD4), // سماوي
    workerCount: 8,
  ),
  WorkerCategory(
    id: 'c7',
    title: 'ميكانيكا',
    imagePath: 'assets/images/mechanic_category.png',
    color: Color(0xFF795548), // بني
    workerCount: 14,
  ),
  WorkerCategory(
    id: 'c8',
    title: 'حدادين',
    imagePath: 'assets/images/blacksmith_category.png',
    color: Color(0xFF607D8B), // أزرق رمادي
    workerCount: 9,
  ),
];
