import 'dart:ui' show Locale, PlatformDispatcher;

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';

/// Resolves localized strings for background MediaBrowser calls without a BuildContext.
AppLocalizations resolveAaL10n([Locale? localeOverride]) {
  try {
    final locale = localeOverride ?? PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(locale);
  } catch (_) {
    return AppLocalizationsEn();
  }
}
