// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Sonora';

  @override
  String get home => 'Home';

  @override
  String get search => 'Cerca';

  @override
  String get settingsLabel => 'Impostazioni';

  @override
  String get failedToLoadArtist => 'Impossibile caricare l\'artista';

  @override
  String get failedToLoadAlbum => 'Impossibile caricare l\'album';

  @override
  String get albums => 'Album';

  @override
  String get singles => 'Singoli';

  @override
  String get videos => 'Video';

  @override
  String get similarArtists => 'Artisti Simili';

  @override
  String get topSongs => 'Brani Popolari';

  @override
  String get showLess => 'Mostra meno';

  @override
  String get showMore => 'Mostra altro';

  @override
  String failedToLoadSongs(String error) {
    return 'Impossibile caricare i brani: $error';
  }

  @override
  String get playTopSongs => 'Riproduci Brani Popolari';

  @override
  String get shuffle => 'Riproduzione casuale';

  @override
  String get share => 'Condividi';

  @override
  String playingArtist(String artistName) {
    return 'Riproduzione di $artistName…';
  }

  @override
  String failedToPlay(String error) {
    return 'Impossibile riprodurre: $error';
  }

  @override
  String shufflingArtist(String artistName) {
    return 'Riproduzione casuale di $artistName…';
  }

  @override
  String get follow => 'Segui';

  @override
  String get following => 'Seguito';

  @override
  String get artistRadio => 'Radio Artista';

  @override
  String failedToStartArtistRadio(String error) {
    return 'Impossibile avviare radio artista: $error';
  }

  @override
  String get subscribers => 'iscritti';

  @override
  String get views => 'visualizzazioni';

  @override
  String get description => 'Descrizione';

  @override
  String get failedToLoadPlaylist => 'Impossibile caricare la playlist';

  @override
  String get failedToLoadVideos => 'Impossibile caricare i video';

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Riproduci tutto';

  @override
  String get shufflePlay => 'Riproduzione casuale';

  @override
  String get addToQueue => 'Aggiungi alla Coda';

  @override
  String addedToQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0 aggiunti alla coda';
  }

  @override
  String failedToAddToQueue(String error) {
    return 'Impossibile aggiungere alla coda: $error';
  }

  @override
  String playingPlaylist(String playlistName) {
    return 'Riproduzione di $playlistName…';
  }

  @override
  String failedToPlayPlaylist(String error) {
    return 'Impossibile riprodurre la playlist: $error';
  }

  @override
  String shufflingPlaylist(String playlistName) {
    return 'Riproduzione casuale di $playlistName…';
  }

  @override
  String get allSongsAlreadyDownloading => 'Tutti i brani sono già in download';

  @override
  String get alreadyDownloaded => 'Già scaricato';

  @override
  String alreadyDownloadedSongs(int count, String playlistName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sono',
      one: 'è',
    );
    return '$_temp0 da $playlistName $_temp1 già scaricati. Scaricare di nuovo sovrascriverà i file esistenti. Continuare?';
  }

  @override
  String get cancel => 'Annulla';

  @override
  String get continueAction => 'Continua';

  @override
  String downloadingSongs(int count, String playlistName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return 'Download di $_temp0 da $playlistName…';
  }

  @override
  String get likePlaylist => 'Mi Piace Playlist';

  @override
  String get unlikePlaylist => 'Non Mi Piace Playlist';

  @override
  String downloadedCount(int downloaded, int total) {
    return 'Scaricati $downloaded/$total';
  }

  @override
  String get downloadPlaylist => 'Scarica Playlist';

  @override
  String get playlistEmpty => 'Questa playlist è vuota';

  @override
  String get library => 'Libreria';

  @override
  String get favorites => 'Preferiti';

  @override
  String get artists => 'Artisti';

  @override
  String get playlists => 'Playlist';

  @override
  String get history => 'Cronologia';

  @override
  String get failedToLoadFavorites => 'Impossibile caricare i preferiti';

  @override
  String get failedToLoadArtists => 'Impossibile caricare gli artisti';

  @override
  String get failedToLoadPlaylists => 'Impossibile caricare le playlist';

  @override
  String get failedToLoadLikedPlaylists =>
      'Impossibile caricare le playlist con \'Mi piace\'';

  @override
  String get failedToLoadAlbums => 'Impossibile caricare gli album';

  @override
  String get failedToLoadHistory => 'Impossibile caricare la cronologia';

  @override
  String get noFavoritesYet => 'Nessun preferito ancora';

  @override
  String get noFavoritesHint =>
      'Tocca l\'icona del cuore su qualsiasi brano per aggiungerlo qui.';

  @override
  String get noFollowedArtists => 'Nessun artista seguito';

  @override
  String get noFollowedArtistsHint =>
      'Segui gli artisti dalla loro pagina per vederli qui.';

  @override
  String get myPlaylists => 'Le Mie Playlist';

  @override
  String get createPlaylist => 'Crea Playlist';

  @override
  String get noLocalPlaylistsYet => 'Nessuna playlist locale ancora.';

  @override
  String get deletePlaylist => 'Elimina playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Sei sicuro di voler eliminare \"$name\"?';
  }

  @override
  String get delete => 'Elimina';

  @override
  String get likedPlaylists => 'Playlist con Mi Piace';

  @override
  String get likePlaylistHint =>
      'Metti \'Mi piace\' a una playlist dalla sua pagina per vederla qui.';

  @override
  String get renamePlaylist => 'Rinomina playlist';

  @override
  String get noLikedAlbums => 'Nessun album con Mi Piace';

  @override
  String get noLikedAlbumsHint =>
      'Metti \'Mi piace\' a un album dalla sua pagina per vederlo qui.';

  @override
  String albumInfo(String artistName, String year) {
    return '$artistName · $year';
  }

  @override
  String get noListeningHistory => 'Nessuna cronologia di ascolto';

  @override
  String get noListeningHistoryHint =>
      'I brani riprodotti di recente appariranno qui.';

  @override
  String get clearHistory => 'Cancella cronologia';

  @override
  String get clearHistoryConfirm =>
      'Sei sicuro di voler cancellare tutta la cronologia di ascolto?';

  @override
  String get clear => 'Cancella';

  @override
  String get failedToLoadPlaylistEntries =>
      'Impossibile caricare gli elementi della playlist';

  @override
  String get emptyPlaylist => 'Playlist vuota';

  @override
  String get emptyPlaylistHint =>
      'Aggiungi brani dal menu contestuale per far crescere la tua playlist.';

  @override
  String get downloads => 'Download';

  @override
  String get failedToLoadDownloads => 'Impossibile caricare i download';

  @override
  String get noDownloadsYet => 'Nessun download ancora';

  @override
  String get noDownloadsHint =>
      'Tieni premuto su qualsiasi brano e seleziona Download\nper salvarlo per la riproduzione offline.';

  @override
  String get activeDownloads => 'Download Attivi';

  @override
  String get downloadFailed => 'Download fallito';

  @override
  String get downloadedSongs => 'Brani Scaricati';

  @override
  String get unknownSize => 'dimensione sconosciuta';

  @override
  String get searchHint => 'Cerca brani, artisti, album...';

  @override
  String get searchForMusic => 'Cerca musica';

  @override
  String get searchForMusicHint =>
      'Trova i tuoi brani, artisti e album preferiti';

  @override
  String get recentSearches => 'Ricerche Recenti';

  @override
  String get all => 'Tutto';

  @override
  String get songs => 'Brani';

  @override
  String get searchArtists => 'Artisti';

  @override
  String get searchAlbums => 'Album';

  @override
  String get searchPlaylists => 'Playlist';

  @override
  String get searchFailed => 'Ricerca fallita';

  @override
  String get noResults => 'Nessun risultato';

  @override
  String get noResultsHint => 'Prova un termine di ricerca diverso';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Chiaro';

  @override
  String get dark => 'Scuro';

  @override
  String get appearance => 'Aspetto';

  @override
  String get amoledDarkMode => 'Modalità scura AMOLED';

  @override
  String get amoledDarkModeHint => 'Usa lo sfondo nero puro';

  @override
  String get dynamicColor => 'Colore dinamico';

  @override
  String get dynamicColorHint => 'Adatta il tema allo sfondo (Android 12+)';

  @override
  String get content => 'Contenuto';

  @override
  String get countryGl => 'Paese (gl)';

  @override
  String get languageHl => 'Lingua (hl)';

  @override
  String get playback => 'Riproduzione';

  @override
  String get crossfade => 'Dissolvenza incrociata';

  @override
  String get duration => 'Durata';

  @override
  String get restoreQueueOnStartup => 'Ripristina coda all\'avvio';

  @override
  String get autoPlayUpNext => 'Riproduzione automatica Up Next';

  @override
  String get autoPlayUpNextHint =>
      'Riproduci automaticamente contenuti correlati quando la coda termina';

  @override
  String get downloadsSettings => 'Download';

  @override
  String get downloadFolder => 'Cartella download';

  @override
  String get defaultLocation => 'Posizione predefinita';

  @override
  String get downloadOnlyOnWifi => 'Scarica solo su Wi-Fi';

  @override
  String get privacy => 'Privacy';

  @override
  String get trackListeningHistory => 'Traccia cronologia di ascolto';

  @override
  String get clearSearchHistory => 'Cancella cronologia ricerca';

  @override
  String get clearListeningHistory => 'Cancella cronologia di ascolto';

  @override
  String get clearSearchHistoryConfirm =>
      'Questa azione non può essere annullata.';

  @override
  String get searchHistoryCleared => 'Cronologia ricerca cancellata';

  @override
  String get listeningHistoryCleared => 'Cronologia di ascolto cancellata';

  @override
  String get backupRestore => 'Backup e Ripristino';

  @override
  String get exportData => 'Esporta dati';

  @override
  String get exportDataHint => 'Salva playlist, Mi Piace e impostazioni';

  @override
  String get importData => 'Importa dati';

  @override
  String get importDataHint => 'Ripristina da un file di backup';

  @override
  String backupSaved(String path) {
    return 'Backup salvato in $path';
  }

  @override
  String get backupExportedSuccessfully => 'Backup esportato con successo';

  @override
  String exportFailed(String error) {
    return 'Esportazione fallita: $error';
  }

  @override
  String get importBackup => 'Importa backup';

  @override
  String get importBackupConfirm =>
      'Questo aggiungerà brani, artisti e playlist di backup alla tua libreria esistente. Nessun dato verrà sovrascritto.';

  @override
  String get import => 'Importa';

  @override
  String get backupImportedSuccessfully => 'Backup importato con successo';

  @override
  String importFailed(String error) {
    return 'Importazione fallita: $error';
  }

  @override
  String get updates => 'Aggiornamenti';

  @override
  String get checkOnStartup => 'Controlla all\'avvio';

  @override
  String get checkOnStartupHint =>
      'Controllo automatico aggiornamenti (max una volta ogni 24h)';

  @override
  String get checkNow => 'Controlla ora';

  @override
  String get updateAvailable => 'Aggiornamento Disponibile';

  @override
  String get upToDate => 'Aggiornato';

  @override
  String currentVersion(String version) {
    return 'Versione attuale: $version';
  }

  @override
  String latestVersion(String version) {
    return 'Ultima versione: $version';
  }

  @override
  String get close => 'Chiudi';

  @override
  String get downloadUpdate => 'Scarica Aggiornamento';

  @override
  String updateCheckFailed(String error) {
    return 'Controllo aggiornamento fallito: $error';
  }

  @override
  String get checkingForUpdates => 'Verifica aggiornamenti…';

  @override
  String get downloadingUpdate => 'Scaricamento aggiornamento…';

  @override
  String get downloadComplete => 'Download completato';

  @override
  String get installUpdate => 'Installa';

  @override
  String get error => 'Errore';

  @override
  String get unknownError => 'Errore sconosciuto';

  @override
  String get about => 'Info';

  @override
  String get appVersion => 'Versione app';

  @override
  String get licenses => 'Licenze';

  @override
  String get gitHubRepository => 'Repository GitHub';

  @override
  String get batteryOptimization => 'Ottimizzazione Batteria';

  @override
  String get batteryOptimizationHint =>
      'Consenti all\'app di funzionare senza interruzioni in background';

  @override
  String get disableBatteryOptimization => 'Disabilita ottimizzazione batteria';

  @override
  String get disableBatteryOptimizationHint =>
      'Impedisce ad Android di fermare la riproduzione quando l\'app è in background';

  @override
  String get manufacturerBatteryOptimization =>
      'Ottimizzazione batteria produttore';

  @override
  String get manufacturerBatteryOptimizationHint =>
      'Funzioni aggiuntive di risparmio energetico del produttore del dispositivo';

  @override
  String get playingFrom => 'RIPRODOTTO DA';

  @override
  String get nowPlaying => 'IN RIPRODUZIONE';

  @override
  String get mv => 'MV';

  @override
  String get unknownArtist => 'Artista Sconosciuto';

  @override
  String get lyrics => 'Testi';

  @override
  String get queue => 'Coda';

  @override
  String get sleepTimerActive => 'Timer sleep attivo';

  @override
  String get sleepTimer => 'Timer sleep';

  @override
  String hours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '$count ora',
    );
    return '$_temp0';
  }

  @override
  String minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuti',
      one: '$count minuto',
    );
    return '$_temp0';
  }

  @override
  String get cancelTimer => 'Annulla Timer';

  @override
  String get devices => 'Dispositivi';

  @override
  String get shuffleOn => 'Casuale attivo';

  @override
  String get shuffleOff => 'Casuale disattivato';

  @override
  String get repeatAll => 'Ripeti tutto';

  @override
  String get repeatOne => 'Ripeti uno';

  @override
  String get repeatOff => 'Ripetizione disattivata';

  @override
  String get queueIsEmpty => 'La coda è vuota';

  @override
  String get lyricsNotAvailable => 'Testi non disponibili';

  @override
  String get playNow => 'Riproduci Ora';

  @override
  String get playNext => 'Riproduci Dopo';

  @override
  String get goToArtist => 'Vai all\'Artista';

  @override
  String get goToAlbum => 'Vai all\'Album';

  @override
  String get goToPlaylist => 'Vai alla Playlist';

  @override
  String get startRadio => 'Avvia Radio';

  @override
  String get failedToStartRadio => 'Impossibile avviare radio';

  @override
  String get addToPlaylist => 'Aggiungi a Playlist';

  @override
  String get downloaded => 'Scaricato';

  @override
  String get download => 'Scarica';

  @override
  String get alreadyDownloadedConfirm =>
      'Questo brano è già scaricato. Scaricare di nuovo sovrascriverà il file esistente. Continuare?';

  @override
  String get downloadStarted => 'Download avviato';

  @override
  String get like => 'Mi Piace';

  @override
  String get unlike => 'Non Mi Piace';

  @override
  String get createNewPlaylist => 'Crea Nuova Playlist';

  @override
  String addedTo(String name) {
    return 'Aggiunto a \"$name\"';
  }

  @override
  String addedToPlaylist(String playlistName) {
    return 'Aggiunto a \"$playlistName\"';
  }

  @override
  String get continueListening => 'Continua ad ascoltare';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get failedToLoadHomeFeed => 'Impossibile caricare la home';

  @override
  String get retry => 'Riprova';

  @override
  String get newPlaylist => 'Nuova playlist';

  @override
  String get playlistName => 'Nome playlist';

  @override
  String get myPlaylist => 'La mia playlist';

  @override
  String get save => 'Salva';

  @override
  String get onLabel => 'On';

  @override
  String get offLabel => 'Off';
}
