import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

final ValueNotifier<bool> webHighContrastEnabled = ValueNotifier(false);

final List<web.MediaQueryList> _contrastQueries = [
  web.window.matchMedia('(forced-colors: active)'),
  web.window.matchMedia('(prefers-contrast: more)'),
];

bool _initialized = false;

bool get _isHighContrast =>
    _contrastQueries.any((query) => query.matches);

void _handleContrastChange(web.Event event) {
  debugPrint('[contrast] Browser preference changed: ${event.type}');

  webHighContrastEnabled.value = _isHighContrast;
  debugPrint(
    '[contrast] webHighContrastEnabled=${webHighContrastEnabled.value}',
  );
}

final JSFunction _changeListener = _handleContrastChange.toJS;

void initializeWebHighContrastDetection() {
  if (_initialized) return;

  for (final query in _contrastQueries) {
    debugPrint('[contrast] Listening to: ${query.media}');
    query.addEventListener('change', _changeListener);
  }
  _initialized = true;

  webHighContrastEnabled.value = _isHighContrast;
}