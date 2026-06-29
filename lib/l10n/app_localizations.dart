import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sonora'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsLabel;

  /// No description provided for @failedToLoadArtist.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artist'**
  String get failedToLoadArtist;

  /// No description provided for @failedToLoadAlbum.
  ///
  /// In en, this message translates to:
  /// **'Failed to load album'**
  String get failedToLoadAlbum;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @singles.
  ///
  /// In en, this message translates to:
  /// **'Singles'**
  String get singles;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @similarArtists.
  ///
  /// In en, this message translates to:
  /// **'Similar Artists'**
  String get similarArtists;

  /// No description provided for @topSongs.
  ///
  /// In en, this message translates to:
  /// **'Top Songs'**
  String get topSongs;

  /// No description provided for @featuredOn.
  ///
  /// In en, this message translates to:
  /// **'Featured On'**
  String get featuredOn;

  /// No description provided for @relatedReleases.
  ///
  /// In en, this message translates to:
  /// **'Related Releases'**
  String get relatedReleases;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @failedToLoadSongs.
  ///
  /// In en, this message translates to:
  /// **'Failed to load songs: {error}'**
  String failedToLoadSongs(String error);

  /// No description provided for @playTopSongs.
  ///
  /// In en, this message translates to:
  /// **'Play Top Songs'**
  String get playTopSongs;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @playingArtist.
  ///
  /// In en, this message translates to:
  /// **'Playing {artistName}…'**
  String playingArtist(String artistName);

  /// No description provided for @failedToPlay.
  ///
  /// In en, this message translates to:
  /// **'Failed to play: {error}'**
  String failedToPlay(String error);

  /// No description provided for @shufflingArtist.
  ///
  /// In en, this message translates to:
  /// **'Shuffling {artistName}…'**
  String shufflingArtist(String artistName);

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @artistRadio.
  ///
  /// In en, this message translates to:
  /// **'Artist Radio'**
  String get artistRadio;

  /// No description provided for @failedToStartArtistRadio.
  ///
  /// In en, this message translates to:
  /// **'Failed to start artist radio: {error}'**
  String failedToStartArtistRadio(String error);

  /// No description provided for @subscribers.
  ///
  /// In en, this message translates to:
  /// **'subscribers'**
  String get subscribers;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'views'**
  String get views;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @failedToLoadPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlist'**
  String get failedToLoadPlaylist;

  /// No description provided for @failedToLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Failed to load videos'**
  String get failedToLoadVideos;

  /// No description provided for @videoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 video} other{{count} videos}}'**
  String videoCount(int count);

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @shufflePlay.
  ///
  /// In en, this message translates to:
  /// **'Shuffle play'**
  String get shufflePlay;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get addToQueue;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added {count, plural, =1{1 song} other{{count} songs}} to queue'**
  String addedToQueue(int count);

  /// No description provided for @failedToAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Failed to add to queue: {error}'**
  String failedToAddToQueue(String error);

  /// No description provided for @playingPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playing {playlistName}…'**
  String playingPlaylist(String playlistName);

  /// No description provided for @failedToPlayPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Failed to play playlist: {error}'**
  String failedToPlayPlaylist(String error);

  /// No description provided for @shufflingPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Shuffling {playlistName}…'**
  String shufflingPlaylist(String playlistName);

  /// No description provided for @allSongsAlreadyDownloading.
  ///
  /// In en, this message translates to:
  /// **'All songs already downloading'**
  String get allSongsAlreadyDownloading;

  /// No description provided for @alreadyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Already downloaded'**
  String get alreadyDownloaded;

  /// No description provided for @alreadyDownloadedSongs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} from {playlistName} {count, plural, =1{is} other{are}} already downloaded. Downloading again will overwrite existing files. Continue?'**
  String alreadyDownloadedSongs(int count, String playlistName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @downloadingSongs.
  ///
  /// In en, this message translates to:
  /// **'Downloading {count, plural, =1{1 song} other{{count} songs}} from {playlistName}…'**
  String downloadingSongs(int count, String playlistName);

  /// No description provided for @likePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Like Playlist'**
  String get likePlaylist;

  /// No description provided for @unlikePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Unlike Playlist'**
  String get unlikePlaylist;

  /// No description provided for @downloadedCount.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {downloaded}/{total}'**
  String downloadedCount(int downloaded, int total);

  /// No description provided for @downloadPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Download Playlist'**
  String get downloadPlaylist;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get playlistEmpty;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'View List'**
  String get viewList;

  /// No description provided for @viewGrid.
  ///
  /// In en, this message translates to:
  /// **'View Grid'**
  String get viewGrid;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @failedToLoadFavorites.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorites'**
  String get failedToLoadFavorites;

  /// No description provided for @failedToLoadArtists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artists'**
  String get failedToLoadArtists;

  /// No description provided for @failedToLoadPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlists'**
  String get failedToLoadPlaylists;

  /// No description provided for @failedToLoadLikedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load liked playlists'**
  String get failedToLoadLikedPlaylists;

  /// No description provided for @failedToLoadAlbums.
  ///
  /// In en, this message translates to:
  /// **'Failed to load albums'**
  String get failedToLoadAlbums;

  /// No description provided for @failedToLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history'**
  String get failedToLoadHistory;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @noFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any song to add it here.'**
  String get noFavoritesHint;

  /// No description provided for @noFollowedArtists.
  ///
  /// In en, this message translates to:
  /// **'No followed artists'**
  String get noFollowedArtists;

  /// No description provided for @noFollowedArtistsHint.
  ///
  /// In en, this message translates to:
  /// **'Follow artists from their artist page to see them here.'**
  String get noFollowedArtistsHint;

  /// No description provided for @myPlaylists.
  ///
  /// In en, this message translates to:
  /// **'My Playlists'**
  String get myPlaylists;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @noLocalPlaylistsYet.
  ///
  /// In en, this message translates to:
  /// **'No local playlists yet.'**
  String get noLocalPlaylistsYet;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deletePlaylistConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @likedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Liked Playlists'**
  String get likedPlaylists;

  /// No description provided for @likePlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Like a playlist from its page to see it here.'**
  String get likePlaylistHint;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get renamePlaylist;

  /// No description provided for @noLikedAlbums.
  ///
  /// In en, this message translates to:
  /// **'No liked albums'**
  String get noLikedAlbums;

  /// No description provided for @noLikedAlbumsHint.
  ///
  /// In en, this message translates to:
  /// **'Like an album from its page to see it here.'**
  String get noLikedAlbumsHint;

  /// No description provided for @albumInfo.
  ///
  /// In en, this message translates to:
  /// **'{artistName} · {year}'**
  String albumInfo(String artistName, String year);

  /// No description provided for @noListeningHistory.
  ///
  /// In en, this message translates to:
  /// **'No listening history'**
  String get noListeningHistory;

  /// No description provided for @noListeningHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Your recently played songs will appear here.'**
  String get noListeningHistoryHint;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all listening history?'**
  String get clearHistoryConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @searchLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Search in library...'**
  String get searchLibraryHint;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @leastRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Least recently added'**
  String get leastRecentlyAdded;

  /// No description provided for @alphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical (A - Z)'**
  String get alphabetical;

  /// No description provided for @alphabeticalReverse.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical (Z - A)'**
  String get alphabeticalReverse;

  /// No description provided for @failedToLoadPlaylistEntries.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlist entries'**
  String get failedToLoadPlaylistEntries;

  /// No description provided for @emptyPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Empty playlist'**
  String get emptyPlaylist;

  /// No description provided for @emptyPlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Add songs from the context menu to grow your playlist.'**
  String get emptyPlaylistHint;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @playlistNameRequired.
  ///
  /// In en, this message translates to:
  /// **'A playlist name is required'**
  String get playlistNameRequired;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @failedToLoadDownloads.
  ///
  /// In en, this message translates to:
  /// **'Failed to load downloads'**
  String get failedToLoadDownloads;

  /// No description provided for @noDownloadsYet.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get noDownloadsYet;

  /// No description provided for @noDownloadsHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press on any song and select Download\nto save it for offline playback.'**
  String get noDownloadsHint;

  /// No description provided for @activeDownloads.
  ///
  /// In en, this message translates to:
  /// **'Active Downloads'**
  String get activeDownloads;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadedSongs.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Songs'**
  String get downloadedSongs;

  /// No description provided for @unknownSize.
  ///
  /// In en, this message translates to:
  /// **'unknown size'**
  String get unknownSize;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums...'**
  String get searchHint;

  /// No description provided for @searchForMusic.
  ///
  /// In en, this message translates to:
  /// **'Search for music'**
  String get searchForMusic;

  /// No description provided for @searchForMusicHint.
  ///
  /// In en, this message translates to:
  /// **'Find your favorite songs, artists, and albums'**
  String get searchForMusicHint;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchArtists;

  /// No description provided for @searchAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get searchAlbums;

  /// No description provided for @searchPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get searchPlaylists;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @noResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get noResultsHint;

  /// No description provided for @topResult.
  ///
  /// In en, this message translates to:
  /// **'Top Result'**
  String get topResult;

  /// No description provided for @featuredTrack.
  ///
  /// In en, this message translates to:
  /// **'Featured Track'**
  String get featuredTrack;

  /// No description provided for @featuredArtist.
  ///
  /// In en, this message translates to:
  /// **'Featured Artist'**
  String get featuredArtist;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @amoledDarkMode.
  ///
  /// In en, this message translates to:
  /// **'AMOLED dark mode'**
  String get amoledDarkMode;

  /// No description provided for @amoledDarkModeHint.
  ///
  /// In en, this message translates to:
  /// **'Use true black background'**
  String get amoledDarkModeHint;

  /// No description provided for @dynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get dynamicColor;

  /// No description provided for @dynamicColorHint.
  ///
  /// In en, this message translates to:
  /// **'Adapt theme to wallpaper (Android 12+)'**
  String get dynamicColorHint;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @countryGl.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryGl;

  /// No description provided for @languageHl.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageHl;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @crossfade.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get crossfade;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @restoreQueueOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Restore queue on startup'**
  String get restoreQueueOnStartup;

  /// No description provided for @autoPlayUpNext.
  ///
  /// In en, this message translates to:
  /// **'Auto-play Up Next'**
  String get autoPlayUpNext;

  /// No description provided for @autoPlayUpNextHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically play related content when queue ends'**
  String get autoPlayUpNextHint;

  /// No description provided for @downloadsSettings.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsSettings;

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

  /// No description provided for @defaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Default location'**
  String get defaultLocation;

  /// No description provided for @downloadOnlyOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Download only on Wi-Fi'**
  String get downloadOnlyOnWifi;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @trackListeningHistory.
  ///
  /// In en, this message translates to:
  /// **'Track listening history'**
  String get trackListeningHistory;

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// No description provided for @clearListeningHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear listening history'**
  String get clearListeningHistory;

  /// No description provided for @clearSearchHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get clearSearchHistoryConfirm;

  /// No description provided for @searchHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Search history cleared'**
  String get searchHistoryCleared;

  /// No description provided for @listeningHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Listening history cleared'**
  String get listeningHistoryCleared;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// No description provided for @exportDataHint.
  ///
  /// In en, this message translates to:
  /// **'Save playlists, likes, and settings'**
  String get exportDataHint;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importData;

  /// No description provided for @importDataHint.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
  String get importDataHint;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to {path}'**
  String backupSaved(String path);

  /// No description provided for @backupExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Backup exported successfully'**
  String get backupExportedSuccessfully;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get importBackup;

  /// No description provided for @importBackupConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will add backed-up songs, artists, and playlists to your existing library. No data will be overwritten.'**
  String get importBackupConfirm;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @backupImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Backup imported successfully'**
  String get backupImportedSuccessfully;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @checkOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Check on startup'**
  String get checkOnStartup;

  /// No description provided for @checkOnStartupHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-check for updates (max once per 24h)'**
  String get checkOnStartupHint;

  /// No description provided for @checkNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get checkNow;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to Date'**
  String get upToDate;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version: {version}'**
  String currentVersion(String version);

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest version: {version}'**
  String latestVersion(String version);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get downloadUpdate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get checkingForUpdates;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get downloadingUpdate;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get downloadComplete;

  /// No description provided for @installUpdate.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get installUpdate;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// No description provided for @donateHint.
  ///
  /// In en, this message translates to:
  /// **'Support the development with a donation'**
  String get donateHint;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @gitHubRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get gitHubRepository;

  /// No description provided for @batteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization'**
  String get batteryOptimization;

  /// No description provided for @batteryOptimizationHint.
  ///
  /// In en, this message translates to:
  /// **'Allow the app to run uninterrupted in the background'**
  String get batteryOptimizationHint;

  /// No description provided for @disableBatteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Disable battery optimization'**
  String get disableBatteryOptimization;

  /// No description provided for @disableBatteryOptimizationHint.
  ///
  /// In en, this message translates to:
  /// **'Prevents Android from stopping playback when the app is in the background'**
  String get disableBatteryOptimizationHint;

  /// No description provided for @manufacturerBatteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer battery optimization'**
  String get manufacturerBatteryOptimization;

  /// No description provided for @manufacturerBatteryOptimizationHint.
  ///
  /// In en, this message translates to:
  /// **'Additional battery saving features from your device manufacturer'**
  String get manufacturerBatteryOptimizationHint;

  /// No description provided for @playingFrom.
  ///
  /// In en, this message translates to:
  /// **'PLAYING FROM'**
  String get playingFrom;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING'**
  String get nowPlaying;

  /// No description provided for @mv.
  ///
  /// In en, this message translates to:
  /// **'MV'**
  String get mv;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get unknownArtist;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @sleepTimerActive.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer active'**
  String get sleepTimerActive;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} hour} other{{count} hours}}'**
  String hours(int count);

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} minute} other{{count} minutes}}'**
  String minutes(int count);

  /// No description provided for @cancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel Timer'**
  String get cancelTimer;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @shuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle on'**
  String get shuffleOn;

  /// No description provided for @shuffleOff.
  ///
  /// In en, this message translates to:
  /// **'Shuffle off'**
  String get shuffleOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get repeatOne;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @queueIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueIsEmpty;

  /// No description provided for @lyricsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Lyrics not available'**
  String get lyricsNotAvailable;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// No description provided for @noUpcomingSongs.
  ///
  /// In en, this message translates to:
  /// **'No upcoming songs'**
  String get noUpcomingSongs;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get playNow;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get playNext;

  /// No description provided for @goToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get goToArtist;

  /// No description provided for @goToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get goToAlbum;

  /// No description provided for @goToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Go to Playlist'**
  String get goToPlaylist;

  /// No description provided for @startRadio.
  ///
  /// In en, this message translates to:
  /// **'Start Radio'**
  String get startRadio;

  /// No description provided for @failedToStartRadio.
  ///
  /// In en, this message translates to:
  /// **'Failed to start radio'**
  String get failedToStartRadio;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @alreadyDownloadedConfirm.
  ///
  /// In en, this message translates to:
  /// **'This song is already downloaded. Downloading again will overwrite the existing file. Continue?'**
  String get alreadyDownloadedConfirm;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @unlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get unlike;

  /// No description provided for @createNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create New Playlist'**
  String get createNewPlaylist;

  /// No description provided for @addedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String addedTo(String name);

  /// No description provided for @addedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{playlistName}\"'**
  String addedToPlaylist(String playlistName);

  /// No description provided for @continueListening.
  ///
  /// In en, this message translates to:
  /// **'Continue Listening'**
  String get continueListening;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @failedToLoadHomeFeed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load home feed'**
  String get failedToLoadHomeFeed;

  /// No description provided for @yourPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Your playlists'**
  String get yourPlaylists;

  /// No description provided for @yourArtists.
  ///
  /// In en, this message translates to:
  /// **'Your artists'**
  String get yourArtists;

  /// No description provided for @likedAlbumsHome.
  ///
  /// In en, this message translates to:
  /// **'Liked albums'**
  String get likedAlbumsHome;

  /// No description provided for @newReleases.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get newReleases;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @similarArtistsHome.
  ///
  /// In en, this message translates to:
  /// **'Similar artists'**
  String get similarArtistsHome;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @myPlaylist.
  ///
  /// In en, this message translates to:
  /// **'My playlist'**
  String get myPlaylist;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @onLabel.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onLabel;

  /// No description provided for @offLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offLabel;

  /// No description provided for @reduceEffects.
  ///
  /// In en, this message translates to:
  /// **'Reduce visual effects'**
  String get reduceEffects;

  /// No description provided for @reduceEffectsHint.
  ///
  /// In en, this message translates to:
  /// **'Disable background blurs and shadows to improve performance on older devices'**
  String get reduceEffectsHint;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @castToDevice.
  ///
  /// In en, this message translates to:
  /// **'Cast to a device'**
  String get castToDevice;

  /// No description provided for @searchingDevices.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices…'**
  String get searchingDevices;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @alexaBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Amazon Alexa (Bluetooth)'**
  String get alexaBluetooth;

  /// No description provided for @alexaBluetoothInstructions.
  ///
  /// In en, this message translates to:
  /// **'Say \"Alexa, connect Bluetooth\" and pair from your device\'s panel.'**
  String get alexaBluetoothInstructions;

  /// No description provided for @openBluetoothSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Bluetooth Settings'**
  String get openBluetoothSettings;

  /// No description provided for @offlineNotification.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Downloaded tracks only'**
  String get offlineNotification;

  /// No description provided for @connectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get connectionRestored;

  /// No description provided for @weakConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Internet connection is weak or absent. Please check your network or play downloaded tracks.'**
  String get weakConnectionError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
