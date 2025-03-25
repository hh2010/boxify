import 'dart:convert';

import 'package:boxify/app_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:http/http.dart' as http;

import 'base_user_repository.dart';

class UserRepository extends BaseUserRepository {
  final FirebaseFirestore _firebaseFirestore;
  final CacheHelper _cacheHelper;

  UserRepository({
    FirebaseFirestore? firebaseFirestore,
    required CacheHelper cacheHelper,
  })  : _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance,
        _cacheHelper = cacheHelper;

  Future<void> clearUserCache(String userId) async {
    await _cacheHelper.clearSpecific(CacheHelper.keyForUser(userId));
  }

  Future<void> clearArtistsCache() async {
    await _cacheHelper.clearSpecific(CacheHelper.KEY_ARTISTS);
  }

  @override

  /// Adds a playlistId to a user's playlistIds array.
  /// Also updates the user's lastPlaylistNumber if the user just created this playlist.
  Future<void> addUserPlaylist(String userId, String playlistId,
      {int? newLastPlaylistNumber}) async {
    await _firebaseFirestore.collection(Paths.users).doc(userId).update({
      'playlistIds': FieldValue.arrayUnion([playlistId]),
      'lastPlaylistNumber': newLastPlaylistNumber
    });
  }

  @override
  Future<void> deleteUser(String userId) async {
    logger.i('deleteing $userId');
    await _firebaseFirestore.collection(Paths.users).doc(userId).delete();
    logger.i('deleting playlists');
    // But this doesn't delete the playlistIds from other users' followed playlists arrays
    await _firebaseFirestore
        .collection(Paths.playlists)
        .where('owner.id', isEqualTo: userId)
        .get()
        .then(
          (res) => res.docs.forEach(
            (doc) => _firebaseFirestore
                .collection(Paths.playlists)
                .doc(doc.id)
                .delete(),
          ),
          onError: (e) => logger.i("Error completing: $e"),
        );
    logger.i('deleting ratings');
    await _firebaseFirestore
        .collection(Paths.ratings)
        .where('userId', isEqualTo: userId)
        .get()
        .then(
          (res) => res.docs.forEach(
            (doc) => _firebaseFirestore
                .collection(Paths.ratings)
                .doc(doc.id)
                .delete(),
          ),
          onError: (e) => logger.i("Error completing: $e"),
        );
  }

  @override
  Future<void> connectDiscord({
    required User user,
    required String discordId,
  }) async {
    // logger.i(user.banned);
    discordId = discordId.replaceAll('<@!', '').replaceAll('>', '').trim();
    try {
      await _firebaseFirestore
          .collection(Paths.users)
          .doc(user.id)
          .update({'discordId': discordId});
    } catch (err) {
      logger.i('user_repo connectDiscord error: $err');
    }
    // logger.i('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    // logger.i(user.banned);
  }

  /// Fetches a user with the given [userId] from the Firestore collection
  /// or returns a cached user if offline.
  /// When fetching the currently logged-in user, it is better to use the [getSelfUser] method.
  @override
  Future<User> getUserWithId({required String userId}) async {
    logger.i('getUserWithId: $userId');

    if (ConnectivityManager.instance.currentStatus == ConnectivityResult.none) {
      // Offline, get user from cache
      return getUserFromCacheWithException(userId);
    } else {
      // Online, fetch from Firestore
      try {
        final userDocRef =
            _firebaseFirestore.collection(Paths.users).doc(userId);
        final doc = await userDocRef.get();

        if (doc.exists) {
          // User exists
          final user = User.fromDocument(doc);
          return user;
        } else {
          logger.i('No user doc found, returning empty user');
          final user = User.empty.copyWith(id: userId);
          return user;
        }
      } catch (e) {
        logger.e('Error fetching user data: $e');
        return getUserFromCacheWithException(userId);
      }
    }
  }

  /// Fetches the currently logged-in user from Firestore.
  /// If offline, it attempts to get the user from the cache.
  /// If the user is not found in the cache, it returns an empty user.
  ///
  /// This method will update the user's last seen timestamp in Firestore
  /// and cache the user data, unlike the [getUserWithId] method.
  @override
  Future<User> getSelfUser(String userId) async {
    logger.i('getSelfUser: $userId');

    if (ConnectivityManager.instance.currentStatus == ConnectivityResult.none) {
      // Offline, get user from cache
      return getUserFromCacheWithException(userId);
    } else {
      // Online, fetch from Firestore
      try {
        final userDocRef =
            _firebaseFirestore.collection(Paths.users).doc(userId);
        final doc = await userDocRef.get();

        if (doc.exists) {
          logger.i('User exists, updating lastSeen timestamp');
          await userDocRef.update({'lastSeen': DateTime.now()});
          final user = User.fromDocument(doc);

          // Save user to cache
          await _cacheHelper.saveUser(user);

          return user;
        } else {
          logger.i('No user doc found, returning empty user');
          final user = User.empty.copyWith(id: userId);
          return user;
        }
      } catch (e) {
        logger.e('Error fetching user data: $e');
        return getUserFromCacheWithException(userId);
      }
    }
  }

  /// Returns user from cache, or raises an exception if not found.
  Future<User> getUserFromCacheWithException(String userId) async {
    final cachedUser = await getUserFromCache(userId);
    if (cachedUser != null) {
      logger.i('Returning cached user data');
      return cachedUser;
    } else {
      logger.e('No cached user data available.');
      throw CacheException('No cached user data available.');
    }
  }

