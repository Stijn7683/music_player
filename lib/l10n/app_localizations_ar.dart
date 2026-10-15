// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get options => 'الخيارات';

  @override
  String get skip5Seconds => 'تخطي ٥ ثوانٍ';

  @override
  String get playLive => 'استمع مباشرةً';

  @override
  String get playing => 'قيد التشغيل';

  @override
  String get soundOff => 'الصوت مكتوم';

  @override
  String get paused => 'متوقف مؤقتًا';

  @override
  String get offline => 'غير متصل';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get stopped => 'متوقف';

  @override
  String get radioStation => 'محطة الراديو:';
}
