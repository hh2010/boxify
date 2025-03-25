import 'package:boxify/app_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

abstract class BaseUserRepository {
  Future<void> addUserPlaylist(String userId, String playlistId,
      {int? newLastPlaylistNumber});
  void connectDiscord({required User user, required String discordId});
  Future<List<User>> getAllArtists();
  Future<User> getUserWithId({required String userId});
  Future<User> getSelfUser(String userId);
  Future<void> updateUser({required User user});
  Future<List<User>> searchUsers({required String query});
  Future<List<User>> fetchUsersApi();
  void toggleUserSetting(
      {required User user, required bool value, required String field});
  void addRemoveUserBundles({
    required User user,
    required bool switchOff,
    required String bundleId,
  });
  void addRemoveUserBadges(
      {required User user, required bool switchOff, required String badge});
  void changeUsername({required User user, required String newUsername});
  Future<void> deleteUser(
    String id,
  );
  Future<bool> saveUserRecord(
      {required String username, required auth.User user});
}