  /// Returns a user from Firestore or cache. Returns null if not found.
  Future<User?> getUserFromCache(String userId) async {
    return _cacheHelper.getUser(userId);
  }

  @override
  Future<void> updateUser({required User? user}) async {
    await _firebaseFirestore
        .collection(Paths.users)
        .doc(user!.id)
        .update(user.toDocument());
  }

  @override
  Future<void> toggleUserSetting({
    required User user,
    required String field,
    required bool value,
  }) async {
    // logger.i(user.banned);
    await _firebaseFirestore
        .collection(Paths.users)
        .doc(user.id)
        .update({field: !value});
  }

  @override
  Future<void> addRemoveUserBundles({
    required User user,
    required String bundleId,
    required bool switchOff,
  }) async {
    logger.i(
        'addRemoveUserbundleIds | bundleId: $bundleId | switchOff: $switchOff');

    switchOff
        ? await _firebaseFirestore.collection(Paths.users).doc(user.id).update({
            'bundleIds': FieldValue.arrayRemove([bundleId])
          })
        : await _firebaseFirestore.collection(Paths.users).doc(user.id).update({
            'bundleIds': FieldValue.arrayUnion([bundleId])
          });
  }

  @override
  Future<void> addRemoveUserBadges({
    required User user,
    required String badge,
    required bool switchOff,
  }) async {
    logger.i('addRemoveUserBadges');

    logger.i(user);
    logger.i(badge);
    logger.i(switchOff);
    switchOff
        ? await _firebaseFirestore.collection(Paths.users).doc(user.id).update({
            'badges': FieldValue.arrayRemove([badge])
          })
        : await _firebaseFirestore.collection(Paths.users).doc(user.id).update({
            'badges': FieldValue.arrayUnion([badge])
          });
    // logger.i('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    // logger.i(user.banned);
  }

  @override
  Future<void> changeUsername({
    required User? user,
    required String? newUsername,
  }) async {
    await _firebaseFirestore
        .collection(Paths.users)
        .doc(user!.id)
        .update({'username': newUsername});
  }

  @override
  Future<List<User>> searchUsers({required String? query}) async {
    final userSnap = await _firebaseFirestore
        .collection(Paths.users)
        .where('username', isGreaterThanOrEqualTo: query)
        .limit(10) // I added
        .get();
    return userSnap.docs.map((doc) => User.fromDocument(doc)).toList();
  }

  @override
  Future<List<User>> fetchUsersApi() async {
    logger.i('searchUsersApi: $Core.app.usersAPIUrl');
    final response = await http.get(
      Uri.parse(Core.app.usersAPIUrl),
      headers: {
        'TOKEN': Core.app.serverToken,
        'userId': '8',
      },
    );
    try {
      // // Notice how you have to call body from the response if you are using http to retrieve json
      final body = json.decode(response.body);
      final data = body['users'] as List<dynamic>;
      final users = data
          .map((dynamic item) => User.fromJson(item as Map<String, dynamic>))
          .toList();
      return users;
    } catch (err) {
      logger.i('user_repo fetchUsersApi error: $err');
      return [];
    }
  }

  @override
  Future<List<User>> getAllArtists() async {
    logger.i('getAllArtists()');

    if (ConnectivityManager.instance.currentStatus == ConnectivityResult.none) {
      // Offline, get artists from cache
      return getArtistsFromCache();
    } else {
      // Online, fetch from Firestore
      try {
        final userSnap = await _firebaseFirestore
            .collection(Paths.users)
            .where('artist', isEqualTo: true)
            .get();

        final artists =
            userSnap.docs.map((doc) => User.fromDocument(doc)).toList();

        // Save artists to cache
        await _cacheHelper.saveArtists(artists);

        return artists;
      } catch (e) {
        logger.e('Error fetching artists: $e');
        // Return cached artists if available
        return getArtistsFromCache();
      }
    }
  }

  /// Returns artists from cache
  Future<List<User>> getArtistsFromCache() async {
    final cachedArtists = await _cacheHelper.getArtists();
    if (cachedArtists != null) {
      logger.i('Returning cached artists');
      return cachedArtists;
    } else {
      logger.e('No cached artists available.');
      return [];
    }
  }

  // @override
  // Future<List<User>> getAllArtists() async {
  //   logger.i('getAllArtists()');
  //   final userSnap = await _firebaseFirestore
  //       .collection(Paths.users)
  //       .where('artist', isEqualTo: true)
  //       // .limit(10) // I added
  //       .get();
  //   return userSnap.docs.map((doc) => User.fromDocument(doc)).toList();
  // }

  /// This is actually the function that creates the user record
  @override
  Future<bool> saveUserRecord({
    required String username,
    required auth.User user,
  }) async {
    logger.i('saveUserRecord$username');

    // Check if someone already has the username
    final result = await _firebaseFirestore
        .collection(Paths.users)
        .where('username', isEqualTo: username)
        .get();
    // If someone already has the username, fail
    if (result.docs.isNotEmpty) {
      return false;
    }
    await _firebaseFirestore.collection(Paths.users).doc(user.uid).set({
      'username': username, // + 'as;dlkfj',
      'email': user.email,
      'playlistIds': Core.app.defaultPlaylistIds,
      'lastSeen': DateTime.now(),
      'registeredOn': DateTime.now(),
    });

    return true;
  }
}
