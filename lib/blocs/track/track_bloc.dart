import 'dart:async';
import 'package:bloc/bloc.dart';

import 'package:boxify/app_core.dart';
import 'package:boxify/enums/load_status.dart';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:equatable/equatable.dart';

part 'track_event.dart';
part 'track_state.dart';

class TrackBloc extends Bloc<TrackEvent, TrackState> {
  final AuthBloc _authBloc;
  final TrackRepository _trackRepository;
  final UserRepository _userRepository;
  List<CancelToken> downloadTokens = [];
  final CacheHelper _cacheHelper;
  final TrackHelper _trackHelper;

  TrackBloc({
    required AuthBloc authBloc,
    required UserRepository userRepository,
    required TrackRepository trackRepository,
    required MetaDataRepository metaDataRepository,
    required StorageRepository storageRepository,
  })  : _authBloc = authBloc,
        _trackRepository = trackRepository,
        _userRepository = userRepository,
        _cacheHelper = CacheHelper(),
        _trackHelper = TrackHelper(),
        super(TrackState.initial()) {
    on<LoadAllTracks>(_onLoadAllTracks);
    on<MapRatingsToTracks>(_onMapRatingsToTracks);
    on<SetDisplayedTracksWithTracks>(_onSetDisplayedTracksWithTrack);
    on<LoadDisplayedTracks>(_onLoadDisplayedTracks);
    on<ReplaceSelectedTracksWithSearchResults>(
        _onReplaceSelectedTracksWithSearchResults);
    on<SetMouseClickedTrackId>(_onSetMouseClickedTrackId);
    on<TrackReset>(_onTrackReset);
    on<UpdateTracks>(_onUpdateTracks);
    on<UpdateDisplayedTracks>(_onUpdateDisplayedTracks);
  }
  
  void _onUpdateDisplayedTracks(
    UpdateDisplayedTracks event,
    Emitter<TrackState> emit,
  ) {
    logger.i('_onUpdateDisplayedTracks');
    emit(state.copyWith(status: TrackStatus.displayedTracksLoading));
    
    final displayedTracks = event.tracks;
    final displayedTracksPlayable = displayedTracks.where((track) {
      return track.available == true;
    }).toList();
    
    emit(
      state.copyWith(
        displayedTracks: displayedTracks,
        displayedTracksPlayable: displayedTracksPlayable,
        status: TrackStatus.displayedTracksLoaded,
      ),
    );
    logger.i('Updated displayedTracks with ${displayedTracks.length} tracks');
  }
  
  void _onUpdateTracks(
    UpdateTracks event,
    Emitter<TrackState> emit,
  ) {
    logger.i('_onUpdateTracks');
    emit(state.copyWith(status: TrackStatus.displayedTracksLoading));
    final Map<String, Track> allTracksMap = {
      for (var track in state.allTracks) track.uuid!: track
    };
    final Map<String, Track> displayedTracksMap = {
      for (var track in state.displayedTracks) track.uuid!: track
    };
    for (var updatedTrack in event.updatedTracks) {
      allTracksMap[updatedTrack.uuid!] = updatedTrack;
      if (displayedTracksMap.containsKey(updatedTrack.uuid!)) {
        displayedTracksMap[updatedTrack.uuid!] = updatedTrack;
      }
    }
    _cacheHelper.saveTracks(
        allTracksMap.values.toList(), _authBloc.state.user!.uid);
    final displayedTracks = displayedTracksMap.values.toList();
    final displayedTracksPlayable = displayedTracks.where((track) {
      return track.available == true;
    }).toList();
    emit(
      state.copyWith(
        allTracks: allTracksMap.values.toList(),
        displayedTracks: displayedTracks,
        displayedTracksPlayable: displayedTracksPlayable,
        status: TrackStatus.displayedTracksLoaded,
      ),
    );
  }

  Future<void> _onSetMouseClickedTrackId(
    SetMouseClickedTrackId event,
    Emitter<TrackState> emit,
  ) async {
    emit(state.copyWith(mouseClickedTrackId: event.trackId));
  }

  Future<void> _onTrackReset(
    TrackReset event,
    Emitter<TrackState> emit,
  ) async {
    emit(TrackState.initial());
  }

  // Future<void> _onSetTrackIdPassedToUrl(
  //     SetTrackIdPassedToUrl event, Emitter<TrackState> emit) async {
  //   emit(state.copyWith(trackIdPassedToUrl: event.trackId));
  // }

