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
  bool showRated = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : Column(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('Users')
                  .doc(user.uid).snapshots(),
                builder: (context, snapshot){
                  final profile = snapshot.data?.data() ?? {};
                  final firstName = profile['first'] as String? ?? '';
                  final lastName = profile['last'] as String ?;
                  final username = profile['username'] as String ?;

                  final fullName = '$firstName $lastName'.trim();

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20,24,20,20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.blue.shade800
                          )
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isNotEmpty ? fullName : 'Your Name',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold
                                )
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@$username',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600
                                )
                              )
                            ]
                          )
                        )
                      ]
                    )
                  );
                }
              ),

              const Divider(height: 1),

              const SizedBox(height: 16),
              ToggleButtons(
                isSelected: [showRated, !showRated],
                onPressed: (index) {
                  setState(() {
                    showRated = index == 0;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                selectedColor: Colors.white,
                fillColor: Colors.blue,
                color: Colors.white,
                constraints: const BoxConstraints(
                  minHeight: 42,
                  minWidth: 120
                ),
                children: const [
                  Text('Watched'),
                  Text('To-Watch')
                ]
              ),

              const SizedBox(height: 16),
                  
              Expanded(
                child:  StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .collection(showRated ? 'Ratings' : 'Watchlist')
                  .orderBy(showRated ? 'timestamp' : 'addedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return
                  showRated ?
                  const Center(
                    child: Text(
                      'You haven\'t rated any titles yet!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ) :
                  const Center(
                    child: Text(
                      'You haven\'t added any titles to your to-watch list yet!'
                    )
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
                    final userRating = 
                    showRated ? (data['rating'] as num?)?.toDouble() ?? 0.0 : -1;

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
                                    showRated ?
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
                                    ) : Row(
                                      children: [
                                        const SizedBox(width: 30)
                                      ]
                                    )
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
            )
              ])
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
}