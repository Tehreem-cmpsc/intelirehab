import 'package:flutter/material.dart';

/// Unicode-aware helper for extracting privacy-conscious patient initials.
/// 
/// Privacy guarantee:
/// - Only extracts the first grapheme cluster of up to two name components.
/// - Never exposes additional parts of the patient's actual name.
/// - Gracefully handles whitespace, empty strings, and diverse Unicode scripts.
class PatientInitialsHelper {
  const PatientInitialsHelper._();

  /// Returns up to 2 uppercase initials for [displayName], or 'P' if empty/whitespace.
  static String extract(String? displayName) {
    if (displayName == null) return 'P';
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'P';

    // Split on whitespace to find word segments
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'P';

    if (words.length == 1) {
      final characters = words.first.characters;
      return characters.isNotEmpty ? characters.first.toUpperCase() : 'P';
    }

    // First word initial and last word initial (e.g., "Ayesha K." -> "AK")
    final firstChar = words.first.characters.isNotEmpty
        ? words.first.characters.first.toUpperCase()
        : '';
    final lastChar = words.last.characters.isNotEmpty
        ? words.last.characters.first.toUpperCase()
        : '';

    final initials = '$firstChar$lastChar';
    return initials.isNotEmpty ? initials : 'P';
  }
}
