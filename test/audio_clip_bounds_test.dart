import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/features/audio/audio_clip_bounds.dart';

void main() {
  test(
    'minor MPEG padding clamps the final verse to actual media duration',
    () {
      final bounds = checkedAudioClip(
        duration: const Duration(microseconds: 29518256),
        start: const Duration(seconds: 21),
        end: const Duration(milliseconds: 29547),
      );
      expect(bounds.start, const Duration(seconds: 21));
      expect(bounds.end, const Duration(microseconds: 29518256));
    },
  );

  test(
    '250ms padding is allowed; larger catalog/media mismatch is rejected',
    () {
      expect(
        checkedAudioClip(
          duration: const Duration(seconds: 30),
          start: const Duration(seconds: 20),
          end: const Duration(milliseconds: 30250),
        ).end,
        const Duration(seconds: 30),
      );
      expect(
        () => checkedAudioClip(
          duration: const Duration(seconds: 30),
          start: const Duration(seconds: 20),
          end: const Duration(milliseconds: 30251),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'valid interior timing remains exact; invalid start/range never plays',
    () {
      final bounds = checkedAudioClip(
        duration: const Duration(seconds: 30),
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      );
      expect(bounds, (
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ));
      for (final start in [
        const Duration(milliseconds: -1),
        const Duration(seconds: 30),
        const Duration(seconds: 31),
      ]) {
        expect(
          () => checkedAudioClip(
            duration: const Duration(seconds: 30),
            start: start,
            end: const Duration(seconds: 32),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => checkedAudioClip(
          duration: const Duration(seconds: 30),
          start: const Duration(seconds: 3),
          end: const Duration(seconds: 2),
        ),
        throwsFormatException,
      );
    },
  );
}
