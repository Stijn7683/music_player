import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/services.dart';

// Joe Radio - A simple radio streaming app using just_audio and audio_service
// in this version state management will be properly implemented with the use of Provider
late final RadioAudioHandler radioHandler;
const _layoutDirectionChannel = MethodChannel('app/layout_direction');
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
    backgroundColor: Colors.orange.shade400, // const Color.fromRGBO(255, 167, 38, 1)
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

final highContrastLightTheme = lightTheme.copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color.fromARGB(255, 168, 200, 255),
    surface: Color.fromRGBO(255, 246, 227, 1),
    contrastLevel: 1.0,
  ),
  scaffoldBackgroundColor: Color.fromRGBO(255, 246, 227, 1),
  appBarTheme: const AppBarTheme(
    backgroundColor: const Color.fromRGBO(238, 151, 0, 1),
    foregroundColor: Colors.white,
  ),
);

final highContrastDarkTheme = darkTheme.copyWith(
  colorScheme: ColorScheme.fromSeed(
    // seedColor: Color.fromRGBO(209, 147, 45, 0.7),
    seedColor: const Color.fromARGB(255, 229, 236, 254),

    brightness: Brightness.dark,
    surface: Color.fromRGBO(0, 4, 21, 1),
    contrastLevel: 1.0,
  ),
  scaffoldBackgroundColor: Color.fromRGBO(0, 4, 21, 1),
  appBarTheme: AppBarTheme(
    backgroundColor: Color.fromRGBO(209, 147, 45, 0.7), // Color.fromARGB(255, 51, 31, 0),

    // backgroundColor: Colors.white,
    // foregroundColor: Colors.black,
  ),
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isRtl = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readDirection());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_readDirection());
    }
  }

  Future<void> _readDirection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final isRtl = await _layoutDirectionChannel.invokeMethod<bool>('isRtl') ?? false;
      debugPrint('RTL channel returned: $isRtl');
      if (mounted && isRtl != _isRtl) {
        setState(() => _isRtl = isRtl);
      }
    } on MissingPluginException {
      // Keep the framework's locale-based direction when the native channel is unavailable.
      debugPrint('RTL channel failed: MissingPluginException');
    } on PlatformException catch (error) {
      debugPrint('Unable to read Android layout direction: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
    
      highContrastTheme: highContrastLightTheme,
      highContrastDarkTheme: highContrastDarkTheme,
      
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Directionality(
              textDirection:
                _isRtl ? TextDirection.rtl : Directionality.of(context),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
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
  bool deviceSoundOff = false;
  Timer? _metadataResetTimer;
  Timer? _deviceSoundCheckTimer;
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

    final delay = _metadataResetRemaining!;
    _metadataResetRemaining = null;
    final now = DateTime.now();
    _metadataResetDeadline = now.add(delay);
    _metadataResetTimer = Timer(delay, () {
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
      return;
    }

    if (extendIfNeeded && _metadataResetDeadline != null) {
      final remaining = _metadataResetDeadline!.difference(now);

      // If the current timer has less than 20 seconds left
      if (remaining > Duration.zero && remaining < const Duration(seconds: 20)) {
        delay = remaining + (news ? const Duration(seconds: 10) : const Duration(seconds: 15)); // extend it by 15 seconds or 10s when playing news.
        // debugPrint('Extending metadata reset timer by 15 seconds (new timer: ${delay.inSeconds}s)');
      } else {
        // Keep the existing timer when the metadata is unchanged and the countdown is still healthy.
        return;
      }
    }

    _resetMetadataResetTimer();
    _metadataResetRemaining = delay;
    _metadataResetDeadline = now.add(delay);
    
    _metadataResetTimer = Timer(delay, () {
      // set the timer
      _resetMetadata();
    });
  }

  void _resetMetadata() {
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
        playing: playing,
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
        setPlayBackState(processingState);
        notifyListeners();

        if (processingState != .ready && isInitialAd && playing && !connection) {
          // debugPrint("initial ad didn't finish, stopping reset timer");
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
        } else if(processingState == .completed && playing) {
          debugPrint('Stream completed, attempting to reconnect...');
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
      }


      // playbackState.close();
    });

    if (!kIsWeb) {
      FlutterVolumeController.addListener(
        (_) => unawaited(_refreshDeviceSoundState()),
        emitOnStart: true,
      );
    }

    

    // 4. Listen to ICY metadata and update the media item accordingly
    _player.icyMetadataStream.listen((metadata) {
      final metadataInfo = metadata?.info?.title?.trim();
      // final genre = metadata?.headers?.genre?.trim();
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
      if (!connection) { // when it changed
        notifyListeners();
      }
    }

    Connectivity().onConnectivityChanged.listen((results) {      
      if (connection != (results.first != ConnectivityResult.none)) {
        connection = results.first != ConnectivityResult.none;
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
          // setPlayBackState(_player.processingState);
         
        }
      }      
    });
  } // end of init

  @override
  void dispose() {
    super.dispose();
    debugPrint('dispose called, disposing audio player');
    _resetMetadataResetTimer();
    _deviceSoundCheckTimer?.cancel();
    if (!kIsWeb) {
      FlutterVolumeController.removeListener();
    }
    _player.dispose();
  }

  Future<void> _refreshDeviceSoundState() async {
    if (kIsWeb) return;

    try {
      final isMuted = await FlutterVolumeController.getMute();
      if (isMuted != null && deviceSoundOff != isMuted) {
        deviceSoundOff = isMuted;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Unable to read device mute state: $error');
    }
  }

  void setMetaData(String? title, String? artist) {
    debugPrint('Setting metadata: title="$title", artist="$artist"');
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
    setPlayBackState(processingState);
    notifyListeners();
  }

  @override
  Future<void> play() async {
    // debugPrint('Playing radio...');
    _player.play();
    playing = true;
    setPlayBackState(processingState);
    notifyListeners();
  }

  double easeOutCubic(double x) {
    return 1 - math.pow(1 - x, 3).toDouble();
  }

  Future<void> startFadeIn() async {
    playing = true;
    setPlayBackState(processingState);
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
    _pauseMetadataResetTimer();
    _player.pause();
    playing = false;
    setPlayBackState(processingState);
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
    final statusText = (status == .playing || status == .loading) && widget.handler.deviceSoundOff
        ? l10n.soundOff
        : switch (status) {
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
          tooltip: l10n.options,
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
        SizedBox(height: 8),
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