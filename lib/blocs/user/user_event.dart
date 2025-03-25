part of 'user_bloc.dart';

// import 'package:boxify/app_core.dart';
// import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class TEST extends UserEvent {
  @override
  List<Object?> get props => [];
}

class BadUserPlaylistIdsFound extends UserEvent {
  final List<String> badPlaylistIds;

  const BadUserPlaylistIdsFound({required this.badPlaylistIds});

  @override
  List<Object?> get props => [badPlaylistIds];
}

class UserBundlePurchaseSuccess extends UserEvent {
  final String bundleId;

  const UserBundlePurchaseSuccess({required this.bundleId});

  @override
  List<Object?> get props => [bundleId];
}

class GetUser extends UserEvent {
  const GetUser();
  @override
  List<Object?> get props => [];
}

class GetUserRatings extends UserEvent {
  const GetUserRatings();
  @override
  List<Object?> get props => [];
}

class NewPlaylistCreated extends UserEvent {
  final Playlist playlist;
  final int? lastPlaylistNumber;

  const NewPlaylistCreated({required this.playlist, this.lastPlaylistNumber});

  @override
  List<Object?> get props => [playlist, lastPlaylistNumber];
}

class ResetUser extends UserEvent {
  const ResetUser();
  @override
  List<Object?> get props => [];
}

class LoadUser extends UserEvent {
  final bool clearCache;
  final DateTime serverRatingsUpdated;

  /// Callback to be called when the user roles are updated (basic app only)
  final VoidCallback? onRolesUpdated;

  const LoadUser({
    this.clearCache = false,
    this.onRolesUpdated,
    required this.serverRatingsUpdated,
  });

  @override
  List<Object?> get props => [clearCache, serverRatingsUpdated];
}

class InitialState extends UserEvent {
  @override
  List<Object?> get props => [];
}

class UpdateRating extends UserEvent {
  final String trackId;
  final double value;

  const UpdateRating({required this.trackId, required this.value});
  @override
  List<Object?> get props => [];
}

// class SetScreen extends UserEvent {
//   final String screen;
//   const SetScreen(this.screen);

//   @override
//   List<Object?> get props => [screen];
// }
