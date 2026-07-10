// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

// TODO: upload to github so I can work on it while on vacation
// TODO: add logo

// Joe Radio - A simple radio streaming app using just_audio and audio_service
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final stopwatch = Stopwatch()..start();

  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    stopwatch.stop();
    stopwatch.elapsedMilliseconds;
    debugPrint('${stopwatch.elapsedMilliseconds} ms');
  });
}

// const orangeTint = Color.fromRGBO(255, 243, 224, 1);
final orangeTint = Colors.orange.shade50;

// same as Colors.orange.shade50

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color.fromARGB(255, 168, 200, 255),
    surface: orangeTint,

    // background: orangeTint,
  ),
  scaffoldBackgroundColor: orangeTint,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.orange.shade400,
    // foregroundColor: Colors.white,
  ),
);

// final darkOrangeTint = Color.fromRGBO(35, 25, 15, 1);
final darkOrangeTint = Color.fromRGBO(0, 12, 31, 1);

// subtle dark orange-tinted background

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color.fromARGB(255, 229, 236, 254),
    brightness: Brightness.dark,
    surface: darkOrangeTint,
    // background: darkOrangeTint,
  ),
  scaffoldBackgroundColor: darkOrangeTint,
  appBarTheme: AppBarTheme(
    backgroundColor: const Color.fromARGB(122, 255, 168, 38), // Color.fromARGB(255, 51, 31, 0),
    foregroundColor: Colors.white,
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joe radio',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('nl'), // Dutch
        Locale('en'), // English
        Locale('pap') // Papiamento
      ],
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const RadioPage(),
    );
  }
}

class RadioStation {
  final String name;
  final String url;
  final bool iCYMetadataReversed; // some stations have the artist and title reversed in the ICY metadata
  final bool canStartWithAd;

  const RadioStation({required this.name, required this.url, this.iCYMetadataReversed = false, this.canStartWithAd = false});
}

