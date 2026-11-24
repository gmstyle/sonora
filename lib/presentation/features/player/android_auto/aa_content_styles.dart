import 'package:audio_service/audio_service.dart';

/// Android MediaBrowser extras & Sonora Pulse drawable helpers for Android Auto.
abstract final class AaContentStyles {
  static const String packageName = 'com.gmstyle.sonora';

  static const String contentStyleSupported =
      'android.media.browse.CONTENT_STYLE_SUPPORTED';
  static const String contentStyleBrowsable =
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const String contentStylePlayable =
      'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT';
  static const String contentStyleGroupTitle =
      'android.media.browse.CONTENT_STYLE_GROUP_TITLE_HINT';

  static const int styleList = 1;
  static const int styleGrid = 2;
  static const int styleCategoryList = 3;
  static const int styleCategoryGrid = 4;

  static const String extraIsExplicit = 'android.media.IS_EXPLICIT';

  static Uri drawableUri(String name) =>
      Uri.parse('android.resource://$packageName/drawable/$name');

  static Map<String, dynamic> styleExtras({
    int browsable = styleList,
    int playable = styleList,
    String? groupTitle,
    bool isExplicit = false,
  }) {
    return {
      contentStyleBrowsable: browsable,
      contentStylePlayable: playable,
      if (groupTitle != null && groupTitle.isNotEmpty)
        contentStyleGroupTitle: groupTitle,
      if (isExplicit) extraIsExplicit: 1,
    };
  }

  static MediaItem withExtras(
    MediaItem item, {
    int? browsableStyle,
    int? playableStyle,
    String? groupTitle,
  }) {
    final extras = Map<String, dynamic>.from(item.extras ?? {});
    if (browsableStyle != null) {
      extras[contentStyleBrowsable] = browsableStyle;
    }
    if (playableStyle != null) {
      extras[contentStylePlayable] = playableStyle;
    }
    if (groupTitle != null && groupTitle.isNotEmpty) {
      extras[contentStyleGroupTitle] = groupTitle;
    }
    return item.copyWith(extras: extras);
  }
}
