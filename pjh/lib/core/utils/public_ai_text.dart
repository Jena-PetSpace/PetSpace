/// Removes confidence percentages embedded by the legacy emotion-share caption.
///
/// Stored captions remain untouched. Public rendering and sharing use this
/// function so ordinary user-authored percentages remain unchanged.
String publicAiText(String text) {
  final sanitized = text.replaceAllMapped(
    RegExp(
      r'(^|\s)\d{1,3}(?:\.\d+)?%\s*(?=(?:🐾\s*)?AI\s*감정\s*분석\s*결과)',
    ),
    (match) => match.group(1) ?? '',
  );
  return sanitized.replaceAll(RegExp(r' {2,}'), ' ').trim();
}
