import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snae3ya/models/worker_model.dart';
import 'package:snae3ya/widgets/customer/worker_card.dart';
import 'package:snae3ya/providers/worker_provider.dart';
import 'package:snae3ya/screens/customer/worker_profile_screen.dart';

class WorkersListScreen extends StatefulWidget {
  final String category;

  const WorkersListScreen({
    super.key,
    required this.category,
  });

  @override
  State<WorkersListScreen> createState() => _WorkersListScreenState();
}

class _WorkersListScreenState extends State<WorkersListScreen> {
  bool _sortByDistance = true;

  @override
  Widget build(BuildContext context) {
    final workerProvider = Provider.of<WorkerProvider>(context);
    final hasLocation = workerProvider.hasUserLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          if (hasLocation)
            IconButton(
              icon: Icon(
                _sortByDistance ? Icons.sort : Icons.sort_by_alpha,
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
      body: StreamBuilder<List<Worker>>(
        stream: workerProvider.getWorkersStream(profession: widget.category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('حدث خطأ: ${snapshot.error}'),
                ],
              ),
            );
          }

          var workers = snapshot.data ?? [];

          if (workers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد ${widget.category} متاحين حالياً',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // ترتيب حسب المسافة إذا كان مفعل
          if (_sortByDistance && hasLocation) {
            workers.sort((a, b) {
              final distA = _calculateDistance(a, workerProvider);
              final distB = _calculateDistance(b, workerProvider);
              return distA.compareTo(distB);
            });
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];
              final distance = _calculateDistance(worker, workerProvider);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: WorkerCard(
                  worker: worker,
                  distance: distance < 999999 ? distance : null,
                  showDistance: _sortByDistance && hasLocation && distance < 999999,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkerProfileScreen(
                          workerId: worker.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  double _calculateDistance(Worker worker, WorkerProvider provider) {
    if (!provider.hasUserLocation || 
        worker.latitude == null || 
        worker.longitude == null) {
      return 999999.0;
    }

    // هنا بنستخدم LocationService لحساب المسافة
    // مؤقتاً هنرجع قيمة كبيرة
    return 999999.0;
  }
}