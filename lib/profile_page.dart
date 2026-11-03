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

Future<void> _editProfile(
    String uid, String first, String last, String username) async {
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (_) => EditProfileDialog(
      uid: uid,
      firstName: first,
      lastName: last,
      username: username,
    ),
  );

  if (result == null) return; // cancelled

  try {
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .set(result, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated!')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update profile: $e')),
    );
  }
}



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
                  final lastName = profile['last'] as String? ?? '';
                  final username = profile['username'] as String? ?? '';

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
                                ),
                              ),
                            ]
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit Profile',
                            onPressed: () => _editProfile(
                              user.uid,
                              firstName,
                              lastName,
                              username,
                            ),
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

class EditProfileDialog extends StatefulWidget {
  final String uid;
  final String firstName;
  final String lastName;
  final String username;

  const EditProfileDialog({
    super.key,
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.username,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _usernameController = TextEditingController(text: widget.username);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? 'Please enter $label' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'User Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, 'a username'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, 'your first name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, 'your last name'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'username': _usernameController.text.trim(),
              'first': _firstNameController.text.trim(),
              'last': _lastNameController.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}