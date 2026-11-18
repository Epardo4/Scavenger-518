import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'media_details_page.dart';
import 'episode_details_page.dart';
import 'Models/media.dart';

// Type definitions to avoid nested angle bracket syntax issues
typedef ChatQuerySnapshot = QuerySnapshot<Map<String, dynamic>>;
typedef ChatDocumentSnapshot = DocumentSnapshot<Map<String, dynamic>>;
typedef UserCollectionReference = CollectionReference<Map<String, dynamic>>;

class Friend {
  final String uid;
  final String username;
  const Friend({required this.uid, required this.username});
}

class FriendRating {
  final Friend friend;
  final String docId;
  final Map<String, dynamic> data;
  const FriendRating({
    required this.friend,
    required this.docId,
    required this.data,
  });

  double get rating => (data['rating'] as num?)?.toDouble() ?? -1;
  bool get recommended => (data['recommended'] as bool?) ?? false;
  String get review => (data['review'] as String?)?.trim() ?? '';
  bool get isEpisode => data['seasonNumber'] != null;
  String get title => data['title'] as String? ?? 'Unknown Title';
  Timestamp? get timestamp => data['timestamp'] as Timestamp?;
}

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static String get me => FirebaseAuth.instance.currentUser!.uid;

  static String getChatId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  static Stream<ChatQuerySnapshot> getChatsStream() {
    return _db
        .collection('Chats')
        .where('participants', arrayContains: me)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  static Stream<ChatQuerySnapshot> getMessagesStream(String chatId) {
    return _db
        .collection('Chats')
        .doc(chatId)
        .collection('Messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Future<void> sendMessage({
    required String recipientUid,
    required String text,
    Map<String, dynamic>? recommendation,
  }) async {
    final chatId = getChatId(me, recipientUid);
    final chatRef = _db.collection('Chats').doc(chatId);

    final batch = _db.batch();
    batch.set(
      chatRef,
      {
        'participants': [me, recipientUid],
        'lastMessage': recommendation != null ? 'Recommended: ${recommendation['title']}' : text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final msgRef = chatRef.collection('Messages').doc();
    batch.set(msgRef, {
      'senderId': me,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'recommendation': ?recommendation,
    });

    await batch.commit();
  }
}

Future<void> showRecommendDialog(
  BuildContext context, {
  required int mediaId,
  required String mediaType,
  required String title,
  required String posterPath,
  int? seasonNumber,
  int? episodeNumber,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final friendSnap = await FirebaseFirestore.instance
      .collection('Users')
      .doc(user.uid)
      .collection('Friends')
      .get();
  
  final friends = friendSnap.docs
      .map((d) => Friend(uid: d.id, username: d.data()['username'] as String? ?? ''))
      .toList();

  if (friends.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You need to add friends before recommending titles!')),
    );
    return;
  }

  final selectedFriends = <String>{};
  final messageController = TextEditingController();

  // Format title nicely if it's an episode
  final displayTitle = seasonNumber != null && episodeNumber != null
      ? '$title (S${seasonNumber}E$episodeNumber)'
      : title;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Recommend "$displayTitle"'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select friends to send recommendation:'),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final f = friends[index];
                        final isSelected = selectedFriends.contains(f.uid);
                        return CheckboxListTile(
                          title: Text('@${f.username}'),
                          value: isSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedFriends.add(f.uid);
                              } else {
                                selectedFriends.remove(f.uid);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Optional message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedFriends.isEmpty
                    ? null
                    : () async {
                        final text = messageController.text.trim().isEmpty
                            ? 'Check out this recommendation!'
                            : messageController.text.trim();

                        final recommendationMap = <String, dynamic>{
                          'mediaId': mediaId,
                          'mediaType': mediaType,
                          'title': displayTitle,
                          'posterPath': posterPath,
                        };

                        if (seasonNumber != null && episodeNumber != null) {
                          recommendationMap['seasonNumber'] = seasonNumber;
                          recommendationMap['episodeNumber'] = episodeNumber;
                        }

                        for (final recipientUid in selectedFriends) {
                          await ChatService.sendMessage(
                            recipientUid: recipientUid,
                            text: text,
                            recommendation: recommendationMap,
                          );
                        }

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Recommendation sent successfully!')),
                        );
                      },
                child: const Text('Send'),
              ),
            ],
          );
        },
      );
    },
  );
}

