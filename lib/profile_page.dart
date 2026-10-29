
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'media_details_page.dart';
import 'Models/media.dart';
import 'home_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Make sure a user is logged in.
    if (user == null) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        return userDoc.data();
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('Error getting user data: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .collection('Ratings')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'You haven\'t rated any titles yet!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final mediaId = data['mediaId'] as int;
                    final mediaTypeStr = data['mediaType'] as String;
                    final title = data['title'] as String? ?? 'Unknown Title';
                    final posterPath = data['posterPath'] as String? ?? '';
                    final userRating = (data['rating'] as num?)?.toDouble() ?? 0.0;

                    final mediaType = mediaTypeStr == 'tv' ? MediaType.tv : MediaType.movie;
                    final posterUrl = posterPath.isNotEmpty
                        ? 'https://image.tmdb.org/t/p/w500$posterPath'
                        : '';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MediaDetailsPage(
                                mediaId: mediaId,
                                mediaType: mediaType,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 60,
                                  height: 90,
                                  child: posterUrl.isNotEmpty
                                      ? Image.network(
                                          posterUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _posterPlaceholder(),
                                        )
                                      : _posterPlaceholder(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: mediaType == MediaType.movie
                                                ? Colors.blue[50]
                                                : Colors.purple[50],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            mediaType == MediaType.movie ? 'MOVIE' : 'TV',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: mediaType == MediaType.movie
                                                  ? Colors.blue[800]
                                                  : Colors.purple[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Your Rating: ${userRating.toStringAsFixed(0)} / 10',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.movie, size: 30, color: Colors.grey),
      ),
    );
  }

  Widget mediaListBuild(BuildContext context){
    return DefaultTabController(
      length: 2,
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
            ),
                    TabBar(
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: 'To-Watch List'),
                        Tab(text: 'Watched List')
                      ],
                    ),
                    Expanded(
                       child: TabBarView(
                          children: [
                            Center(child: Text('View for To-Watch List')),
                            Center(child: Text('View for Watched List'))
                          ]
                        )
                      )
          ]
        )

    );
  }
}
