import 'dart:async';
import 'package:boxify/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_event.dart';
part 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final AuthBloc _authBloc;
  final UserRepository _userRepository;
  final TrackRepository _trackRepository;
  final CacheHelper _cacheHelper;
  final FirebaseFirestore _firebaseFirestore;

  UserBloc({
    required AuthBloc authBloc,
    required UserRepository userRepository,
    required TrackRepository trackRepository,
  })  : _authBloc = authBloc,
        _userRepository = userRepository,
        _trackRepository = trackRepository,
        _cacheHelper = CacheHelper(),
        _firebaseFirestore = FirebaseFirestore.instance,
        super(UserState.initial()) {
    // logger.f('UserBloc constructor ${state.hashCode}');

    on<LoadUser>((event, emit) async {
      // logger.f('UserBloc loaduser called on ${state.hashCode}');
      if (Core.app.type == AppType.advanced) {
        await _loadAdvancedUser(event, emit);
      } else {
        await _loadBasicUser(event, emit);
      }
    });
    on<InitialState>(_onInitialState);
    on<NewPlaylistCreated>(_onNewPlaylistCreated);
    on<UpdateRating>(_onUpdateRating);
    on<UserBundlePurchaseSuccess>(_onBundlePurchaseSuccess);
    on<BadUserPlaylistIdsFound>(_onBadUserPlaylistIdsFound);
  }

  Future<void> _onBadUserPlaylistIdsFound(
    BadUserPlaylistIdsFound event,
    Emitter<UserState> emit,
  ) async {
    logger.f('UserBloc: BadUserPlaylistIdsFound: ${event.badPlaylistIds}');

    if (state.user.isAnonymous) {
      logger.i('User is anonymous, so not updating playlistIds');
      return;
    }

    // Update the user's playlistIds with the newly purchased bundle.
    final updatedPlaylistIds = List<String>.from(state.user.playlistIds)
      ..removeWhere((element) => event.badPlaylistIds.contains(element));

    final updatedUser = state.user.copyWith(playlistIds: updatedPlaylistIds);

    _userRepository.updateUser(user: updatedUser);

    // Assuming this is synchronous, you can use a Future.value() to create a completed Future.
    return Future<void>.value(_cacheHelper.saveUser(updatedUser)).then((_) {
      // Emit the new state with the updated user
      emit(state.copyWith(user: updatedUser));
    }).catchError((e) {
      // You may want to handle any potential errors here
      logger.e('Error when processing BadUserPlaylistIdsFound event: $e');
    });
  }

  Future<void> _onInitialState(
    InitialState event,
    Emitter<UserState> emit,
  ) async {
    emit(UserState.initial());
  }

  Future<void> _loadBasicUser(
    LoadUser event,
    Emitter<UserState> emit,
  ) async {
    logger.i('_loadBasicUser');
    emit(state.copyWith(status: UserStatus.loading));

    final userId = _authBloc.state.user!.uid;

    if (event.clearCache == true) {
      await _userRepository.clearUserCache(userId);
      await _trackRepository.clearRatingsCache(userId);
    }

    try {
      // Is there a cached user available?
      // We use the cached user first as it's much faster to load
      // then we can fetch the updated user from the server
      User? user = await _userRepository.getUserFromCache(userId);
      final isSelfCached = user != null;

      // User couldn't be found in the cache, so we need to fetch it right away (synchronously)
      if (!isSelfCached) {
        user = await _userRepository.getSelfUser(userId);
      }

      final ratings =
          await _trackRepository.getUserRatings(userId, _firebaseFirestore);

      emit(state.copyWith(
        user: user,
        ratings: ratings,
        status: UserStatus.loaded,
      ));

      // Now, if the user wasn't cached previously, fetch the user from Firestore.
      // this is done once UserStatus.loaded is emitted so this is not blocking the UI
      if (isSelfCached) {
        user = await _userRepository.getSelfUser(userId);
        emit(state.copyWith(user: user));

        // Check if the user roles have changed between cached and server user
        if (event.onRolesUpdated != null && user.roles != state.user.roles) {
          event.onRolesUpdated!();
        }
      }
    } on NoConnectionException catch (e) {
      logger.e('NoConnectionException: $e');
      emit(state.copyWith(
        status: UserStatus.error,
        failure: Failure(
          message: e.message,
        ),
      ));
    } on DataFetchException catch (e) {
      logger.e('DataFetchException: $e');
      emit(state.copyWith(
        status: UserStatus.error,
        failure: Failure(
          message: e.message,
        ),
      ));
    } catch (e) {
      logger.e('An unexpected error occurred: $e');
      emit(state.copyWith(
        status: UserStatus.error,
        failure: Failure(
          message: 'An unexpected error occurred.',
        ),
      ));
    }
  }

  Future<void> _loadAdvancedUser(
    LoadUser event,
    Emitter<UserState> emit,
  ) async {
    logger.i('_loadAdvancedUser');
    emit(state.copyWith(status: UserStatus.loading));

    final startTime = DateTime.now();
    final userId = _authBloc.state.user!.uid;

    if (event.clearCache == true) {
      await _userRepository.clearUserCache(userId);
      await _trackRepository.clearRatingsCache(userId);
      await _userRepository.clearArtistsCache();
    }

    try {
      // Is there a cached user available?
      // We use the cached user first since it's much faster to load
      // then we can load the updated user from the server
      User? user = await _userRepository.getUserFromCache(userId);
      final isSelfCached = user != null;

      // User couldn't be found in the cache, so we need to fetch it right away (synchronously)
      if (!isSelfCached) {
        user = await _userRepository.getSelfUser(userId);
      }

      final ratings =
          await _trackRepository.getUserRatings(userId, _firebaseFirestore);
      final allArtists = await _userRepository.getAllArtists();

      // Optionally sort the artists if needed
      allArtists.sort(
        (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
      );

      emit(state.copyWith(
        user: user,
        ratings: ratings,
        allArtists: allArtists,
        status: UserStatus.loaded,
      ));

      logRunTime(startTime, 'load user');

      // Now, if the user wasn't cached previously, fetch the user from Firestore.
      // this is done once UserStatus.loaded is emitted so this is not blocking the UI
      if (isSelfCached) {
        user = await _userRepository.getSelfUser(userId);
        emit(state.copyWith(user: user));
      }
    } on NoConnectionException catch (e) {
      logger.e('NoConnectionException: $e');
      emit(state.copyWith(
        status: UserStatus.error,
        failure: Failure(
          message: e.message,
        ),
      ));
    } on DataFetchException catch (e) {
      logger.e('DataFetchException: $e');
      emit(state.copyWith(
        status: UserStatus.error,
        failure: Failure(
          message: e.message,
        ),
      ));
    } catch (e) {
      logger.e('An unexpected error occurred: $e');
      emit(state.copyWith(
        status: UserStatus.error,
        failure: Failure(
          message: 'An unexpected error occurred.',
        ),
      ));
    }
  }

  Future<void> _onBundlePurchaseSuccess(
      UserBundlePurchaseSuccess event, Emitter<UserState> emit) {
    logger.i('UserBloc: BundlePurchaseSuccess: ${event.bundleId}');

    // Update the user's bundle IDs with the newly purchased bundle.
    final updatedBundleIds = List<String>.from(state.user.bundleIds)
      ..add(event.bundleId);

    final updatedUser = state.user.copyWith(bundleIds: updatedBundleIds);

    // Assuming this is synchronous, you can use a Future.value() to create a completed Future.
    return Future<void>.value(_cacheHelper.saveUser(updatedUser)).then((_) {
      // Emit the new state with the updated user
      emit(state.copyWith(user: updatedUser));
    }).catchError((e) {
      // You may want to handle any potential errors here
      logger.e('Error when processing BundlePurchaseSuccess event: $e');
    });
  }

  Future<void> _onNewPlaylistCreated(
    NewPlaylistCreated event,
    Emitter<UserState> emit,
  ) async {
    _userRepository.addUserPlaylist(state.user.id, event.playlist.id!,
        newLastPlaylistNumber: event.lastPlaylistNumber);

    final updateUserPlaylistIds = state.user.playlistIds
      ..insert(0, event.playlist.id!);

    final updateUser = state.user.copyWith(playlistIds: updateUserPlaylistIds);

    if (event.lastPlaylistNumber != null) {
      updateUser.lastPlaylistNumber = event.lastPlaylistNumber!;
    }

    CacheHelper().saveUser(updateUser);

    emit(state.copyWith(user: updateUser));
  }

  /// Handles the event of updating a track's rating, adding a new rating if the track is being rated for the first time.
  ///
  /// Parameters:
  /// - [event] UpdateRating event containing the track ID and the new rating value.
  /// - [emit] Function to emit new states.
  ///
  /// Emits a state indicating the updating process, followed by an updated state with the new rating or indicates an error.
  Future<void> _onUpdateRating(
    UpdateRating event,
    Emitter<UserState> emit,
  ) async {
    // Log the rating update attempt
    logger.i('saveRating${event.trackId}: ${event.value}');

    // Emit a state indicating that rating update is in process
    emit(state.copyWith(status: UserStatus.updatingRating));
    final trackId = event.trackId;

    // Emit a state to keep track of which track is being rated
    emit(state.copyWith(trackIdOfTrackBeingRated: trackId));

    // Update the rating in Firestore and handle possible errors
    bool firestoreUpdateSucceeded = await _updateFirestoreRating(
      trackId: trackId,
      rating: event.value,
    );
    if (!firestoreUpdateSucceeded) {
      // Stop execution if Firestore update failed
      return;
    }

    // Update the rating in the local state
    final ratings = state.ratings;
    final existingRatingIndex =
        ratings.indexWhere((rating) => rating.trackUuid == trackId);

    List<Rating> updatedRatings;
    if (existingRatingIndex != -1) {
      // Track already has a rating, so we update it
      updatedRatings = ratings.map((rating) {
        if (rating.trackUuid == trackId) {
          return rating.copyWith(value: event.value);
        }
        return rating;
      }).toList();
    } else {
      // Track is being rated for the first time, add a new rating entry
      final newRating = Rating(
          userId: _authBloc.state.user!.uid,
          trackUuid: trackId,
          value: event.value);
      updatedRatings = List.from(ratings)..add(newRating);
    }

    // Cache the updated ratings
    _cacheHelper.saveRatings(updatedRatings, _authBloc.state.user!.uid);

    // Emit the updated state with new ratings
    emit(state.copyWith(
        ratings: updatedRatings,
        trackIdOfTrackBeingRated: null,
        status: UserStatus.updatedRating));
  }

  Future<bool> _updateFirestoreRating(
      {required String trackId, required double rating}) async {
    try {
      await _trackRepository.updateRating(
        trackUuid: trackId,
        userId: _authBloc.state.user!.uid,
        value: rating,
      );
      return true;
    } catch (err) {
      logger.i('psb _updateRating error: $err');
      // ... Update state with error information as needed
      return false;
    }
  }
}
