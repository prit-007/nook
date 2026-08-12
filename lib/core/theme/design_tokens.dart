import 'package:flutter/material.dart';

/// Curated M3-friendly seed palette for per-note theming.
/// Each color is chosen to produce pleasant tonal palettes via ColorScheme.fromSeed.
class NookColors {
  NookColors._();

  static const violet = Color(0xFF6750A4);
  static const teal = Color(0xFF006A6A);
  static const coral = Color(0xFFBF4A3F);
  static const sage = Color(0xFF5A6340);
  static const amber = Color(0xFF7D5700);
  static const rose = Color(0xFF984061);
  static const sky = Color(0xFF0061A4);
  static const slate = Color(0xFF4A5568);
  static const indigo = Color(0xFF4355B9);
  static const mint = Color(0xFF006D3B);
  static const peach = Color(0xFF9C4400);
  static const lavender = Color(0xFF7B4F9A);

  /// All curated seeds for the color picker.
  static const List<Color> seeds = [
    violet,
    teal,
    coral,
    sage,
    amber,
    rose,
    sky,
    slate,
    indigo,
    mint,
    peach,
    lavender,
  ];

  /// Human-readable names for each seed.
  static const List<String> seedNames = [
    'Violet',
    'Teal',
    'Coral',
    'Sage',
    'Amber',
    'Rose',
    'Sky',
    'Slate',
    'Indigo',
    'Mint',
    'Peach',
    'Lavender',
  ];

  /// Default seed when no preference is set.
  static const defaultSeed = violet;

  /// Safely parses a hex color string (e.g. `#6750A4`, `6750A4`, `FF6750A4`)
  /// into a [Color]. Returns [fallback] when [hex] is null, empty, or not
  /// valid hex — callers must never crash on a malformed stored seed.
  static Color parseHex(String? hex, {Color fallback = defaultSeed}) {
    if (hex == null) return fallback;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) return fallback;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }
}
