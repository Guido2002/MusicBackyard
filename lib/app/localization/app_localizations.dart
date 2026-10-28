import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('nl')];

  /// No description provided for @appName.
  ///
  /// In nl, this message translates to:
  /// **'MusicBackyard'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In nl, this message translates to:
  /// **'Jouw muziek. Jouw plek.'**
  String get tagline;

  /// No description provided for @library.
  ///
  /// In nl, this message translates to:
  /// **'Bibliotheek'**
  String get library;

  /// No description provided for @studio.
  ///
  /// In nl, this message translates to:
  /// **'Studio'**
  String get studio;

  /// No description provided for @setlists.
  ///
  /// In nl, this message translates to:
  /// **'Setlists'**
  String get setlists;

  /// No description provided for @performance.
  ///
  /// In nl, this message translates to:
  /// **'Speelmodus'**
  String get performance;

  /// No description provided for @more.
  ///
  /// In nl, this message translates to:
  /// **'Meer'**
  String get more;

  /// No description provided for @welcome.
  ///
  /// In nl, this message translates to:
  /// **'Welkom bij MusicBackyard'**
  String get welcome;

  /// No description provided for @welcomeBody.
  ///
  /// In nl, this message translates to:
  /// **'Bewaar al jouw muziek op één plek. Schrijf, verzamel en speel — ook zonder internet.'**
  String get welcomeBody;

  /// No description provided for @start.
  ///
  /// In nl, this message translates to:
  /// **'Aan de slag'**
  String get start;

  /// No description provided for @instrument.
  ///
  /// In nl, this message translates to:
  /// **'Jouw instrument'**
  String get instrument;

  /// No description provided for @guitar.
  ///
  /// In nl, this message translates to:
  /// **'Gitaar'**
  String get guitar;

  /// No description provided for @piano.
  ///
  /// In nl, this message translates to:
  /// **'Piano/toetsen'**
  String get piano;

  /// No description provided for @voice.
  ///
  /// In nl, this message translates to:
  /// **'Zang'**
  String get voice;

  /// No description provided for @bass.
  ///
  /// In nl, this message translates to:
  /// **'Basgitaar'**
  String get bass;

  /// No description provided for @other.
  ///
  /// In nl, this message translates to:
  /// **'Ander instrument'**
  String get other;

  /// No description provided for @multiple.
  ///
  /// In nl, this message translates to:
  /// **'Meerdere instrumenten'**
  String get multiple;

  /// No description provided for @next.
  ///
  /// In nl, this message translates to:
  /// **'Volgende'**
  String get next;

  /// No description provided for @back.
  ///
  /// In nl, this message translates to:
  /// **'Terug'**
  String get back;

  /// No description provided for @firstSong.
  ///
  /// In nl, this message translates to:
  /// **'Maak ruimte voor je muziek'**
  String get firstSong;

  /// No description provided for @firstSongBody.
  ///
  /// In nl, this message translates to:
  /// **'Schrijf je eerste nummer of importeer je eigen muziekdocument. Een account is niet nodig.'**
  String get firstSongBody;

  /// No description provided for @newSong.
  ///
  /// In nl, this message translates to:
  /// **'Nieuw nummer'**
  String get newSong;

  /// No description provided for @add.
  ///
  /// In nl, this message translates to:
  /// **'Toevoegen'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In nl, this message translates to:
  /// **'Annuleren'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In nl, this message translates to:
  /// **'Opslaan'**
  String get save;

  /// No description provided for @title.
  ///
  /// In nl, this message translates to:
  /// **'Titel'**
  String get title;

  /// No description provided for @artist.
  ///
  /// In nl, this message translates to:
  /// **'Artiest'**
  String get artist;

  /// No description provided for @search.
  ///
  /// In nl, this message translates to:
  /// **'Zoek op titel, artiest, tekst of notitie…'**
  String get search;

  /// No description provided for @emptyLibrary.
  ///
  /// In nl, this message translates to:
  /// **'Hier begint jouw muziek'**
  String get emptyLibrary;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In nl, this message translates to:
  /// **'Voeg een nummer toe en geef je ideeën een vaste plek. Alles wordt op dit apparaat bewaard.'**
  String get emptyLibraryBody;

  /// No description provided for @allSongs.
  ///
  /// In nl, this message translates to:
  /// **'Alle nummers'**
  String get allSongs;

  /// No description provided for @favorites.
  ///
  /// In nl, this message translates to:
  /// **'Favorieten'**
  String get favorites;

  /// No description provided for @recent.
  ///
  /// In nl, this message translates to:
  /// **'Recent geopend'**
  String get recent;

  /// No description provided for @folders.
  ///
  /// In nl, this message translates to:
  /// **'Mappen'**
  String get folders;

  /// No description provided for @newFolder.
  ///
  /// In nl, this message translates to:
  /// **'Nieuwe map'**
  String get newFolder;

  /// No description provided for @name.
  ///
  /// In nl, this message translates to:
  /// **'Naam'**
  String get name;

  /// No description provided for @untitled.
  ///
  /// In nl, this message translates to:
  /// **'Naamloos nummer'**
  String get untitled;

  /// No description provided for @delete.
  ///
  /// In nl, this message translates to:
  /// **'Verwijderen'**
  String get delete;

  /// No description provided for @restore.
  ///
  /// In nl, this message translates to:
  /// **'Herstellen'**
  String get restore;

  /// No description provided for @deleted.
  ///
  /// In nl, this message translates to:
  /// **'Verplaatst naar prullenbak'**
  String get deleted;

  /// No description provided for @trash.
  ///
  /// In nl, this message translates to:
  /// **'Prullenbak'**
  String get trash;

  /// No description provided for @duplicate.
  ///
  /// In nl, this message translates to:
  /// **'Dupliceren'**
  String get duplicate;

  /// No description provided for @archive.
  ///
  /// In nl, this message translates to:
  /// **'Archiveren'**
  String get archive;

  /// No description provided for @archived.
  ///
  /// In nl, this message translates to:
  /// **'Archief'**
  String get archived;

  /// No description provided for @unarchive.
  ///
  /// In nl, this message translates to:
  /// **'Terug naar bibliotheek'**
  String get unarchive;

  /// No description provided for @move.
  ///
  /// In nl, this message translates to:
  /// **'Verplaatsen'**
  String get move;

  /// No description provided for @rootFolder.
  ///
  /// In nl, this message translates to:
  /// **'Geen map'**
  String get rootFolder;

  /// No description provided for @sort.
  ///
  /// In nl, this message translates to:
  /// **'Sorteren'**
  String get sort;

  /// No description provided for @sortTitle.
  ///
  /// In nl, this message translates to:
  /// **'Titel'**
  String get sortTitle;

  /// No description provided for @sortUpdated.
  ///
  /// In nl, this message translates to:
  /// **'Laatst bewerkt'**
  String get sortUpdated;

  /// No description provided for @sortOpened.
  ///
  /// In nl, this message translates to:
  /// **'Laatst geopend'**
  String get sortOpened;

  /// No description provided for @offline.
  ///
  /// In nl, this message translates to:
  /// **'Jouw muziek, offline bewaard'**
  String get offline;

  /// No description provided for @songCount.
  ///
  /// In nl, this message translates to:
  /// **'nummers'**
  String get songCount;

  /// No description provided for @lyrics.
  ///
  /// In nl, this message translates to:
  /// **'Tekst & akkoorden'**
  String get lyrics;

  /// No description provided for @tabs.
  ///
  /// In nl, this message translates to:
  /// **'Gitaartabs'**
  String get tabs;

  /// No description provided for @notes.
  ///
  /// In nl, this message translates to:
  /// **'Notities'**
  String get notes;

  /// No description provided for @audio.
  ///
  /// In nl, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @attachments.
  ///
  /// In nl, this message translates to:
  /// **'Bijlagen'**
  String get attachments;

  /// No description provided for @metadata.
  ///
  /// In nl, this message translates to:
  /// **'Nummergegevens'**
  String get metadata;

  /// No description provided for @key.
  ///
  /// In nl, this message translates to:
  /// **'Toonsoort'**
  String get key;

  /// No description provided for @bpm.
  ///
  /// In nl, this message translates to:
  /// **'BPM'**
  String get bpm;

  /// No description provided for @capo.
  ///
  /// In nl, this message translates to:
  /// **'Capo'**
  String get capo;

  /// No description provided for @duration.
  ///
  /// In nl, this message translates to:
  /// **'Duur (seconden)'**
  String get duration;

  /// No description provided for @tags.
  ///
  /// In nl, this message translates to:
  /// **'Tags (komma’s)'**
  String get tags;

  /// No description provided for @spotify.
  ///
  /// In nl, this message translates to:
  /// **'Spotify-link'**
  String get spotify;

  /// No description provided for @album.
  ///
  /// In nl, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @genre.
  ///
  /// In nl, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @timeSignature.
  ///
  /// In nl, this message translates to:
  /// **'Maatsoort'**
  String get timeSignature;

  /// No description provided for @tuning.
  ///
  /// In nl, this message translates to:
  /// **'Stemming'**
  String get tuning;

  /// No description provided for @originalKey.
  ///
  /// In nl, this message translates to:
  /// **'Originele toonsoort'**
  String get originalKey;

  /// No description provided for @comments.
  ///
  /// In nl, this message translates to:
  /// **'Persoonlijke opmerkingen'**
  String get comments;

  /// No description provided for @sections.
  ///
  /// In nl, this message translates to:
  /// **'Secties'**
  String get sections;

  /// No description provided for @addSection.
  ///
  /// In nl, this message translates to:
  /// **'Sectie toevoegen'**
  String get addSection;

  /// No description provided for @sectionName.
  ///
  /// In nl, this message translates to:
  /// **'Sectienaam'**
  String get sectionName;

  /// No description provided for @verse.
  ///
  /// In nl, this message translates to:
  /// **'Couplet'**
  String get verse;

  /// No description provided for @chorus.
  ///
  /// In nl, this message translates to:
  /// **'Refrein'**
  String get chorus;

  /// No description provided for @bridge.
  ///
  /// In nl, this message translates to:
  /// **'Bridge'**
  String get bridge;

  /// No description provided for @intro.
  ///
  /// In nl, this message translates to:
  /// **'Intro'**
  String get intro;

  /// No description provided for @outro.
  ///
  /// In nl, this message translates to:
  /// **'Outro'**
  String get outro;

  /// No description provided for @freeSection.
  ///
  /// In nl, this message translates to:
  /// **'Vrije sectie'**
  String get freeSection;

  /// No description provided for @lyricsHint.
  ///
  /// In nl, this message translates to:
  /// **'Plak of schrijf hier je songtekst…'**
  String get lyricsHint;

  /// No description provided for @addChord.
  ///
  /// In nl, this message translates to:
  /// **'Akkoord op cursor invoegen'**
  String get addChord;

  /// No description provided for @chord.
  ///
  /// In nl, this message translates to:
  /// **'Akkoord'**
  String get chord;

  /// No description provided for @invalidChord.
  ///
  /// In nl, this message translates to:
  /// **'Voer een geldig akkoord in, bijvoorbeeld F#m7 of C/E.'**
  String get invalidChord;

  /// No description provided for @transpose.
  ///
  /// In nl, this message translates to:
  /// **'Transponeren'**
  String get transpose;

  /// No description provided for @semitoneUp.
  ///
  /// In nl, this message translates to:
  /// **'Halve toon hoger'**
  String get semitoneUp;

  /// No description provided for @semitoneDown.
  ///
  /// In nl, this message translates to:
  /// **'Halve toon lager'**
  String get semitoneDown;

  /// No description provided for @undo.
  ///
  /// In nl, this message translates to:
  /// **'Ongedaan maken'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In nl, this message translates to:
  /// **'Opnieuw'**
  String get redo;

  /// No description provided for @saved.
  ///
  /// In nl, this message translates to:
  /// **'Opgeslagen op dit apparaat'**
  String get saved;

  /// No description provided for @saving.
  ///
  /// In nl, this message translates to:
  /// **'Opslaan…'**
  String get saving;

  /// No description provided for @saveError.
  ///
  /// In nl, this message translates to:
  /// **'Opslaan mislukt. Je wijzigingen staan nog op dit scherm. Probeer opnieuw.'**
  String get saveError;

  /// No description provided for @retry.
  ///
  /// In nl, this message translates to:
  /// **'Opnieuw proberen'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In nl, this message translates to:
  /// **'Er ging iets mis'**
  String get error;

  /// No description provided for @close.
  ///
  /// In nl, this message translates to:
  /// **'Sluiten'**
  String get close;

  /// No description provided for @importFile.
  ///
  /// In nl, this message translates to:
  /// **'Bestand importeren'**
  String get importFile;

  /// No description provided for @export.
  ///
  /// In nl, this message translates to:
  /// **'Exporteren'**
  String get export;

  /// No description provided for @chordpro.
  ///
  /// In nl, this message translates to:
  /// **'ChordPro opslaan'**
  String get chordpro;

  /// No description provided for @pdfExport.
  ///
  /// In nl, this message translates to:
  /// **'PDF Export Studio'**
  String get pdfExport;

  /// No description provided for @noSongs.
  ///
  /// In nl, this message translates to:
  /// **'Voeg eerst een nummer toe.'**
  String get noSongs;

  /// No description provided for @newSetlist.
  ///
  /// In nl, this message translates to:
  /// **'Nieuwe setlist'**
  String get newSetlist;

  /// No description provided for @emptySetlists.
  ///
  /// In nl, this message translates to:
  /// **'Een goed optreden begint hier'**
  String get emptySetlists;

  /// No description provided for @emptySetlistsBody.
  ///
  /// In nl, this message translates to:
  /// **'Verzamel nummers, bepaal de volgorde en neem je muziek mee het podium op.'**
  String get emptySetlistsBody;

  /// No description provided for @addSong.
  ///
  /// In nl, this message translates to:
  /// **'Nummer toevoegen'**
  String get addSong;

  /// No description provided for @breakLabel.
  ///
  /// In nl, this message translates to:
  /// **'Pauze'**
  String get breakLabel;

  /// No description provided for @minutes.
  ///
  /// In nl, this message translates to:
  /// **'minuten'**
  String get minutes;

  /// No description provided for @play.
  ///
  /// In nl, this message translates to:
  /// **'Spelen'**
  String get play;

  /// No description provided for @previous.
  ///
  /// In nl, this message translates to:
  /// **'Vorige'**
  String get previous;

  /// No description provided for @fontSize.
  ///
  /// In nl, this message translates to:
  /// **'Lettergrootte'**
  String get fontSize;

  /// No description provided for @showChords.
  ///
  /// In nl, this message translates to:
  /// **'Akkoorden tonen'**
  String get showChords;

  /// No description provided for @autoscroll.
  ///
  /// In nl, this message translates to:
  /// **'Automatisch scrollen'**
  String get autoscroll;

  /// No description provided for @speed.
  ///
  /// In nl, this message translates to:
  /// **'Snelheid'**
  String get speed;

  /// No description provided for @reset.
  ///
  /// In nl, this message translates to:
  /// **'Opnieuw vanaf boven'**
  String get reset;

  /// No description provided for @stop.
  ///
  /// In nl, this message translates to:
  /// **'Stoppen'**
  String get stop;

  /// No description provided for @pause.
  ///
  /// In nl, this message translates to:
  /// **'Pauzeren'**
  String get pause;

  /// No description provided for @record.
  ///
  /// In nl, this message translates to:
  /// **'Opname starten'**
  String get record;

  /// No description provided for @recordStop.
  ///
  /// In nl, this message translates to:
  /// **'Opname stoppen'**
  String get recordStop;

  /// No description provided for @microphoneDenied.
  ///
  /// In nl, this message translates to:
  /// **'Geef microfoontoestemming om een opname te maken.'**
  String get microphoneDenied;

  /// No description provided for @noAudio.
  ///
  /// In nl, this message translates to:
  /// **'Nog geen opnames. Bewaar hier een eigen demo of repetitiefragment.'**
  String get noAudio;

  /// No description provided for @noAttachments.
  ///
  /// In nl, this message translates to:
  /// **'Nog geen bijlagen. Importeer een PDF of afbeelding.'**
  String get noAttachments;

  /// No description provided for @openSpotify.
  ///
  /// In nl, this message translates to:
  /// **'Openen in Spotify'**
  String get openSpotify;

  /// No description provided for @invalidSpotify.
  ///
  /// In nl, this message translates to:
  /// **'Gebruik een Spotify-tracklink: https://open.spotify.com/track/…'**
  String get invalidSpotify;

  /// No description provided for @openFailed.
  ///
  /// In nl, this message translates to:
  /// **'Dit bestand of deze link kon niet worden geopend.'**
  String get openFailed;

  /// No description provided for @theme.
  ///
  /// In nl, this message translates to:
  /// **'Weergave'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In nl, this message translates to:
  /// **'Licht'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In nl, this message translates to:
  /// **'Donker'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In nl, this message translates to:
  /// **'Systeem'**
  String get system;

  /// No description provided for @preferences.
  ///
  /// In nl, this message translates to:
  /// **'Voorkeuren'**
  String get preferences;

  /// No description provided for @profile.
  ///
  /// In nl, this message translates to:
  /// **'Profiel'**
  String get profile;

  /// No description provided for @appUpdates.
  ///
  /// In nl, this message translates to:
  /// **'App-updates'**
  String get appUpdates;

  /// No description provided for @backup.
  ///
  /// In nl, this message translates to:
  /// **'Back-up opslaan'**
  String get backup;

  /// No description provided for @restoreBackup.
  ///
  /// In nl, this message translates to:
  /// **'Back-up terugzetten'**
  String get restoreBackup;

  /// No description provided for @backupWarning.
  ///
  /// In nl, this message translates to:
  /// **'Terugzetten vervangt je huidige bibliotheek. Maak eerst een back-up.'**
  String get backupWarning;

  /// No description provided for @confirmRestore.
  ///
  /// In nl, this message translates to:
  /// **'Back-up terugzetten?'**
  String get confirmRestore;

  /// No description provided for @about.
  ///
  /// In nl, this message translates to:
  /// **'Over MusicBackyard'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In nl, this message translates to:
  /// **'Een persoonlijke muziekwerkplek. Je bibliotheek blijft op je apparaat. Verwijder de app pas nadat je een back-up hebt gemaakt.'**
  String get aboutBody;

  /// No description provided for @checkUpdates.
  ///
  /// In nl, this message translates to:
  /// **'Controleren op updates'**
  String get checkUpdates;

  /// No description provided for @currentVersion.
  ///
  /// In nl, this message translates to:
  /// **'Huidige versie'**
  String get currentVersion;

  /// No description provided for @lastChecked.
  ///
  /// In nl, this message translates to:
  /// **'Laatste succesvolle controle'**
  String get lastChecked;

  /// No description provided for @notChecked.
  ///
  /// In nl, this message translates to:
  /// **'Nog niet gecontroleerd'**
  String get notChecked;

  /// No description provided for @updateUnconfigured.
  ///
  /// In nl, this message translates to:
  /// **'Updatecontroles zijn nog niet ingesteld voor deze build.'**
  String get updateUnconfigured;

  /// No description provided for @checking.
  ///
  /// In nl, this message translates to:
  /// **'Controleren op updates…'**
  String get checking;

  /// No description provided for @upToDate.
  ///
  /// In nl, this message translates to:
  /// **'Je app is up-to-date'**
  String get upToDate;

  /// No description provided for @available.
  ///
  /// In nl, this message translates to:
  /// **'Er staat een nieuwe versie klaar'**
  String get available;

  /// No description provided for @download.
  ///
  /// In nl, this message translates to:
  /// **'Update downloaden'**
  String get download;

  /// No description provided for @downloading.
  ///
  /// In nl, this message translates to:
  /// **'Update downloaden…'**
  String get downloading;

  /// No description provided for @interrupted.
  ///
  /// In nl, this message translates to:
  /// **'Download onderbroken'**
  String get interrupted;

  /// No description provided for @downloaded.
  ///
  /// In nl, this message translates to:
  /// **'Download voltooid en gecontroleerd'**
  String get downloaded;

  /// No description provided for @install.
  ///
  /// In nl, this message translates to:
  /// **'Installeren'**
  String get install;

  /// No description provided for @preparing.
  ///
  /// In nl, this message translates to:
  /// **'Installatie voorbereiden…'**
  String get preparing;

  /// No description provided for @installStarted.
  ///
  /// In nl, this message translates to:
  /// **'Android-installatie geopend. Bevestig de installatie in het systeemvenster.'**
  String get installStarted;

  /// No description provided for @updateError.
  ///
  /// In nl, this message translates to:
  /// **'De update kon niet worden voltooid. Je muziek blijft beschikbaar.'**
  String get updateError;

  /// No description provided for @releaseNotes.
  ///
  /// In nl, this message translates to:
  /// **'Wat is er nieuw?'**
  String get releaseNotes;

  /// No description provided for @storeUpdate.
  ///
  /// In nl, this message translates to:
  /// **'Open de appwinkel'**
  String get storeUpdate;

  /// No description provided for @installPermission.
  ///
  /// In nl, this message translates to:
  /// **'Sta installatie vanuit MusicBackyard toe en tik daarna opnieuw op Installeren.'**
  String get installPermission;

  /// No description provided for @updateSource.
  ///
  /// In nl, this message translates to:
  /// **'Distributiekanaal'**
  String get updateSource;

  /// No description provided for @noUpdateEndpoint.
  ///
  /// In nl, this message translates to:
  /// **'Geen release-endpoint geconfigureerd'**
  String get noUpdateEndpoint;

  /// No description provided for @exportStyle.
  ///
  /// In nl, this message translates to:
  /// **'Template'**
  String get exportStyle;

  /// No description provided for @standard.
  ///
  /// In nl, this message translates to:
  /// **'Standaard'**
  String get standard;

  /// No description provided for @compact.
  ///
  /// In nl, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @minimal.
  ///
  /// In nl, this message translates to:
  /// **'Minimal'**
  String get minimal;

  /// No description provided for @bandbook.
  ///
  /// In nl, this message translates to:
  /// **'Bandboek'**
  String get bandbook;

  /// No description provided for @paper.
  ///
  /// In nl, this message translates to:
  /// **'Papierformaat'**
  String get paper;

  /// No description provided for @landscape.
  ///
  /// In nl, this message translates to:
  /// **'Liggend'**
  String get landscape;

  /// No description provided for @includeNotes.
  ///
  /// In nl, this message translates to:
  /// **'Notities opnemen'**
  String get includeNotes;

  /// No description provided for @includeTabs.
  ///
  /// In nl, this message translates to:
  /// **'Gitaartabs opnemen'**
  String get includeTabs;

  /// No description provided for @preview.
  ///
  /// In nl, this message translates to:
  /// **'Voorbeeld & delen'**
  String get preview;

  /// No description provided for @importReview.
  ///
  /// In nl, this message translates to:
  /// **'Import controleren'**
  String get importReview;

  /// No description provided for @importWarning.
  ///
  /// In nl, this message translates to:
  /// **'Controleer de tekst en akkoorden vóór het opslaan. Bij scans wordt geen tekst gevonden; het origineel blijft als bijlage bewaard.'**
  String get importWarning;

  /// No description provided for @importEmpty.
  ///
  /// In nl, this message translates to:
  /// **'Dit document bevat geen selecteerbare tekst. Voeg zelf tekst toe; het origineel blijft bewaard.'**
  String get importEmpty;

  /// No description provided for @importInvalid.
  ///
  /// In nl, this message translates to:
  /// **'Het bestand is beschadigd of heeft een niet-ondersteund formaat.'**
  String get importInvalid;

  /// No description provided for @importSuccess.
  ///
  /// In nl, this message translates to:
  /// **'Bestand geïmporteerd'**
  String get importSuccess;

  /// No description provided for @findReplace.
  ///
  /// In nl, this message translates to:
  /// **'Zoeken en vervangen'**
  String get findReplace;

  /// No description provided for @find.
  ///
  /// In nl, this message translates to:
  /// **'Zoeken'**
  String get find;

  /// No description provided for @replace.
  ///
  /// In nl, this message translates to:
  /// **'Vervangen door'**
  String get replace;

  /// No description provided for @apply.
  ///
  /// In nl, this message translates to:
  /// **'Toepassen'**
  String get apply;

  /// No description provided for @chordView.
  ///
  /// In nl, this message translates to:
  /// **'Weergave'**
  String get chordView;

  /// No description provided for @lyricsOnly.
  ///
  /// In nl, this message translates to:
  /// **'Alleen tekst'**
  String get lyricsOnly;

  /// No description provided for @chordsOnly.
  ///
  /// In nl, this message translates to:
  /// **'Alleen akkoorden'**
  String get chordsOnly;

  /// No description provided for @both.
  ///
  /// In nl, this message translates to:
  /// **'Tekst en akkoorden'**
  String get both;

  /// No description provided for @arrangement.
  ///
  /// In nl, this message translates to:
  /// **'Arrangement'**
  String get arrangement;

  /// No description provided for @newArrangement.
  ///
  /// In nl, this message translates to:
  /// **'Nieuw arrangement'**
  String get newArrangement;

  /// No description provided for @standardArrangement.
  ///
  /// In nl, this message translates to:
  /// **'Origineel'**
  String get standardArrangement;

  /// No description provided for @collapse.
  ///
  /// In nl, this message translates to:
  /// **'Inklappen'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In nl, this message translates to:
  /// **'Uitklappen'**
  String get expand;

  /// No description provided for @tabHelp.
  ///
  /// In nl, this message translates to:
  /// **'Tik op een positie en vul een fret (0–24), x of een techniek in. Een lege invoer verwijdert de noot.'**
  String get tabHelp;

  /// No description provided for @addMeasure.
  ///
  /// In nl, this message translates to:
  /// **'Maat toevoegen'**
  String get addMeasure;

  /// No description provided for @fret.
  ///
  /// In nl, this message translates to:
  /// **'Fret / techniek'**
  String get fret;

  /// No description provided for @removeMeasure.
  ///
  /// In nl, this message translates to:
  /// **'Maat verwijderen'**
  String get removeMeasure;

  /// No description provided for @standardTuning.
  ///
  /// In nl, this message translates to:
  /// **'Standaard'**
  String get standardTuning;

  /// No description provided for @customTuning.
  ///
  /// In nl, this message translates to:
  /// **'Eigen stemming'**
  String get customTuning;

  /// No description provided for @attach.
  ///
  /// In nl, this message translates to:
  /// **'Bijlage toevoegen'**
  String get attach;

  /// No description provided for @rename.
  ///
  /// In nl, this message translates to:
  /// **'Hernoemen'**
  String get rename;

  /// No description provided for @select.
  ///
  /// In nl, this message translates to:
  /// **'Selecteren'**
  String get select;

  /// No description provided for @selection.
  ///
  /// In nl, this message translates to:
  /// **'Geselecteerd'**
  String get selection;

  /// No description provided for @exportSelected.
  ///
  /// In nl, this message translates to:
  /// **'Selectie exporteren'**
  String get exportSelected;

  /// No description provided for @clearSelection.
  ///
  /// In nl, this message translates to:
  /// **'Selectie opheffen'**
  String get clearSelection;

  /// No description provided for @filter.
  ///
  /// In nl, this message translates to:
  /// **'Filteren'**
  String get filter;

  /// No description provided for @all.
  ///
  /// In nl, this message translates to:
  /// **'Alles'**
  String get all;

  /// No description provided for @noResults.
  ///
  /// In nl, this message translates to:
  /// **'Geen nummers gevonden'**
  String get noResults;

  /// No description provided for @addBreak.
  ///
  /// In nl, this message translates to:
  /// **'Pauze toevoegen'**
  String get addBreak;

  /// No description provided for @setlistNotes.
  ///
  /// In nl, this message translates to:
  /// **'Setlistnotities'**
  String get setlistNotes;

  /// No description provided for @copy.
  ///
  /// In nl, this message translates to:
  /// **'Kopiëren'**
  String get copy;

  /// No description provided for @linkSaved.
  ///
  /// In nl, this message translates to:
  /// **'Link opgeslagen'**
  String get linkSaved;

  /// No description provided for @restoreDone.
  ///
  /// In nl, this message translates to:
  /// **'Back-up teruggezet'**
  String get restoreDone;

  /// No description provided for @backupInvalid.
  ///
  /// In nl, this message translates to:
  /// **'Ongeldige back-up; je bibliotheek is niet gewijzigd.'**
  String get backupInvalid;

  /// No description provided for @backupContents.
  ///
  /// In nl, this message translates to:
  /// **'Back-ups bevatten nummers, setlists en lokale bijlagen. Bewaar het bestand op een veilige plek.'**
  String get backupContents;

  /// No description provided for @notAvailable.
  ///
  /// In nl, this message translates to:
  /// **'Niet beschikbaar'**
  String get notAvailable;

  /// No description provided for @chordShapes.
  ///
  /// In nl, this message translates to:
  /// **'Akkoordgrepen'**
  String get chordShapes;

  /// No description provided for @noChordShape.
  ///
  /// In nl, this message translates to:
  /// **'Voor dit akkoord is nog geen greep beschikbaar.'**
  String get noChordShape;

  /// No description provided for @soundingKey.
  ///
  /// In nl, this message translates to:
  /// **'Klinkende toonsoort'**
  String get soundingKey;

  /// No description provided for @playedKey.
  ///
  /// In nl, this message translates to:
  /// **'Gespeelde grepen'**
  String get playedKey;

  /// No description provided for @emptyTrash.
  ///
  /// In nl, this message translates to:
  /// **'De prullenbak is leeg'**
  String get emptyTrash;

  /// No description provided for @deleteForever.
  ///
  /// In nl, this message translates to:
  /// **'Definitief verwijderen'**
  String get deleteForever;

  /// No description provided for @confirmDelete.
  ///
  /// In nl, this message translates to:
  /// **'Dit definitief verwijderen?'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In nl, this message translates to:
  /// **'Deze actie kan niet ongedaan worden gemaakt.'**
  String get confirmDeleteBody;

  /// No description provided for @dataError.
  ///
  /// In nl, this message translates to:
  /// **'De lokale bibliotheek kon niet worden geopend. Bestaande gegevens zijn niet verwijderd.'**
  String get dataError;

  /// No description provided for @chooseSong.
  ///
  /// In nl, this message translates to:
  /// **'Kies een nummer'**
  String get chooseSong;

  /// No description provided for @folderParent.
  ///
  /// In nl, this message translates to:
  /// **'Bovenliggende map'**
  String get folderParent;

  /// No description provided for @moveUp.
  ///
  /// In nl, this message translates to:
  /// **'Omhoog'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In nl, this message translates to:
  /// **'Omlaag'**
  String get moveDown;

  /// No description provided for @savedNotice.
  ///
  /// In nl, this message translates to:
  /// **'Wijzigingen worden automatisch opgeslagen.'**
  String get savedNotice;

  /// No description provided for @recentSetlists.
  ///
  /// In nl, this message translates to:
  /// **'Jouw setlists'**
  String get recentSetlists;

  /// No description provided for @libraryHeading.
  ///
  /// In nl, this message translates to:
  /// **'Ruimte voor jouw muziek.'**
  String get libraryHeading;

  /// No description provided for @librarySubheading.
  ///
  /// In nl, this message translates to:
  /// **'Van een eerste idee tot het laatste akkoord.'**
  String get librarySubheading;

  /// No description provided for @instrumentFilter.
  ///
  /// In nl, this message translates to:
  /// **'Instrumentfilter'**
  String get instrumentFilter;

  /// No description provided for @keyFilter.
  ///
  /// In nl, this message translates to:
  /// **'Toonsoortfilter'**
  String get keyFilter;

  /// No description provided for @categoryFilter.
  ///
  /// In nl, this message translates to:
  /// **'Tagfilter'**
  String get categoryFilter;

  /// No description provided for @exportDone.
  ///
  /// In nl, this message translates to:
  /// **'Bestand opgeslagen'**
  String get exportDone;

  /// No description provided for @attachmentMissing.
  ///
  /// In nl, this message translates to:
  /// **'De bijlage ontbreekt op dit apparaat.'**
  String get attachmentMissing;

  /// No description provided for @margin.
  ///
  /// In nl, this message translates to:
  /// **'Marge (mm)'**
  String get margin;

  /// No description provided for @lineSpacing.
  ///
  /// In nl, this message translates to:
  /// **'Regelafstand'**
  String get lineSpacing;

  /// No description provided for @pageNumbers.
  ///
  /// In nl, this message translates to:
  /// **'Paginanummers'**
  String get pageNumbers;

  /// No description provided for @tableOfContents.
  ///
  /// In nl, this message translates to:
  /// **'Inhoudsopgave'**
  String get tableOfContents;

  /// No description provided for @header.
  ///
  /// In nl, this message translates to:
  /// **'Koptekst'**
  String get header;

  /// No description provided for @footer.
  ///
  /// In nl, this message translates to:
  /// **'Voettekst'**
  String get footer;

  /// No description provided for @deleteSong.
  ///
  /// In nl, this message translates to:
  /// **'Nummer verwijderen'**
  String get deleteSong;

  /// No description provided for @rehearsal.
  ///
  /// In nl, this message translates to:
  /// **'Klaar voor de repetitie'**
  String get rehearsal;

  /// No description provided for @audioName.
  ///
  /// In nl, this message translates to:
  /// **'Naam van de opname'**
  String get audioName;

  /// No description provided for @never.
  ///
  /// In nl, this message translates to:
  /// **'Nog nooit'**
  String get never;

  /// No description provided for @fullScreen.
  ///
  /// In nl, this message translates to:
  /// **'Volledig scherm'**
  String get fullScreen;

  /// No description provided for @exitPerformance.
  ///
  /// In nl, this message translates to:
  /// **'Speelmodus verlaten'**
  String get exitPerformance;

  /// No description provided for @scrollHelp.
  ///
  /// In nl, this message translates to:
  /// **'Spatie: scrollen starten/pauzeren · pijltjes: bladeren · PageUp/PageDown: vorig/volgend nummer'**
  String get scrollHelp;

  /// No description provided for @updateReady.
  ///
  /// In nl, this message translates to:
  /// **'Update beschikbaar'**
  String get updateReady;

  /// No description provided for @cancelled.
  ///
  /// In nl, this message translates to:
  /// **'Geannuleerd'**
  String get cancelled;

  /// No description provided for @folderCycle.
  ///
  /// In nl, this message translates to:
  /// **'Een map kan niet naar zichzelf worden verplaatst.'**
  String get folderCycle;

  /// No description provided for @stopRecordingFirst.
  ///
  /// In nl, this message translates to:
  /// **'Stop eerst de opname voordat je dit nummer verlaat.'**
  String get stopRecordingFirst;

  /// No description provided for @manageFolders.
  ///
  /// In nl, this message translates to:
  /// **'Mappen beheren'**
  String get manageFolders;

  /// No description provided for @folderActions.
  ///
  /// In nl, this message translates to:
  /// **'Mapacties'**
  String get folderActions;

  /// No description provided for @deleteFolder.
  ///
  /// In nl, this message translates to:
  /// **'Map verwijderen?'**
  String get deleteFolder;

  /// No description provided for @deleteFolderBody.
  ///
  /// In nl, this message translates to:
  /// **'Alleen de map wordt verwijderd. Nummers en submappen blijven bewaard in de bovenliggende map.'**
  String get deleteFolderBody;

  /// No description provided for @emptyFolders.
  ///
  /// In nl, this message translates to:
  /// **'Maak mappen om je nummers overzichtelijk te bewaren.'**
  String get emptyFolders;

  /// No description provided for @copyTabs.
  ///
  /// In nl, this message translates to:
  /// **'Tabs kopiëren'**
  String get copyTabs;

  /// No description provided for @pasteTabs.
  ///
  /// In nl, this message translates to:
  /// **'Tabs plakken'**
  String get pasteTabs;

  /// No description provided for @pasteTabsHelp.
  ///
  /// In nl, this message translates to:
  /// **'Plak zes uitgelijnde snaren met maatstrepen, bijvoorbeeld e|---0---|. Lange maten worden verdeeld over blokken van acht posities.'**
  String get pasteTabsHelp;

  /// No description provided for @replaceTabs.
  ///
  /// In nl, this message translates to:
  /// **'Bestaande tabs vervangen'**
  String get replaceTabs;

  /// No description provided for @replaceTabsHelp.
  ///
  /// In nl, this message translates to:
  /// **'Uitgeschakeld: de geplakte maten worden achteraan toegevoegd.'**
  String get replaceTabsHelp;

  /// No description provided for @invalidTab.
  ///
  /// In nl, this message translates to:
  /// **'Controleer de zes snaren, maatstrepen en uitlijning. Gebruik fretten 0–24, x en technieken zoals 5h7 of 7/9.'**
  String get invalidTab;

  /// No description provided for @tabTuningMismatch.
  ///
  /// In nl, this message translates to:
  /// **'De stemming wijkt af. Kies vervangen om ook de stemming over te nemen.'**
  String get tabTuningMismatch;

  /// No description provided for @copiedTabs.
  ///
  /// In nl, this message translates to:
  /// **'Tabs naar het klembord gekopieerd'**
  String get copiedTabs;

  /// No description provided for @tabTextView.
  ///
  /// In nl, this message translates to:
  /// **'ASCII-tekstweergave'**
  String get tabTextView;

  /// No description provided for @zoom.
  ///
  /// In nl, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// No description provided for @invalidFret.
  ///
  /// In nl, this message translates to:
  /// **'Gebruik een fret van 0–24, x of een techniek zoals 5h7.'**
  String get invalidFret;

  /// No description provided for @invalidTuning.
  ///
  /// In nl, this message translates to:
  /// **'Voer zes geldige noten in, bijvoorbeeld D A D G B e.'**
  String get invalidTuning;

  /// No description provided for @preservePitch.
  ///
  /// In nl, this message translates to:
  /// **'Klinkende toonsoort behouden'**
  String get preservePitch;

  /// No description provided for @preservePitchHelp.
  ///
  /// In nl, this message translates to:
  /// **'Past de akkoordgrepen in alle arrangementen aan. Controleer bijbehorende tablatuur zelf.'**
  String get preservePitchHelp;

  /// No description provided for @capoSuggestions.
  ///
  /// In nl, this message translates to:
  /// **'Alternatieven met eenvoudige grepen'**
  String get capoSuggestions;

  /// No description provided for @noCapoSuggestions.
  ///
  /// In nl, this message translates to:
  /// **'Voor deze akkoorden is geen alternatief met alleen eenvoudige open grepen gevonden.'**
  String get noCapoSuggestions;

  /// No description provided for @pdfContent.
  ///
  /// In nl, this message translates to:
  /// **'Muziekinhoud'**
  String get pdfContent;

  /// No description provided for @tabsOnly.
  ///
  /// In nl, this message translates to:
  /// **'Alleen gitaartabs'**
  String get tabsOnly;

  /// No description provided for @exportError.
  ///
  /// In nl, this message translates to:
  /// **'Het PDF-voorbeeld kon niet worden gemaakt. Controleer de instellingen en probeer opnieuw.'**
  String get exportError;

  /// No description provided for @print.
  ///
  /// In nl, this message translates to:
  /// **'Afdrukken'**
  String get print;

  /// No description provided for @share.
  ///
  /// In nl, this message translates to:
  /// **'Delen'**
  String get share;

  /// No description provided for @updateTrack.
  ///
  /// In nl, this message translates to:
  /// **'Updatekanaal'**
  String get updateTrack;

  /// No description provided for @stableTrack.
  ///
  /// In nl, this message translates to:
  /// **'Stabiel'**
  String get stableTrack;

  /// No description provided for @betaTrack.
  ///
  /// In nl, this message translates to:
  /// **'Bèta'**
  String get betaTrack;

  /// No description provided for @stableTrackHelp.
  ///
  /// In nl, this message translates to:
  /// **'Geteste releases voor dagelijks gebruik.'**
  String get stableTrackHelp;

  /// No description provided for @betaTrackHelp.
  ///
  /// In nl, this message translates to:
  /// **'Nieuwe functies eerder proberen. Bètaversies kunnen minder stabiel zijn.'**
  String get betaTrackHelp;

  /// No description provided for @autoWifiUpdates.
  ///
  /// In nl, this message translates to:
  /// **'Updates automatisch downloaden via wifi'**
  String get autoWifiUpdates;

  /// No description provided for @autoWifiUpdatesHelp.
  ///
  /// In nl, this message translates to:
  /// **'De app controleert automatisch op updates. Android vraagt altijd om bevestiging vóór installatie.'**
  String get autoWifiUpdatesHelp;

  /// No description provided for @updateReadyToInstall.
  ///
  /// In nl, this message translates to:
  /// **'De update staat klaar om te installeren'**
  String get updateReadyToInstall;

  /// No description provided for @viewUpdate.
  ///
  /// In nl, this message translates to:
  /// **'Bekijken'**
  String get viewUpdate;

  /// No description provided for @directDistribution.
  ///
  /// In nl, this message translates to:
  /// **'Rechtstreeks (APK)'**
  String get directDistribution;

  /// No description provided for @stableNeedsNewerBuild.
  ///
  /// In nl, this message translates to:
  /// **'Je gebruikt nog een bètaversie. De volgende stabiele versie met een hoger buildnummer wordt automatisch aangeboden.'**
  String get stableNeedsNewerBuild;
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
      <String>['nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
