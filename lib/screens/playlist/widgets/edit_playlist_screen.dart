import 'package:boxify/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:boxify/blocs/player/player_bloc.dart';

/// This is for reording the tracks in a playlist as well as editing the details of the playlist.
/// The user can change the name, description, and image of the playlist.
class EditPlaylistScreen extends StatefulWidget {
  @override
  _EditPlaylistScreenState createState() => _EditPlaylistScreenState();
}

class _EditPlaylistScreenState extends State<EditPlaylistScreen>
    with EditPlaylistMixin {
  List<Track> _localTracks = [];
  List<Track> _originalTracks = []; // Store original tracks for comparison

  @override
  void initState() {
    super.initState();
    final trackBloc = context.read<TrackBloc>();
    _originalTracks = List<Track>.from(trackBloc.state.displayedTracks);
    _localTracks = List<Track>.from(_originalTracks);
  }

  void _deleteTrack(Playlist playlist, Track track, int index) {
    // Only update UI, not database
    setState(() {
      _localTracks.removeAt(index);
    });
  }

  void _reorderTracks(Playlist playlist, int oldIndex, int newIndex) {
    // Adjust for ReorderableListView's behavior
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final track = _localTracks.removeAt(oldIndex);
      _localTracks.insert(newIndex, track);
    });
  }

  void _updatePlayerState(Playlist updatedPlaylist) {
    final playerBloc = context.read<PlayerBloc>();
    if (updatedPlaylist.id != null) {
      playerBloc.add(PlaylistEdited(
        updatedTracks: _localTracks,
        playlistId: updatedPlaylist.id!,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistBloc = context.watch<PlaylistBloc>();
    final playlist = playlistBloc.state.editingPlaylist ?? Playlist.empty;

    titleController.text = playlist.displayTitle ?? 'Playlist name';
    descriptionController.text = playlist.description!.isNotEmpty
        ? playlist.description.toString()
        : 'Add description';

    return WillPopScope(
      onWillPop: () async {
        // If changes were made, reset to original tracks
        if (!_areListsEqual(_localTracks, _originalTracks)) {
          // Reset displayed tracks to original
          context
              .read<TrackBloc>()
              .add(UpdateDisplayedTracks(tracks: _originalTracks));
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Core.appColor.widgetBackgroundColor,
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              // Reset to original tracks when closing without saving
              if (!_areListsEqual(_localTracks, _originalTracks)) {
                context
                    .read<TrackBloc>()
                    .add(UpdateDisplayedTracks(tracks: _originalTracks));
              }
              Navigator.pop(context);
            },
          ),
          centerTitle: true,
          title: Text(
            "editPlaylist".translate(),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => _savePlaylist(context, playlist),
              child: Text(
                "save".translate(),
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: _buildBody(context, playlist),
      ),
    );
  }

  void _savePlaylist(BuildContext context, Playlist playlist) {
    if (titleController.text.isEmpty) return;

    final updatedPlaylist = playlist.copyWith(
      displayTitle: titleController.text,
      description: descriptionController.text,
      trackIds: _localTracks.map((t) => t.uuid!).toList(),
    );

    // Save playlist to database
    context.read<PlaylistInfoBloc>().add(kIsWeb
        ? SubmitOnWeb(
            playlist: updatedPlaylist,
            description: descriptionController.text,
            name: titleController.text,
            userId: context.read<UserBloc>().state.user.id,
          )
        : Submit(
            playlist: updatedPlaylist,
            description: descriptionController.text,
            name: titleController.text,
            userId: context.read<UserBloc>().state.user.id,
          ));

    // Apply track changes to database
    _applyTrackChangesToDatabase(playlist);

    _updatePlayerState(updatedPlaylist);
    context.read<TrackBloc>().add(UpdateDisplayedTracks(tracks: _localTracks));
    context
        .read<PlaylistBloc>()
        .add(SetViewedPlaylist(playlist: updatedPlaylist));
    context
        .read<TrackBloc>()
        .add(LoadDisplayedTracks(playlist: updatedPlaylist));

    Navigator.of(context, rootNavigator: true).pop();
  }

  // Apply track changes to the database only when saving
  void _applyTrackChangesToDatabase(Playlist playlist) {
    final playlistTracksBloc = context.read<PlaylistTracksBloc>();

    // Calculate the tracks that were removed
    final removedTracks = _getDeletedTracks(_originalTracks, _localTracks);

    // First, completely update the track IDs in the playlist to match our current local list
    // This is the most reliable approach to ensure correct track order and removal
    if (_originalTracks.length != _localTracks.length ||
        !_areListsEqual(_originalTracks, _localTracks)) {
      // Get the final list of track IDs
      final List<String> trackIds = _localTracks.map((t) => t.uuid!).toList();

      // Update the entire playlist's track order
      playlistTracksBloc.add(UpdatePlaylistTracks(
        playlist: playlist,
        trackIds: trackIds,
      ));
    }
  }

  // Helper method to get tracks that were deleted
  List<Track> _getDeletedTracks(List<Track> original, List<Track> current) {
    return original.where((track) {
      return !current.any((t) => t.uuid == track.uuid);
    }).toList();
  }

  // Helper method to check if two track lists are equal
  bool _areListsEqual(List<Track> list1, List<Track> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].uuid != list2[i].uuid) {
        return false;
      }
    }

    return true;
  }

  Widget _buildBody(BuildContext context, Playlist playlist) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          _buildImageSelector(context, playlist),
          sizedBox12,
          _buildTitleField(),
          _buildDescriptionField(),
          _buildTracksList(context, playlist),
        ],
      ),
    );
  }

  Widget _buildImageSelector(BuildContext context, Playlist playlist) {
    return GestureDetector(
      onTap: () => selectPlaylistImage(context),
      child: Column(
        children: [
          BlocBuilder<PlaylistBloc, PlaylistState>(
            builder: (context, state) {
              return Container(
                height: 120,
                width: 120,
                color: Colors.grey[900],
                child: imageForEditDetails(playlist),
              );
            },
          ),
          sizedBox12,
          Text(
            "changeImage".translate(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: titleController,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: descriptionController,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTracksList(BuildContext context, Playlist playlist) {
    return ReorderableListView.builder(
      physics: NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      onReorder: (oldIndex, newIndex) =>
          _reorderTracks(playlist, oldIndex, newIndex),
      itemCount: _localTracks.length,
      itemBuilder: (context, index) {
        final track = _localTracks[index];
        return ListTile(
          key: ValueKey("track_$index"),
          leading: IconButton(
            icon: Icon(Icons.remove_circle),
            onPressed: () => _deleteTrack(playlist, track, index),
          ),
          title: Text(track.displayTitle),
          subtitle: Text(track.artist ?? ''),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle),
          ),
        );
      },
    );
  }
}
