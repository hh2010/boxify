import 'package:boxify/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// A utility class for common playlist operations
class PlaylistUtils {
  /// Deletes a playlist and shows feedback to the user
  static void deletePlaylist(BuildContext context, Playlist playlist) {
    // Remove from library
    context.read<LibraryBloc>().add(
          RemovePlaylist(
            playlist: playlist,
            user: context.read<UserBloc>().state.user,
          ),
        );

    // Delete from database
    context.read<LibraryBloc>().add(
          DeletePlaylist(
            playlistId: playlist.id!,
          ),
        );

    // Navigate to home screen
    GoRouter.of(context).go('/');

    // Show feedback
    showMySnack(context, message: 'Deleted ${playlist.name} playlist');
  }

  /// Compares two track lists to see if they contain the same tracks in the same order
  static bool areTracksEqual(List<Track> list1, List<Track> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].uuid != list2[i].uuid) return false;
    }

    return true;
  }

  /// Finds tracks that exist in the original list but not in the current list
  static List<Track> getDeletedTracks(
      List<Track> original, List<Track> current) {
    return original.where((track) {
      return !current.any((t) => t.uuid == track.uuid);
    }).toList();
  }
}
