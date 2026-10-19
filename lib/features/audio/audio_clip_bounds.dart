/// Small MPEG frame-padding differences are bounded, never stretched into
/// another verse or an unbounded recording.
({Duration start, Duration end}) checkedAudioClip({
  required Duration duration,
  required Duration start,
  required Duration end,
}) {
  if (duration <= Duration.zero ||
      start < Duration.zero ||
      start >= duration ||
      end <= start ||
      end - duration > const Duration(milliseconds: 250)) {
    throw const FormatException(
      'Audio verse timing differs from media duration',
    );
  }
  return (start: start, end: end > duration ? duration : end);
}
