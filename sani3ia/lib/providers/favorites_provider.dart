import 'package:flutter/foundation.dart';
import 'package:snae3ya/models/post_model.dart';

class FavoritesProvider with ChangeNotifier {
  final List<Post> _favoritePosts = [];

  List<Post> get favoritePosts => _favoritePosts;

  void toggleFavorite(Post post) {
    final isExisting = _favoritePosts.any((p) => p.id == post.id);
    if (isExisting) {
      _favoritePosts.removeWhere((p) => p.id == post.id);
    } else {
      _favoritePosts.add(post.copyWith(isFavorite: true));
    }
    notifyListeners();
  }

  bool isFavorite(String postId) {
    return _favoritePosts.any((p) => p.id == postId);
  }
}
