// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// /// Stores ratings at: Users/{uid}/ratings/{key}
// ///   movie  -> key = movie_{id}
// ///   episode -> key = tv_{tvId}_s{season}_e{episode}

// class Ratings {
    
//   final FirebaseAuth _db = FirebaseFirestore.instance;

//   CollectionReference<Map<String, dynamic>>? get _ratings {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return null;
//     return _db.collection('Users').doc(uid).collection('ratings');
//   }

//   static String movieKey(int movieId) => 'movie_$movieId';
//   static String episodeKey(int tvId, int season, int episode) => 'tv_$tvId_s$season_e$episode';

//   Stream<int> movieRating(int movieId){
//     final col = _ratings;
//     if (col == null) return Stream.value(0);
//     return col.doc(movieKey(movieId)).snapshots().map((doc) => doc.data()?['rating'] as num?)?.toInt() ?? 0,
//     );
//   }

//   Stream<Map<String, int>> tvRating(int tvId){
//     final col = _ratings;
//     if (col == null) return Stream.value({});
//     return col
//     .where('mediaType', isEqualTo: 'tv')
//     .where('mediaId', isEqualTo: tvId)
//     .snapshots()
//     .map((snap) => 
//       for (final doc in snap.docs) 
//         doc.id: doc.data()?['rating'] as num?),?.toInt() ?? 0,
//       }
//     };
  


// Future<void> movieRating(int movieId, int rating){
//   return _save(
//     movieKey(movieId),
//     rating,
//     {'mediaType': 'movie', 'mediaId': movieId},
//   );
// }

// Future<void> episodeRating(int tvId, int season, int episode, int rating){
//   return _save(
//     episodeKey(tvId, season, episode),
//     rating,
//     {'mediaType': 'tv', 'mediaId': tvId, 'season': season, 'episode': episode},
//   );
// }

// Future<void> _save(String key, int rating, Map<String, dynamic> meta) async{
//   final col = _ratings;
//   if (col == null) return;
  
//   if (rating <= 0) {
//     await col.doc(key).delete();
//     return;
//   }
//   await col.doc(key).set({
//     ...meta,
//     'rating': rating.clamp(1,5),
//     'updatedAt': FieldValue.serverTimestamp(),
//   });
// }
