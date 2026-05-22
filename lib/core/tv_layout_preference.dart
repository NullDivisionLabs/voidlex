import 'package:flutter/services.dart';

/// User-visible setting that picks between the mobile (portrait) UI,
/// the TV (horizontal) UI, and a tablet-friendly "follow device
/// orientation" mode that runs the TV UI regardless of which way the
/// device is held.
///
/// On a real Google TV / Android TV host (detected natively via
/// `UiModeManager` and `FEATURE_LEANBACK`) the TV layout is always
/// used, regardless of this preference — the setting only governs
/// behaviour on phones, tablets, and desktop targets.
enum TvLayoutPreference {
  /// Mobile UI, orientation locked to portrait.
  vertical,

  /// TV UI, orientation locked to landscape. Useful as a dev override
  /// for previewing the 10-foot UI on a phone.
  horizontal,

  /// TV UI, all orientations allowed. The TV canvas is composed at a
  /// fixed 1920×1080 and `FittedBox`-scaled into the available area, so
  /// it adapts cleanly to either tablet orientation.
  autoRotate;

  /// Stable string used in `SharedPreferences`. Hard-coded so a future
  /// rename of an enum value can't silently invalidate stored data.
  String get wireName => switch (this) {
    TvLayoutPreference.vertical => 'vertical',
    TvLayoutPreference.horizontal => 'horizontal',
    TvLayoutPreference.autoRotate => 'auto',
  };

  /// Inverse of [wireName] with a safe fallback for unknown / null
  /// inputs (treat as the conservative default — vertical mobile UI).
  static TvLayoutPreference parse(String? raw) {
    return switch (raw) {
      'vertical' => TvLayoutPreference.vertical,
      'horizontal' => TvLayoutPreference.horizontal,
      'auto' => TvLayoutPreference.autoRotate,
      _ => TvLayoutPreference.vertical,
    };
  }

  /// Whether this preference asks for the 10-foot TV layout. Combined
  /// with the native-TV detection in `TvModeDetector` to decide which
  /// `home:` widget to render.
  bool get prefersTvLayout => this != TvLayoutPreference.vertical;

  /// Orientation lock to apply at the app level when this preference is
  /// active on a phone or tablet. A real TV ignores orientation; the
  /// app-level manager skips applying the lock in that case.
  List<DeviceOrientation> get allowedOrientations => switch (this) {
    TvLayoutPreference.vertical => const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
    TvLayoutPreference.horizontal => const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    TvLayoutPreference.autoRotate => DeviceOrientation.values,
  };
}
