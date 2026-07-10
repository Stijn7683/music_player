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
// TODO: add splash screen color

// Joe Radio - A simple radio streaming app using just_audio and audio_service
// in this version state management will be properly implemented with the use of Provider
late final RadioAudioHandler radioHandler;
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  final stopwatch = Stopwatch()..start();

  radioHandler = await AudioService.init<RadioAudioHandler>(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(const MyApp());

  // for the stopwatch:
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

final buttonStyle = ElevatedButton.styleFrom(
  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
);

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
      home: RadioPage(handler: radioHandler),
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

const List<RadioStation> radioStations = [
    RadioStation(
      name: 'Joe NL',
      url: 'https://stream.joe.nl/joe/aac',
      canStartWithAd: true,
      // can have news, often a bit later, like 2 minutes later
    ),
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
      // can have news,
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
    ), // bevat nieuws, evenlang as nl en belgium
    RadioStation(
      name: 'Joe non-stop',
      url: 'https://stream.joe.nl/nonstop/aac',
      canStartWithAd: true,
      // TODO: make it so radio stations can have custom news length
    ),
  ];

class RadioAudioHandler extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  static const Duration _metadataResetDelay = Duration(seconds: 245);
  int streamNumber = 0;
  // Notifier so the UI can listen to station changes
  final _player = AudioPlayer(useProxyForRequestHeaders: false);
  bool connection = true;
  Timer? _metadataResetTimer;
  DateTime? _metadataResetDeadline;
  Duration? _metadataResetRemaining;
  String? _currentIcyMetadataKey;
  bool isInitialAd = false;
  bool playing = false;
  ProcessingState processingState = .idle;

  void _resetMetadataResetTimer() {
    // debugPrint('metadata timer got restet');
    _metadataResetTimer?.cancel();
    _metadataResetTimer = null;
    _metadataResetDeadline = null;
    _metadataResetRemaining = null;
  }

  void _pauseMetadataResetTimer() {
    if (_metadataResetTimer == null || _metadataResetDeadline == null) {
      return;
    }

    final remaining = _metadataResetDeadline!.difference(DateTime.now());
    debugPrint('pausing the timer $remaining');
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

    debugPrint('resume the timer: $_metadataResetRemaining');

    final delay = _metadataResetRemaining!;
    _metadataResetRemaining = null;
    final now = DateTime.now();
    _metadataResetDeadline = now.add(delay);
    _metadataResetTimer = Timer(delay, () {
      debugPrint('Icy metadata has reset');
      _resetMetadata();
    });
  }

  void _scheduleMetadataReset({bool extendIfNeeded = false, bool news = false, final bool isInitialAd = false}) {
    // Start from the normal reset interval unless this is an extension request.
    // if (isInitialAd) {
    //   _resetMetadataResetTimer();
    //   return;
    // }

    Duration delay;
    if (news) {
      delay = const Duration(seconds: 116);
    } else if (isInitialAd) {
      delay = const Duration(seconds: 25);
    } else {
      delay = _metadataResetDelay;
    }

    final now = DateTime.now();
    
    if (!playing) {
      _metadataResetRemaining = delay;
      _metadataResetDeadline = now.add(delay);
      debugPrint('Skipping metadata reset scheduling while playback is paused.');
      return;
    }

    if (extendIfNeeded && _metadataResetDeadline != null) {
      final remaining = _metadataResetDeadline!.difference(now);

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
    _metadataResetRemaining = delay;
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
    if (isInitialAd) {
      isInitialAd = false;
      notifyListeners();
    }
    
    setMetaData(null, null);
  }

  Future<void> initialize() async {
    await _init();
  }

  void setPlayBackState(ProcessingState? processingState) {
    playbackState.add(
      PlaybackState(
        controls: [
          if (processingState == ProcessingState.ready || (processingState == ProcessingState.buffering && connection))
            (_player.playing ? MediaControl.pause : MediaControl.play),
          if (processingState == ProcessingState.ready && connection && !isInitialAd)
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
  }

  Future<void> _init() async {
    // 1. Broadcast the item currently playing so the system draws the notification UI
    setMetaData(null, null);

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
      if (connection) {
        connection = false;
        notifyListeners();
      }
      print('Error loading audio source: $e');
    }

    // 3. Listen to playback events and mirror them to AudioService
    _player.playbackEventStream.listen((event) {
      if (processingState != event.processingState) {
        processingState = event.processingState;
        notifyListeners();

        if (processingState != .ready && isInitialAd && playing && !connection) {
          debugPrint("initial ad didn't finish, stopping reset timer");
          _resetMetadataResetTimer();
          final locale = WidgetsBinding.instance.platformDispatcher.locale;
          final String title;
          if (locale.languageCode == 'nl') {
            title = "Reclame";
          } else if (locale.languageCode == 'pap') {
            title = "Reklamo";
          } else {
            if (isInitialAd) {
              title = "Advertisement";
            } else {
              title = "Ad break";
            }
          }
          setMetaData(title, null);
        }
      }

      setPlayBackState(processingState); // TODO: check if it can be in there ^

      // playbackState.close();
    });

    

    // 4. Listen to ICY metadata and update the media item accordingly
    _player.icyMetadataStream.listen((metadata) {
      final metadataInfo = metadata?.info?.title?.trim();
      // final genre = metadata?.headers?.genre?.trim();
      debugPrint('ICY metadata received: title="$metadataInfo"');

      if (metadataInfo == null) {
        return;
      }      

      final List<String> parts;
      final String title;
      final String? artist;
      final String metadataKey;
      late final bool isNews;
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
        isNews = false;
        if (isInitialAd) {
          isInitialAd = false;
          notifyListeners();
        }
        metadataKey = '$title|$artist';
      } else {
        // news: JOE nieuws
        artist = null;
        metadataKey = metadataInfo;
        
        if (metadataInfo == "JOE nieuws") {
          title = metadataInfo;
          isNews = true;
          if (isInitialAd) {
            isInitialAd = false;
            notifyListeners();
          }
        } else if (metadataInfo == "Ad break" || metadataInfo == "adbreak" || metadataInfo == "dynamic_break_1" || metadataInfo == "") {
          final locale = WidgetsBinding.instance.platformDispatcher.locale;
          if (locale.languageCode == 'nl') {
            title = "Reclame";
          } else if (locale.languageCode == 'pap') {
            title = "Reklamo";
          } else {
            if (metadataInfo == "") {
              title = "Advertisement";
            } else {
              title = "Ad break";
            }
          }
          isNews = false;          
          if (isInitialAd != (metadataInfo == "")) {
            isInitialAd = metadataInfo == "";
            notifyListeners();
          }
        } else {
          title = metadataInfo;
          isNews = false;
          if (isInitialAd) {
            isInitialAd = false;
            notifyListeners();
          }
        }
      }
      print('anitial ad: $isInitialAd');

      // Ignore repeated metadata unless it is close to expiry, in which case extend the timer.
      if (_currentIcyMetadataKey == metadataKey) {
        _scheduleMetadataReset(extendIfNeeded: true, news: isNews, isInitialAd: isInitialAd);
        return;
      }

      _currentIcyMetadataKey = metadataKey;
      debugPrint('Artist: $artist');
      debugPrint('Song: $title');
      setMetaData(title, artist);
      _scheduleMetadataReset(news: isNews, isInitialAd: isInitialAd);
    });

    // 5. Listen to connectivity changes and update the connection status
    if (kIsWeb) {
      connection = (await Connectivity().checkConnectivity()).first != ConnectivityResult.none;
      debugPrint("initial connectivity: $connection");
      if (!connection) { // when it changed
        notifyListeners();
      }
    }

    Connectivity().onConnectivityChanged.listen((results) {
      debugPrint('Connectivity changed: $results');
      
      if (connection != (results.first != ConnectivityResult.none)) {
        connection = results.first != ConnectivityResult.none;
        debugPrint("verbindingveranderd, verbinding: $connection");
        notifyListeners();

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
        } else if (!connection) {
          setPlayBackState(_player.processingState); // TODO: check if needed
         
        }
      }      
    });
  } // end of init

  @override
  void dispose() {
    super.dispose();
    debugPrint('dispose called, disposing audio player');
    _resetMetadataResetTimer();
    _player.dispose();
  }

  void setMetaData(String? title, String? artist) {
    mediaItem.add(
      MediaItem(
        id: 'joe-radio',
        title: title ?? 'Joe Radio',
        artist: artist,
        genre: 'various',
        isLive: true,
      ),
    );
  }

RadioStatus get status {
  if (_player.processingState == ProcessingState.ready ||(_player.processingState == ProcessingState.buffering && connection)) {
    return playing ? RadioStatus.playing : RadioStatus.paused;
  }
  if (!connection) {
    return RadioStatus.offline;
  }
  if (_player.processingState == ProcessingState.loading) {
    return RadioStatus.loading;
  }

  // if (processingState == AudioProcessingState.error)
  //     return RadioStatus.error;

  return RadioStatus.stopped;
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
    notifyListeners();
  }

  @override
  Future<void> play() async {
    debugPrint('Playing radio...');
    _player.play();
    playing = true;
    notifyListeners();
  }

  double easeOutCubic(double x) {
    return 1 - math.pow(1 - x, 3).toDouble();
  }

  Future<void> startFadeIn() async {
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
    notifyListeners();
  }

  // @override
  // Future<void> skipToPrevious() async {
  //   // skipForward(-5);
  // }

  @override
  Future<void> skipToNext() async {
    if (connection && !isInitialAd) {
      skipForward(5);
    }
  }

  Future<void> setStreamSource(int number) async {
    if (number == streamNumber) return;

    streamNumber = number;
    notifyListeners();
    debugPrint('Switching to stream ${radioStations[streamNumber].name}');
    _resetMetadata();

    final bool oldPlaying = playing;

    try {
      if (kIsWeb) {
        await _player.stop();
      }
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(radioStations[streamNumber].url),
          headers: kIsWeb
            ? null
            : const {'Icy-MetaData': '1'},
        ),
      );
      if (kIsWeb && oldPlaying) {
        _player.play();
      }
    } on Exception catch (e) {
      debugPrint('error:');
      debugPrint(e.toString()); //  Loading interrupted
    }
  }
}

