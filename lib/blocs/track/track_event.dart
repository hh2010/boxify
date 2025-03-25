part of 'track_bloc.dart';

abstract class TrackEvent extends Equatable {
  const TrackEvent();

  @override
  List<Object?> get props => [];
}

class TrackReset extends TrackEvent {
  @override
  List<Object?> get props => [];
}

class SetMouseClickedTrackId extends TrackEvent {
  final String? trackId;

  const SetMouseClickedTrackId({this.trackId});

  @override
  List<Object?> get props => [trackId];
}

// class SetTrackIdPassedToUrl extends TrackEvent {
//   final String? trackId;

//   const SetTrackIdPassedToUrl({this.trackId});

//   @override
//   List<Object?> get props => [trackId];
// }

class MarkAvailable extends TrackEvent {
  final User user;

  const MarkAvailable(this.user);

  @override
  List<Object?> get props => [user];
}

class TrackBundlePurchaseSuccess extends TrackEvent {
  final String bundleId;

  const TrackBundlePurchaseSuccess({required this.bundleId});

  @override
  List<Object?> get props => [bundleId];
}

class GetUserTracks extends TrackEvent {
  const GetUserTracks();
  @override
  List<Object?> get props => [];
}

class SetDisplayedTracksWithTracks extends TrackEvent {
  final List<Track> tracks;

  /// Replaces the list of DisplayedTracks with a new list
  /// that consists of the single track passed as a parameter.
  /// It does not update the states queue or the audio player's audioSource.
  /// ///
  /// It does not update the [PlayerState].queue or the [PlayerState].audioPlayer.audioSource.
  /// That is handled by [Playerbloc].[LoadPlayer]
  const SetDisplayedTracksWithTracks({required this.tracks});
  @override
  List<Object?> get props => tracks;
}

class LoadDisplayedTracks extends TrackEvent {
  // final List<Track> allTracks;
  final Playlist playlist;

  /// Returns [TrackStatus].displayedTracksLoaded
  /// Replaces the list of [DisplayedTracks] with a new list
  /// that consists of a [Playlist]'s tracks, derived from allTracks passed as a parameter.
  ///
  /// Previously but not longer?:
  /// - sorts them according to the app's sort order.
  ///
  /// It does not update the [PlayerState].queue or the [PlayerState].audioPlayer.audioSource.
  /// That is handled by [Playerbloc].[LoadPlayer]
  const LoadDisplayedTracks(
      {
      // required this.allTracks,
      required this.playlist});
  @override
  List<Object?> get props => [
        // allTracks,
        playlist
      ];
}

/// Loads all tracks from the database into the state's tracks list.
class LoadAllTracks extends TrackEvent {
  final bool clearCache;

  final DateTime serverUpdated;
  final User? user;

  const LoadAllTracks({
    this.clearCache = false,
    required this.serverUpdated,
    this.user,
  });

  @override
  List<Object?> get props => [clearCache, serverUpdated, user];
}

class MapRatingsToTracks extends TrackEvent {
  final List<Track> tracks;
  final List<Rating> ratings;

  // emits TrackStatus.ratingsMapped
  const MapRatingsToTracks(this.tracks, this.ratings);

  @override
  List<Object?> get props => [tracks, ratings];
}

class InitialTrackState extends TrackEvent {
  @override
  List<Object?> get props => [];
}

class GetUserTracksApi extends TrackEvent {
  const GetUserTracksApi();
  @override
  List<Object?> get props => [];
}

class ReplaceSelectedTracksWithSearchResults extends TrackEvent {
  final List<Track> tracks;

  ReplaceSelectedTracksWithSearchResults(this.tracks);
  @override
  List<Object?> get props => [tracks];
}

// Define a new event for updating tracks in the state
class UpdateTracks extends TrackEvent {
  final List<Track> updatedTracks;

  UpdateTracks({required this.updatedTracks});

  @override
  List<Object> get props => [updatedTracks];
}

class UpdateDisplayedTracks extends TrackEvent {
  final List<Track> tracks;

  /// Immediately updates the displayedTracks in the state with the provided list of tracks
  /// This is useful for UI updates without waiting for a database refresh
  const UpdateDisplayedTracks({required this.tracks});

  @override
  List<Object> get props => [tracks];
}
