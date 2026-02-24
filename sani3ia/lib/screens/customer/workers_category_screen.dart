import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/models/worker_category_model.dart';
import 'package:snae3ya/screens/customer/workers_list_screen.dart';
import 'package:snae3ya/widgets/customer/worker_category_card.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/providers/worker_provider.dart';

class WorkersCategoryScreen extends StatefulWidget {
  const WorkersCategoryScreen({super.key});

  @override
  State<WorkersCategoryScreen> createState() => _WorkersCategoryScreenState();
}

class _WorkersCategoryScreenState extends State<WorkersCategoryScreen> {
  bool _sortByDistance = true;
  final double _searchRadius = 50;
  Map<String, int> _professionCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUserLocation();
      _loadProfessionCounts();
    });
  }

  Future<void> _updateUserLocation() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    await postProvider.updateUserLocation();
  }

  Future<void> _loadProfessionCounts() async {
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);
    final counts = await workerProvider.getProfessionCounts();
    setState(() {
      _professionCounts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر المهنة'),
        actions: [
          IconButton(
            icon: Icon(
              _sortByDistance ? Icons.sort_by_alpha : Icons.location_on,
              color: _sortByDistance ? Colors.blue : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _sortByDistance = !_sortByDistance;
              });
            },
            tooltip: _sortByDistance ? 'ترتيب حسب المسافة' : 'ترتيب عادي',
          ),
        ],
      ),
      body: Column(
        children: [
          if (postProvider.isLocationLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.blue,
              minHeight: 2,
            )
          else if (!postProvider.hasUserLocation && _sortByDistance)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange[100],
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تحديد موقعك. سيتم عرض المهن بدون ترتيب.',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                  TextButton(
                    onPressed: _updateUserLocation,
                    child: const Text('تحديد الموقع'),
                  ),
                ],
              ),
            ),

          if (_sortByDistance && postProvider.hasUserLocation)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم عرض الصنايعية الأقرب لموقعك أولاً (ضمن نطاق $_searchRadius كم)',
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: defaultCategories.length,
              itemBuilder: (context, index) {
                final category = defaultCategories[index];
                final count = _professionCounts[category.title] ?? 0;

                // إنشاء نسخة محدثة من التصنيف مع العدد الحقيقي
                final updatedCategory = WorkerCategory(
                  id: category.id,
                  title: category.title,
                  imagePath: category.imagePath,
                  color: category.color,
                  workerCount: count,
                );

                return WorkerCategoryCard(
                  category: updatedCategory,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            WorkersListScreen(category: category.title),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
