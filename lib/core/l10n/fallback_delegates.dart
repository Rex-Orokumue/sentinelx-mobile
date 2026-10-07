import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'gen/app_localizations.dart';

/// Material, Widgets and Cupertino ship no Pidgin (`pcm`). Without a delegate for a locale the framework
/// cannot find MaterialLocalizations and any TextField or picker throws. This wraps each Global delegate so
/// an unsupported locale loads English instead; the app's own strings still come from [AppLocalizations].
class _FallbackDelegate<T> extends LocalizationsDelegate<T> {
  const _FallbackDelegate(this._inner);
  final LocalizationsDelegate<T> _inner;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => _inner.load(_inner.isSupported(locale) ? locale : const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

final List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  _FallbackDelegate<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
  _FallbackDelegate<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
  _FallbackDelegate<CupertinoLocalizations>(GlobalCupertinoLocalizations.delegate),
];
