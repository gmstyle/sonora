// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sonora';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get settingsLabel => 'Settings';

  @override
  String get failedToLoadArtist => 'Failed to load artist';

  @override
  String get failedToLoadAlbum => 'Failed to load album';

  @override
  String get albums => 'Albums';

  @override
  String get singles => 'Singles';

  @override
  String get videos => 'Videos';

  @override
  String get similarArtists => 'Similar Artists';

  @override
  String get topSongs => 'Top Songs';

  @override
  String get featuredOn => 'Featured On';

  @override
  String get relatedReleases => 'Related Releases';

  @override
  String get popular => 'Popular';

  @override
  String get showLess => 'Show less';

  @override
  String get showMore => 'Show more';

  @override
  String failedToLoadSongs(String error) {
    return 'Failed to load songs: $error';
  }

  @override
  String get playTopSongs => 'Play Top Songs';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get share => 'Share';

  @override
  String playingArtist(String artistName) {
    return 'Playing $artistName…';
  }

  @override
  String failedToPlay(String error) {
    return 'Failed to play: $error';
  }

  @override
  String shufflingArtist(String artistName) {
    return 'Shuffling $artistName…';
  }

  @override
  String get follow => 'Follow';

  @override
  String get following => 'Following';

  @override
  String get artistRadio => 'Artist Radio';

  @override
  String failedToStartArtistRadio(String error) {
    return 'Failed to start artist radio: $error';
  }

  @override
  String get subscribers => 'subscribers';

  @override
  String get views => 'views';

  @override
  String get description => 'Description';

  @override
  String get failedToLoadPlaylist => 'Failed to load playlist';

  @override
  String get failedToLoadVideos => 'Failed to load videos';

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Play all';

  @override
  String get shufflePlay => 'Shuffle play';

  @override
  String get addToQueue => 'Add to Queue';

  @override
  String addedToQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return 'Added $_temp0 to queue';
  }

  @override
  String failedToAddToQueue(String error) {
    return 'Failed to add to queue: $error';
  }

  @override
  String playingPlaylist(String playlistName) {
    return 'Playing $playlistName…';
  }

  @override
  String failedToPlayPlaylist(String error) {
    return 'Failed to play playlist: $error';
  }

  @override
  String shufflingPlaylist(String playlistName) {
    return 'Shuffling $playlistName…';
  }

  @override
  String get allSongsAlreadyDownloading => 'All songs already downloading';

  @override
  String get alreadyDownloaded => 'Already downloaded';

  @override
  String alreadyDownloadedSongs(int count, String playlistName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'are',
      one: 'is',
    );
    return '$_temp0 from $playlistName $_temp1 already downloaded. Downloading again will overwrite existing files. Continue?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String downloadingSongs(int count, String playlistName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return 'Downloading $_temp0 from $playlistName…';
  }

  @override
  String get likePlaylist => 'Like Playlist';

  @override
  String get unlikePlaylist => 'Unlike Playlist';

  @override
  String downloadedCount(int downloaded, int total) {
    return 'Downloaded $downloaded/$total';
  }

  @override
  String get downloadPlaylist => 'Download Playlist';

  @override
  String get playlistEmpty => 'This playlist is empty';

  @override
  String get library => 'Library';

  @override
  String get viewList => 'View List';

  @override
  String get viewGrid => 'View Grid';

  @override
  String get favorites => 'Favorites';

  @override
  String get artists => 'Artists';

  @override
  String get playlists => 'Playlists';

  @override
  String get history => 'History';

  @override
  String get failedToLoadFavorites => 'Failed to load favorites';

  @override
  String get failedToLoadArtists => 'Failed to load artists';

  @override
  String get failedToLoadPlaylists => 'Failed to load playlists';

  @override
  String get failedToLoadLikedPlaylists => 'Failed to load liked playlists';

  @override
  String get failedToLoadAlbums => 'Failed to load albums';

  @override
  String get failedToLoadHistory => 'Failed to load history';

  @override
  String get noFavoritesYet => 'No favorites yet';

  @override
  String get noFavoritesHint =>
      'Tap the heart icon on any song to add it here.';

  @override
  String get noFollowedArtists => 'No followed artists';

  @override
  String get noFollowedArtistsHint =>
      'Follow artists from their artist page to see them here.';

  @override
  String get myPlaylists => 'My Playlists';

  @override
  String get createPlaylist => 'Create Playlist';

  @override
  String get noLocalPlaylistsYet => 'No local playlists yet.';

  @override
  String get deletePlaylist => 'Delete playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get likedPlaylists => 'Liked Playlists';

  @override
  String get likePlaylistHint =>
      'Like a playlist from its page to see it here.';

  @override
  String get renamePlaylist => 'Rename playlist';

  @override
  String get noLikedAlbums => 'No liked albums';

  @override
  String get noLikedAlbumsHint => 'Like an album from its page to see it here.';

  @override
  String albumInfo(String artistName, String year) {
    return '$artistName · $year';
  }

  @override
  String get noListeningHistory => 'No listening history';

  @override
  String get noListeningHistoryHint =>
      'Your recently played songs will appear here.';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirm =>
      'Are you sure you want to clear all listening history?';

  @override
  String get clear => 'Clear';

  @override
  String get searchLibraryHint => 'Search in library...';

  @override
  String get sortBy => 'Sort by';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get leastRecentlyAdded => 'Least recently added';

  @override
  String get alphabetical => 'Alphabetical (A - Z)';

  @override
  String get alphabeticalReverse => 'Alphabetical (Z - A)';

  @override
  String get failedToLoadPlaylistEntries => 'Failed to load playlist entries';

  @override
  String get emptyPlaylist => 'Empty playlist';

  @override
  String get emptyPlaylistHint =>
      'Add songs from the context menu to grow your playlist.';

  @override
  String get remove => 'Remove';

  @override
  String get playlistNameRequired => 'A playlist name is required';

  @override
  String get downloads => 'Downloads';

  @override
  String get failedToLoadDownloads => 'Failed to load downloads';

  @override
  String get noDownloadsYet => 'No downloads yet';

  @override
  String get noDownloadsHint =>
      'Long-press on any song and select Download\nto save it for offline playback.';

  @override
  String get activeDownloads => 'Active Downloads';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadedSongs => 'Downloaded Songs';

  @override
  String get unknownSize => 'unknown size';

  @override
  String get searchHint => 'Search songs, artists, albums...';

  @override
  String get searchForMusic => 'Search for music';

  @override
  String get searchForMusicHint =>
      'Find your favorite songs, artists, and albums';

  @override
  String get recentSearches => 'Recent Searches';

  @override
  String get all => 'All';

  @override
  String get songs => 'Songs';

  @override
  String get searchArtists => 'Artists';

  @override
  String get searchAlbums => 'Albums';

  @override
  String get searchPlaylists => 'Playlists';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get noResults => 'No results';

  @override
  String get noResultsHint => 'Try a different search term';

  @override
  String get topResult => 'Top Result';

  @override
  String get featuredTrack => 'Featured Track';

  @override
  String get featuredArtist => 'Featured Artist';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get appearance => 'Appearance';

  @override
  String get amoledDarkMode => 'AMOLED dark mode';

  @override
  String get amoledDarkModeHint => 'Use true black background';

  @override
  String get dynamicColor => 'Dynamic color';

  @override
  String get dynamicColorHint => 'Adapt theme to wallpaper (Android 12+)';

  @override
  String get content => 'Content';

  @override
  String get countryGl => 'Country';

  @override
  String get languageHl => 'Language';

  @override
  String get playback => 'Playback';

  @override
  String get crossfade => 'Crossfade';

  @override
  String get duration => 'Duration';

  @override
  String get restoreQueueOnStartup => 'Restore queue on startup';

  @override
  String get autoPlayUpNext => 'Auto-play Up Next';

  @override
  String get autoPlayUpNextHint =>
      'Automatically play related content when queue ends';

  @override
  String get downloadsSettings => 'Downloads';

  @override
  String get downloadFolder => 'Download folder';

  @override
  String get defaultLocation => 'Default location';

  @override
  String get downloadOnlyOnWifi => 'Download only on Wi-Fi';

  @override
  String get privacy => 'Privacy';

  @override
  String get trackListeningHistory => 'Track listening history';

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get clearListeningHistory => 'Clear listening history';

  @override
  String get clearSearchHistoryConfirm => 'This action cannot be undone.';

  @override
  String get searchHistoryCleared => 'Search history cleared';

  @override
  String get listeningHistoryCleared => 'Listening history cleared';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get exportData => 'Export data';

  @override
  String get exportDataHint => 'Save playlists, likes, and settings';

  @override
  String get importData => 'Import data';

  @override
  String get importDataHint => 'Restore from a backup file';

  @override
  String backupSaved(String path) {
    return 'Backup saved to $path';
  }

  @override
  String get backupExportedSuccessfully => 'Backup exported successfully';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importBackup => 'Import backup';

  @override
  String get importBackupConfirm =>
      'This will add backed-up songs, artists, and playlists to your existing library. No data will be overwritten.';

  @override
  String get import => 'Import';

  @override
  String get backupImportedSuccessfully => 'Backup imported successfully';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get updates => 'Updates';

  @override
  String get checkOnStartup => 'Check on startup';

  @override
  String get checkOnStartupHint => 'Auto-check for updates (max once per 24h)';

  @override
  String get checkNow => 'Check now';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get upToDate => 'Up to Date';

  @override
  String currentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String latestVersion(String version) {
    return 'Latest version: $version';
  }

  @override
  String get close => 'Close';

  @override
  String get downloadUpdate => 'Download Update';

  @override
  String updateCheckFailed(String error) {
    return 'Update check failed: $error';
  }

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get downloadingUpdate => 'Downloading update…';

  @override
  String get downloadComplete => 'Download complete';

  @override
  String get installUpdate => 'Install';

  @override
  String get error => 'Error';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get support => 'Support';

  @override
  String get donate => 'Donate';

  @override
  String get donateHint => 'Support the development with a donation';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'App version';

  @override
  String get licenses => 'Licenses';

  @override
  String get gitHubRepository => 'GitHub repository';

  @override
  String get batteryOptimization => 'Battery Optimization';

  @override
  String get batteryOptimizationHint =>
      'Allow the app to run uninterrupted in the background';

  @override
  String get disableBatteryOptimization => 'Disable battery optimization';

  @override
  String get disableBatteryOptimizationHint =>
      'Prevents Android from stopping playback when the app is in the background';

  @override
  String get manufacturerBatteryOptimization =>
      'Manufacturer battery optimization';

  @override
  String get manufacturerBatteryOptimizationHint =>
      'Additional battery saving features from your device manufacturer';

  @override
  String get playingFrom => 'PLAYING FROM';

  @override
  String get nowPlaying => 'NOW PLAYING';

  @override
  String get mv => 'MV';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get queue => 'Queue';

  @override
  String get sleepTimerActive => 'Sleep timer active';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String hours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String get cancelTimer => 'Cancel Timer';

  @override
  String get devices => 'Devices';

  @override
  String get shuffleOn => 'Shuffle on';

  @override
  String get shuffleOff => 'Shuffle off';

  @override
  String get repeatAll => 'Repeat all';

  @override
  String get repeatOne => 'Repeat one';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get queueIsEmpty => 'Queue is empty';

  @override
  String get lyricsNotAvailable => 'Lyrics not available';

  @override
  String get upNext => 'Up Next';

  @override
  String get noUpcomingSongs => 'No upcoming songs';

  @override
  String get playNow => 'Play Now';

  @override
  String get playNext => 'Play Next';

  @override
  String get goToArtist => 'Go to Artist';

  @override
  String get goToAlbum => 'Go to Album';

  @override
  String get goToPlaylist => 'Go to Playlist';

  @override
  String get startRadio => 'Start Radio';

  @override
  String get failedToStartRadio => 'Failed to start radio';

  @override
  String get addToPlaylist => 'Add to Playlist';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get download => 'Download';

  @override
  String get alreadyDownloadedConfirm =>
      'This song is already downloaded. Downloading again will overwrite the existing file. Continue?';

  @override
  String get downloadStarted => 'Download started';

  @override
  String get like => 'Like';

  @override
  String get unlike => 'Unlike';

  @override
  String get createNewPlaylist => 'Create New Playlist';

  @override
  String addedTo(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String addedToPlaylist(String playlistName) {
    return 'Added to \"$playlistName\"';
  }

  @override
  String get continueListening => 'Continue Listening';

  @override
  String get refresh => 'Refresh';

  @override
  String get failedToLoadHomeFeed => 'Failed to load home feed';

  @override
  String get yourPlaylists => 'Your playlists';

  @override
  String get yourArtists => 'Your artists';

  @override
  String get likedAlbumsHome => 'Liked albums';

  @override
  String get newReleases => 'New releases';

  @override
  String get discover => 'Discover';

  @override
  String get similarArtistsHome => 'Similar artists';

  @override
  String get retry => 'Retry';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get myPlaylist => 'My playlist';

  @override
  String get save => 'Save';

  @override
  String get onLabel => 'On';

  @override
  String get offLabel => 'Off';

  @override
  String get reduceEffects => 'Reduce visual effects';

  @override
  String get reduceEffectsHint =>
      'Disable background blurs and shadows to improve performance on older devices';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get castToDevice => 'Cast to a device';

  @override
  String get searchingDevices => 'Searching for devices…';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get alexaBluetooth => 'Amazon Alexa (Bluetooth)';

  @override
  String get alexaBluetoothInstructions =>
      'Say \"Alexa, connect Bluetooth\" and pair from your device\'s panel.';

  @override
  String get openBluetoothSettings => 'Open Bluetooth Settings';
}
