import 'dart:async';
import 'dart:io';

import 'package:boxify/app_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
// needed in playlist_event

part 'playlist_tracks_event.dart';
part 'playlist_tracks_state.dart';

class PlaylistTracksBloc
    extends Bloc<PlaylistTracksEvent, PlaylistTracksState> {
  final PlaylistRepository _playlistRepository;

  PlaylistTracksBloc({
    required PlaylistRepository playlistRepository,
  })  : _playlistRepository = playlistRepository,
        super(PlaylistTracksState.initial()) {
    /// PlaylistTracks Bloc
    on<SelectTrackForAddingToPlaylist>(_onSelectTrackForAddingToPlaylist);
    on<AddTrackToPlaylist>(_onAddTrackToPlaylist);
    on<RemoveTrackFromPlaylist>(_onRemoveTrackFromPlaylist);
    on<MoveTrack>(_onMoveTrack);
    on<PlaylistTracksReset>(_onPlaylistTracksReset);
    on<UpdatePlaylistTracks>(_onUpdatePlaylistTracks);
  }

  Future<void> _onPlaylistTracksReset(
    PlaylistTracksReset event,
    Emitter<PlaylistTracksState> emit,
  ) async {
    emit(state.copyWith(status: PlaylistTracksStatus.initial));
  }

  Future<void> _onAddTrackToPlaylist(
    AddTrackToPlaylist event,
    Emitter<PlaylistTracksState> emit,
  ) async {
    logger.i('addTrackToPlaylist: ');

    // Indicate that an update operation is in progress
    emit(state.copyWith(status: PlaylistTracksStatus.updating));

    final playlist = event.playlist;

    // Check if the track already exists in the playlist - skip check if forceAdd is true
    final bool isDuplicate = !event.forceAdd &&
        event.track.uuid != null &&
        playlist.trackIds.contains(event.track.uuid);

    if (isDuplicate) {
      // Emit a duplicate state so the UI can show a warning
      emit(state.copyWith(
        status: PlaylistTracksStatus.duplicate,
        duplicateTrack: event.track,
        updatedPlaylist: playlist,
      ));
      return;
    }

    try {
      // Perform the operation to add the track to the playlist
      await _playlistRepository.addTrackToPlaylist(
        playlistId: playlist.id!,
        track: event.track,
      );

      // Create an updated playlist with the new track added
      Playlist updatedPlaylist = playlist.copyWith(
        trackIds: List.from(playlist.trackIds)..add(event.track.uuid!),
        total: playlist.total + 1,
        updated:
            Timestamp.fromDate(DateTime.now()), // Convert DateTime to Timestamp
      );

      // Emit the new state with the updated playlist
      emit(
        state.copyWith(
          updatedPlaylist: updatedPlaylist,
          status: PlaylistTracksStatus.updated,
        ),
      );
    } catch (e) {
      // Log the error
      logger.e('Failed to add track to playlist: $e');

      // Emit the error state or failure state, based on your state management
      emit(
        state.copyWith(
          status: PlaylistTracksStatus.error,
        ),
      );
    }
  }

  Future<void> _onMoveTrack(
      MoveTrack event, Emitter<PlaylistTracksState> emit) async {
    // Indicate that an update operation is in progress
    emit(state.copyWith(status: PlaylistTracksStatus.updating));

    final playlist = event.playlist;

    try {
      final List<String> trackIds = playlist.trackIds;
      final String trackId = trackIds.removeAt(event.oldIndex);
      trackIds.insert(event.newIndex, trackId);

      await _playlistRepository.setPlaylistSequence(
        playlistId: playlist.id!,
        trackIds: trackIds,
      );

      final updatedPlaylist = playlist.copyWith(
        trackIds: trackIds,
        updated:
            Timestamp.fromDate(DateTime.now()), // Convert DateTime to Timestamp
      );

      // Emit a new state with the updated playlist if the operation succeeded
      emit(state.copyWith(
        updatedPlaylist: updatedPlaylist,
        status: PlaylistTracksStatus.updated,
      ));
    } catch (error) {
      // Handle the error state by emitting an error state or logging the error
      logger.e('Failed to move track: $error');
      emit(state.copyWith(status: PlaylistTracksStatus.error));
    }
  }

  Future<void> _onRemoveTrackFromPlaylist(
    RemoveTrackFromPlaylist event,
    Emitter<PlaylistTracksState> emit,
  ) async {
    logger.i('removeTrackFromPlaylist bloc ');
    emit(state.copyWith(status: PlaylistTracksStatus.updating));

    final playlist = event.playlist;

    try {
      await _playlistRepository.removeTrackFromPlaylist(
        playlistId: playlist.id!,
        index: event.index,
      );

      // Create an updated playlist with the track removed
      Playlist updatedPlaylist = playlist.copyWith(
        trackIds: List.from(playlist.trackIds)
          ..remove(playlist.trackIds[event.index]),
        total: playlist.total - 1,

        updated:
            Timestamp.fromDate(DateTime.now()), // Convert DateTime to Timestamp
      );

      emit(
        state.copyWith(
          updatedPlaylist: updatedPlaylist,
          status: PlaylistTracksStatus.updated,
        ),
      );
    } catch (e) {
      // Log the error
      logger.e('Failed to remove track from playlist: $e');

      // Emit the error state or failure state, based on your state management
      emit(
        state.copyWith(
          status: PlaylistTracksStatus.error,
        ),
      );
    }
  }

  Future<void> _onSelectTrackForAddingToPlaylist(
    SelectTrackForAddingToPlaylist event,
    Emitter<PlaylistTracksState> emit,
  ) async {
    logger.i('selectTrackForAddingToPlaylist bloc ${event.track.title} ');

    emit(
      state.copyWith(
        trackToAdd: event.track,
      ),
    );
  }

  Future<void> _onUpdatePlaylistTracks(
    UpdatePlaylistTracks event,
    Emitter<PlaylistTracksState> emit,
  ) async {
    logger.i('_onUpdatePlaylistTracks: Updating all tracks at once');
    emit(state.copyWith(status: PlaylistTracksStatus.updating));

    final playlist = event.playlist;
    final trackIds = event.trackIds;

    try {
      // Update the playlist's track sequence with the new complete list of track IDs
      await _playlistRepository.setPlaylistSequence(
        playlistId: playlist.id!,
        trackIds: trackIds,
      );

      // Create an updated playlist with the new tracks
      Playlist updatedPlaylist = playlist.copyWith(
        trackIds: trackIds,
        total: trackIds.length,
        updated: Timestamp.fromDate(DateTime.now()),
      );

      // Emit the new state with the updated playlist
      emit(
        state.copyWith(
          updatedPlaylist: updatedPlaylist,
          status: PlaylistTracksStatus.updated,
        ),
      );
      logger.i('_onUpdatePlaylistTracks: Successfully updated playlist tracks');
    } catch (e) {
      // Log the error
      logger.e('Failed to update playlist tracks: $e');

      // Emit the error state
      emit(
        state.copyWith(
          status: PlaylistTracksStatus.error,
          failure: Failure(message: 'Failed to update playlist tracks: $e'),
        ),
      );
    }
  }
}