class FriendsService {
  static final _db = FirebaseFirestore.instance;
  static String get me => FirebaseAuth.instance.currentUser!.uid;

  static UserCollectionReference _friends(String uid) =>
      _db.collection('Users').doc(uid).collection('Friends');

  static Stream<List<Friend>> friendsStream() => _friends(me).snapshots().map(
        (s) => s.docs
            .map((d) => Friend(
                  uid: d.id,
                  username: d.data()['username'] as String? ?? '',
                ))
            .toList(),
      );

  static Stream<ChatQuerySnapshot> incomingRequests() =>
      _db.collection('FriendRequests').where('to', isEqualTo: me).snapshots();

  static Stream<ChatQuerySnapshot> outgoingRequests() =>
      _db.collection('FriendRequests').where('from', isEqualTo: me).snapshots();

  static Future<List<Friend>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final snap = await _db
        .collection('Users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '$q\uf8ff')
        .limit(15)
        .get();
    return snap.docs
        .where((d) => d.id != me)
        .map((d) => Friend(
              uid: d.id,
              username: d.data()['username'] as String? ?? '',
            ))
        .toList();
  }

  static Future<void> sendRequest(Friend to) async {
    final myDoc = await _db.collection('Users').doc(me).get();
    final myUsername = myDoc.data()?['username'] as String? ?? '';
    await _db.collection('FriendRequests').doc('${me}_${to.uid}').set({
      'from': me,
      'to': to.uid,
      'fromUsername': myUsername,
      'toUsername': to.username,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> cancelOrDecline(String requestId) =>
      _db.collection('FriendRequests').doc(requestId).delete();

  static Future<void> acceptRequest(
      String requestId, String fromUid, String fromUsername) async {
    final myDoc = await _db.collection('Users').doc(me).get();
    final myUsername = myDoc.data()?['username'] as String? ?? '';

    final batch = _db.batch();
    batch.set(_friends(me).doc(fromUid), {
      'username': fromUsername,
      'since': FieldValue.serverTimestamp(),
    });
    batch.set(_friends(fromUid).doc(me), {
      'username': myUsername,
      'since': FieldValue.serverTimestamp(),
    });
    batch.delete(_db.collection('FriendRequests').doc(requestId));
    await batch.commit();
  }

  static Future<void> removeFriend(String friendUid) async {
    final batch = _db.batch();
    batch.delete(_friends(me).doc(friendUid));
    batch.delete(_friends(friendUid).doc(me));
    await batch.commit();
  }
}

class _FriendsData {
  final List<Friend> friends;
  final List<FriendRating> ratings;
  final Set<String> myRatedIds;
  const _FriendsData(this.friends, this.ratings, this.myRatedIds);
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late Future<_FriendsData> _future = _load();

  Future<_FriendsData> _load() async {
    final db = FirebaseFirestore.instance;
    final me = FirebaseAuth.instance.currentUser!.uid;

    final friendSnap =
        await db.collection('Users').doc(me).collection('Friends').get();
    final friends = friendSnap.docs
        .map((d) => Friend(
              uid: d.id,
              username: d.data()['username'] as String? ?? '',
            ))
        .toList();

    final mySnap =
        await db.collection('Users').doc(me).collection('Ratings').get();
    final myIds = mySnap.docs.map((d) => d.id).toSet();

    final lists = await Future.wait(friends.map((f) async {
      final s = await db
          .collection('Users')
          .doc(f.uid)
          .collection('Ratings')
          .orderBy('timestamp', descending: true)
          .limit(25)
          .get();
      return s.docs
          .map((d) => FriendRating(friend: f, docId: d.id, data: d.data()))
          .toList();
    }));

    final all = lists.expand((l) => l).toList()
      ..sort((a, b) {
        final ta = a.timestamp?.millisecondsSinceEpoch ?? 0;
        final tb = b.timestamp?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

    return _FriendsData(friends, all, myIds);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Activity'),
              Tab(text: 'For You'),
              Tab(text: 'Friends'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AsyncTab(
                  future: _future,
                  onRefresh: _refresh,
                  builder: (data) => _ActivityList(data: data),
                ),
                _AsyncTab(
                  future: _future,
                  onRefresh: _refresh,
                  builder: (data) => _RecommendationList(data: data),
                ),
                _ManageFriendsTab(onChanged: _refresh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Friend friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      await ChatService.sendMessage(
        recipientUid: widget.friend.uid,
        text: text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatId = ChatService.getChatId(ChatService.me, widget.friend.uid);

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.friend.username}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<ChatQuerySnapshot>(
              stream: ChatService.getMessagesStream(chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Say hello or send a recommendation!'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data();
                    final isMe = msg['senderId'] == ChatService.me;
                    final text = msg['text'] as String? ?? '';
                    final recommendation = msg['recommendation'] as Map<String, dynamic>?;

                   return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          // 1. Set background to transparent so it respects your theme background
                          color: Colors.transparent,
                          // 2. Add an outline border using theme colors
                          border: Border.all(
                            color: isMe 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.outline,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recommendation != null) ...[
                              InkWell(
                                onTap: () {
                                  final mediaId = (recommendation['mediaId'] as num?)?.toInt();
                                  final mediaTypeStr = recommendation['mediaType'] as String? ?? 'movie';
                                  final seasonNum = (recommendation['seasonNumber'] as num?)?.toInt();
                                  final episodeNum = (recommendation['episodeNumber'] as num?)?.toInt();

                                  if (mediaId != null) {
                                    if (seasonNum != null && episodeNum != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EpisodeDetailsPage(
                                            tvId: mediaId,
                                            seasonNumber: seasonNum,
                                            episodeNumber: episodeNum,
                                          ),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MediaDetailsPage(
                                            mediaId: mediaId,
                                            mediaType: mediaTypeStr == 'tv' ? MediaType.tv : MediaType.movie,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.movie, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          recommendation['title'] ?? 'Title',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // 3. Ensure text automatically adapts to theme text contrast
                            Text(
                              text, 
                              style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ); },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncTab extends StatelessWidget {
  final Future<_FriendsData> future;
  final Future<void> Function() onRefresh;
  final Widget Function(_FriendsData) builder;

  const _AsyncTab({
    required this.future,
    required this.onRefresh,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FriendsData>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your friends\' activity.'),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: onRefresh, child: const Text('Try Again')),
              ],
            ),
          );
        }
        return RefreshIndicator(onRefresh: onRefresh, child: builder(snap.data!));
      },
    );
  }
}

Widget _emptyScroll(String message) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        ),
      ],
    );

class _ActivityList extends StatelessWidget {
  final _FriendsData data;
  const _ActivityList({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.friends.isEmpty) {
      return _emptyScroll(
          'Add friends in the Friends tab to see what they\'re watching.');
    }
    if (data.ratings.isEmpty) {
      return _emptyScroll('Your friends haven\'t rated anything yet.');
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: data.ratings.length,
      itemBuilder: (_, i) =>
          RatingTile(item: data.ratings[i], showFriendName: true),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  final _FriendsData data;
  const _RecommendationList({required this.data});

  static const double _minRating = 8;

  @override
  Widget build(BuildContext context) {
    if (data.friends.isEmpty) {
      return _emptyScroll('Add friends to get recommendations from them.');
    }

    final Map<String, List<FriendRating>> grouped = {};
    for (final r in data.ratings) {
      if (r.isEpisode) continue;
      if (r.rating < _minRating) continue;
      if (data.myRatedIds.contains(r.docId)) continue;
      grouped.putIfAbsent(r.docId, () => []).add(r);
    }

    if (grouped.isEmpty) {
      return _emptyScroll(
          'No new recommendations yet. Titles your friends rate $_minRating+ '
          'that you haven\'t seen will show up here.');
    }

    double avg(List<FriendRating> l) =>
        l.map((e) => e.rating).reduce((a, b) => a + b) / l.length;

    final entries = grouped.values.toList()
      ..sort((a, b) {
        final c = b.length.compareTo(a.length);
        return c != 0 ? c : avg(b).compareTo(avg(a));
      });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final group = entries[i];
        final first = group.first;
        final names = group.map((g) => '@${g.friend.username}').join(', ');
        return _PosterCard(
          data: first.data,
          onTap: () => openMedia(context, first.data),
          children: [
            Text(first.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _TypeChip(isMovie: first.data['mediaType'] != 'tv'),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text('${avg(group).toStringAsFixed(1)} / 10 from friends',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text('Recommended by $names',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        );
      },
    );
  }
}

class _ManageFriendsTab extends StatefulWidget {
  final Future<void> Function() onChanged;
  const _ManageFriendsTab({required this.onChanged});

  @override
  State<_ManageFriendsTab> createState() => _ManageFriendsTabState();
}

class _ManageFriendsTabState extends State<_ManageFriendsTab> {
  final _searchController = TextEditingController();
  List<Friend> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    try {
      final r = await FriendsService.searchUsers(q);
      if (!mounted) return;
      setState(() => _results = r);
    } catch (e) {
      _snack('Search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send(Friend f) async {
    try {
      await FriendsService.sendRequest(f);
      _snack('Friend request sent to @${f.username}');
    } catch (e) {
      _snack('Could not send request: $e');
    }
  }

  Future<void> _accept(String id, String fromUid, String fromName) async {
    try {
      await FriendsService.acceptRequest(id, fromUid, fromName);
      _snack('You are now friends with @$fromName');
      await widget.onChanged();
    } catch (e) {
      _snack('Could not accept request: $e');
    }
  }

  Future<void> _remove(Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('Remove @${f.username} from your friends?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FriendsService.removeFriend(f.uid);
      await widget.onChanged();
    } catch (e) {
      _snack('Could not remove friend: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Friend>>(
      stream: FriendsService.friendsStream(),
      builder: (context, friendsSnap) {
        final friends = friendsSnap.data ?? [];
        final friendIds = friends.map((f) => f.uid).toSet();

        return StreamBuilder<ChatQuerySnapshot>(
          stream: FriendsService.outgoingRequests(),
          builder: (context, outSnap) {
            final pendingOut =
                (outSnap.data?.docs ?? []).map((d) => d.data()['to'] as String).toSet();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Find friends by username...',
                    prefixIcon: const Icon(Icons.person_search),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_hasSearched) ...[
                  const SizedBox(height: 8),
                  if (_results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('No users found. Usernames are case-sensitive.'),
                    ),
                  for (final r in _results)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text('@${r.username}'),
                      trailing: friendIds.contains(r.uid)
                          ? const Text('Friends')
                          : pendingOut.contains(r.uid)
                              ? const Text('Requested')
                              : ElevatedButton(
                                  onPressed: () => _send(r),
                                  child: const Text('Add')),
                    ),
                  const Divider(),
                ],
                StreamBuilder<ChatQuerySnapshot>(
                  stream: FriendsService.incomingRequests(),
                  builder: (context, inSnap) {
                    final docs = inSnap.data?.docs ?? [];
                    if (docs.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Text('Friend Requests',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        for (final d in docs)
                          ListTile(
                            leading:
                                const CircleAvatar(child: Icon(Icons.person_add)),
                            title: Text('@${d.data()['fromUsername'] ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  tooltip: 'Accept',
                                  onPressed: () => _accept(
                                    d.id,
                                    d.data()['from'] as String,
                                    d.data()['fromUsername'] as String? ?? '',
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.redAccent),
                                  tooltip: 'Decline',
                                  onPressed: () =>
                                      FriendsService.cancelOrDecline(d.id),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text('Your Friends (${friends.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No friends yet. Search for a username above!',
                        style: TextStyle(color: Colors.grey)),
                  ),
                for (final f in friends)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('@${f.username}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          tooltip: 'Chat',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ChatScreen(friend: f)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: 'Remove friend',
                          onPressed: () => _remove(f),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FriendProfilePage(friend: f)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class FriendProfilePage extends StatefulWidget {
  final Friend friend;
  const FriendProfilePage({super.key, required this.friend});

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    return Scaffold(
      appBar: AppBar(
        title: Text('@${f.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Chat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(friend: f)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<ChatDocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .doc(f.uid)
                .snapshots(),
            builder: (context, snap) {
              final Map<String, dynamic> p = snap.data?.data() ?? <String, dynamic>{};
              final name = '${p['first'] ?? ''} ${p['last'] ?? ''}'.trim();
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person,
                          size: 36, color: Colors.blue.shade800),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isNotEmpty ? name : f.username,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('@${f.username}',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Watched')),
              ButtonSegment(value: 1, label: Text('Reviews')),
              ButtonSegment(value: 2, label: Text('Recommended')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<ChatQuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(f.uid)
                  .collection('Ratings')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return const Center(child: Text('Could not load this profile.'));
                }
                var items = (snap.data?.docs ?? [])
                    .map((d) =>
                        FriendRating(friend: f, docId: d.id, data: d.data()))
                    .toList();

                String empty;
                if (_tab == 1) {
                  items = items.where((r) => r.review.isNotEmpty).toList();
                  empty = 'No reviews yet.';
                } else if (_tab == 2) {
                  items = items.where((r) => r.rating >= 8).toList()
                    ..sort((a, b) => b.rating.compareTo(a.rating));
                  empty = 'No recommendations yet.';
                } else {
                  empty = 'Nothing watched yet.';
                }

                if (items.isEmpty) {
                  return Center(
                      child: Text(empty,
                          style: const TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) =>
                      RatingTile(item: items[i], showFriendName: false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void openMedia(BuildContext context, Map<String, dynamic> data) {
  final id = (data['mediaId'] as num?)?.toInt();
  if (id == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MediaDetailsPage(
        mediaId: id,
        mediaType: data['mediaType'] == 'tv' ? MediaType.tv : MediaType.movie,
      ),
    ),
  );
}

class RatingTile extends StatelessWidget {
  final FriendRating item;
  final bool showFriendName;
  const RatingTile({
    super.key,
    required this.item,
    required this.showFriendName,
  });

  @override
  Widget build(BuildContext context) {
    final rated = item.rating != -1;
    return _PosterCard(
      data: item.data,
      onTap: () => openMedia(context, item.data),
      children: [
        if (showFriendName)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('@${item.friend.username}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary)),
          ),
        Text(item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _TypeChip(isMovie: item.data['mediaType'] != 'tv'),
        const SizedBox(height: 8),
        Row(children: [
          Icon(rated ? Icons.star : Icons.visibility,
              color: rated ? Colors.amber : Colors.blue, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              rated
                  ? '${item.rating.toStringAsFixed(0)} / 10'
                  : 'Watched, no rating',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        if (item.recommended) ...[
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.thumb_up, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text('Recommends this',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green)),
          ]),
        ],
        if (item.review.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(item.review,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.3)),
        ],
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final List<Widget> children;
  const _PosterCard({
    required this.data,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final posterPath = data['posterPath'] as String? ?? '';
    final posterUrl = posterPath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : '';
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 90,
                  child: posterUrl.isNotEmpty
                      ? Image.network(posterUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder())
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.movie, size: 30, color: Colors.grey),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final bool isMovie;
  const _TypeChip({required this.isMovie});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMovie ? Colors.blue[50] : Colors.purple[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isMovie ? 'MOVIE' : 'TV',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isMovie ? Colors.blue[800] : Colors.purple[800],
        ),
      ),
    );
  }
}