enum RadioStatus {
  playing,
  paused,
  loading,
  offline,
  stopped,
  error,
}

class RadioPage extends StatefulWidget {
  final RadioAudioHandler handler;
 
  const RadioPage({
    super.key,
    required this.handler,
  });

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  // late final RadioControllerProvider _controller;

  @override
  void initState() {
    super.initState();
    // _controller = RadioControllerProvider();
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   _controller.initialize();
    // });
// widget.handler.playbackState.listen((state) {
//   setState(() {});
// });
widget.handler.initialize();
widget.handler.addListener(() {
  setState(() {});
});
  }

  @override
  void dispose() {
    debugPrint('dispose called, disposing radio page');
    widget.handler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ProcessingState processingState = widget.handler.processingState;
    final isConnected = widget.handler.connection;
    final isPlaying = widget.handler.playing;
    final RadioStatus status = widget.handler.status;
    final bool isInitialAd = widget.handler.isInitialAd;
    final int streamNumber = widget.handler.streamNumber;
    final statusText = switch (status) {
      RadioStatus.playing => l10n.playing,
      RadioStatus.paused => l10n.paused,
      RadioStatus.loading => l10n.loading,
      RadioStatus.offline => l10n.offline,
      RadioStatus.stopped => l10n.stopped,
      RadioStatus.error => 'Error',
    };
    final h = MediaQuery.sizeOf(context).height;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joe Radio'),
        centerTitle: true,
        actions: [
          menuItems(l10n, isConnected, processingState, streamNumber, isInitialAd),
        ],
      ),
      body: Align(
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: double.infinity),
            if (h > 340+56)
              const Icon(
                Icons.radio,
                size: 120,
                color: Colors.orange,
              ),
            if (h > 340+56)
              const SizedBox(height: 24),
            if (h > 175+56)
              const Text(
                'Joe',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (h > 175+56)
              const SizedBox(height: 12),
            if (h > 75+56)
              Text(
                statusText,
                style: const TextStyle(fontSize: 18),
              ),
            if (kDebugMode && h > 230+56)
              const SizedBox(height: 12),
            if (kDebugMode && h > 230+56)
              Text(processingState.toString()),
            if (h > 75+56)
              SizedBox(height: (h > 200+56) ? 32 : 12),
            controlButtons(isPlaying, l10n, widget.handler),
          ],
        ),
      ),
    );
        
  }

  Widget menuItems(AppLocalizations l10n, bool isConnected, ProcessingState processingState, int streamNumber, bool isInitialAd) {
    return MenuAnchor(
      animated: true,
      builder: (context, menuController, child) {
        return IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
        );
      },
      menuChildren: [
        skipButton(l10n, isConnected, processingState, isInitialAd),
        liveButton(l10n, isConnected, processingState, isInitialAd),
        SizedBox(
          width: 220,
          height: 56,
          child: ListTile(
            title: Text(l10n.radioStation),
          ),
        ),
        radioStationsWidget(streamNumber),
      ],
    );
  }

  Widget skipButton(AppLocalizations l10n, bool isConnected, ProcessingState processingState, bool isInitialAd) {
    return SizedBox(
      width: 220,
      child: ListTile(
        leading: const Icon(Icons.forward_5),
        title: Text(l10n.skip5Seconds),
        enabled: isConnected && processingState == ProcessingState.ready && !isInitialAd,
        onTap: () {
          widget.handler.skipForward(5);
        },
      ),
    );
  }

  Widget liveButton(AppLocalizations l10n, bool isConnected, ProcessingState processingState, bool isInitialAd) {
    return SizedBox(
      width: 220,
      child: ListTile(
        leading: const Icon(Icons.live_tv),
        title: Text(l10n.playLive),
        enabled: processingState == ProcessingState.ready && !isInitialAd,
        onTap: () {
          widget.handler.playLive();
        },
      ),
    );
  }
      
  Widget radioStationsWidget(final int streamNumber) {
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          radioStations.length,
          (index) {
            final station = radioStations[index];
            return ListTile(
              leading: streamNumber == index
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text(station.name),
              onTap: () {
                if (streamNumber != index) {
                  widget.handler.setStreamSource(index);
                }
              },
            );
          },
        ),
      ),
    );
  }
    
  Widget controlButtons(bool isPlaying, AppLocalizations l10n, RadioAudioHandler controller) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: !isPlaying ? () => controller.play() : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.play),
          style: buttonStyle,
        ),
        ElevatedButton.icon(
          onPressed: isPlaying ? () => controller.pause() : null,
          icon: const Icon(Icons.pause),
          label: Text(l10n.pause),
          style: buttonStyle,
        ),
        if (kDebugMode)
          ElevatedButton.icon(
            onPressed: isPlaying ? () => controller.stop() : null,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),

            style: buttonStyle,
          ),
      ],
    );
  }
}