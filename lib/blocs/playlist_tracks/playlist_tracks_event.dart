part of 'playlist_tracks_bloc.dart';

abstract class PlaylistTracksEvent extends Equatable {
  const PlaylistTracksEvent();

  @override
  List<Object?> get props => [];
}

class PlaylistTracksReset extends PlaylistTracksEvent {
  @override
  List<Object?> get props => [];
}

class MoveTrack extends PlaylistTracksEvent {
  final int newIndex;
  final int oldIndex;
  final Playlist playlist;

  const MoveTrack({
    required this.newIndex,
    required this.oldIndex,
    required this.playlist,
  });
  @override
  List<Object?> get props => [newIndex, oldIndex, playlist];
}

class RemoveTrackFromPlaylist extends PlaylistTracksEvent {
  final Playlist playlist;
  final int index;

  const RemoveTrackFromPlaylist({
    required this.playlist,
    required this.index,
  });

  @override
  List<Object?> get props => [playlist, index];
}

class AddTrackToPlaylist extends PlaylistTracksEvent {
  final Track track;
  final Playlist playlist;
  final bool forceAdd;

  const AddTrackToPlaylist({
    required this.track,
    required this.playlist,
    this.forceAdd = false,
  });

  @override
  List<Object?> get props => [track, playlist, forceAdd];
}

class CreatePlaylistWithTrack extends PlaylistTracksEvent {
  final User? user;

  const CreatePlaylistWithTrack({this.user});
  @override
  List<Object?> get props => [
        user,
      ];
}

class SelectTrackForAddingToPlaylist extends PlaylistTracksEvent {
  final Track track;

  /// Used in [OverflowIconForTrack] in a [BasePlaylistScreen] or [SearchResult].
  const SelectTrackForAddingToPlaylist({required this.track});
  @override
  List<Object?> get props => [track];
}