  Future<void> _onLoadAllTracks(
    LoadAllTracks event,
    Emitter<TrackState> emit,
  ) async {
    final start = DateTime.now();
    logger.i('_onLoadAllTracks');
    emit(state.copyWith(
        status: TrackStatus.allTracksLoading,
        tracksLoadStatus: LoadStatus.loading));

    if (event.clearCache == true) {
      await _cacheHelper
          .clearSpecific(CacheHelper.keyForTracks(_authBloc.state.user!.uid));
    }

    final start2 = DateTime.now();

    // check for cached tracks first
    final cachedTracks = await _cacheHelper.getTracks(
        event.serverUpdated, _authBloc.state.user!.uid);

    logRunTime(start2, 'cacheHelper.getTracks');

    // If there are cached tracks, use them
    if (cachedTracks != null && cachedTracks.isNotEmpty) {
      logger.i('there are cachedTracks!');
      final userId = _authBloc.state.user!.uid;
      _trackHelper.updateTrackLinksBulk(cachedTracks, userId);
      emit(state.copyWith(
        allTracks: cachedTracks,
        status: TrackStatus.allTracksLoaded,
        tracksLoadStatus: LoadStatus.loaded,
      ));
      logRunTime(start, 'load all tracks');
      return;
    }
    logger.i('cachedTracks is null or empty');

    // If there are no cached tracks, fetch them from the server
    final List<Track> tracks;

    if (Core.app.type == AppType.advanced) {
      tracks = await _trackRepository
          .fetchTracksFromRCServerAPI(_authBloc.state.user!.uid);
    } else if (Core.app.type == AppType.basic) {
      if (event.user == null) {
        throw Exception(
            'Must provide user to trackBlock.loadAllTracks for basic app so I can get the tracks from Firestore that correspond to their roles.');
      } else {
        tracks =
            await _trackRepository.fetchPrivateTracksFromFirestore(event.user!);
      }
    } else {
      throw Exception('AppType not valid');
    }
    final userId = _authBloc.state.user!.uid;
    _trackHelper.updateTrackLinksBulk(tracks, userId);

    // Save the fetched tracks to cache
    await _cacheHelper.saveTracks(tracks, _authBloc.state.user!.uid);

    logger.i('emitting allTracksLoaded with tracks.length: ${tracks.length}');

    emit(state.copyWith(
      allTracks: tracks,
      status: TrackStatus.allTracksLoaded,
      tracksLoadStatus: LoadStatus.loaded,
    ));
    // logger.f('Time to load all tracks: ${DateTime.now().difference(start)}');
    logRunTime(start, 'load all tracks');
  }

  Future<void> _onMapRatingsToTracks(
    MapRatingsToTracks event,
    Emitter<TrackState> emit,
  ) async {
    final start = DateTime.now();
    logger.i('_onMapRatingsToTracks ${event.ratings.length}');
    emit(state.copyWith(status: TrackStatus.ratingsMapping));

    // MAP THIS USER'S DEMO RATINGS TO THEIR LIST OF DEMOS
    final mappedTracks =
        _trackHelper.mapTracksToRatings(event.tracks, event.ratings);

    emit(state.copyWith(
      allTracks: mappedTracks,
      status: TrackStatus.ratingsMapped,
    ));
    // logger.f(
    //     'Time to map ratings to tracks: ${DateTime.now().difference(start)}');
    logRunTime(start, 'map ratings to tracks');
  }

  /// Updates the displayedTracks in the [TrackBloc] state to the tracks in the playlist
  /// returns status.displayedTracksLoaded
  Future<void> _onLoadDisplayedTracks(
    LoadDisplayedTracks event,
    Emitter<TrackState> emit,
  ) async {
    logger.i('_onLoadDisplayedTracks');
    final start = DateTime.now();
    emit(state.copyWith(status: TrackStatus.displayedTracksLoading));
    // Populate selected Tracks
    final playlistTracks = <Track>[];

    for (final trackId in event.playlist.trackIds) {
      try {
        final track = state.allTracks.firstWhere((x) => x.uuid! == trackId);
        playlistTracks.add(track);
        // logger.f('${track.sequence} ${track.displayTitle}');
      } catch (err) {
        logger.e('TrackBloc._onLoadDisplayedTracks: $err No trackId: $trackId');
      }
    }

    _trackHelper.updateTrackLinksBulk(
        playlistTracks, _authBloc.state.user!.uid);
    logger.i('playlistTracks.length: ${playlistTracks.length}');

    final displayedTracksPlayable = playlistTracks.where((track) {
      return track.available == true;
    }).toList();
    try {
      emit(
        state.copyWith(
          displayedTracks: playlistTracks,
          displayedTracksPlayable: displayedTracksPlayable,
          status: TrackStatus.displayedTracksLoaded,
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: TrackStatus.error,
          failure: Failure(
            message: 'TrackBloc._selectTrackForViewing: ${err.toString()}.',
          ),
        ),
      );
    }
    logRunTime(start, '_onLoadDisplayedTracks');
  }

  Future<void> _onSetDisplayedTracksWithTrack(
    SetDisplayedTracksWithTracks event,
    Emitter<TrackState> emit,
  ) async {
    logger.i('_onSetDisplayedTracksWithTrack');
    emit(state.copyWith(status: TrackStatus.displayedTracksLoading));
    // Populate selected Tracks
    final displayedTracks = event.tracks;
    final displayedTracksPlayable = displayedTracks.where((track) {
      return track.available == true;
    }).toList();
    // await state.player.seek(Duration.zero, index: 0); // Just added this?

    try {
      emit(
        state.copyWith(
          displayedTracks: displayedTracks,
          displayedTracksPlayable: displayedTracksPlayable,
          // trackIdPassedToUrl: null,
          status: TrackStatus.displayedTracksLoaded,
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: TrackStatus.error,
          failure: Failure(
            message: 'TrackBloc._selectTrackForViewing: ${err.toString()}.',
          ),
        ),
      );
    }
  }

  Future<void> _onReplaceSelectedTracksWithSearchResults(
    ReplaceSelectedTracksWithSearchResults event,
    Emitter<TrackState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: TrackStatus.displayedTracksLoading,
        ),
      );
      final displayedTracksPlayable = event.tracks.where((track) {
        return track.available == true;
      }).toList();

      emit(
        state.copyWith(
            displayedTracks: event.tracks,
            displayedTracksPlayable: displayedTracksPlayable,
            status: TrackStatus.displayedTracksLoaded),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: TrackStatus.error,
          failure: Failure(
            message:
                'TrackBloc._replaceSelectedTracksWithSearchResults: ${err.toString()}.',
          ),
        ),
      );
    }
  }
}