class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  static const Duration _metadataResetDelay = Duration(seconds: 245);
  int streamNumber = 0;
  // Notifier so the UI can listen to station changes
  final streamNumberNotifier = ValueNotifier<int>(0);
  final _player = AudioPlayer(useProxyForRequestHeaders: false);
  static const List<RadioStation> radioStations = [
    RadioStation(
      name: 'Joe NL',
      url: 'https://stream.joe.nl/joe/aac',
      canStartWithAd: true,
      // can have news, often a bit later, like 2 minutes later
    ),
    // RadioStation(
    //   name: 'Joe NL high aac',
    //   url: 'https://stream.joe.nl/joe/aachigh',
    //   canStartWithAd: true,
    //   // can have news, often a bit later, like 2 minutes later
    // ),
    // RadioStation(
    //   name: 'Joe NL low aac',
    //   url: 'https://stream.joe.nl/joe/aaclow', //TODO: check specifics and maybe choose one automatically depending on if on metered wifi or not
    //   canStartWithAd: true,
    //   // can have news, often a bit later, like 2 minutes later
    // ),
    RadioStation(
      name: 'Joe Belgium',
      url: 'https://audio-streaming.joe.be/joe.aac',
      iCYMetadataReversed: true,
      canStartWithAd: true,
      // can have news
    ),
    RadioStation(
      name: 'Joe Gold',
      url: 'https://audio-streaming.joe.be/joe-gold.aac',
      iCYMetadataReversed: true,
      canStartWithAd: true,
      // can have news, often on time
    ),
    RadioStation(
      name: 'Joe 80s & 90s',
      url: 'https://audio-streaming.joe.be/joe_80s_90s.aac',
      iCYMetadataReversed: true,
      // can have news, often on time
    ),
    RadioStation(
      name: 'Joe Easy',
      url: 'https://audio-streaming.joe.be/joe_easy.aac',
      iCYMetadataReversed: true,
      canStartWithAd: true,
    ),
    RadioStation(
      name: 'Joe Top 2000',
      url: 'https://audio-streaming.joe.be/joe_top2000.aac',
      iCYMetadataReversed: true,
    ),
    RadioStation(
      name: 'Joe Lage Landen',
      url: 'https://audio-streaming.joe.be/joe_lage_landen.aac',
      iCYMetadataReversed: true,
    ), // bevat nieuws
    RadioStation(
      name: 'Joe non-stop',
      url: 'https://stream.joe.nl/nonstop/aac',
      canStartWithAd: true,
      // TODO: make it so radio stations can have custom news length
    ),
  ];
  bool connection = false;
  final connectionNotifier = ValueNotifier<bool>(false);
  Timer? _metadataResetTimer;
  DateTime? _metadataResetDeadline;
  Duration? _metadataResetRemaining;
  String? _currentIcyMetadataKey;
  final playingNotifier = ValueNotifier<bool>(false);

  bool get playing => playingNotifier.value;
  set playing(bool value) {
    if (playingNotifier.value != value) {
      playingNotifier.value = value;
    }
  }

  void _resetMetadataResetTimer() {
    _metadataResetTimer?.cancel();
    _metadataResetTimer = null;
    _metadataResetDeadline = null;
    _metadataResetRemaining = null;
  }

  void _pauseMetadataResetTimer() {
    if (_metadataResetTimer == null || _metadataResetDeadline == null) {
      return;
    }
    debugPrint('pausing the timer');

    final remaining = _metadataResetDeadline!.difference(DateTime.now());
    debugPrint(remaining.toString());
    _metadataResetRemaining = remaining.isNegative ? Duration.zero : remaining;
    _metadataResetTimer?.cancel();
    _metadataResetTimer = null;
    _metadataResetDeadline = null;
  }

  void _resumeMetadataResetTimer() {
    if (_metadataResetRemaining == null || _metadataResetRemaining! <= Duration.zero) {
      _metadataResetRemaining = null;
      return;
    }

    debugPrint('resume the timer');

    final delay = _metadataResetRemaining!;
    _metadataResetRemaining = null;
    final now = DateTime.now();
    _metadataResetDeadline = now.add(delay);
    _metadataResetTimer = Timer(delay, () {
      debugPrint('Icy metadata has reset');
      _resetMetadata();
    });
  }

  void _scheduleMetadataReset({bool extendIfNeeded = false, bool news = false}) {
    if (!playing) {
      debugPrint('Skipping metadata reset scheduling while playback is paused.');
      return;
    }

    // Start from the normal reset interval unless this is an extension request.
    Duration delay;
    if (news) {
      delay = const Duration(seconds: 116);
    } else {
      delay = _metadataResetDelay;
    }
    final now = DateTime.now();

    if (extendIfNeeded && _metadataResetDeadline != null) {
      final remaining = _metadataResetDeadline!.difference(now); // TODO: pause when music is paused, important!

      // If the current timer has less than 20 seconds left
      if (remaining > Duration.zero && remaining < const Duration(seconds: 20)) {
        delay = remaining + (news ? const Duration(seconds: 10) : const Duration(seconds: 15)); // extend it by 15 seconds or 10s when playing news.
        debugPrint('Extending metadata reset timer by 15 seconds (new timer: ${delay.inSeconds}s)');
      } else {
        // Keep the existing timer when the metadata is unchanged and the countdown is still healthy.
        return;
      }
    }

    debugPrint('Scheduling metadata reset in ${delay.inSeconds} seconds...');
    _resetMetadataResetTimer();
    _metadataResetDeadline = now.add(delay);
    _metadataResetTimer = Timer(delay, () {
      // set the timer
      debugPrint('Icy metadata has reset');
      _resetMetadata();
    });
  }

  void _resetMetadata() {
    debugPrint('Resetting metadata to default values');
    _resetMetadataResetTimer();
    _currentIcyMetadataKey = null;
    mediaItem.add(
      const MediaItem(
        id: 'joe-radio',
        title: 'Joe Radio',
        genre: 'various',
        isLive: true,
      ),
    );
  }

  RadioAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // 1. Broadcast the item currently playing so the system draws the notification UI
    mediaItem.add(
      const MediaItem(
        id: 'joe-radio',
        title: 'Joe Radio',
        genre: 'various',
        isLive: true,
      ),
    );

    // 2. Load the source stream
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(radioStations[streamNumber].url),
          headers: kIsWeb
            ? null
            : const {'Icy-MetaData': '1'},
        ),
      );
    } catch (e) {
      connection = false;
      connectionNotifier.value = false;
      print('Error loading audio source: $e');
    }

    // 3. Listen to playback events and mirror them to AudioService
    _player.playbackEventStream.listen((event) {
      final processingState = _player.processingState;

      // if (processingState == ProcessingState.idle && !kIsWeb) {
      //   _resetMetadata();
      // }

      playbackState.add(
        PlaybackState(
          controls: [
            if (processingState == ProcessingState.ready ||
                (processingState == ProcessingState.buffering && connection))
              (_player.playing ? MediaControl.pause : MediaControl.play),
            if (processingState == ProcessingState.ready)
              MediaControl.skipToNext,
          ],

          systemActions: const {
            MediaAction.play,
            MediaAction.pause,
            MediaAction.seekForward,
            // MediaAction.seekBackward,
          },
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[processingState]!,
          playing: _player.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );

      // playbackState.close();
    });

    // 4. Listen to ICY metadata and update the media item accordingly
    _player.icyMetadataStream.listen((metadata) {
      // TODO: try to figure out if it is possible to detect initial ad by checking if the time < 2 seconds and title=""
      final metadataInfo = metadata?.info?.title?.trim();
      // final genre = metadata?.headers?.genre?.trim();
      debugPrint('ICY metadata received: title="$metadataInfo"');

      if (metadataInfo == null) {
        // _resetMetadata();
        return;
      }

      // if (metadataInfo == null) {
      //   connection = false;
      //   connectionNotifier.value = connection;
      //   print('offline detected');
      //   return;
      // }
      // if (!connection) {
      //   connection = true;
      //   connectionNotifier.value = connection;
      // }
      

      final List<String> parts;
      final String title;
      final String? artist;
      final String metadataKey;
      bool isNews = false;
      if (metadataInfo.contains(' - ')) {
        parts = metadataInfo.split(' - ');
        if (radioStations[streamNumber].iCYMetadataReversed) {
          // some stations have the artist and title reversed in the ICY metadata
          // "Artist - Song"
          title = parts.sublist(1).join(' - ').trim();
          artist = parts.first.trim();
        } else {
          // "Song - Artist"
          title = parts.first.trim();
          artist = parts.sublist(1).join(' - ').trim();
        }
        metadataKey = '$title|$artist';
      } else {
        // news: JOE nieuws
        
        artist = null;
        metadataKey = metadataInfo;
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        if (metadataInfo == "JOE nieuws") {
          title = metadataInfo;
          isNews = true;
        } else if (metadataInfo == "Ad break" || metadataInfo == "adbreak" || metadataInfo == "") { // TODO: make initial add have a shorter time
          if (locale.languageCode == 'nl') { // TODO: che
            title = "Reclame";
          } else {
            title = "Ad break";
          }
        } else {
          title = metadataInfo;
        }
      }

      // Ignore repeated metadata unless it is close to expiry, in which case extend the timer.
      if (_currentIcyMetadataKey == metadataKey) {
        _scheduleMetadataReset(extendIfNeeded: true, news: isNews);
        return;
      }

      _currentIcyMetadataKey = metadataKey;
      debugPrint('Artist: $artist');
      debugPrint('Song: $title');
      setMetaData(title, artist);
      _scheduleMetadataReset(news: isNews);
    });

    // 5. Listen to connectivity changes and update the connection status
    if (kIsWeb) {
      connection = (await Connectivity().checkConnectivity()).first != ConnectivityResult.none;
      debugPrint("initial connectivity: $connection");
      connectionNotifier.value = connection;
    }
    
    Connectivity().onConnectivityChanged.listen((results) {
      debugPrint('Connectivity changed: $results');
      connection = results.first != ConnectivityResult.none;
      connectionNotifier.value = connection;
      debugPrint("verbindingveranderd, verbinding: $connection");

      if (connection && playing && _player.processingState != ProcessingState.ready) {
        debugPrint('Reconnecting to stream...');
        _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(radioStations[streamNumber].url),
            headers: kIsWeb
              ? null
              : const {'Icy-MetaData': '1'},
          ),
        );
        _player.play();
      }
    });
  } // end of init

  void dispose() {
    debugPrint('dispose called, disposing audio player');
    _resetMetadataResetTimer();
    streamNumberNotifier.dispose();
    _player.dispose();
  }

  void setMetaData(String title, String? artist) {
    mediaItem.add(
      MediaItem(
        id: 'joe-radio',
        title: title,
        artist: artist,
        genre: 'various',
        isLive: true,
      ),
    );
  }

  // Exposed getter so the UI page can track live positions
  AudioPlayer get player => _player;

  Future<void> playLive() async {
    // if (_player.bufferedPosition > Duration.zero) {
    //   // Catch up to the absolute live edge of the buffer
    //   await _player.seek(_player.bufferedPosition);
    // }
    Duration current = _player.position;
    Duration buffered = _player.bufferedPosition;
    while (buffered - current > Duration(seconds: 2)) {
      current = _player.position;
      buffered = _player.bufferedPosition;
      final target = current + Duration(seconds: 1);
      // keep skipping 1 second until it is live
      await _player.seek(target);
    }
  }

  Future<void> skipForward(int seconds) async {
    final current = _player.position;
    final buffered = _player.bufferedPosition;
    if (seconds > 0 && buffered - current < Duration.zero) return;
    final target = current + Duration(seconds: seconds);
    debugPrint(
      'Attempting to skip forward $seconds seconds from $current to $target (buffered: $buffered)',
    );
    // final seekPosition = target < buffered ? target : buffered;
    await _player.seek(target);
  }

  @override
  Future<void> stop() async {
    debugPrint('Stopping radio...');
    _player.stop();
    playing = false;
  }

  @override
  Future<void> play() async {
    debugPrint('Playing radio...');
    _player.play();
    playing = true;
    _resumeMetadataResetTimer();
  }

  double easeOutCubic(double x) {
    return 1 - math.pow(1 - x, 3).toDouble();
  }

  void startFadeIn() async {
    playing = true;
    if (_player.playing) return;
    final int waitTime = radioStations[streamNumber].canStartWithAd ? 10 : 8;
    await _player.setVolume(0);
    _player.play();
    _resumeMetadataResetTimer();
    debugPrint('Fading in volume...');
    for (double v = 0; v < 1; v += 0.01) {
      await Future.delayed(Duration(milliseconds: waitTime));
      await _player.setVolume(easeOutCubic(v));
    }
  }

  @override
  Future<void> pause() async {
    debugPrint('Pausing radio...');
    _pauseMetadataResetTimer();
    _player.pause();
    playing = false;
  }

  @override
  Future<void> skipToPrevious() async {
    // skipForward(-5);
  }

  @override
  Future<void> skipToNext() async { // TODO: disable on no connection
    skipForward(5);
  }

  Future<void> setStreamSource(int number) async {
    if (number == streamNumber) return;

    final wasPlaying = playing;
    streamNumber = number;
    streamNumberNotifier.value = streamNumber;
    debugPrint('Switching to stream ${radioStations[streamNumber].name}');
    _resetMetadata();

    try {
      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(radioStations[streamNumber].url),
          headers: kIsWeb
            ? null
            : const {'Icy-MetaData': '1'},
        ),
      );

      if (wasPlaying) {
        await _player.play();
      }
    } on Exception catch (e) {
      debugPrint('error:');
      debugPrint(e.toString());
    }
  }
}

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  RadioAudioHandler? _handler;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAudioHandler();
    });
  }

  Future<void> _initializeAudioHandler() async {
    try {
      final RadioAudioHandler audioHandler = await AudioService.init<RadioAudioHandler>(
        builder: () => RadioAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.channel.audio',
          androidNotificationChannelName: 'Audio playback',
          androidNotificationOngoing: true,
        ),
      );
      if (!mounted) return;

      setState(() {
        _handler = audioHandler;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializationError = error.toString();
      });
    }
  }

  @override
  void dispose() {
    debugPrint('dispose called, disposing radio page');
    _handler?.dispose();
    super.dispose();
  }

  double easeOutCubic(double x) {
    return 1 - math.pow(1 - x, 3).toDouble();
  }

  Future<void> playRadio() async {
    if (_handler == null || _handler!.playing) return;
    _handler?.playing = true;
    if (_handler!.player.playing) return;

    if (_handler!.player.processingState != ProcessingState.ready) {
      // if (!_handler!.connection) {
      //   debugPrint('Cannot play radio: no internet connection');
      //   _handler!.playing = true;
      //   return;
      // }
      _handler!.startFadeIn();
    } else {
      _handler!.play();
      _handler!.player.setVolume(1);
    }
  }

  void pauseRadio() {
    _handler?.pause();
  }

  void stopRadio() {
    _handler?.stop();
  }

  void skipForward(int seconds) {
    _handler?.skipForward(seconds);
  }

  @override
  Widget build(BuildContext context) {
    // if (_initializingAudio) {
    //   return const Scaffold(
    //     body: Center(child: CircularProgressIndicator()),
    //   );
    // }

    if (_handler == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _initializationError ?? 'Preparing audio…',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final handler = _handler!;
    return ValueListenableBuilder<bool>(
      valueListenable: handler.connectionNotifier,
      builder: (context, isConnected, _) {
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final processingState = state?.processingState ?? AudioProcessingState.idle;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Joe Radio'),
                centerTitle: true,
                actions: [
                  ValueListenableBuilder<int>(
                    valueListenable: handler.streamNumberNotifier,
                    builder: (context, streamNumber, _) {
                      return MenuAnchor(
                        animated: true,
                        builder: (context, controller, child) {
                          return IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                          );
                        },
                        menuChildren: [
                          SizedBox(
                            width: 220,
                            child: ListTile(
                              leading: const Icon(Icons.forward_5),
                              title: Text(AppLocalizations.of(context)!.skip5Seconds),//Text('Skip 5 seconds'),
                              enabled: isConnected && processingState == AudioProcessingState.ready,
                              onTap: () {
                                skipForward(5);
                              },
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: ListTile(
                              leading: const Icon(Icons.live_tv),
                              title: Text(AppLocalizations.of(context)!.playLive), // Play live
                              enabled: processingState == AudioProcessingState.ready,
                              onTap: () {
                                handler.playLive();
                              },
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            height: 56,
                            child: ListTile(
                              // leading: const SizedBox(width: 24),
                              title: Text(AppLocalizations.of(context)!.radioStation), // Radio station:
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                RadioAudioHandler.radioStations.length,
                                (index) {
                                  final station = RadioAudioHandler.radioStations[index];

                                  return ListTile(
                                    leading: streamNumber == index
                                        ? const Icon(Icons.check)
                                        : const SizedBox(width: 24),
                                    title: Text(station.name),
                                    onTap: () async {
                                      if (streamNumber != index) {
                                        await handler.setStreamSource(index);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  )
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: handler.playingNotifier,
                    builder: (context, isPlayingValue, _) {
                      final bool offline = !isConnected;
                      final String statusText;
                      if (processingState == AudioProcessingState.ready || (processingState == AudioProcessingState.buffering && !offline)) {
                        if (isPlayingValue) {
                          statusText = AppLocalizations.of(context)!.playing; // Playing
                        } else {
                          statusText = AppLocalizations.of(context)!.paused; // Paused
                        }
                      } else {
                        if (offline) {
                          statusText = AppLocalizations.of(context)!.offline; // Offline
                        } else if (processingState == AudioProcessingState.loading) {
                          statusText = AppLocalizations.of(context)!.loading; // Loading 
                        } else if (processingState == AudioProcessingState.error) {
                          statusText = 'Error: ${state?.errorMessage ?? 'Unknown'}';
                        } else {
                          statusText = AppLocalizations.of(context)!.stopped; // Stopped
                        }
                      }
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(width: double.infinity),
                              if (constraints.maxHeight > 340)
                                const Icon(
                                  Icons.radio,
                                  size: 120,
                                  color: Colors.orange,
                                ),
                              if (constraints.maxHeight > 340)
                                const SizedBox(height: 24),
                              if (constraints.maxHeight > 175)
                                const Text(
                                  'Joe',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (constraints.maxHeight > 175)
                                const SizedBox(height: 12),
                              if (constraints.maxHeight > 70)
                                Text(
                                  statusText,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              if (kDebugMode && constraints.maxHeight > 230)
                                const SizedBox(height: 12),
                              if (kDebugMode && constraints.maxHeight > 230)
                                // Text(_handler.player.bufferedPosition == Duration.zero ? 'Loading stream...' : 'Buffered: ${(_handler.player.bufferedPosition - _handler.player.position).inSeconds}s'),
                                // Text(processingState.toString()),
                                Text((state?.processingState).toString()),
                              if (constraints.maxHeight > 70)
                                SizedBox(height: (constraints.maxHeight > 200) ? 32 : 12),
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: !isPlayingValue ? playRadio : null,
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(AppLocalizations.of(context)!.play), // Play
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isPlayingValue ? pauseRadio : null,
                                    icon: const Icon(Icons.pause),
                                    label: Text(AppLocalizations.of(context)!.pause), // pause
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                  if (kDebugMode)
                                    ElevatedButton.icon(
                                      onPressed: isPlayingValue ? stopRadio : null,
                                      icon: const Icon(Icons.stop),
                                      label: const Text('Stop'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          }
        );
      },
    );
  }
}
