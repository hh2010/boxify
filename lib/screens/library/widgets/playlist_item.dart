import 'package:boxify/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Basically copied from SmallLibraryScreen above
class SmallLibraryScreenForAddingPlaylists extends StatefulWidget {
  const SmallLibraryScreenForAddingPlaylists({super.key});

  @override
  _SmallLibraryScreenForAddingPlaylistsState createState() =>
      _SmallLibraryScreenForAddingPlaylistsState();
}

class _SmallLibraryScreenForAddingPlaylistsState
    extends State<SmallLibraryScreenForAddingPlaylists> {
  @override
  Widget build(BuildContext context) {
    MediaQueryData device;
    device = MediaQuery.of(context);
    logger.i(
      'in SmallLibraryScreenForAddingPlaylists builder. This is your list of playlists in the addtoplaylist screen.',
    );

    return BlocConsumer<PlaylistTracksBloc, PlaylistTracksState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        // Handle successful track addition
        if (state.status == PlaylistTracksStatus.updated &&
            state.updatedPlaylist != null) {
          // Show success message and pop screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            showMySnack(
              context,
              message: 'Added to ${state.updatedPlaylist!.name}',
            );
          });
        }
      },
      builder: (context, playlistTracksState) {
        return BlocBuilder<PlaylistBloc, PlaylistState>(
          builder: (context, state) {
            return Container(
              color: Core.appColor.widgetBackgroundColor,
              child: SizedBox(
                  height: device.size.height,
                  width: device.size.width,
                  child: SmallLibraryBody(
                    type: LibraryScreenType.addToPlaylist,
                  )),
            );
          },
        );
      },
    );
  }
}
