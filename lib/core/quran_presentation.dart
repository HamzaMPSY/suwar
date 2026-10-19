import 'package:flutter/material.dart';
import 'quran_repository.dart';

/// Presentation only. Exact source text and verse identity remain on [Ayah].
/// Split only a verified trailing verse-number marker, never Quran lexical text.
class QuranPresentation {
  QuranPresentation(Ayah ayah) : source = ayah.text, number = ayah.number {
    final match = RegExp(r'(\s+)([٠-٩۰-۹0-9]+)$').firstMatch(source);
    if (match != null && displayNumber(match.group(2)!) == '$number') {
      lexicalText = source.substring(0, match.start);
      separator = match.group(1)!;
      sourceMarker = match.group(2)!;
    } else {
      // Unknown input must remain untouched, rather than stripping scripture.
      lexicalText = source;
      separator = '';
      sourceMarker = null;
    }
  }

  final String source;
  final int number;
  late final String lexicalText, separator;
  late final String? sourceMarker;

  String get accessibleText => sourceMarker == null
      ? source
      : '$lexicalText$separator${displayNumber(number)}';

  TextSpan span(TextStyle style) => TextSpan(
    style: style,
    children: [
      TextSpan(text: lexicalText),
      if (sourceMarker != null)
        TextSpan(
          text: '$separator\u2066${displayNumber(number)}\u2069',
          style: style.copyWith(
            fontFamily: 'NotoSansArabic',
            fontSize: (style.fontSize ?? 28) * .65,
            fontWeight: FontWeight.normal,
          ),
        ),
    ],
  );
}
