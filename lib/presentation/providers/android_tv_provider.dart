import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the Android TV shell should be used.
///
/// Overridden in [main] after [AndroidTv.isAndroidTv]. Defaults to `false`
/// so phone/desktop tests and previews stay on the touch shells.
final isAndroidTvProvider = Provider<bool>((ref) => false);
