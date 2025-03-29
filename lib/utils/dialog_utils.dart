import 'package:boxify/app_core.dart';
import 'package:flutter/material.dart';

/// A utility class to centralize and standardize dialogs across the application
class DialogUtils {
  /// Shows a confirmation dialog before deleting a playlist
  static Future<bool?> showDeletePlaylistConfirmation(
      BuildContext context, Playlist playlist) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('deletePlaylist'.translate()),
          content: Text('areYouSureDeletePlaylist'.translate()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.translate()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('delete'.translate()),
            ),
          ],
        );
      },
    );
  }

  /// Shows a confirmation dialog when a duplicate track is detected in a playlist
  static Future<bool?> showDuplicateTrackConfirmation(
      BuildContext context, Track track, Playlist playlist) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('duplicateTrack'.translate()),
          content: Text('duplicateTrackWarning'
              .translate()
              .replaceAll('{trackTitle}', track.displayTitle)
              .replaceAll('{playlistName}',
                  playlist.name ?? playlist.displayTitle ?? '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.translate()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('addAnyway'.translate()),
            ),
          ],
        );
      },
    );
  }
}
