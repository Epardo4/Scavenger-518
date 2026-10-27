import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stores ratings at: Users/{uid}/ratings/{key}
///   movie  -> key = movie_{id}
///   episode -> key = tv_{tvId}_s{season}_e{episode}

class Ratings {
    
  final FirebaseAuth _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? get _ratings {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('Users').doc(uid).collection('ratings');
  }

  static String movieKey(int movieId) => 'movie_$movieId';
  static String episodeKey(int tvId, int season, int episode) => 'tv_$tvId_s$season_e$episode';

  Stream<int> movieRating(int movieId){
    final col = _ratings;
    if (col == null) return Stream.value(0);
    return col.doc(movieKey(movieId)).snapshots().map((snapshot) => snapshot.data()?['rating'] ?? 0);
  } 
  
  }
