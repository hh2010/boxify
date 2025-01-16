bundles_path = r"C:\RC Dropbox\Rivers Cuomo\Music--Me\Rivers Cuomo\BUNDLES"
default_from_path = bundles_path
default_table_name = "tracks"
ratings_table_name = "ratings2"


# playlist ids
# defaultPlaylistId = "40briftVDwVQmA0NAayo"
# DON'T PUT THIS IN WITH THE BEST PLAYLISTS because playlists_routine.py will destroy it.
# highest_rated_demos_playlist_id = "6C7GjLWSQKvvTco33Sfz"

# newReleasesPlaylistId will be pulled separately in player screen bloc load user
# newReleasesPlaylistId = "RAUZopvzD6WjWa2PuVin"
# piano_playlist_id = "5zztuyJ7Vjd4GFnJCoPj"

pre_weezer_playlist_id = "Xih5mmsI9PVYttdiCvbE"
the_blue_pinkerton_years_playlist_id = "tjGtXvfS2mnf1KCCARMy"
the_green_years_playlist_id = "1cHanICoiKFZ5kJgrkj0"
the_make_believe_years_playlist_id = "7PBHKKun1I8miewHqfuU"
by_the_people_playlist_id = "n7Dgp6oJVc6iDvkpPZQB"
the_red_raditude_hurley_years_playlist_id = "YS4qmRtQzjVaQJPz85WJ"
ewbaite_playlist_id = "oDIz7u5HqWvFnOvD6P2p"
the_white_years_playlist_id = "ifxcDmApNKjjEaj2sstu"
patrick_and_rivers_playlist_id = "EHrCdpuWBfMQnCV63Jx9"
weezma_playlist_id = "8OwoXYmtyXBmiifq1Y5R"
the_pacific_daydream_black_years_playlist_id = "yFE6XUB8hZFk4MNvd9wE"
piano_playlist_id = "btQRMVXFDwWxjrU6bhfA"

# The track lists for these are updated in firestore automatically when I run playlists_routine.py
# Playlist IDs must be stored in each user record so they can reorder them.
# see also one time function add_default_playlists_to_users in playlists_routine.py to add a new playlist to all users
best_of_playlist_ids = [
    # piano_playlist_id, No because you don't have any highest rated demos here
    pre_weezer_playlist_id,
    the_blue_pinkerton_years_playlist_id,
    the_green_years_playlist_id,
    the_make_believe_years_playlist_id,
    by_the_people_playlist_id,
    the_red_raditude_hurley_years_playlist_id,
    ewbaite_playlist_id,
    the_white_years_playlist_id,
    patrick_and_rivers_playlist_id,
    weezma_playlist_id,
    the_pacific_daydream_black_years_playlist_id,
    piano_playlist_id,
]

# Every user gets all of these
# newReleasesPlaylistId will be pulled separately in player screen bloc load user
default_playlist_ids = best_of_playlist_ids


# user ids

