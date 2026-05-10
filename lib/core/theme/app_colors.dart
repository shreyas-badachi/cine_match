import 'package:flutter/material.dart';

abstract final class AppColors {
  // Seed color drives the entire Material 3 tonal palette via ColorScheme.fromSeed.
  // Warm crimson reads as cinematic without copying any specific streaming brand.
  static const Color seedCrimson = Color(0xFFB91C1C);

  // Accent kept outside the M3 palette so it stays visually distinct from
  // primary surfaces — used for save-count badges and "match" highlights.
  static const Color accentAmber = Color(0xFFFFB020);

  // Slightly deeper than the M3 default surface for a cinema-feel scaffold.
  static const Color surfaceDim = Color(0xFF0E0E10);
  static const Color surfaceContainer = Color(0xFF1A1A1D);

  static const Color success = Color(0xFF34D399);
}
