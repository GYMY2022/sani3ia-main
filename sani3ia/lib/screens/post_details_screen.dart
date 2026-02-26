import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snae3ya/models/post_model.dart';
import 'package:snae3ya/providers/post_provider.dart';
import 'package:snae3ya/providers/application_provider.dart';
import 'package:snae3ya/screens/edit_post_screen.dart';
import 'package:snae3ya/screens/single_chat_screen.dart';
import 'package:snae3ya/services/notification_helper.dart'; // ⭐ إضافة

class PostDetailsScreen extends StatefulWidget {
  final Post post;

  const PostDetailsScreen({super.key, required this.post});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late Post _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyPost = currentUser != null && _post.authorId == currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنشور'),
        actions: [
          if (isMyPost)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  'منشورك',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معرض الصور
            _buildImageGallery(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات الناشر مع حالة الشغلانة
                  _buildAuthorInfo(isMyPost),

                  const SizedBox(height: 16),

                  // تفاصيل المنشور
                  _buildPostDetails(),

                  const SizedBox(height: 16),

                  // معلومات العامل إذا كانت الشغلانة متفق عليها
                  if (_post.isAgreed && _post.workerId != null)
                    _buildWorkerInfo(),

                  const SizedBox(height: 16),

                  // صور الإنجاز إذا كانت الشغلانة مكتملة
                  if (_post.isCompleted && _post.completionImages.isNotEmpty)
                    _buildCompletionImages(),

                  const SizedBox(height: 16),

                  // التقييم إذا كان موجوداً
                  if (_post.clientRating != null) _buildRatingInfo(),

                  const SizedBox(height: 16),

                  // الميزانية والتصنيف
                  _buildPostStats(),

                  const SizedBox(height: 24),

                  // أزرار الإجراءات
                  _buildActionButtons(context, isMyPost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: _post.images.isNotEmpty
          ? PageView.builder(
              itemCount: _post.images.length,
              itemBuilder: (context, index) => Image(
                image: _getImageProvider(_post.images[index]),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholderImage(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 80, color: Colors.grey),
          SizedBox(height: 8),
          Text('لا توجد صور', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAuthorInfo(bool isMyPost) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: _getImageProvider(_post.authorImage),
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.authorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _post.location,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            _buildJobStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobStatus() {
    if (_post.isAgreed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
            SizedBox(width: 4),
            Text(
              'قيد التنفيذ',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_post.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 4),
            Text(
              'مكتملة',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_post.isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cancel, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text(
              'ملغاة',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _post.isAvailable
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _post.isAvailable ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _post.isAvailable ? Icons.check_circle : Icons.cancel,
            color: _post.isAvailable ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            _post.isAvailable ? 'متوفرة' : 'غير متوفرة',
            style: TextStyle(
              color: _post.isAvailable ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerInfo() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الصنايعي المنفذ:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: _getImageProvider(_post.workerImage ?? ''),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post.workerName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_post.agreedAt != null)
                        Text(
                          'منذ ${_getTimeAgo(_post.agreedAt!)}',
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
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionImages() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'صور بعد الإنجاز:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _post.completionImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Image.network(
                              _post.completionImages[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _post.completionImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_post.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'تم الإنجاز: ${_formatDate(_post.completedAt!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingInfo() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < (_post.clientRating ?? 0).floor()
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${_post.clientRating}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_post.clientReview != null &&
                _post.clientReview!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${_post.clientReview}"',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _post.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _post.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(Icons.category, 'التصنيف', _post.category),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.attach_money,
              'الميزانية',
              '${_post.budget.toInt()} جنيه',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.location_on, 'الموقع', _post.location),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.visibility, 'المشاهدات', '${_post.views}'),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.person,
              'عدد المتقدمين',
              '${_post.applications}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isMyPost) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.grey,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
            );
          },
          child: const Text(
            'سجل الدخول للتقدم',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      );
    }

    if (!isMyPost) {
      return Consumer<ApplicationProvider>(
        builder: (context, applicationProvider, child) {
          final hasApplied = applicationProvider.hasAppliedForPost(_post.id);

          if (hasApplied) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                onPressed: () {
                  _openChatDirectly(context, _post);
                },
                child: const Text(
                  'فتح المحادثة للمتابعة',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            );
          }

          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              onPressed: () {
                _applyForJob(context, _post);
              },
              child: const Text(
                'التقدم لهذا العمل',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
            ),
            onPressed: () {
              _editPost(context, _post);
            },
            child: const Text(
              'تعديل المنشور',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: () {
              _deletePost(context, _post);
            },
            child: const Text(
              'حذف المنشور',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _toggleAvailability(context),
            icon: Icon(
              _post.isAvailable ? Icons.visibility_off : Icons.visibility,
              color: _post.isAvailable ? Colors.orange : Colors.green,
            ),
            label: Text(
              _post.isAvailable ? 'تعيين كغير متوفر' : 'تعيين كمتوفر',
              style: TextStyle(
                color: _post.isAvailable ? Colors.orange : Colors.green,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _post.isAvailable
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              side: BorderSide(
                color: _post.isAvailable ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else if (imagePath.contains('profile') || imagePath.contains('user')) {
      return const AssetImage('assets/images/default_profile.png');
    } else {
      return const AssetImage('assets/images/default_job_1.png');
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'لحظات';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openChatDirectly(BuildContext context, Post post) {
    print('🚀 فتح الشات مباشرة للشغلانة: ${post.title}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SingleChatScreen(
          userName: post.authorName,
          userImage: post.authorImage,
          receiverId: post.authorId,
          isOnline: true,
          postId: post.id,
          chatType: 'job',
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم فتح المحادثة للمتابعة'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _applyForJob(BuildContext context, Post post) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser!.uid == post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التقدم لشغلانتك الخاصة')),
      );
      return;
    }

    print('🚀 بدء عملية التقدم للشغلانة: ${post.title}');

    final applicationProvider = Provider.of<ApplicationProvider>(
      context,
      listen: false,
    );
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    applicationProvider
        .applyForJob(
          postId: post.id,
          postTitle: post.title,
          postOwnerId: post.authorId,
          postOwnerName: post.authorName,
          postOwnerImage: post.authorImage,
          message: 'هل الشغلانة "${post.title}" متوفرة؟',
        )
        .then((hasAppliedBefore) {
          if (hasAppliedBefore) {
            _openChatDirectly(context, post);
          } else {
            postProvider.incrementApplications(post.id);

            // ⭐ إرسال إشعار لصاحب الشغلانة
            NotificationHelper.sendNewJobApplicationNotification(
              postOwnerId: post.authorId,
              applicantId: currentUser.uid,
              applicantName: currentUser.displayName ?? 'مستخدم',
              postTitle: post.title,
              postId: post.id,
              applicantImage: currentUser.photoURL,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SingleChatScreen(
                  userName: post.authorName,
                  userImage: post.authorImage,
                  receiverId: post.authorId,
                  isOnline: true,
                  initialMessage: 'هل الشغلانة "${post.title}" متوفرة؟',
                  postId: post.id,
                  isFromJobApplication: true,
                  chatType: 'job',
                ),
              ),
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم التقدم للشغلانة وفتح المحادثة'),
                backgroundColor: Colors.green,
              ),
            );

            print('✅ تم التقدم للشغلانة بنجاح: ${post.title}');
          }
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في التقدم للشغلانة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
  }

  void _editPost(BuildContext context, Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditPostScreen(post: post)),
    );
  }

  void _deletePost(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المنشور'),
          content: const Text(
            'هل أنت متأكد أنك تريد حذف هذا المنشور وجميع الصور المرتبطة به؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final postProvider = Provider.of<PostProvider>(
                    context,
                    listen: false,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري حذف المنشور والصور...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await postProvider.deletePost(post.id);

                  Navigator.of(context).pop();
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف المنشور والصور بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل في الحذف: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAvailability(BuildContext context) {
    final newAvailability = !_post.isAvailable;
    final message = newAvailability
        ? 'تفعيل المنشور ليظهر للصنايعية'
        : 'تعطيل المنشور عن الظهور للصنايعية';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newAvailability ? 'تفعيل المنشور' : 'تعطيل المنشور'),
        content: Text('هل أنت متأكد من $message؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final postProvider = Provider.of<PostProvider>(
                  context,
                  listen: false,
                );
                await postProvider.setPostAvailability(
                  _post.id,
                  newAvailability,
                );

                setState(() {
                  _post = _post.copyWith(isAvailable: newAvailability);
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newAvailability
                            ? 'تم تفعيل المنشور بنجاح'
                            : 'تم تعطيل المنشور بنجاح',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل في تغيير حالة المنشور: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newAvailability ? Colors.green : Colors.orange,
            ),
            child: Text(newAvailability ? 'تفعيل' : 'تعطيل'),
          ),
        ],
      ),
    );
  }
}
