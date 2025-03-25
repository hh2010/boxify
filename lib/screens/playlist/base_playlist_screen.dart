import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:boxify/app_core.dart';

import 'playlist_status_is_loaded.dart';

/// Top level widget for the playlist screen.
/// Handles [PlaylistStatus]
/// ---- [PlaylistTouchScreen]
/// ---- [PlaylistMouseScreen]
///
/// Now using this also for a [SmallTrackScreen].

class BasePlaylistScreen extends StatefulWidget {
  final String playlistId;

  const BasePlaylistScreen({Key? key, required this.playlistId})
      : super(key: key);

  @override
  State<BasePlaylistScreen> createState() => _BasePlaylistScreenState();
}

class _BasePlaylistScreenState extends State<BasePlaylistScreen>
    with ScrollListenerMixin, PurchaseListenerMixin {
  @override
  void initState() {
    super.initState();
    loadPlaylist(widget.playlistId);
    final userBloc = context.read<UserBloc>();
    if (Core.app.type == AppType.advanced) {
      initializePurchaseListener(userBloc.state.user.id);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(BasePlaylistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistId != widget.playlistId) {
      loadPlaylist(widget.playlistId);
    }
  }

  void loadPlaylist(String playlistId) {
    final playlistBloc = context.read<PlaylistBloc>();
    final userBloc = context.read<UserBloc>();
    Playlist playlist = Playlist.empty;

    if (widget.playlistId == '${userBloc.state.user.id}_allsongs') {
      playlist = playlistBloc.state.allSongsPlaylist;
    } else if (widget.playlistId == '${userBloc.state.user.id}_liked') {
      playlist = playlistBloc.state.likedSongsPlaylist;
    } else if (widget.playlistId == '${userBloc.state.user.id}_unrated') {
      playlist = playlistBloc.state.unratedPlaylist;
    } else {
      try {
        final Track? track = findTrackById(widget.playlistId);
        if (track != null) {
          playlist = TrackHelper.convertTrackToPlaylist(track);
          playlistBloc.add(SetEnqueuedPlaylist(playlist: playlist));
        } else {
          playlist = playlistBloc.state.allPlaylists
              .firstWhere((playlist) => playlist.id == widget.playlistId);
          logger.w('found playlist: ${playlist.displayTitle}');
        }
      } catch (e) {
        if (widget.playlistId != context.read<AuthBloc>().state.user!.uid) {
          logger.e('Error finding playlist with id: ${widget.playlistId}  $e');
        }
      }
    }

    logger.f('found playlist: ${playlist.displayTitle}');
    // Appears to be necessary only in the case that the web app is loading from a url
    // though it fires in all cases.
    playlistBloc.add(SetViewedPlaylist(playlist: playlist));
  }

  Track? findTrackById(String id) {
    try {
      return context
          .read<TrackBloc>()
          .state
          .allTracks
          .firstWhere((t) => t.uuid == id);
    } on StateError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistBloc, PlaylistState>(
      builder: (context, state) {
        final status = state.status;
        final playlistBloc = context.read<PlaylistBloc>();
        final trackBloc = context.read<TrackBloc>();
        final playlist = playlistBloc.state.viewedPlaylist;

        final displayedTracks = trackBloc.state.displayedTracks;
        final isPlaylistLoaded = playlistStatusIsLoaded(status);

        final containsDownloaded = displayedTracks.any((element) =>
            element.downloadedUrl != null &&
            element.downloadedUrl!
                .toLowerCase()
                .contains('file')); // Added null check for downloadedUrl

        final containsAvailable = displayedTracks.any((element) =>
            element.link != null &&
            element.link!.isNotEmpty); // Added null check for link

        if (playlist == null) {
          return Container(
            color: Core.appColor.widgetBackgroundColor,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (playlist.displayTitle == Playlist.empty.displayTitle) {
          return ErrorPage();
        }

        final device = MediaQuery.of(context);
        final isSmall = device.size.width < Core.app.largeSmallBreakpoint;

        final isNativePlatform = !kIsWeb;
        final isMouse = !isNativePlatform && !isSmall;
        List<Widget> trackMouseRowItems = [];
        if (isMouse) {
          final trackMouseRowHelper = TrackMouseRowHelper();

          // Fetch the list of row items with dragging logic
          trackMouseRowItems = trackMouseRowHelper.getTrackMouseRowItems(
            context,
            canBeADragTarget: kIsWeb,
            canDrag: kIsWeb,
            trackRowType: TrackRowType.displayedTracks,
          );
        }

        return BlocProvider(
          create: (context) => DraggingCubit(),
          child: SafeArea(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                isNativePlatform || isSmall
                    ? SliverAppBarExpandable(
                        expandedHeight: expandedHeight,
                        appBarBackgroundOpacity: appBarBackgroundOpacity,
                        titleOpacity: titleOpacity,
                        imageUrl: playlist.imageUrl,
                        title: playlist.displayTitle ?? '',
                        imageFilename: playlist.imageFilename,
                        color: playlist.backgroundColor,
                      )
                    : SliverAppBarNoExpand(
                        type: SliverAppBarNoExpandType.playlist,
                        expandedHeight: kToolbarHeight,
                        appBarBackgroundOpacity: appBarBackgroundOpacity,
                        titleOpacity: titleOpacity,
                        title: playlist.displayTitle!,
                        color: playlist.backgroundColor,
                      ),
                if (isNativePlatform || isSmall)
                  PlaylistTouchScreen(
                    playlist: playlist,
                    containsDownloaded: containsDownloaded,
                    containsAvailable: containsAvailable,
                    isPlaylistLoaded: isPlaylistLoaded,
                  )
                else
                  ...PlaylistMouseScreen.buildSlivers(
                      context,
                      PlaylistMouseScreen(playlist: playlist),
                      playlist,
                      trackMouseRowItems,
                      containsAvailable,
                      isPlaylistLoaded),
              ],
            ),
          ),
        );
      },
    );
  }
}
